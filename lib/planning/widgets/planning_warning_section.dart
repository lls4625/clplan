import 'package:flutter/material.dart' hide Text;

import '../../l10n/l10n.dart';
import '../../l10n/ui_text.dart';
import '../planning_models.dart';

class PlanningWarningSection extends StatelessWidget {
  const PlanningWarningSection({super.key, required this.warnings});

  final List<PlanningWarning> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: warnings.map((warning) {
        final message = _message(context, warning.messageKey);
        final foreground = warning.isBlocking
            ? colors.onErrorContainer
            : colors.onSurfaceVariant;
        final semanticsLabel = warning.isBlocking
            ? context.l10n.planningBlockingWarningSemantics(message)
            : context.l10n.planningAdvisoryWarningSemantics(message);
        return Semantics(
          container: true,
          liveRegion: warning.isBlocking,
          label: localizeUiText(context, semanticsLabel),
          child: ExcludeSemantics(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warning.isBlocking
                    ? colors.errorContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    warning.isBlocking
                        ? Icons.error_outline
                        : Icons.info_outline,
                    size: 20,
                    color: foreground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(message, style: TextStyle(color: foreground)),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _message(BuildContext context, String key) => switch (key) {
    'planning.warning.emptyTitle' => context.l10n.planningWarningEmptyTitle,
    'planning.warning.pastSchedule' => context.l10n.planningWarningPastSchedule,
    'planning.warning.pastReminder' => context.l10n.planningWarningPastReminder,
    'planning.warning.missingDateForTime' =>
      context.l10n.planningWarningMissingDateForTime,
    'planning.warning.missingReminderSchedule' =>
      context.l10n.planningWarningMissingReminderSchedule,
    'planning.warning.inputTooLong' => context.l10n.planningWarningInputTooLong,
    'planning.warning.localeNotSupported' =>
      context.l10n.planningWarningLocaleNotSupported,
    'planning.warning.unsupportedComplexTime' =>
      context.l10n.planningWarningUnsupportedComplexTime,
    _ => context.l10n.planningWarningFallback,
  };
}
