import 'package:flutter/material.dart' hide Text;

import '../../l10n/l10n.dart';
import '../../l10n/ui_text.dart';
import '../planning_models.dart';

class PlanningAmbiguitySection extends StatelessWidget {
  const PlanningAmbiguitySection({
    super.key,
    required this.ambiguities,
    required this.onSelected,
  });

  final List<PlanningAmbiguity> ambiguities;
  final void Function(
    PlanningAmbiguity ambiguity,
    PlanningAmbiguityChoice choice,
  )
  onSelected;

  @override
  Widget build(BuildContext context) {
    if (ambiguities.isEmpty) return const SizedBox.shrink();
    final strings = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: RawText(
              strings.planningNeedsConfirmation,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          ...ambiguities.map(
            (ambiguity) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_message(context, ambiguity.messageKey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ambiguity.choices
                        .map(
                          (choice) => ActionChip(
                            label: Text(_choiceLabel(context, choice.labelKey)),
                            onPressed: () => onSelected(ambiguity, choice),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _message(BuildContext context, String key) => switch (key) {
    'planning.ambiguity.bareHour' => context.l10n.planningAmbiguityBareHour,
    'planning.ambiguity.timeNeedsDate' =>
      context.l10n.planningAmbiguityTimeNeedsDate,
    _ => context.l10n.planningAmbiguityFallback,
  };

  String _choiceLabel(BuildContext context, String key) => switch (key) {
    'planning.choice.noTime' => context.l10n.planningChoiceNoTime,
    'planning.choice.noDate' => context.l10n.planningChoiceNoDate,
    _ => key,
  };
}
