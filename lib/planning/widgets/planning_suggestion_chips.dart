import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../planning_models.dart';

class PlanningSuggestionChips extends StatelessWidget {
  const PlanningSuggestionChips({
    super.key,
    required this.proposal,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClearSchedule,
    required this.onClearTime,
    required this.onRemoveReminders,
  });

  final PlanningProposal proposal;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onClearSchedule;
  final VoidCallback onClearTime;
  final VoidCallback onRemoveReminders;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final schedule = proposal.schedule;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.event_outlined, size: 18),
          label: Text(
            schedule.hasDate
                ? strings.planningScheduleDate(schedule.localDate)
                : strings.planningSetScheduleDate,
          ),
          onPressed: onPickDate,
        ),
        ActionChip(
          avatar: const Icon(Icons.schedule_outlined, size: 18),
          label: Text(
            schedule.hasTime
                ? strings.planningScheduleTime(schedule.localTime)
                : strings.planningSetScheduleTime,
          ),
          onPressed: onPickTime,
        ),
        if (schedule.hasTime)
          ActionChip(
            avatar: const Icon(Icons.schedule_outlined, size: 18),
            label: Text(strings.planningRemoveScheduleTime),
            onPressed: onClearTime,
          ),
        if (schedule.hasDate)
          ActionChip(
            avatar: const Icon(Icons.event_busy_outlined, size: 18),
            label: Text(strings.planningRemoveSchedule),
            onPressed: onClearSchedule,
          ),
        if (proposal.reminders.intent == ReminderDraftIntent.unspecified)
          Chip(
            avatar: const Icon(Icons.notifications_none, size: 18),
            label: Text(strings.planningReminderUseDefault),
          ),
        if (proposal.reminders.intent == ReminderDraftIntent.explicitlyNone)
          Chip(
            avatar: const Icon(Icons.notifications_off_outlined, size: 18),
            label: Text(strings.planningReminderNone),
          ),
        if (proposal.reminders.intent == ReminderDraftIntent.specified)
          ...proposal.reminders.values.map(
            (reminder) => ActionChip(
              avatar: Icon(
                reminder.deliveryType == PlanningReminderDeliveryType.alarm
                    ? Icons.alarm_outlined
                    : Icons.notifications_none,
                size: 18,
              ),
              label: Text(_reminderLabel(context, reminder)),
              tooltip: strings.planningRemoveReminderTooltip,
              onPressed: onRemoveReminders,
            ),
          ),
        ...proposal.tags.map(
          (tag) => Semantics(
            label: strings.planningTagSemantics(tag),
            child: ExcludeSemantics(
              child: Chip(
                avatar: const Icon(Icons.label_outline, size: 18),
                label: Text('#$tag'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _reminderLabel(BuildContext context, ReminderDraft reminder) {
    final strings = context.l10n;
    final delivery = reminder.deliveryType == PlanningReminderDeliveryType.alarm
        ? strings.planningDeliveryAlarm
        : strings.planningDeliveryNotification;
    return switch (reminder.type) {
      PlanningReminderRuleType.relativeDuration =>
        strings.planningReminderWithDelivery(
          _offsetLabel(context, reminder.offsetMinutes ?? 0),
          delivery,
        ),
      PlanningReminderRuleType.relativeDayTime =>
        strings.planningReminderDayTime(
          reminder.dayOffset ?? 0,
          reminder.timeOfDay ?? '--:--',
          delivery,
        ),
      PlanningReminderRuleType.absolute => strings.planningReminderAbsolute(
        reminder.absoluteAt?.toLocal().toString().substring(0, 16) ??
            strings.planningSpecifiedTime,
        delivery,
      ),
    };
  }

  String _offsetLabel(BuildContext context, int minutes) {
    final strings = context.l10n;
    if (minutes == 0) return strings.planningReminderOnTime;
    if (minutes % 1440 == 0) {
      return strings.planningReminderDaysBefore(minutes ~/ 1440);
    }
    if (minutes % 60 == 0) {
      return strings.planningReminderHoursBefore(minutes ~/ 60);
    }
    return strings.planningReminderMinutesBefore(minutes);
  }
}
