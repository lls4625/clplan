import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_controller.dart';
import 'models.dart';
import 'notification_service.dart';
import 'work_form_widgets.dart';

class ReminderFormSection extends StatelessWidget {
  const ReminderFormSection({
    super.key,
    required this.controller,
    required this.reminders,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onAdd,
    required this.onRemove,
    this.readOnly = false,
    this.resolveFireAt,
  });

  final AppController controller;
  final List<TaskReminderRule> reminders;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<ReminderDeliveryType> onAdd;
  final ValueChanged<TaskReminderRule> onRemove;
  final bool readOnly;
  final DateTime? Function(TaskReminderRule rule)? resolveFireAt;

  @override
  Widget build(BuildContext context) {
    final hasNotificationReminders = reminders.any(
      (item) => item.deliveryType == ReminderDeliveryType.notification,
    );
    final hasAlarmReminders = reminders.any(
      (item) => item.deliveryType == ReminderDeliveryType.alarm,
    );
    return WorkFormSection(
      title: '通知与闹铃',
      icon: Icons.notifications_active_outlined,
      subtitle: reminders.isEmpty
          ? '可设置多个通知或闹铃'
          : '${reminders.length} 个提醒',
      trailing: Semantics(
        label: '启用通知与闹铃',
        child: Switch.adaptive(
          value: enabled,
          onChanged: readOnly ? null : onEnabledChanged,
        ),
      ),
      children: enabled || reminders.isNotEmpty
          ? [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: readOnly || !enabled
                          ? null
                          : () => onAdd(ReminderDeliveryType.notification),
                      icon: const Icon(Icons.notifications_none),
                      label: const Text('通知提醒'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: readOnly || !enabled
                          ? null
                          : () => onAdd(ReminderDeliveryType.alarm),
                      icon: const Icon(Icons.alarm_outlined),
                      label: const Text('闹铃提醒'),
                    ),
                  ),
                ],
              ),
              if (reminders.isNotEmpty)
                Column(
                  children: reminders
                      .map((rule) => _ReminderListTile(
                            rule: rule,
                            fireAt: resolveFireAt?.call(rule) ?? rule.absoluteAt,
                            readOnly: readOnly,
                            onRemove: () => onRemove(rule),
                          ))
                      .toList(),
                ),
              if (hasNotificationReminders &&
                  controller.reminderPermission ==
                      ReminderPermissionState.disabled)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '提醒会保存，但需在系统设置中允许通知后才会生效。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.openReminderSettings,
                      child: const Text('去设置'),
                    ),
                  ],
                ),
              if (hasAlarmReminders)
                Text(
                  controller.alarmPermission == AlarmPermissionState.unsupported
                      ? '当前系统不支持闹铃提醒；规则会保留，但不会生效。'
                      : controller.alarmPermission == AlarmPermissionState.denied
                      ? '闹铃权限未开启；规则会保留，但不会生效。'
                      : '闹铃提醒需要 iOS 26 或更高版本及独立授权。',
                  style: const TextStyle(fontSize: 12),
                ),
            ]
          : const [],
    );
  }
}

class _ReminderListTile extends StatelessWidget {
  const _ReminderListTile({
    required this.rule,
    required this.fireAt,
    required this.readOnly,
    required this.onRemove,
  });

  final TaskReminderRule rule;
  final DateTime? fireAt;
  final bool readOnly;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final expired = fireAt != null && fireAt!.isBefore(DateTime.now());
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        rule.deliveryType == ReminderDeliveryType.alarm
            ? Icons.alarm_outlined
            : Icons.notifications_none,
      ),
      title: Text('${rule.deliveryLabel} · ${rule.label}'),
      subtitle: fireAt == null
          ? const Text('等待关联时间')
          : Text(
              expired
                  ? '已过期，不会再提醒'
                  : DateFormat('yyyy-MM-dd HH:mm').format(fireAt!),
            ),
      trailing: readOnly
          ? null
          : IconButton(
              tooltip: '删除提醒',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
    );
  }
}

Future<DateTime?> showReminderDateTimePicker(
  BuildContext context,
  ReminderDeliveryType deliveryType, {
  DateTime? initialDate,
}) async {
  final now = DateTime.now();
  final initial = initialDate != null && initialDate.isAfter(now)
      ? initialDate
      : now;
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(2200),
    helpText: deliveryType == ReminderDeliveryType.alarm
        ? '选择闹铃日期'
        : '选择通知日期',
  );
  if (!context.mounted || date == null) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
    helpText: deliveryType == ReminderDeliveryType.alarm
        ? '选择闹铃时间'
        : '选择通知时间',
  );
  if (!context.mounted || time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
