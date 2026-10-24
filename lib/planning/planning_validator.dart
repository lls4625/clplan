import 'planning_models.dart';

class PlanningProposalValidator {
  const PlanningProposalValidator();

  List<PlanningWarning> validate(
    PlanningProposal proposal, {
    required DateTime referenceNow,
  }) {
    final warnings = <PlanningWarning>[];
    if (proposal.title.trim().isEmpty) {
      warnings.add(
        const PlanningWarning(
          code: PlanningWarningCode.emptyTitle,
          messageKey: 'planning.warning.emptyTitle',
          severity: PlanningWarningSeverity.blocking,
        ),
      );
    }

    final scheduledAt = _scheduledAt(proposal.schedule);
    final scheduledDate = proposal.schedule.hasDate
        ? DateTime.tryParse(proposal.schedule.localDate)
        : null;
    final today = DateTime(
      referenceNow.year,
      referenceNow.month,
      referenceNow.day,
    );
    if (!proposal.schedule.hasDate && proposal.schedule.hasTime) {
      warnings.add(
        const PlanningWarning(
          code: PlanningWarningCode.missingDateForTime,
          messageKey: 'planning.warning.missingDateForTime',
          severity: PlanningWarningSeverity.blocking,
        ),
      );
    }
    if ((scheduledAt != null && scheduledAt.isBefore(referenceNow)) ||
        (scheduledAt == null &&
            scheduledDate != null &&
            scheduledDate.isBefore(today))) {
      warnings.add(
        const PlanningWarning(
          code: PlanningWarningCode.pastSchedule,
          messageKey: 'planning.warning.pastSchedule',
          severity: PlanningWarningSeverity.blocking,
        ),
      );
    }

    if (proposal.reminders.intent == ReminderDraftIntent.specified) {
      for (final reminder in proposal.reminders.values) {
        if (reminder.type != PlanningReminderRuleType.absolute &&
            (!proposal.schedule.hasDate || !proposal.schedule.hasTime)) {
          warnings.add(
            const PlanningWarning(
              code: PlanningWarningCode.missingScheduleForRelativeReminder,
              messageKey: 'planning.warning.missingReminderSchedule',
              severity: PlanningWarningSeverity.blocking,
            ),
          );
          break;
        }
        if (reminder.type == PlanningReminderRuleType.absolute &&
            reminder.absoluteAt != null &&
            !reminder.absoluteAt!.isAfter(referenceNow)) {
          warnings.add(
            const PlanningWarning(
              code: PlanningWarningCode.pastReminder,
              messageKey: 'planning.warning.pastReminder',
              severity: PlanningWarningSeverity.blocking,
            ),
          );
          break;
        }
      }
    }
    return warnings;
  }

  DateTime? _scheduledAt(ScheduledDraft schedule) {
    if (!schedule.hasDate || !schedule.hasTime) return null;
    return DateTime.tryParse('${schedule.localDate}T${schedule.localTime}:00');
  }
}
