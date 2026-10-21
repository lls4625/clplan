import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import 'app_database.dart';
import 'models.dart';

class _AlarmCandidate {
  const _AlarmCandidate({
    required this.title,
    required this.ownerType,
    required this.ownerId,
    required this.rule,
    required this.fireAt,
  });

  final String title;
  final String ownerType;
  final String ownerId;
  final TaskReminderRule rule;
  final DateTime fireAt;

  String get requestId => '$ownerType:$ownerId:alarm:${rule.id}';
}

class AlarmService {
  AlarmService(this.db);

  static const _channel = MethodChannel('vip.ichiki.javalee.clplan/alarm_kit');

  final AppDatabase db;

  Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<AlarmPermissionState> permissionState() async {
    if (!await isSupported()) return AlarmPermissionState.unsupported;
    try {
      final value = await _channel.invokeMethod<String>('authorizationState');
      return switch (value) {
        'authorized' => AlarmPermissionState.authorized,
        'denied' => AlarmPermissionState.denied,
        _ => AlarmPermissionState.notDetermined,
      };
    } catch (_) {
      return AlarmPermissionState.unsupported;
    }
  }

  Future<AlarmPermissionState> requestPermission() async {
    if (!await isSupported()) return AlarmPermissionState.unsupported;
    try {
      final value = await _channel.invokeMethod<String>('requestAuthorization');
      return switch (value) {
        'authorized' => AlarmPermissionState.authorized,
        'denied' => AlarmPermissionState.denied,
        _ => AlarmPermissionState.notDetermined,
      };
    } catch (_) {
      return AlarmPermissionState.denied;
    }
  }

  Future<bool> openSettings() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelOwner(String ownerType, String ownerId) async {
    final jobs = await db.getAlarmJobs(ownerType: ownerType, ownerId: ownerId);
    for (final job in jobs) {
      await _cancel(job.alarmId);
    }
    await db.deleteAlarmJobsForOwner(ownerType, ownerId);
  }

  Future<void> reconcileAll(
    List<TaskItem> tasks,
    List<PlanItem> plans, {
    required bool Function(TaskItem task) isDone,
    bool requestPermission = false,
  }) async {
    final now = DateTime.now();
    final candidates = <_AlarmCandidate>[];
    for (final task in tasks) {
      if (!task.reminderEnabled || isDone(task)) continue;
      for (final rule in task.reminders.where(
        (item) =>
            item.enabled && item.deliveryType == ReminderDeliveryType.alarm,
      )) {
        final fireAt = rule.fireDateFor(
          startDate: task.startDate,
          startTime: task.startTime,
        );
        if (fireAt != null && fireAt.isAfter(now)) {
          candidates.add(
            _AlarmCandidate(
              title: task.title,
              ownerType: 'task',
              ownerId: task.id,
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
            item.enabled && item.deliveryType == ReminderDeliveryType.alarm,
      )) {
        final fireAt = rule.fireDateFor(startDate: '', startTime: '');
        if (fireAt != null && fireAt.isAfter(now)) {
          candidates.add(
            _AlarmCandidate(
              title: plan.name,
              ownerType: 'plan',
              ownerId: plan.id,
              rule: rule,
              fireAt: fireAt,
            ),
          );
        }
      }
    }
    candidates.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    final supported = await isSupported();
    var permission = await permissionState();
    if (supported &&
        requestPermission &&
        candidates.isNotEmpty &&
        permission == AlarmPermissionState.notDetermined) {
      permission = await this.requestPermission();
    }

    final oldJobs = await db.getAlarmJobs();
    final oldByRequest = {for (final job in oldJobs) job.requestId: job};
    final expectedRequests = candidates.map((item) => item.requestId).toSet();
    for (final job in oldJobs.where(
      (item) => !expectedRequests.contains(item.requestId),
    )) {
      await _cancel(job.alarmId);
      await db.deleteAlarmJob(job.alarmId);
    }

    final systemAlarmIds = supported ? await _listAlarmIds() : <String>{};
    for (final candidate in candidates) {
      final old = oldByRequest[candidate.requestId];
      final sameSchedule =
          old != null &&
          old.fireAt.toUtc().isAtSameMomentAs(candidate.fireAt.toUtc());
      if (supported &&
          permission == AlarmPermissionState.authorized &&
          sameSchedule &&
          old.state == 'scheduled' &&
          systemAlarmIds.contains(old.alarmId)) {
        continue;
      }
      if (old != null) await _cancel(old.alarmId);

      final alarmId = old?.alarmId ?? _newUuid();
      var state = 'unsupported';
      String? lastError;
      if (supported) {
        if (permission != AlarmPermissionState.authorized) {
          state = 'permission_disabled';
        } else {
          try {
            await _channel.invokeMethod<void>('scheduleAlarm', {
              'alarmId': alarmId,
              'title': candidate.title,
              'fireAtMilliseconds': candidate.fireAt.millisecondsSinceEpoch,
            });
            state = 'scheduled';
          } catch (exception) {
            state = 'failed';
            lastError = exception.toString();
          }
        }
      }
      await db.saveAlarmJob(
        AlarmJob(
          alarmId: alarmId,
          requestId: candidate.requestId,
          ownerType: candidate.ownerType,
          ownerId: candidate.ownerId,
          reminderRuleId: candidate.rule.id,
          fireAt: candidate.fireAt,
          state: state,
          lastError: lastError,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<Set<String>> _listAlarmIds() async {
    try {
      final values = await _channel.invokeListMethod<String>('listAlarms');
      return values?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _cancel(String alarmId) async {
    if (!await isSupported()) return;
    try {
      await _channel.invokeMethod<void>('cancelAlarm', {'alarmId': alarmId});
    } catch (_) {
      // Missing or already-fired alarms are reconciled by the local job table.
    }
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
