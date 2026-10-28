import 'package:flutter/material.dart' hide Text;

import '../../app_controller.dart';
import '../../l10n/l10n.dart';
import '../../l10n/preset_text.dart';
import '../../l10n/ui_text.dart';
import '../../models.dart';
import '../../task_widgets.dart';
import '../planning_models.dart';
import '../planning_view_model.dart';
import 'planning_ambiguity_section.dart';
import 'planning_suggestion_chips.dart';
import 'planning_warning_section.dart';

Future<bool?> showPlanningComposer(
  BuildContext context,
  AppController controller, {
  required PlanningTargetKind targetKind,
  required String initialDate,
  required Future<bool?> Function(PlanningDraft draft) openEditor,
}) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PlanningComposer(
      controller: controller,
      targetKind: targetKind,
      initialDate: initialDate,
      localeTag: localeTag,
      openEditor: openEditor,
    ),
  );
}

class PlanningComposer extends StatefulWidget {
  const PlanningComposer({
    super.key,
    required this.controller,
    required this.targetKind,
    required this.initialDate,
    required this.localeTag,
    required this.openEditor,
  });

  final AppController controller;
  final PlanningTargetKind targetKind;
  final String initialDate;
  final String localeTag;
  final Future<bool?> Function(PlanningDraft draft) openEditor;

  @override
  State<PlanningComposer> createState() => _PlanningComposerState();
}

class _PlanningComposerState extends State<PlanningComposer> {
  late final PlanningViewModel viewModel;
  bool allowClose = false;

  Locale get _locale {
    final parts = widget.localeTag.replaceAll('_', '-').split('-');
    return Locale.fromSubtags(
      languageCode: parts.first,
      scriptCode: parts.length > 1 && parts[1].length == 4 ? parts[1] : null,
      countryCode: parts.length > 1 && parts[1].length != 4
          ? parts[1]
          : parts.length > 2
          ? parts[2]
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    viewModel = PlanningViewModel(
      engine: widget.controller.planningOrchestrator,
      initialDate: widget.initialDate,
      localeTag: widget.localeTag,
      defaultReminderMinutes:
          widget.controller.preferences.defaultReminderMinutes,
      availableTags: widget.controller.tagDefinitions
          .map((tag) => tagDefinitionName(tag, _locale))
          .toSet(),
    );
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _attemptClose() async {
    if (!viewModel.hasInput) {
      _closeSheet();
      return;
    }
    final strings = context.l10n;
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: RawText(strings.planningDiscardTitle),
            content: RawText(strings.planningDiscardMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: RawText(strings.planningContinueEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: RawText(strings.planningDiscard),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !discard) return;
    _closeSheet();
  }

  Future<void> _pickDate(PlanningProposal proposal) async {
    final initial =
        DateTime.tryParse(proposal.schedule.localDate) ??
        DateTime.tryParse(widget.initialDate) ??
        DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (value != null) viewModel.setDate(dateOnly(value));
  }

  Future<void> _pickTime(PlanningProposal proposal) async {
    final parts = proposal.schedule.localTime.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? TimeOfDay.now().hour,
            minute: int.tryParse(parts[1]) ?? TimeOfDay.now().minute,
          )
        : TimeOfDay.now();
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value == null) return;
    viewModel.setTime(
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _openEditor(PlanningDraft? draft) async {
    if (draft == null) return;
    final normalizedTags = draft.tags.map((name) {
      return widget.controller.tagDefinitionForDisplayName(name, _locale)?.name ??
          name;
    }).toSet();
    final saved = await widget.openEditor(
      PlanningDraft(
        title: draft.title,
        description: draft.description,
        schedule: draft.schedule,
        reminders: draft.reminders,
        tags: normalizedTags,
      ),
    );
    if (!mounted || saved != true) return;
    _closeSheet(true);
  }

  void _closeSheet([bool? result]) {
    if (!mounted) return;
    setState(() => allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  bool _hasUnsupportedAlarm(PlanningProposal? proposal) =>
      widget.controller.alarmPermission == AlarmPermissionState.unsupported &&
      (proposal?.reminders.values.any(
            (item) => item.deliveryType == PlanningReminderDeliveryType.alarm,
          ) ??
          false);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: viewModel,
    builder: (context, _) {
      final strings = context.l10n;
      final proposal = viewModel.proposal;
      final unsupportedAlarm = _hasUnsupportedAlarm(proposal);
      return PopScope(
        canPop: allowClose || !viewModel.hasInput,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _attemptClose();
        },
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: RawText(
                          widget.targetKind == PlanningTargetKind.plan
                              ? strings.planningPlanTitle
                              : strings.planningTaskTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: strings.planningClose,
                      onPressed: _attemptClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: viewModel.textController,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 100,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            labelText:
                                widget.targetKind == PlanningTargetKind.plan
                                ? strings.planningPlanInputLabel
                                : strings.planningTaskInputLabel,
                            hintText: strings.planningInputHint,
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (viewModel.isPlanning)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              liveRegion: true,
                              label: strings.planningAnalysisInProgress,
                              child: const ExcludeSemantics(
                                child: LinearProgressIndicator(),
                              ),
                            ),
                          ),
                        if (viewModel.hasAnalysisError)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: RawText(
                                strings.planningAnalysisUnavailable,
                              ),
                            ),
                          ),
                        if (proposal != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            header: true,
                            child: RawText(
                              strings.planningSuggestedTitle,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 5),
                          SelectableText(
                            proposal.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          PlanningSuggestionChips(
                            proposal: proposal,
                            onPickDate: () => _pickDate(proposal),
                            onPickTime: () => _pickTime(proposal),
                            onClearSchedule: viewModel.clearSchedule,
                            onClearTime: viewModel.clearTime,
                            onRemoveReminders: viewModel.removeReminders,
                          ),
                          const SizedBox(height: 14),
                          PlanningAmbiguitySection(
                            ambiguities: proposal.ambiguities,
                            onSelected: viewModel.resolveAmbiguity,
                          ),
                          if (proposal.ambiguities.isNotEmpty)
                            const SizedBox(height: 12),
                          PlanningWarningSection(warnings: proposal.warnings),
                          if (unsupportedAlarm) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RawText(
                                    strings.planningAlarmUnsupported,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ActionChip(
                                        label: RawText(
                                          strings.planningConvertToNotification,
                                        ),
                                        onPressed: viewModel
                                            .convertAlarmsToNotifications,
                                      ),
                                      ActionChip(
                                        label: RawText(
                                          strings.planningRemoveReminder,
                                        ),
                                        onPressed: viewModel.removeReminders,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          RawText(
                            _sourceDescription(
                              context,
                              viewModel.result?.metadata,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final rawButton = OutlinedButton(
                      onPressed: viewModel.hasInput
                          ? () => _openEditor(viewModel.createRawDraft())
                          : null,
                      child: RawText(strings.planningUseRawText),
                    );
                    final applyButton = FilledButton(
                      onPressed: viewModel.canContinue && !unsupportedAlarm
                          ? () => _openEditor(viewModel.createDraft())
                          : null,
                      child: RawText(strings.planningApplyAndContinue),
                    );
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    if (constraints.maxWidth < 310 || textScale > 1.2) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          rawButton,
                          const SizedBox(height: 8),
                          applyButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: rawButton),
                        const SizedBox(width: 12),
                        Expanded(child: applyButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  String _sourceDescription(
    BuildContext context,
    PlanningExecutionMetadata? metadata,
  ) {
    if (metadata == null) return '';
    final strings = context.l10n;
    if (metadata.fallbackReason == PlanningFallbackReason.modelNotInstalled) {
      return strings.planningSourceBasicModelNotInstalled;
    }
    return metadata.source == PlanningSource.basic
        ? strings.planningSourceBasic
        : strings.planningSourceModel;
  }
}
