import 'package:flutter/material.dart';

import 'app_database.dart';
import 'alarm_service.dart';
import 'l10n/preset_text.dart';
import 'models.dart';
import 'notification_service.dart';
import 'planning/basic_planning_engine.dart';
import 'planning/planning_orchestrator.dart';
import 'planning/unavailable_model_planning_engine.dart';

class AppController extends ChangeNotifier {
  AppController(this.db)
    : notifications = NotificationService(db),
      alarms = AlarmService(db),
      planningOrchestrator = const PlanningOrchestrator(
        basicEngine: BasicPlanningEngine(),
        modelEngine: UnavailableModelPlanningEngine(),
      );

  final AppDatabase db;
  final NotificationService notifications;
  final AlarmService alarms;
  final PlanningOrchestrator planningOrchestrator;
  bool loading = true;
  String? error;
  List<TaskItem> tasks = [];
  List<TaskStatus> statuses = [];
  List<TaskTagDefinition> tagDefinitions = [];
  List<ContactEntry> contacts = [];
  List<CategoryDefinition> categoryDefinitions = [];
  List<ProgressTemplate> progressTemplates = [];
  List<PlanItem> plans = [];
  List<ColumnPreference> columns = [];
  AppPreferences preferences = const AppPreferences();
  ReminderPermissionState reminderPermission =
      ReminderPermissionState.unsupported;
  AlarmPermissionState alarmPermission = AlarmPermissionState.unsupported;
  int scheduledReminderCount = 0;
  int waitingReminderCount = 0;
  int failedReminderCount = 0;
  int scheduledAlarmCount = 0;
  int inactiveAlarmCount = 0;
  int failedAlarmCount = 0;
  String? pendingTaskToOpen;
  String? pendingPlanToOpen;

  Future<void> initialize() async {
    try {
      try {
        await notifications.initialize(_handleNotificationAction);
      } catch (_) {
        // Notification availability must not prevent access to local task data.
      }
      await db.materializeRecurringTasks();
      await reload();
      final pendingAction = notifications.takePendingAction();
      if (pendingAction != null) await _handleNotificationAction(pendingAction);
      await _reconcileReminders();
    } catch (exception) {
      error = exception.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    statuses = await db.getStatuses();
    tagDefinitions = _withFixedQuadrantOrder(await db.getTagDefinitions());
    contacts = await db.getContacts();
    categoryDefinitions = await db.getCategoryDefinitions();
    progressTemplates = await db.getProgressTemplates();
    plans = await db.getPlans();
    tasks = await db.getTasks();
    preferences = await db.getPreferences();
    columns = await db.getColumns();
    loading = false;
    error = null;
    notifyListeners();
  }

  TaskStatus statusOf(String id) => statuses.firstWhere(
    (status) => status.id == id,
    orElse: () => statuses.first,
  );

  bool isDone(TaskItem task) =>
      task.progress?.completed ?? statusOf(task.statusId).completed;

  CategoryDefinition? categoryDefinitionForName(String name) {
    for (final category in categoryDefinitions) {
      if (category.name == name) return category;
    }
    return null;
  }

  CategoryDefinition? categoryDefinitionForId(String? id) {
    if (id == null) return null;
    for (final category in categoryDefinitions) {
      if (category.id == id) return category;
    }
    return null;
  }

  TaskTagDefinition? tagDefinitionForName(String name) {
    for (final tag in tagDefinitions) {
      if (tag.name == name) return tag;
    }
    return null;
  }

  TaskTagDefinition? tagDefinitionForId(String? id) {
    if (id == null) return null;
    for (final tag in tagDefinitions) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  TaskTagDefinition? tagDefinitionForDisplayName(
    String name,
    Locale locale,
  ) {
    for (final tag in tagDefinitions) {
      if (tagDefinitionName(tag, locale) == name || tag.name == name) {
        return tag;
      }
    }
    return null;
  }

  String displayCategoryName(
    String? sourceId,
    String snapshot,
    Locale locale,
  ) {
    final definition = categoryDefinitionForId(sourceId);
    return definition == null
        ? snapshot
        : categoryDefinitionName(definition, locale);
  }

  String displayTagName(TaskTagSnapshot snapshot, Locale locale) {
    final definition = tagDefinitionForId(snapshot.sourceTagId);
    return definition == null
        ? snapshot.name
        : tagDefinitionName(definition, locale);
  }

  String displayProgressTemplateName(
    ProgressSnapshot snapshot,
    Locale locale,
  ) {
    for (final template in progressTemplates) {
      if (template.id == snapshot.sourceTemplateId) {
        return progressTemplateName(template, locale);
      }
    }
    return presetNameForLocale(
      locale: locale,
      id: snapshot.sourceTemplateId ?? '',
      fallback: snapshot.templateName,
      nameSource: snapshot.templateNameSource,
    );
  }

  String displayProgressNodeName(ProgressNode node, Locale locale) {
    final sourceId = node.sourceNodeId;
    if (sourceId != null) {
      for (final template in progressTemplates) {
        for (final definitionNode in template.nodes) {
          if (definitionNode.id == sourceId) {
            return progressNodeName(definitionNode, locale);
          }
        }
      }
    }
    return progressNodeName(node, locale);
  }

  String displayStatusName(TaskStatus status, Locale locale) =>
      taskStatusName(status, locale);

  TaskItem _withSnapshots(TaskItem task) {
    var next = task;
    if (next.progress == null && progressTemplates.isNotEmpty) {
      var snapshot = progressSnapshotForTask(next.id);
      final legacyCompleted = statusOf(next.statusId).completed;
      if (legacyCompleted) {
        final end = snapshot.nodes.firstWhere(
          (node) => node.kind == ProgressNodeKind.end,
          orElse: () => snapshot.nodes.last,
        );
        snapshot = snapshot.copyWith(currentNodeId: end.id);
      }
      next = next.copyWith(progress: snapshot);
    }
    final category = categoryDefinitionForName(next.type);
    if (category != null && next.sourceCategoryId == null) {
      next = next.copyWith(
        sourceCategoryId: category.id,
        categoryColorValue: category.colorValue,
        categoryIconName: category.iconName,
      );
    }
    if (next.tagSnapshots.isEmpty && next.tags.isNotEmpty) {
      next = next.copyWith(
        tagSnapshots: next.tags.map((name) {
          final definition = tagDefinitionForName(name);
          return TaskTagSnapshot(
            sourceTagId: definition?.id,
            name: name,
            colorValue: definition?.colorValue ?? 0xff8e8e93,
            iconName: definition?.iconName ?? 'label',
          );
        }).toList(),
      );
    }
    return next;
  }

  List<TaskItem> childrenOf(String parentId) =>
      tasks.where((task) => task.parentTaskId == parentId).toList()
        ..sort(compareTasks);

  TaskItem? taskById(String? id) {
    if (id == null) return null;
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  PlanItem? planById(String? id) {
    if (id == null) return null;
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  ContactEntry? contactById(String? id) {
    if (id == null) return null;
    for (final contact in contacts) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  int compareTasks(TaskItem a, TaskItem b) {
    final dateCompare = (a.startDate.isEmpty ? '9999' : a.startDate).compareTo(
      b.startDate.isEmpty ? '9999' : b.startDate,
    );
    if (dateCompare != 0) return dateCompare;
    final timeCompare = (a.startTime.isEmpty ? '99' : a.startTime).compareTo(
      b.startTime.isEmpty ? '99' : b.startTime,
    );
    if (timeCompare != 0) return timeCompare;
    return a.title.compareTo(b.title);
  }

  Future<void> saveTask(
    TaskItem task, {
    String? followup,
    List<String> history = const [],
  }) async {
    if (task.title.trim().characters.length > 100) {
      throw StateError('任务名称最多 100 个字符。');
    }
    if (task.description.characters.length > 200) {
      throw StateError('任务内容最多 200 个字符。');
    }
    if (task.planId == null && taskById(task.id) == null) {
      throw StateError('任务必须从计划详情中新增。');
    }
    if (task.planId != null && !plans.any((plan) => plan.id == task.planId)) {
      throw StateError('任务所属的计划不存在。');
    }
    if (task.parentTaskId != null) {
      final parent = taskById(task.parentTaskId);
      if (parent == null) throw StateError('选择的主任务不存在。');
      if (parent.parentTaskId != null) throw StateError('当前版本只支持一层子任务。');
      if (parent.id == task.id) throw StateError('任务不能成为自己的子任务。');
    }
    var next = _withSnapshots(task);
    if (next.contacts.isEmpty && next.contact.trim().isNotEmpty) {
      final contact = await saveContact(name: next.contact, phone: '');
      next = next.copyWith(contacts: [contact]);
    }
    await db.saveTask(next, followup: followup, history: history);
    await reload();
    final activeReminders = next.reminderEnabled && !isDone(next)
        ? next.reminders
        : const <TaskReminderRule>[];
    await _reconcileReminders(
      requestNotificationPermission: activeReminders.any(
        (item) => item.deliveryType == ReminderDeliveryType.notification,
      ),
      requestAlarmPermission: activeReminders.any(
        (item) => item.deliveryType == ReminderDeliveryType.alarm,
      ),
    );
  }

  Future<ContactEntry> saveContact({
    String? id,
    required String name,
    required String phone,
    String remark = '',
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final trimmedRemark = remark.trim();
    if (trimmedName.isEmpty) throw StateError('请输入联系人。');
    if (trimmedRemark.characters.length > maxContactRemarkLength) {
      throw StateError('联系人备注最多 $maxContactRemarkLength 个字符。');
    }
    for (final contact in contacts) {
      if (contact.name.toLowerCase() == trimmedName.toLowerCase() &&
          contact.phone == trimmedPhone) {
        if (contact.id == id) continue;
        if (id == null) return contact;
        throw StateError('相同姓名和电话的联系人已存在。');
      }
    }
    final contact = ContactEntry(
      id: id ?? 'contact-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmedName,
      phone: trimmedPhone,
      remark: trimmedRemark,
    );
    await db.saveContact(contact);
    await reload();
    return contact;
  }

  Future<void> deleteContact(String id) async {
    await db.deleteContact(id);
    await reload();
  }

  Future<void> deleteTask(TaskItem task) async {
    final children = childrenOf(task.id);
    if (children.isNotEmpty) throw StateError('请先删除或移走该主任务下的子任务。');
    await notifications.cancelTask(task.id);
    await alarms.cancelOwner('task', task.id);
    await db.deleteTask(task.id);
    await reload();
    await _reconcileReminders();
  }

  Future<void> setPreference(String key, String value) async {
    await db.savePreference(key, value);
    preferences = switch (key) {
      'theme' => preferences.copyWith(theme: value),
      'language' => preferences.copyWith(language: value),
      'calendar_density' => preferences.copyWith(calendarDensity: value),
      'default_reminder_minutes' => preferences.copyWith(
        defaultReminderMinutes: int.tryParse(value) ?? -1,
      ),
      'reminder_sound' => preferences.copyWith(reminderSound: value == 'true'),
      'require_authentication_on_launch' => preferences.copyWith(
        requireAuthenticationOnLaunch: value == 'true',
      ),
      'require_authentication_for_export' => preferences.copyWith(
        requireAuthenticationForExport: value == 'true',
      ),
      _ => preferences,
    };
    notifyListeners();
    if (key == 'reminder_sound') await _reconcileReminders();
  }

  Future<void> setSecurityPreferences({
    bool? requireAuthenticationOnLaunch,
    bool? requireAuthenticationForExport,
  }) async {
    if (requireAuthenticationOnLaunch != null) {
      await db.savePreference(
        'require_authentication_on_launch',
        '$requireAuthenticationOnLaunch',
      );
    }
    if (requireAuthenticationForExport != null) {
      await db.savePreference(
        'require_authentication_for_export',
        '$requireAuthenticationForExport',
      );
    }
    preferences = preferences.copyWith(
      requireAuthenticationOnLaunch: requireAuthenticationOnLaunch,
      requireAuthenticationForExport: requireAuthenticationForExport,
    );
    notifyListeners();
  }

  Future<void> setFontScalePreferences({
    required bool followSystem,
    required double scale,
  }) async {
    final normalizedScale = scale
        .clamp(AppPreferences.minimumFontScale, AppPreferences.maximumFontScale)
        .toDouble();
    await db.savePreference(
      'follow_system_font_scale',
      followSystem.toString(),
    );
    await db.savePreference('font_scale', normalizedScale.toString());
    preferences = preferences.copyWith(
      followSystemFontScale: followSystem,
      fontScale: normalizedScale,
    );
    notifyListeners();
  }

  Future<void> setPlanCompletionStyles(
    PlanCompletionStyleScope scope,
    Set<PlanCompletionStyle> styles,
  ) async {
    final normalized = Set<PlanCompletionStyle>.of(styles);
    if (scope == PlanCompletionStyleScope.calendarMonth) {
      normalized.remove(PlanCompletionStyle.check);
    }
    final key = switch (scope) {
      PlanCompletionStyleScope.calendarMonth =>
        'calendar_month_completion_styles',
      PlanCompletionStyleScope.calendarWeek =>
        'calendar_week_completion_styles',
      PlanCompletionStyleScope.quadrant => 'quadrant_completion_styles',
    };
    final stored = PlanCompletionStyle.values
        .where(normalized.contains)
        .map((style) => style.name)
        .join(',');
    await db.savePreference(key, stored);
    preferences = switch (scope) {
      PlanCompletionStyleScope.calendarMonth => preferences.copyWith(
        calendarMonthCompletionStyles: normalized,
      ),
      PlanCompletionStyleScope.calendarWeek => preferences.copyWith(
        calendarWeekCompletionStyles: normalized,
      ),
      PlanCompletionStyleScope.quadrant => preferences.copyWith(
        quadrantCompletionStyles: normalized,
      ),
    };
    notifyListeners();
  }

  Future<void> saveCalendarDensityHeights({
    required double small,
    required double medium,
    required double large,
  }) async {
    double limited(double value) => value
        .clamp(
          AppPreferences.minimumCalendarRowHeight,
          AppPreferences.maximumCalendarRowHeight,
        )
        .toDouble();

    final smallHeight = limited(small);
    final mediumHeight = limited(medium);
    final largeHeight = limited(large);
    await db.savePreference('calendar_small_height', '$smallHeight');
    await db.savePreference('calendar_medium_height', '$mediumHeight');
    await db.savePreference('calendar_large_height', '$largeHeight');
    preferences = preferences.copyWith(
      calendarSmallHeight: smallHeight,
      calendarMediumHeight: mediumHeight,
      calendarLargeHeight: largeHeight,
    );
    notifyListeners();
  }

  Future<void> saveCalendarWeeklyCardHeight(double height) async {
    final limitedHeight = height
        .clamp(1.0, AppPreferences.maximumCalendarWeeklyCardHeight)
        .toDouble();
    await db.savePreference('calendar_weekly_card_height', '$limitedHeight');
    preferences = preferences.copyWith(calendarWeeklyCardHeight: limitedHeight);
    notifyListeners();
  }

  Future<void> saveStatus(TaskStatus status) async {
    await db.saveStatus(status);
    await reload();
  }

  Future<void> saveTagDefinition(TaskTagDefinition tag, Locale locale) async {
    final name = tag.name.trim();
    if (name.isEmpty) throw StateError('标签名称不能为空。');
    TaskTagDefinition? existing;
    for (final item in tagDefinitions) {
      if (item.id == tag.id) existing = item;
    }
    if (existing == null && tagDefinitions.length >= maxTagDefinitionCount) {
      throw StateError('标签最多 $maxTagDefinitionCount 个。');
    }
    if (name.characters.length > maxTagNameLength && existing?.name != name) {
      throw StateError('标签名称最多 $maxTagNameLength 个字符。');
    }
    if (existing?.isQuadrant == true &&
        (name != existing!.name ||
            tag.colorValue != existing.colorValue ||
            tag.iconName != existing.iconName ||
            tag.sortOrder != existing.sortOrder)) {
      throw StateError('四象限默认标签不能修改。');
    }
    final duplicate = tagDefinitions.any(
      (item) =>
          item.id != tag.id &&
          tagDefinitionName(item, locale).toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) throw StateError('标签名称不能重复。');
    final keepsSystemName =
        existing != null &&
        existing.nameSource == NameSource.system &&
        name == tagDefinitionName(existing, locale);
    await db.saveTagDefinition(
      tag.copyWith(
        name: keepsSystemName ? existing!.name : name,
        nameSource: keepsSystemName
            ? NameSource.system
            : existing == null
            ? NameSource.user
            : name == existing.name
            ? existing.nameSource
            : NameSource.user,
      ),
    );
    await reload();
  }

  Future<void> reorderTagDefinitions(int oldIndex, int newIndex) async {
    final previous = tagDefinitions;
    final fixed = tagDefinitions.where((tag) => tag.isQuadrant).toList();
    final reorderable = tagDefinitions.where((tag) => !tag.isQuadrant).toList();
    if (oldIndex < 0 ||
        oldIndex >= reorderable.length ||
        newIndex < 0 ||
        newIndex >= reorderable.length) {
      throw StateError('标签排序位置无效。');
    }
    final moved = reorderable.removeAt(oldIndex);
    reorderable.insert(newIndex, moved);
    final next = [...fixed, ...reorderable];
    final normalized = [
      for (var index = 0; index < next.length; index++)
        next[index].copyWith(sortOrder: index),
    ];
    tagDefinitions = normalized;
    notifyListeners();
    try {
      await db.saveTagDefinitionOrder(normalized);
    } catch (_) {
      tagDefinitions = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveCategoryDefinition(
    CategoryDefinition category,
    Locale locale,
  ) async {
    final name = category.name.trim();
    if (name.isEmpty) throw StateError('分类名称不能为空。');
    CategoryDefinition? existing;
    for (final item in categoryDefinitions) {
      if (item.id == category.id) existing = item;
    }
    if (existing == null &&
        categoryDefinitions.length >= maxCategoryDefinitionCount) {
      throw StateError('分类最多 $maxCategoryDefinitionCount 个。');
    }
    if (name.characters.length > maxCategoryNameLength &&
        existing?.name != name) {
      throw StateError('分类名称最多 $maxCategoryNameLength 个字符。');
    }
    final duplicate = categoryDefinitions.any(
      (item) =>
          item.id != category.id &&
          categoryDefinitionName(item, locale).toLowerCase() ==
              name.toLowerCase(),
    );
    if (duplicate) throw StateError('分类名称不能重复。');
    final keepsSystemName =
        existing != null &&
        existing.nameSource == NameSource.system &&
        name == categoryDefinitionName(existing, locale);
    await db.saveCategoryDefinition(
      category.copyWith(
        name: keepsSystemName ? existing!.name : name,
        nameSource: keepsSystemName
            ? NameSource.system
            : existing == null
            ? NameSource.user
            : name == existing.name
            ? existing.nameSource
            : NameSource.user,
      ),
    );
    await reload();
  }

  Future<void> reorderCategoryDefinitions(int oldIndex, int newIndex) async {
    final previous = categoryDefinitions;
    final next = [...categoryDefinitions];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    final normalized = [
      for (var index = 0; index < next.length; index++)
        next[index].copyWith(sortOrder: index),
    ];
    categoryDefinitions = normalized;
    notifyListeners();
    try {
      await db.saveCategoryDefinitionOrder(normalized);
    } catch (_) {
      categoryDefinitions = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCategoryDefinition(String id) async {
    await db.deleteCategoryDefinition(id);
    final remaining = categoryDefinitions
        .where((item) => item.id != id)
        .toList();
    final normalized = [
      for (var index = 0; index < remaining.length; index++)
        remaining[index].copyWith(sortOrder: index),
    ];
    await db.saveCategoryDefinitionOrder(normalized);
    await reload();
  }

  Future<void> saveProgressTemplate(
    ProgressTemplate template,
    Locale locale,
  ) async {
    final name = template.name.trim();
    if (name.isEmpty) throw StateError('进度方案名称不能为空。');
    ProgressTemplate? existing;
    for (final item in progressTemplates) {
      if (item.id == template.id) existing = item;
    }
    if (existing == null &&
        progressTemplates.length >= maxProgressTemplateCount) {
      throw StateError('进度方案最多 $maxProgressTemplateCount 套。');
    }
    if (name.characters.length > maxProgressTemplateNameLength &&
        existing?.name != name) {
      throw StateError('进度方案名称最多 $maxProgressTemplateNameLength 个字符。');
    }
    if (template.nodes.length > maxProgressNodeCount) {
      throw StateError('每套进度方案最多 $maxProgressNodeCount 个节点。');
    }
    for (final node in template.nodes) {
      ProgressNode? existingNode;
      if (existing != null) {
        for (final item in existing.nodes) {
          if (item.id == node.id) existingNode = item;
        }
      }
      if (node.name.characters.length > maxProgressNodeNameLength &&
          existingNode?.name != node.name) {
        throw StateError('进度节点名称最多 $maxProgressNodeNameLength 个字符。');
      }
    }
    if (template.nodes
            .where((node) => node.kind == ProgressNodeKind.start)
            .length !=
        1) {
      throw StateError('每套进度必须且只能有一个开始节点。');
    }
    if (!template.nodes.any((node) => node.kind == ProgressNodeKind.end)) {
      throw StateError('每套进度至少需要一个结束节点。');
    }
    final duplicate = progressTemplates.any(
      (item) =>
          item.id != template.id &&
          progressTemplateName(item, locale).toLowerCase() ==
              name.toLowerCase(),
    );
    if (duplicate) throw StateError('进度方案名称不能重复。');
    final keepsSystemName =
        existing != null &&
        existing.nameSource == NameSource.system &&
        name == progressTemplateName(existing, locale);
    final savedNodes = template.nodes.map((node) {
      ProgressNode? previous;
      for (final item in existing?.nodes ?? const <ProgressNode>[]) {
        if (item.id == node.id) previous = item;
      }
      final keepsSystemNodeName =
          previous != null &&
          previous.nameSource == NameSource.system &&
          node.name == progressNodeName(previous, locale);
      return node.copyWith(
        name: keepsSystemNodeName ? previous!.name : node.name,
        sourceNodeId: previous?.sourceNodeId ?? node.sourceNodeId ?? node.id,
        nameSource: keepsSystemNodeName
            ? NameSource.system
            : previous == null
            ? NameSource.user
            : node.name == previous.name
            ? previous.nameSource
            : NameSource.user,
      );
    }).toList();
    await db.saveProgressTemplate(
      template.copyWith(
        name: keepsSystemName ? existing!.name : name,
        nameSource: keepsSystemName
            ? NameSource.system
            : existing == null
            ? NameSource.user
            : name == existing.name
            ? existing.nameSource
            : NameSource.user,
        nodes: savedNodes,
      ),
    );
    await reload();
  }

  Future<void> reorderProgressTemplates(int oldIndex, int newIndex) async {
    final previous = progressTemplates;
    final next = [...progressTemplates];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    final normalized = [
      for (var index = 0; index < next.length; index++)
        next[index].copyWith(sortOrder: index),
    ];
    progressTemplates = normalized;
    notifyListeners();
    try {
      await db.saveProgressTemplateOrder(normalized);
    } catch (_) {
      progressTemplates = previous;
      notifyListeners();
      rethrow;
    }
  }

  List<String> orderedCategoryNames(Iterable<String> historicalNames) =>
      _orderedDefinitionNames(
        categoryDefinitions.map((item) => item.name),
        historicalNames,
      );

  List<String> orderedProgressTemplateNames(Iterable<String> historicalNames) =>
      _orderedDefinitionNames(
        progressTemplates.map((item) => item.name),
        historicalNames,
      );

  List<String> progressNodeNamesForTemplate(
    String templateName,
    Iterable<ProgressSnapshot> historicalProgress,
  ) {
    if (templateName.isEmpty) return const [];

    final result = <String>[];
    final seen = <String>{};
    for (final template in progressTemplates) {
      if (template.name != templateName) continue;
      for (final node in template.nodes) {
        if (node.name.isNotEmpty && seen.add(node.name)) {
          result.add(node.name);
        }
      }
    }

    final historicalNames =
        historicalProgress
            .where((progress) => progress.templateName == templateName)
            .expand((progress) => progress.nodes)
            .map((node) => node.name)
            .where((name) => name.isNotEmpty && !seen.contains(name))
            .toSet()
            .toList()
          ..sort();
    result.addAll(historicalNames);
    return result;
  }

  List<String> orderedTagNames(Iterable<String> historicalNames) =>
      _orderedDefinitionNames(
        tagDefinitions.map((item) => item.name),
        historicalNames,
      );

  List<String> _orderedDefinitionNames(
    Iterable<String> definedNames,
    Iterable<String> historicalNames,
  ) {
    final result = <String>[];
    final seen = <String>{};
    for (final name in definedNames) {
      if (name.isNotEmpty && seen.add(name)) result.add(name);
    }
    final historical =
        historicalNames
            .where((name) => name.isNotEmpty && !seen.contains(name))
            .toSet()
            .toList()
          ..sort();
    result.addAll(historical);
    return result;
  }

  List<TaskTagDefinition> _withFixedQuadrantOrder(
    List<TaskTagDefinition> definitions,
  ) {
    final quadrants = <TaskTagDefinition>[];
    for (final expected in defaultQuadrantTags) {
      for (final definition in definitions) {
        if (definition.id == expected.id || definition.name == expected.name) {
          quadrants.add(definition);
          break;
        }
      }
    }
    return [
      ...quadrants,
      ...definitions.where((definition) => !definition.isQuadrant),
    ];
  }

  Future<bool> deleteProgressTemplate(String id) async {
    if (progressTemplates.length <= 1) return false;
    await db.deleteProgressTemplate(id);
    final remaining = progressTemplates.where((item) => item.id != id).toList();
    final normalized = [
      for (var index = 0; index < remaining.length; index++)
        remaining[index].copyWith(sortOrder: index),
    ];
    await db.saveProgressTemplateOrder(normalized);
    await reload();
    return true;
  }

  ProgressSnapshot progressSnapshotForTask(
    String taskId, {
    String? templateId,
  }) {
    final template = progressTemplates.firstWhere(
      (item) => item.id == templateId,
      orElse: () => progressTemplates.first,
    );
    final instanceId = 'task-progress-$taskId';
    final nodes = template.nodes
        .map(
          (node) => ProgressNode(
            id: '$instanceId-${node.id}',
            name: node.name,
            sourceNodeId: node.sourceNodeId ?? node.id,
            nameSource: node.nameSource,
            colorValue: node.colorValue,
            kind: node.kind,
            sortOrder: node.sortOrder,
          ),
        )
        .toList();
    final start = nodes.firstWhere(
      (node) => node.kind == ProgressNodeKind.start,
      orElse: () => nodes.first,
    );
    return ProgressSnapshot(
      instanceId: instanceId,
      sourceTemplateId: template.id,
      templateName: template.name,
      templateNameSource: template.nameSource,
      currentNodeId: start.id,
      nodes: nodes,
    );
  }

  ProgressSnapshot progressSnapshot(String instanceId, {String? templateId}) {
    final template = progressTemplates.firstWhere(
      (item) => item.id == templateId,
      orElse: () => progressTemplates.first,
    );
    final nodes = template.nodes
        .map(
          (node) => ProgressNode(
            id: '$instanceId-${node.id}',
            name: node.name,
            sourceNodeId: node.sourceNodeId ?? node.id,
            nameSource: node.nameSource,
            colorValue: node.colorValue,
            kind: node.kind,
            sortOrder: node.sortOrder,
          ),
        )
        .toList();
    final start = nodes.firstWhere(
      (node) => node.kind == ProgressNodeKind.start,
      orElse: () => nodes.first,
    );
    return ProgressSnapshot(
      instanceId: instanceId,
      sourceTemplateId: template.id,
      templateName: template.name,
      templateNameSource: template.nameSource,
      currentNodeId: start.id,
      nodes: nodes,
    );
  }

  Future<void> savePlan(PlanItem plan) async {
    if (plan.name.trim().isEmpty) throw StateError('计划名称不能为空。');
    if (plan.name.trim().characters.length > 100) {
      throw StateError('计划名称最多 100 个字符。');
    }
    if (plan.description.characters.length > 200) {
      throw StateError('计划内容最多 200 个字符。');
    }
    if (plan.startDate.compareTo(plan.targetDate) > 0) {
      throw StateError('计划开始日期不能晚于目标日期。');
    }
    for (final milestone in plan.milestones) {
      if (milestone.name.trim().isEmpty) {
        throw StateError('里程碑名称不能为空。');
      }
      if (milestone.date.compareTo(plan.startDate) < 0 ||
          milestone.date.compareTo(plan.targetDate) > 0) {
        throw StateError('里程碑日期必须位于计划日期范围内。');
      }
    }
    for (final rule in plan.rules) {
      if (rule.title.trim().isEmpty) {
        throw StateError('周期任务名称不能为空。');
      }
      if (rule.startDate.compareTo(rule.endDate) > 0) {
        throw StateError('重复任务的开始日期不能晚于结束日期。');
      }
      if (rule.startDate.compareTo(plan.startDate) < 0 ||
          rule.endDate.compareTo(plan.targetDate) > 0) {
        throw StateError('周期任务日期必须位于计划日期范围内。');
      }
    }
    final existing = planById(plan.id);
    final wasCompleted = existing?.progress.completed ?? false;
    final normalized = plan.progress.completed
        ? plan.copyWith(
            completedAt: wasCompleted
                ? plan.completedAt ??
                      existing?.completedAt ??
                      existing?.updatedAt ??
                      plan.updatedAt
                : plan.completedAt ?? DateTime.now(),
          )
        : plan.copyWith(clearCompletedAt: true);
    await db.savePlan(normalized);
    await reload();
    final activeReminders = normalized.reminderEnabled
        ? normalized.reminders
        : const <TaskReminderRule>[];
    await _reconcileReminders(
      requestNotificationPermission: activeReminders.any(
        (item) => item.deliveryType == ReminderDeliveryType.notification,
      ),
      requestAlarmPermission: activeReminders.any(
        (item) => item.deliveryType == ReminderDeliveryType.alarm,
      ),
    );
  }

  Future<void> deletePlan(String id) async {
    if (tasks.any((task) => task.planId == id)) {
      throw StateError('请先删除该计划内的任务。');
    }
    await notifications.cancelTask(id);
    await alarms.cancelOwner('plan', id);
    await db.deletePlan(id);
    await reload();
    await _reconcileReminders();
  }

  Future<void> refreshNotifications() => _reconcileReminders();

  Future<void> refreshAfterResume() async {
    await db.materializeRecurringTasks();
    await reload();
    await _reconcileReminders();
  }

  Future<bool> requestReminderPermission() async {
    final granted = await notifications.requestPermission();
    await _reconcileReminders();
    return granted;
  }

  Future<AlarmPermissionState> requestAlarmPermission() async {
    final state = await alarms.requestPermission();
    await _reconcileReminders();
    return state;
  }

  Future<bool> openReminderSettings() =>
      notifications.openNotificationSettings();

  Future<bool> openAlarmSettings() => alarms.openSettings();

  String? takePendingTaskToOpen() {
    final value = pendingTaskToOpen;
    pendingTaskToOpen = null;
    return value;
  }

  String? takePendingPlanToOpen() {
    final value = pendingPlanToOpen;
    pendingPlanToOpen = null;
    return value;
  }

  Future<void> _reconcileReminders({
    bool requestNotificationPermission = false,
    bool requestAlarmPermission = false,
  }) async {
    await notifications.reconcileAll(
      tasks,
      plans,
      isDone: isDone,
      sound: preferences.reminderSound,
      language: preferences.language,
      requestPermission: requestNotificationPermission,
    );
    await alarms.reconcileAll(
      tasks,
      plans,
      isDone: isDone,
      requestPermission: requestAlarmPermission,
    );
    reminderPermission = await notifications.permissionState();
    alarmPermission = await alarms.permissionState();
    final jobs = await db.getNotificationJobs();
    scheduledReminderCount = jobs
        .where((job) => job.state == 'scheduled')
        .length;
    waitingReminderCount = jobs
        .where(
          (job) =>
              job.state == 'waiting_window' ||
              job.state == 'permission_disabled',
        )
        .length;
    failedReminderCount = jobs.where((job) => job.state == 'failed').length;
    final alarmJobs = await db.getAlarmJobs();
    scheduledAlarmCount = alarmJobs
        .where((job) => job.state == 'scheduled')
        .length;
    inactiveAlarmCount = alarmJobs
        .where(
          (job) =>
              job.state == 'permission_disabled' || job.state == 'unsupported',
        )
        .length;
    failedAlarmCount = alarmJobs.where((job) => job.state == 'failed').length;
    notifyListeners();
  }

  Future<void> _handleNotificationAction(
    ReminderNotificationAction action,
  ) async {
    if (action.ownerType == 'plan') {
      if (planById(action.ownerId) == null) return;
      pendingPlanToOpen = action.ownerId;
      notifyListeners();
      return;
    }
    final task = taskById(action.ownerId);
    if (task == null) return;
    if (action.actionId == NotificationService.completeAction) {
      final end = task.progress?.nodes.firstWhere(
        (node) => node.kind == ProgressNodeKind.end,
        orElse: () => task.progress!.nodes.last,
      );
      final completedStatus = statuses.firstWhere(
        (status) => status.completed,
        orElse: () => statuses.last,
      );
      await saveTask(
        task.copyWith(
          statusId: completedStatus.id,
          completedAt: DateTime.now(),
          progress: end == null
              ? task.progress
              : task.progress?.copyWith(currentNodeId: end.id),
          updatedAt: DateTime.now(),
        ),
        history: const ['通过提醒通知完成任务'],
      );
      return;
    }
    if (action.actionId == NotificationService.snoozeAction) {
      final now = DateTime.now();
      final snooze = TaskReminderRule(
        id: 'reminder-${now.microsecondsSinceEpoch}',
        taskId: task.id,
        type: ReminderRuleType.absolute,
        absoluteAt: now.add(const Duration(minutes: 10)),
        sortOrder: task.reminders.length,
      );
      await saveTask(
        task.copyWith(
          reminderEnabled: true,
          reminders: [...task.reminders, snooze],
          updatedAt: now,
        ),
        history: const ['通过通知设置 10 分钟后再次提醒'],
      );
      return;
    }
    pendingTaskToOpen = task.id;
    notifyListeners();
  }

  Future<void> deleteTagDefinition(String id) async {
    if (tagDefinitions.any((tag) => tag.id == id && tag.isQuadrant)) {
      throw StateError('四象限默认标签不能删除。');
    }
    await db.deleteTagDefinition(id);
    final remaining = tagDefinitions.where((item) => item.id != id).toList();
    final normalized = [
      for (var index = 0; index < remaining.length; index++)
        remaining[index].copyWith(sortOrder: index),
    ];
    await db.saveTagDefinitionOrder(normalized);
    await reload();
  }

  Future<bool> deleteStatus(String id) async {
    if (statuses.length <= 1) return false;
    final deleted = await db.deleteStatus(id);
    if (deleted) await reload();
    return deleted;
  }

  Future<void> saveColumns(List<ColumnPreference> next) async {
    await db.saveColumns(next);
    columns = await db.getColumns();
    notifyListeners();
  }

  Future<void> importTasks(
    List<TaskItem> imported,
    Set<String> overwriteIds,
  ) async {
    final importedById = {for (final task in imported) task.id: task};
    final availableIds = {
      ...tasks.map((task) => task.id),
      ...importedById.keys,
    };
    for (final task in imported) {
      if (task.parentTaskId != null &&
          !availableIds.contains(task.parentTaskId)) {
        throw StateError('任务“${task.title}”引用的主任务不存在。');
      }
      final parent =
          importedById[task.parentTaskId] ?? taskById(task.parentTaskId);
      if (parent?.parentTaskId != null) {
        throw StateError('任务“${task.title}”形成了超过一层的嵌套，当前版本不允许导入。');
      }
      if (task.parentTaskId == task.id) {
        throw StateError('任务“${task.title}”不能关联自身。');
      }
    }
    final ordered = [...imported]
      ..sort((a, b) {
        if (a.parentTaskId == null && b.parentTaskId != null) return -1;
        if (a.parentTaskId != null && b.parentTaskId == null) return 1;
        return 0;
      });
    for (final task in ordered) {
      final existing = taskById(task.id);
      if (existing == null || overwriteIds.contains(task.id)) {
        await db.saveTask(_withSnapshots(task));
      }
    }
    await reload();
    await _reconcileReminders();
  }

  Future<void> importPlans(List<PlanItem> imported) async {
    for (final plan in imported) {
      if (plan.name.trim().isEmpty) {
        throw StateError('导入的计划名称不能为空。');
      }
      if (plan.name.trim().characters.length > 100) {
        throw StateError('计划“${plan.name}”名称超过 100 个字符。');
      }
      if (plan.description.characters.length > 200) {
        throw StateError('计划“${plan.name}”内容超过 200 个字符。');
      }
      if (plan.startDate.isNotEmpty &&
          plan.targetDate.isNotEmpty &&
          plan.startDate.compareTo(plan.targetDate) > 0) {
        throw StateError('计划“${plan.name}”的开始日期晚于目标日期。');
      }
      for (final milestone in plan.milestones) {
        if (milestone.name.trim().isEmpty) {
          throw StateError('计划“${plan.name}”存在名称为空的里程碑。');
        }
        if (milestone.date.compareTo(plan.startDate) < 0 ||
            milestone.date.compareTo(plan.targetDate) > 0) {
          throw StateError('计划“${plan.name}”的里程碑日期超出计划范围。');
        }
      }
      for (final rule in plan.rules) {
        if (rule.title.trim().isEmpty) {
          throw StateError('计划“${plan.name}”存在名称为空的周期任务。');
        }
        if (rule.startDate.compareTo(rule.endDate) > 0) {
          throw StateError('计划“${plan.name}”的周期任务开始日期晚于结束日期。');
        }
        if (rule.startDate.compareTo(plan.startDate) < 0 ||
            rule.endDate.compareTo(plan.targetDate) > 0) {
          throw StateError('计划“${plan.name}”的周期任务日期超出计划范围。');
        }
      }
    }
    for (final plan in imported) {
      await db.savePlan(plan);
    }
    await reload();
    await _reconcileReminders();
  }

  Future<void> importContacts(List<ContactEntry> imported) async {
    final importedIds = imported.map((contact) => contact.id).toSet();
    if (importedIds.length != imported.length) {
      throw StateError('导入文件中存在重复的联系人 ID。');
    }
    final usedIdentities = <String>{
      for (final contact in contacts)
        if (!importedIds.contains(contact.id))
          '${contact.name.trim().toLowerCase()}\u0000${contact.phone.trim()}',
    };
    for (final contact in imported) {
      final name = contact.name.trim();
      final phone = contact.phone.trim();
      final remark = contact.remark.trim();
      if (name.isEmpty) throw StateError('导入的联系人姓名不能为空。');
      if (remark.characters.length > maxContactRemarkLength) {
        throw StateError('联系人“$name”备注最多 $maxContactRemarkLength 个字符。');
      }
      final identity = '${name.toLowerCase()}\u0000$phone';
      if (!usedIdentities.add(identity)) {
        throw StateError('联系人“$name”与现有的姓名和电话重复。');
      }
    }
    for (final contact in imported) {
      await db.saveContact(
        ContactEntry(
          id: contact.id,
          name: contact.name.trim(),
          phone: contact.phone.trim(),
          remark: contact.remark.trim(),
        ),
      );
    }
    await reload();
  }
}
