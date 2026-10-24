import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_database.dart';
import 'l10n/ui_text.dart';
import 'models.dart';

enum ReminderPermissionState { authorized, disabled, unsupported }

class ReminderNotificationAction {
  const ReminderNotificationAction({
    required this.ownerType,
    required this.ownerId,
    this.actionId = '',
  });

  final String ownerType;
  final String ownerId;
  final String actionId;
}

class _ReminderCandidate {
  const _ReminderCandidate({
    required this.title,
    required this.ownerType,
    required this.ownerId,
    required this.startLabel,
    required this.rule,
    required this.fireAt,
  });

  final String title;
  final String ownerType;
  final String ownerId;
  final String startLabel;
  final TaskReminderRule rule;
  final DateTime fireAt;
}

class NotificationService {
  NotificationService(this.db);

  static const taskCategory = 'task_reminder';
  static const completeAction = 'complete';
  static const snoozeAction = 'snooze_10';
  static const maximumScheduledNotifications = 60;

  final AppDatabase db;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> Function(ReminderNotificationAction action)? _onAction;
  ReminderNotificationAction? _pendingAction;
  bool _initialized = false;

  Future<void> initialize(
    Future<void> Function(ReminderNotificationAction action) onAction,
  ) async {
    _onAction = onAction;
    if (!Platform.isIOS) return;

    tz_data.initializeTimeZones();
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    } catch (_) {
      // timezone.local remains usable as a safe fallback.
    }

    final category = DarwinNotificationCategory(
      taskCategory,
      actions: [
        DarwinNotificationAction.plain(
          completeAction,
          '完成',
          options: {DarwinNotificationActionOption.foreground},
        ),
        DarwinNotificationAction.plain(
          snoozeAction,
          '10 分钟后提醒',
          options: {DarwinNotificationActionOption.foreground},
        ),
      ],
    );
    final settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [category],
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _receiveResponse,
    );
    _initialized = true;

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      _pendingAction = _actionFromResponse(response);
    }
  }

  ReminderNotificationAction? takePendingAction() {
    final value = _pendingAction;
    _pendingAction = null;
    return value;
  }

  Future<void> _receiveResponse(NotificationResponse response) async {
    final action = _actionFromResponse(response);
    if (action == null) return;
    final handler = _onAction;
    if (handler == null) {
      _pendingAction = action;
    } else {
      await handler(action);
    }
  }

  ReminderNotificationAction? _actionFromResponse(
    NotificationResponse response,
  ) {
    final payload = response.payload ?? '';
    final separator = payload.indexOf(':');
    if (separator <= 0 || separator == payload.length - 1) return null;
    final ownerType = payload.substring(0, separator);
    if (ownerType != 'task' && ownerType != 'plan') return null;
    final ownerId = payload.substring(separator + 1);
    return ReminderNotificationAction(
      ownerType: ownerType,
      ownerId: ownerId,
      actionId: response.actionId ?? '',
    );
  }

  Future<ReminderPermissionState> permissionState() async {
    if (!Platform.isIOS || !_initialized) {
      return ReminderPermissionState.unsupported;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final options = await ios?.checkPermissions();
    return options?.isEnabled == true
        ? ReminderPermissionState.authorized
        : ReminderPermissionState.disabled;
  }

  Future<bool> requestPermission() async {
    if (!Platform.isIOS || !_initialized) return false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<bool> openNotificationSettings() async {
    if (!Platform.isIOS || !_initialized) return false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.openAppNotificationSettings() ?? false;
  }

  Future<void> cancelTask(String taskId) async {
    if (!_initialized) return;
    final jobs = await db.getNotificationJobs(taskId: taskId);
    for (final job in jobs) {
      await _plugin.cancel(id: job.notificationId);
    }
    await db.deleteNotificationJobsForTask(taskId);
  }

  Future<void> reconcileAll(
    List<TaskItem> tasks,
    List<PlanItem> plans, {
    required bool Function(TaskItem task) isDone,
    required bool sound,
    required String language,
    bool requestPermission = false,
  }) async {
    if (!Platform.isIOS || !_initialized) return;

    final oldJobs = await db.getNotificationJobs();
    for (final job in oldJobs) {
      await _plugin.cancel(id: job.notificationId);
    }
    for (final taskId in oldJobs.map((job) => job.taskId).toSet()) {
      await db.deleteNotificationJobsForTask(taskId);
    }

    var permission = await permissionState();
    if (requestPermission && permission != ReminderPermissionState.authorized) {
      final granted = await this.requestPermission();
      permission = granted
          ? ReminderPermissionState.authorized
          : ReminderPermissionState.disabled;
    }

    final now = DateTime.now();
    final candidates = <_ReminderCandidate>[];
    for (final task in tasks) {
      if (!task.reminderEnabled || isDone(task)) continue;
      for (final rule in task.reminders.where(
        (item) =>
            item.enabled &&
            item.deliveryType == ReminderDeliveryType.notification,
      )) {
        final fireAt = rule.fireDateFor(
          startDate: task.startDate,
          startTime: task.startTime,
        );
        if (fireAt != null && fireAt.isAfter(now)) {
          candidates.add(
            _ReminderCandidate(
              title: task.title,
              ownerType: 'task',
              ownerId: task.id,
              startLabel: task.startTime.isEmpty
                  ? task.startDate
                  : '${task.startDate} ${task.startTime}',
              rule: rule,
              fireAt: fireAt,
            ),
          );
        }
      }
    }
    for (final plan in plans) {
      if (!plan.reminderEnabled) continue;
      for (final rule in plan.reminders.where(
        (item) =>
            item.enabled &&
            item.deliveryType == ReminderDeliveryType.notification,
      )) {
        final fireAt = rule.fireDateFor(startDate: '', startTime: '');
        if (fireAt != null && fireAt.isAfter(now)) {
          candidates.add(
            _ReminderCandidate(
              title: plan.name,
              ownerType: 'plan',
              ownerId: plan.id,
              startLabel: '${plan.startDate} 至 ${plan.targetDate}',
              rule: rule,
              fireAt: fireAt,
            ),
          );
        }
      }
    }
    candidates.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final requestId =
          '${candidate.ownerType}:${candidate.ownerId}:rem:${candidate.rule.id}';
      final notificationId = _stableNotificationId(requestId);
      final shouldSchedule =
          permission == ReminderPermissionState.authorized &&
          i < maximumScheduledNotifications;
      String state;
      String? lastError;
      if (!shouldSchedule) {
        state = permission == ReminderPermissionState.authorized
            ? 'waiting_window'
            : 'permission_disabled';
      } else {
        try {
          await _plugin.zonedSchedule(
            id: notificationId,
            title: candidate.title,
            body: _notificationBody(candidate, language),
            scheduledDate: tz.TZDateTime.from(candidate.fireAt, tz.local),
            notificationDetails: NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentSound: sound,
                presentBadge: true,
                categoryIdentifier: candidate.ownerType == 'task'
                    ? taskCategory
                    : null,
                threadIdentifier: '${candidate.ownerType}-${candidate.ownerId}',
                interruptionLevel: InterruptionLevel.active,
              ),
            ),
            payload: '${candidate.ownerType}:${candidate.ownerId}',
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          state = 'scheduled';
        } catch (exception) {
          state = 'failed';
          lastError = exception.toString();
        }
      }
      await db.saveNotificationJob(
        NotificationJob(
          requestId: requestId,
          notificationId: notificationId,
          taskId: candidate.ownerId,
          reminderRuleId: candidate.rule.id,
          fireAt: candidate.fireAt,
          state: state,
          lastError: lastError,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  String _notificationBody(_ReminderCandidate candidate, String language) {
    final systemLanguage = Platform.localeName.toLowerCase();
    final resolvedLanguage = language == 'system'
        ? systemLanguage.startsWith('zh') &&
                  (systemLanguage.contains('hant') ||
                      systemLanguage.contains('tw') ||
                      systemLanguage.contains('hk'))
              ? 'tw'
              : systemLanguage.startsWith('ja')
              ? 'ja'
              : systemLanguage.startsWith('ko')
              ? 'ko'
              : systemLanguage.startsWith('en')
              ? 'en'
              : 'en'
        : language;
    final locale = switch (resolvedLanguage) {
      'tw' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      'ja' => const Locale('ja'),
      'ko' => const Locale('ko'),
      'en' => const Locale('en'),
      _ => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    };
    final rule = localizeUiTextForLocale(locale, candidate.rule.label);
    final owner = localizeUiTextForLocale(
      locale,
      candidate.ownerType == 'task' ? '任务时间' : '计划期间',
    );
    final range = localizeUiTextForLocale(locale, candidate.startLabel);
    return '$rule · $owner $range';
  }

  int _stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
