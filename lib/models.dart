import 'package:flutter/material.dart';

const maxTagDefinitionCount = 20;
const maxTagNameLength = 30;
const maxCategoryDefinitionCount = 20;
const maxCategoryNameLength = 30;
const maxProgressTemplateCount = 20;
const maxProgressTemplateNameLength = 30;
const maxProgressNodeCount = 20;
const maxProgressNodeNameLength = 30;
const maxContactRemarkLength = 100;

class TaskStatus {
  const TaskStatus({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.completed,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int colorValue;
  final bool completed;
  final int sortOrder;

  Color get color => Color(colorValue);

  TaskStatus copyWith({
    String? id,
    String? name,
    int? colorValue,
    bool? completed,
    int? sortOrder,
  }) => TaskStatus(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    completed: completed ?? this.completed,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  factory TaskStatus.fromMap(Map<String, Object?> map) => TaskStatus(
    id: map['id']! as String,
    name: map['name']! as String,
    colorValue: map['color_value']! as int,
    completed: (map['completed']! as int) == 1,
    sortOrder: map['sort_order']! as int,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'color_value': colorValue,
    'completed': completed ? 1 : 0,
    'sort_order': sortOrder,
  };
}

const Map<String, IconData> taskTagIconChoices = {
  'checklist': Icons.checklist_outlined,
  'calendar': Icons.calendar_today_outlined,
  'schedule': Icons.schedule_outlined,
  'reminder': Icons.notifications_none,
  'repeat': Icons.repeat,
  'deadline': Icons.hourglass_bottom,
  'priority': Icons.priority_high,
  'target': Icons.track_changes,
  'milestone': Icons.flag_outlined,
  'project': Icons.folder_outlined,
  'meeting': Icons.groups_outlined,
  'location': Icons.location_on_outlined,
  'work': Icons.work_outline,
  'study': Icons.school_outlined,
  'home': Icons.home_outlined,
  'fitness': Icons.fitness_center,
  'shopping': Icons.shopping_bag_outlined,
  'travel': Icons.flight_outlined,
};

const Map<String, IconData> taskTagIcons = {
  ...taskTagIconChoices,
  'label': Icons.label_outline,
  'event_note': Icons.event_note_outlined,
  'book': Icons.menu_book_outlined,
  'person': Icons.person_outline,
  'favorite': Icons.favorite_border,
  'star': Icons.star_border,
  'flag': Icons.flag_outlined,
  'lightbulb': Icons.lightbulb_outline,
};

class TaskTagDefinition {
  const TaskTagDefinition({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconName,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int colorValue;
  final String iconName;
  final int sortOrder;

  Color get color => Color(colorValue);
  IconData get icon => taskTagIcons[iconName] ?? Icons.label_outline;
  bool get isQuadrant =>
      quadrantTagIds.contains(id) || quadrantTagNames.contains(name);

  TaskTagDefinition copyWith({
    String? name,
    int? colorValue,
    String? iconName,
    int? sortOrder,
  }) => TaskTagDefinition(
    id: id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    iconName: iconName ?? this.iconName,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  factory TaskTagDefinition.fromMap(Map<String, Object?> map) =>
      TaskTagDefinition(
        id: map['id']! as String,
        name: map['name']! as String,
        colorValue: map['color_value']! as int,
        iconName: map['icon_name']! as String,
        sortOrder: map['sort_order']! as int,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'color_value': colorValue,
    'icon_name': iconName,
    'sort_order': sortOrder,
  };
}

const quadrantTagNames = <String>{'重要且紧急', '重要不紧急', '不重要但紧急', '不重要不紧急'};

const quadrantTagIds = <String>{
  'quadrant-important-urgent',
  'quadrant-important-not-urgent',
  'quadrant-not-important-urgent',
  'quadrant-not-important-not-urgent',
};

const defaultQuadrantTags = <TaskTagDefinition>[
  TaskTagDefinition(
    id: 'quadrant-important-urgent',
    name: '重要且紧急',
    colorValue: 0xffff2d55,
    iconName: 'priority',
    sortOrder: 0,
  ),
  TaskTagDefinition(
    id: 'quadrant-important-not-urgent',
    name: '重要不紧急',
    colorValue: 0xffff9500,
    iconName: 'target',
    sortOrder: 1,
  ),
  TaskTagDefinition(
    id: 'quadrant-not-important-urgent',
    name: '不重要但紧急',
    colorValue: 0xff3478f6,
    iconName: 'schedule',
    sortOrder: 2,
  ),
  TaskTagDefinition(
    id: 'quadrant-not-important-not-urgent',
    name: '不重要不紧急',
    colorValue: 0xff18a67a,
    iconName: 'checklist',
    sortOrder: 3,
  ),
];

const defaultOrdinaryTags = <TaskTagDefinition>[
  TaskTagDefinition(
    id: 'starter-tag-meeting',
    name: '会议',
    colorValue: 0xff6155f5,
    iconName: 'meeting',
    sortOrder: 4,
  ),
  TaskTagDefinition(
    id: 'starter-tag-focus',
    name: '专注',
    colorValue: 0xff007aff,
    iconName: 'target',
    sortOrder: 5,
  ),
  TaskTagDefinition(
    id: 'starter-tag-quick',
    name: '快速处理',
    colorValue: 0xffff8d28,
    iconName: 'checklist',
    sortOrder: 6,
  ),
  TaskTagDefinition(
    id: 'starter-tag-routine',
    name: '例行',
    colorValue: 0xff34c759,
    iconName: 'repeat',
    sortOrder: 7,
  ),
  TaskTagDefinition(
    id: 'starter-tag-outside',
    name: '外出',
    colorValue: 0xff30b0c7,
    iconName: 'location',
    sortOrder: 8,
  ),
  TaskTagDefinition(
    id: 'starter-tag-milestone',
    name: '里程碑',
    colorValue: 0xffff2d55,
    iconName: 'milestone',
    sortOrder: 9,
  ),
];

class CategoryDefinition {
  const CategoryDefinition({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconName,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int colorValue;
  final String iconName;
  final int sortOrder;

  Color get color => Color(colorValue);
  IconData get icon => taskTagIcons[iconName] ?? Icons.folder_outlined;

  CategoryDefinition copyWith({
    String? name,
    int? colorValue,
    String? iconName,
    int? sortOrder,
  }) => CategoryDefinition(
    id: id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    iconName: iconName ?? this.iconName,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  factory CategoryDefinition.fromMap(Map<String, Object?> map) =>
      CategoryDefinition(
        id: map['id']! as String,
        name: map['name']! as String,
        colorValue: map['color_value']! as int,
        iconName: map['icon_name']! as String,
        sortOrder: map['sort_order']! as int,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'color_value': colorValue,
    'icon_name': iconName,
    'sort_order': sortOrder,
  };
}

const defaultCategoryDefinitions = <CategoryDefinition>[
  CategoryDefinition(
    id: 'starter-category-work',
    name: '工作',
    colorValue: 0xff007aff,
    iconName: 'work',
    sortOrder: 0,
  ),
  CategoryDefinition(
    id: 'starter-category-study',
    name: '学习',
    colorValue: 0xff6155f5,
    iconName: 'study',
    sortOrder: 1,
  ),
  CategoryDefinition(
    id: 'starter-category-life',
    name: '生活',
    colorValue: 0xffff8d28,
    iconName: 'home',
    sortOrder: 2,
  ),
  CategoryDefinition(
    id: 'starter-category-health',
    name: '健康',
    colorValue: 0xff34c759,
    iconName: 'fitness',
    sortOrder: 3,
  ),
  CategoryDefinition(
    id: 'starter-category-finance',
    name: '财务',
    colorValue: 0xffffcc00,
    iconName: 'shopping',
    sortOrder: 4,
  ),
];

enum ProgressNodeKind { start, middle, end }

ProgressNodeKind progressNodeKindFromName(String? value) => switch (value) {
  'start' => ProgressNodeKind.start,
  'end' => ProgressNodeKind.end,
  _ => ProgressNodeKind.middle,
};

class ProgressNode {
  const ProgressNode({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.kind,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int colorValue;
  final ProgressNodeKind kind;
  final int sortOrder;

  Color get color => Color(colorValue);
  bool get completed => kind == ProgressNodeKind.end;

  ProgressNode copyWith({
    String? name,
    int? colorValue,
    ProgressNodeKind? kind,
    int? sortOrder,
  }) => ProgressNode(
    id: id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    kind: kind ?? this.kind,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

class ProgressTemplate {
  const ProgressTemplate({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.nodes,
  });

  final String id;
  final String name;
  final int sortOrder;
  final List<ProgressNode> nodes;

  ProgressTemplate copyWith({
    String? name,
    int? sortOrder,
    List<ProgressNode>? nodes,
  }) => ProgressTemplate(
    id: id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    nodes: nodes ?? this.nodes,
  );
}

const defaultProgressTemplates = <ProgressTemplate>[
  ProgressTemplate(
    id: 'default-progress',
    name: '通用进度',
    sortOrder: 0,
    nodes: [
      ProgressNode(
        id: 'default-todo',
        name: '未开始',
        colorValue: 0xff8c91a3,
        kind: ProgressNodeKind.start,
        sortOrder: 0,
      ),
      ProgressNode(
        id: 'default-doing',
        name: '进行中',
        colorValue: 0xff497fc4,
        kind: ProgressNodeKind.middle,
        sortOrder: 1,
      ),
      ProgressNode(
        id: 'default-waiting',
        name: '等待反馈',
        colorValue: 0xffc28a35,
        kind: ProgressNodeKind.middle,
        sortOrder: 2,
      ),
      ProgressNode(
        id: 'default-done',
        name: '已完成',
        colorValue: 0xff3f9875,
        kind: ProgressNodeKind.end,
        sortOrder: 3,
      ),
    ],
  ),
  ProgressTemplate(
    id: 'starter-progress-study',
    name: '学习进度',
    sortOrder: 1,
    nodes: [
      ProgressNode(
        id: 'study-pending',
        name: '待学习',
        colorValue: 0xff8c91a3,
        kind: ProgressNodeKind.start,
        sortOrder: 0,
      ),
      ProgressNode(
        id: 'study-learning',
        name: '学习中',
        colorValue: 0xff497fc4,
        kind: ProgressNodeKind.middle,
        sortOrder: 1,
      ),
      ProgressNode(
        id: 'study-reviewing',
        name: '复习巩固',
        colorValue: 0xff8f63c7,
        kind: ProgressNodeKind.middle,
        sortOrder: 2,
      ),
      ProgressNode(
        id: 'study-mastered',
        name: '已掌握',
        colorValue: 0xff3f9875,
        kind: ProgressNodeKind.end,
        sortOrder: 3,
      ),
    ],
  ),
  ProgressTemplate(
    id: 'starter-progress-life',
    name: '生活进度',
    sortOrder: 2,
    nodes: [
      ProgressNode(
        id: 'life-pending',
        name: '待安排',
        colorValue: 0xff8c91a3,
        kind: ProgressNodeKind.start,
        sortOrder: 0,
      ),
      ProgressNode(
        id: 'life-doing',
        name: '进行中',
        colorValue: 0xff497fc4,
        kind: ProgressNodeKind.middle,
        sortOrder: 1,
      ),
      ProgressNode(
        id: 'life-waiting',
        name: '等待处理',
        colorValue: 0xffc28a35,
        kind: ProgressNodeKind.middle,
        sortOrder: 2,
      ),
      ProgressNode(
        id: 'life-done',
        name: '已完成',
        colorValue: 0xff3f9875,
        kind: ProgressNodeKind.end,
        sortOrder: 3,
      ),
    ],
  ),
  ProgressTemplate(
    id: 'starter-progress-health',
    name: '健康进度',
    sortOrder: 3,
    nodes: [
      ProgressNode(
        id: 'health-pending',
        name: '待开始',
        colorValue: 0xff8c91a3,
        kind: ProgressNodeKind.start,
        sortOrder: 0,
      ),
      ProgressNode(
        id: 'health-doing',
        name: '执行中',
        colorValue: 0xff497fc4,
        kind: ProgressNodeKind.middle,
        sortOrder: 1,
      ),
      ProgressNode(
        id: 'health-maintaining',
        name: '持续保持',
        colorValue: 0xff00c7be,
        kind: ProgressNodeKind.middle,
        sortOrder: 2,
      ),
      ProgressNode(
        id: 'health-achieved',
        name: '已达成',
        colorValue: 0xff3f9875,
        kind: ProgressNodeKind.end,
        sortOrder: 3,
      ),
    ],
  ),
  ProgressTemplate(
    id: 'starter-progress-finance',
    name: '财务进度',
    sortOrder: 4,
    nodes: [
      ProgressNode(
        id: 'finance-planning',
        name: '待规划',
        colorValue: 0xff8c91a3,
        kind: ProgressNodeKind.start,
        sortOrder: 0,
      ),
      ProgressNode(
        id: 'finance-doing',
        name: '执行中',
        colorValue: 0xff497fc4,
        kind: ProgressNodeKind.middle,
        sortOrder: 1,
      ),
      ProgressNode(
        id: 'finance-checking',
        name: '核对中',
        colorValue: 0xffc28a35,
        kind: ProgressNodeKind.middle,
        sortOrder: 2,
      ),
      ProgressNode(
        id: 'finance-done',
        name: '已完成',
        colorValue: 0xff3f9875,
        kind: ProgressNodeKind.end,
        sortOrder: 3,
      ),
    ],
  ),
];

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.instanceId,
    required this.templateName,
    required this.currentNodeId,
    required this.nodes,
    this.sourceTemplateId,
  });

  final String instanceId;
  final String? sourceTemplateId;
  final String templateName;
  final String currentNodeId;
  final List<ProgressNode> nodes;

  ProgressNode? get currentNode {
    for (final node in nodes) {
      if (node.id == currentNodeId) return node;
    }
    return null;
  }

  bool get completed => currentNode?.completed ?? false;

  ProgressSnapshot copyWith({String? currentNodeId}) => ProgressSnapshot(
    instanceId: instanceId,
    sourceTemplateId: sourceTemplateId,
    templateName: templateName,
    currentNodeId: currentNodeId ?? this.currentNodeId,
    nodes: nodes,
  );
}

class TaskTagSnapshot {
  const TaskTagSnapshot({
    required this.name,
    required this.colorValue,
    required this.iconName,
    this.sourceTagId,
  });

  final String? sourceTagId;
  final String name;
  final int colorValue;
  final String iconName;
}

class TaskFollowup {
  const TaskFollowup({required this.id, required this.at, required this.text});
  final String id;
  final DateTime at;
  final String text;
}

class TaskHistory {
  const TaskHistory({required this.id, required this.at, required this.text});
  final String id;
  final DateTime at;
  final String text;
}

enum ReminderRuleType { relativeDuration, relativeDayTime, absolute }

enum ReminderDeliveryType { notification, alarm }

ReminderDeliveryType reminderDeliveryTypeFromName(String? value) =>
    value == 'alarm'
    ? ReminderDeliveryType.alarm
    : ReminderDeliveryType.notification;

ReminderRuleType reminderRuleTypeFromName(String? value) => switch (value) {
  'relative_day_time' => ReminderRuleType.relativeDayTime,
  'absolute' => ReminderRuleType.absolute,
  _ => ReminderRuleType.relativeDuration,
};

class TaskReminderRule {
  const TaskReminderRule({
    required this.id,
    required this.taskId,
    required this.type,
    required this.sortOrder,
    this.offsetMinutes,
    this.dayOffset,
    this.timeOfDay,
    this.absoluteAt,
    this.enabled = true,
    this.deliveryType = ReminderDeliveryType.notification,
  });

  final String id;
  final String taskId;
  final ReminderRuleType type;
  final int? offsetMinutes;
  final int? dayOffset;
  final String? timeOfDay;
  final DateTime? absoluteAt;
  final bool enabled;
  final int sortOrder;
  final ReminderDeliveryType deliveryType;

  String get deliveryTypeName => deliveryType.name;

  String get deliveryLabel => switch (deliveryType) {
    ReminderDeliveryType.notification => '通知',
    ReminderDeliveryType.alarm => '闹铃',
  };

  String get typeName => switch (type) {
    ReminderRuleType.relativeDuration => 'relative_duration',
    ReminderRuleType.relativeDayTime => 'relative_day_time',
    ReminderRuleType.absolute => 'absolute',
  };

  DateTime? fireDateFor({
    required String startDate,
    required String startTime,
  }) {
    if (!enabled) return null;
    if (type == ReminderRuleType.absolute) return absoluteAt?.toLocal();
    if (startDate.isEmpty || startTime.isEmpty) return null;
    final start = DateTime.tryParse('${startDate}T$startTime:00');
    if (start == null) return null;
    return switch (type) {
      ReminderRuleType.relativeDuration => start.subtract(
        Duration(minutes: offsetMinutes ?? 0),
      ),
      ReminderRuleType.relativeDayTime => _relativeDayDate(start),
      ReminderRuleType.absolute => absoluteAt?.toLocal(),
    };
  }

  DateTime? _relativeDayDate(DateTime start) {
    final parts = (timeOfDay ?? '').split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final date = DateTime(
      start.year,
      start.month,
      start.day,
    ).subtract(Duration(days: dayOffset ?? 0));
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String get label => switch (type) {
    ReminderRuleType.relativeDuration => _durationLabel(offsetMinutes ?? 0),
    ReminderRuleType.relativeDayTime =>
      (dayOffset ?? 0) == 0
          ? '当天 ${timeOfDay ?? '--:--'}'
          : '提前 ${dayOffset ?? 0} 天 ${timeOfDay ?? '--:--'}',
    ReminderRuleType.absolute =>
      absoluteAt == null
          ? '指定时间'
          : '${absoluteAt!.toLocal().year.toString().padLeft(4, '0')}-${absoluteAt!.toLocal().month.toString().padLeft(2, '0')}-${absoluteAt!.toLocal().day.toString().padLeft(2, '0')} ${absoluteAt!.toLocal().hour.toString().padLeft(2, '0')}:${absoluteAt!.toLocal().minute.toString().padLeft(2, '0')}',
  };

  static String _durationLabel(int minutes) {
    if (minutes == 0) return '准时提醒';
    if (minutes % 1440 == 0) return '提前 ${minutes ~/ 1440} 天';
    if (minutes % 60 == 0) return '提前 ${minutes ~/ 60} 小时';
    return '提前 $minutes 分钟';
  }

  factory TaskReminderRule.fromMap(Map<String, Object?> map) =>
      TaskReminderRule(
        id: map['id']! as String,
        taskId: map['task_id']! as String,
        type: reminderRuleTypeFromName(map['rule_type'] as String?),
        offsetMinutes: map['offset_minutes'] as int?,
        dayOffset: map['day_offset'] as int?,
        timeOfDay: map['time_of_day'] as String?,
        absoluteAt: DateTime.tryParse((map['absolute_at'] as String?) ?? ''),
        enabled: (map['enabled'] as int? ?? 1) == 1,
        sortOrder: map['sort_order'] as int? ?? 0,
        deliveryType: reminderDeliveryTypeFromName(
          map['delivery_type'] as String?,
        ),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'task_id': taskId,
    'rule_type': typeName,
    'offset_minutes': offsetMinutes,
    'day_offset': dayOffset,
    'time_of_day': timeOfDay,
    'absolute_at': absoluteAt?.toIso8601String(),
    'enabled': enabled ? 1 : 0,
    'sort_order': sortOrder,
    'delivery_type': deliveryTypeName,
  };
}

class NotificationJob {
  const NotificationJob({
    required this.requestId,
    required this.notificationId,
    required this.taskId,
    required this.fireAt,
    required this.state,
    required this.updatedAt,
    this.reminderRuleId,
    this.lastError,
  });

  final String requestId;
  final int notificationId;
  final String taskId;
  final String? reminderRuleId;
  final DateTime fireAt;
  final String state;
  final String? lastError;
  final DateTime updatedAt;

  factory NotificationJob.fromMap(Map<String, Object?> map) => NotificationJob(
    requestId: map['request_id']! as String,
    notificationId: map['notification_id']! as int,
    taskId: map['task_id']! as String,
    reminderRuleId: map['reminder_rule_id'] as String?,
    fireAt: DateTime.parse(map['fire_at_utc']! as String),
    state: map['state']! as String,
    lastError: map['last_error'] as String?,
    updatedAt: DateTime.parse(map['updated_at']! as String),
  );

  Map<String, Object?> toMap() => {
    'request_id': requestId,
    'notification_id': notificationId,
    'task_id': taskId,
    'reminder_rule_id': reminderRuleId,
    'fire_at_utc': fireAt.toUtc().toIso8601String(),
    'state': state,
    'last_error': lastError,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

enum AlarmPermissionState { notDetermined, authorized, denied, unsupported }

class AlarmJob {
  const AlarmJob({
    required this.alarmId,
    required this.requestId,
    required this.ownerType,
    required this.ownerId,
    required this.reminderRuleId,
    required this.fireAt,
    required this.state,
    required this.updatedAt,
    this.lastError,
  });

  final String alarmId;
  final String requestId;
  final String ownerType;
  final String ownerId;
  final String reminderRuleId;
  final DateTime fireAt;
  final String state;
  final String? lastError;
  final DateTime updatedAt;

  factory AlarmJob.fromMap(Map<String, Object?> map) => AlarmJob(
    alarmId: map['alarm_id']! as String,
    requestId: map['request_id']! as String,
    ownerType: map['owner_type']! as String,
    ownerId: map['owner_id']! as String,
    reminderRuleId: map['reminder_rule_id']! as String,
    fireAt: DateTime.parse(map['fire_at_utc']! as String),
    state: map['state']! as String,
    lastError: map['last_error'] as String?,
    updatedAt: DateTime.parse(map['updated_at']! as String),
  );

  Map<String, Object?> toMap() => {
    'alarm_id': alarmId,
    'request_id': requestId,
    'owner_type': ownerType,
    'owner_id': ownerId,
    'reminder_rule_id': reminderRuleId,
    'fire_at_utc': fireAt.toUtc().toIso8601String(),
    'state': state,
    'last_error': lastError,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class ContactEntry {
  const ContactEntry({
    required this.id,
    required this.name,
    required this.phone,
    this.remark = '',
  });

  final String id;
  final String name;
  final String phone;
  final String remark;

  ContactEntry copyWith({String? name, String? phone, String? remark}) =>
      ContactEntry(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        remark: remark ?? this.remark,
      );

  factory ContactEntry.fromMap(Map<String, Object?> map) => ContactEntry(
    id: map['id']! as String,
    name: map['name']! as String,
    phone: (map['phone'] as String?) ?? '',
    remark: (map['remark'] as String?) ?? '',
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'remark': remark,
  };
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.contact,
    required this.statusId,
    required this.tags,
    required this.startDate,
    required this.startTime,
    required this.reason,
    required this.completedAt,
    required this.originId,
    required this.parentTaskId,
    required this.updatedAt,
    this.sourceCategoryId,
    this.categoryColorValue = 0xff8e8e93,
    this.categoryIconName = 'project',
    this.tagSnapshots = const [],
    this.progress,
    this.planId,
    this.recurrenceRuleId,
    this.occurrenceDate,
    this.detachedFromRule = false,
    this.contacts = const [],
    this.followups = const [],
    this.history = const [],
    this.reminderEnabled = false,
    this.reminders = const [],
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String contact;
  final String statusId;
  final List<String> tags;
  final String startDate;
  final String startTime;
  final String reason;
  final DateTime? completedAt;
  final String? originId;
  final String? parentTaskId;
  final DateTime updatedAt;
  final String? sourceCategoryId;
  final int categoryColorValue;
  final String categoryIconName;
  final List<TaskTagSnapshot> tagSnapshots;
  final ProgressSnapshot? progress;
  final String? planId;
  final String? recurrenceRuleId;
  final String? occurrenceDate;
  final bool detachedFromRule;
  final List<ContactEntry> contacts;
  final List<TaskFollowup> followups;
  final List<TaskHistory> history;
  final bool reminderEnabled;
  final List<TaskReminderRule> reminders;

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? contact,
    String? statusId,
    List<String>? tags,
    String? startDate,
    String? startTime,
    String? reason,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? originId,
    String? parentTaskId,
    bool clearParentTaskId = false,
    DateTime? updatedAt,
    String? sourceCategoryId,
    int? categoryColorValue,
    String? categoryIconName,
    List<TaskTagSnapshot>? tagSnapshots,
    ProgressSnapshot? progress,
    String? planId,
    String? recurrenceRuleId,
    String? occurrenceDate,
    bool? detachedFromRule,
    List<ContactEntry>? contacts,
    List<TaskFollowup>? followups,
    List<TaskHistory>? history,
    bool? reminderEnabled,
    List<TaskReminderRule>? reminders,
  }) => TaskItem(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    contact: contact ?? this.contact,
    statusId: statusId ?? this.statusId,
    tags: tags ?? this.tags,
    startDate: startDate ?? this.startDate,
    startTime: startTime ?? this.startTime,
    reason: reason ?? this.reason,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    originId: originId ?? this.originId,
    parentTaskId: clearParentTaskId ? null : parentTaskId ?? this.parentTaskId,
    updatedAt: updatedAt ?? this.updatedAt,
    sourceCategoryId: sourceCategoryId ?? this.sourceCategoryId,
    categoryColorValue: categoryColorValue ?? this.categoryColorValue,
    categoryIconName: categoryIconName ?? this.categoryIconName,
    tagSnapshots: tagSnapshots ?? this.tagSnapshots,
    progress: progress ?? this.progress,
    planId: planId ?? this.planId,
    recurrenceRuleId: recurrenceRuleId ?? this.recurrenceRuleId,
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    detachedFromRule: detachedFromRule ?? this.detachedFromRule,
    contacts: contacts ?? this.contacts,
    followups: followups ?? this.followups,
    history: history ?? this.history,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminders: reminders ?? this.reminders,
  );

  factory TaskItem.fromMap(Map<String, Object?> map) => TaskItem(
    id: map['id']! as String,
    title: map['title']! as String,
    description: (map['description'] as String?) ?? '',
    type: (map['type'] as String?) ?? '',
    contact: (map['contact'] as String?) ?? '',
    statusId: map['status_id']! as String,
    tags: const [],
    startDate: (map['start_date'] as String?) ?? '',
    startTime: (map['start_time'] as String?) ?? '',
    reason: (map['reason'] as String?) ?? '',
    completedAt: DateTime.tryParse((map['completed_at'] as String?) ?? ''),
    originId: map['origin_id'] as String?,
    parentTaskId: map['parent_task_id'] as String?,
    updatedAt: DateTime.parse(map['updated_at']! as String),
    sourceCategoryId: map['source_category_id'] as String?,
    categoryColorValue: (map['category_color_value'] as int?) ?? 0xff8e8e93,
    categoryIconName: (map['category_icon_name'] as String?) ?? 'project',
    planId: map['plan_id'] as String?,
    recurrenceRuleId: map['recurrence_rule_id'] as String?,
    occurrenceDate: map['occurrence_date'] as String?,
    detachedFromRule: (map['detached_from_rule'] as int? ?? 0) == 1,
    reminderEnabled: (map['reminder_enabled'] as int? ?? 0) == 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'contact': contact,
    'status_id': statusId,
    'start_date': startDate,
    'start_time': startTime,
    'reason': reason,
    'completed_at': completedAt?.toIso8601String(),
    'origin_id': originId,
    'parent_task_id': parentTaskId,
    'updated_at': updatedAt.toIso8601String(),
    'source_category_id': sourceCategoryId,
    'category_color_value': categoryColorValue,
    'category_icon_name': categoryIconName,
    'plan_id': planId,
    'recurrence_rule_id': recurrenceRuleId,
    'occurrence_date': occurrenceDate,
    'detached_from_rule': detachedFromRule ? 1 : 0,
    'reminder_enabled': reminderEnabled ? 1 : 0,
  };
}

class PlanMilestone {
  const PlanMilestone({
    required this.id,
    required this.name,
    required this.date,
    required this.description,
    required this.completed,
    required this.sortOrder,
  });
  final String id;
  final String name;
  final String date;
  final String description;
  final bool completed;
  final int sortOrder;
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.id,
    required this.planId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.weekdays,
    required this.enabled,
    required this.progress,
  });
  final String id;
  final String planId;
  final String title;
  final String description;
  final String startDate;
  final String endDate;
  final String startTime;
  final Set<int> weekdays;
  final bool enabled;
  final ProgressSnapshot progress;

  bool occursOn(DateTime date) =>
      enabled && (weekdays.isEmpty || weekdays.contains(date.weekday));
}

enum PlanCalendarDisplayMode { wholePeriod, endpoints, startOnly, targetOnly }

PlanCalendarDisplayMode planCalendarDisplayModeFromName(String? value) =>
    switch (value) {
      'endpoints' => PlanCalendarDisplayMode.endpoints,
      'start_only' => PlanCalendarDisplayMode.startOnly,
      'target_only' => PlanCalendarDisplayMode.targetOnly,
      _ => PlanCalendarDisplayMode.wholePeriod,
    };

extension PlanCalendarDisplayModeText on PlanCalendarDisplayMode {
  String get storageName => switch (this) {
    PlanCalendarDisplayMode.wholePeriod => 'whole_period',
    PlanCalendarDisplayMode.endpoints => 'endpoints',
    PlanCalendarDisplayMode.startOnly => 'start_only',
    PlanCalendarDisplayMode.targetOnly => 'target_only',
  };

  String get label => switch (this) {
    PlanCalendarDisplayMode.wholePeriod => '整个期间',
    PlanCalendarDisplayMode.endpoints => '仅起止日',
    PlanCalendarDisplayMode.startOnly => '仅开始日',
    PlanCalendarDisplayMode.targetOnly => '仅目标日',
  };
}

class PlanItem {
  const PlanItem({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.targetDate,
    required this.categoryName,
    required this.categoryColorValue,
    required this.categoryIconName,
    required this.tags,
    required this.progress,
    required this.milestones,
    required this.rules,
    required this.updatedAt,
    this.calendarDisplayMode = PlanCalendarDisplayMode.wholePeriod,
    this.reminderEnabled = false,
    this.reminders = const [],
    this.contacts = const [],
  });
  final String id;
  final String name;
  final String description;
  final String startDate;
  final String targetDate;
  final String categoryName;
  final int categoryColorValue;
  final String categoryIconName;
  final List<TaskTagSnapshot> tags;
  final ProgressSnapshot progress;
  final List<PlanMilestone> milestones;
  final List<RecurrenceRule> rules;
  final DateTime updatedAt;
  final PlanCalendarDisplayMode calendarDisplayMode;
  final bool reminderEnabled;
  final List<TaskReminderRule> reminders;
  final List<ContactEntry> contacts;

  PlanItem copyWith({
    String? name,
    String? description,
    String? startDate,
    String? targetDate,
    String? categoryName,
    int? categoryColorValue,
    String? categoryIconName,
    List<TaskTagSnapshot>? tags,
    ProgressSnapshot? progress,
    List<PlanMilestone>? milestones,
    List<RecurrenceRule>? rules,
    DateTime? updatedAt,
    PlanCalendarDisplayMode? calendarDisplayMode,
    bool? reminderEnabled,
    List<TaskReminderRule>? reminders,
    List<ContactEntry>? contacts,
  }) => PlanItem(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    targetDate: targetDate ?? this.targetDate,
    categoryName: categoryName ?? this.categoryName,
    categoryColorValue: categoryColorValue ?? this.categoryColorValue,
    categoryIconName: categoryIconName ?? this.categoryIconName,
    tags: tags ?? this.tags,
    progress: progress ?? this.progress,
    milestones: milestones ?? this.milestones,
    rules: rules ?? this.rules,
    updatedAt: updatedAt ?? this.updatedAt,
    calendarDisplayMode: calendarDisplayMode ?? this.calendarDisplayMode,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminders: reminders ?? this.reminders,
    contacts: contacts ?? this.contacts,
  );
}

class ColumnPreference {
  const ColumnPreference({
    required this.keyName,
    required this.label,
    required this.visible,
    required this.sortOrder,
  });
  final String keyName;
  final String label;
  final bool visible;
  final int sortOrder;

  ColumnPreference copyWith({bool? visible, int? sortOrder}) =>
      ColumnPreference(
        keyName: keyName,
        label: label,
        visible: visible ?? this.visible,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

enum PlanCompletionStyle { dimText, check, border, strikethrough }

enum PlanCompletionStyleScope { calendarMonth, calendarWeek, quadrant }

class AppPreferences {
  const AppPreferences({
    this.theme = 'system',
    this.font = 'normal',
    this.language = 'zh',
    this.calendarDensity = 'medium',
    this.calendarSmallHeight = 62,
    this.calendarMediumHeight = 82,
    this.calendarLargeHeight = 102,
    this.calendarWeeklyCardHeight = 0,
    this.calendarMonthCompletionStyles = const {
      PlanCompletionStyle.dimText,
      PlanCompletionStyle.strikethrough,
    },
    this.calendarWeekCompletionStyles = const {
      PlanCompletionStyle.dimText,
      PlanCompletionStyle.check,
    },
    this.quadrantCompletionStyles = const {
      PlanCompletionStyle.dimText,
      PlanCompletionStyle.check,
    },
    this.defaultReminderMinutes = -1,
    this.reminderSound = true,
  });

  static const double minimumCalendarRowHeight = 62;
  static const double maximumCalendarRowHeight = 360;
  static const double maximumCalendarWeeklyCardHeight = 2000;

  final String theme;
  final String font;
  final String language;
  final String calendarDensity;
  final double calendarSmallHeight;
  final double calendarMediumHeight;
  final double calendarLargeHeight;
  final double calendarWeeklyCardHeight;
  final Set<PlanCompletionStyle> calendarMonthCompletionStyles;
  final Set<PlanCompletionStyle> calendarWeekCompletionStyles;
  final Set<PlanCompletionStyle> quadrantCompletionStyles;
  final int defaultReminderMinutes;
  final bool reminderSound;

  double get calendarRowHeight => switch (calendarDensity) {
    'small' => calendarSmallHeight,
    'large' => calendarLargeHeight,
    _ => calendarMediumHeight,
  };

  static int estimatedCalendarItemCount(double height) {
    final count = ((height - 62) / 20).floor();
    if (count < 0) return 0;
    if (count > 9) return 9;
    return count;
  }

  AppPreferences copyWith({
    String? theme,
    String? font,
    String? language,
    String? calendarDensity,
    double? calendarSmallHeight,
    double? calendarMediumHeight,
    double? calendarLargeHeight,
    double? calendarWeeklyCardHeight,
    Set<PlanCompletionStyle>? calendarMonthCompletionStyles,
    Set<PlanCompletionStyle>? calendarWeekCompletionStyles,
    Set<PlanCompletionStyle>? quadrantCompletionStyles,
    int? defaultReminderMinutes,
    bool? reminderSound,
  }) => AppPreferences(
    theme: theme ?? this.theme,
    font: font ?? this.font,
    language: language ?? this.language,
    calendarDensity: calendarDensity ?? this.calendarDensity,
    calendarSmallHeight: calendarSmallHeight ?? this.calendarSmallHeight,
    calendarMediumHeight: calendarMediumHeight ?? this.calendarMediumHeight,
    calendarLargeHeight: calendarLargeHeight ?? this.calendarLargeHeight,
    calendarWeeklyCardHeight:
        calendarWeeklyCardHeight ?? this.calendarWeeklyCardHeight,
    calendarMonthCompletionStyles:
        calendarMonthCompletionStyles ?? this.calendarMonthCompletionStyles,
    calendarWeekCompletionStyles:
        calendarWeekCompletionStyles ?? this.calendarWeekCompletionStyles,
    quadrantCompletionStyles:
        quadrantCompletionStyles ?? this.quadrantCompletionStyles,
    defaultReminderMinutes:
        defaultReminderMinutes ?? this.defaultReminderMinutes,
    reminderSound: reminderSound ?? this.reminderSound,
  );
}
