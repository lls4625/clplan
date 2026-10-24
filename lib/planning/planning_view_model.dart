import 'dart:async';

import 'package:flutter/widgets.dart';

import 'planning_engine.dart';
import 'planning_draft_mapper.dart';
import 'planning_models.dart';
import 'planning_validator.dart';

class PlanningViewModel extends ChangeNotifier {
  PlanningViewModel({
    required this.engine,
    required this.initialDate,
    required this.defaultReminderMinutes,
    required this.availableTags,
    this.localeTag = 'zh-Hans-CN',
    this.timeZoneId = 'local',
    this.validator = const PlanningProposalValidator(),
    this.mapper = const PlanningDraftMapper(),
  }) {
    textController.addListener(_onTextChanged);
  }

  final PlanningEngine engine;
  final String initialDate;
  final int defaultReminderMinutes;
  final Set<String> availableTags;
  final String localeTag;
  final String timeZoneId;
  final PlanningProposalValidator validator;
  final PlanningDraftMapper mapper;

  final TextEditingController textController = TextEditingController();
  Timer? _debounce;
  int _nextRequestId = 0;
  int _latestAcceptedRequestId = 0;
  PlanningResult? _result;
  bool _isPlanning = false;
  bool _disposed = false;
  bool _hasAnalysisError = false;
  String? _dateOverride;
  String? _timeOverride;
  ReminderDraftSet? _reminderOverride;
  String? _dateOverrideSource;
  String? _timeOverrideSource;
  String? _reminderOverrideSource;
  final Set<PlanningAmbiguityKind> _resolvedAmbiguityKinds =
      <PlanningAmbiguityKind>{};

  PlanningResult? get result => _result;
  bool get isPlanning => _isPlanning;
  bool get hasAnalysisError => _hasAnalysisError;
  bool get hasInput => textController.text.trim().isNotEmpty;

  PlanningProposal? get proposal {
    final base = _result?.proposal;
    if (base == null) return null;
    final schedule = ScheduledDraft(
      localDate: _dateOverride ?? base.schedule.localDate,
      localTime: _timeOverride ?? base.schedule.localTime,
      timeZoneId: base.schedule.timeZoneId,
    );
    final reminders = _reminderOverride ?? base.reminders;
    final unresolved = base.ambiguities
        .where((item) => !_resolvedAmbiguityKinds.contains(item.kind))
        .toList();
    final draft = PlanningProposal(
      schemaVersion: base.schemaVersion,
      rawText: base.rawText,
      title: base.title,
      schedule: schedule,
      reminders: reminders,
      tags: base.tags,
      evidence: base.evidence,
      ambiguities: unresolved,
    );
    final preservedWarnings = base.warnings.where(
      (warning) =>
          warning.code == PlanningWarningCode.inputTooLong ||
          warning.code == PlanningWarningCode.unsupportedExpression,
    );
    return PlanningProposal(
      schemaVersion: draft.schemaVersion,
      rawText: draft.rawText,
      title: draft.title,
      schedule: draft.schedule,
      reminders: draft.reminders,
      tags: draft.tags,
      evidence: draft.evidence,
      ambiguities: draft.ambiguities,
      warnings: [
        ...preservedWarnings,
        ...validator.validate(draft, referenceNow: DateTime.now()),
      ],
    );
  }

  bool get canContinue {
    final current = proposal;
    if (current == null || current.title.trim().isEmpty) return false;
    if (current.ambiguities.any((item) => item.requiresResolution)) {
      return false;
    }
    return !current.warnings.any((item) => item.isBlocking);
  }

  void _onTextChanged() {
    final value = textController.value;
    _debounce?.cancel();
    if (value.composing.isValid && !value.composing.isCollapsed) {
      notifyListeners();
      return;
    }
    _hasAnalysisError = false;
    if (value.text.trim().isEmpty) {
      _clearOverrides();
      _result = null;
      _isPlanning = false;
      notifyListeners();
      return;
    }
    _result = null;
    _isPlanning = true;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 200), _generate);
  }

  Future<void> _generate() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    final requestId = ++_nextRequestId;
    final referenceNow = DateTime.now();
    try {
      final next = await engine.generate(
        PlanningRequest(
          requestId: requestId,
          rawText: text,
          localeTag: localeTag,
          timeZoneId: timeZoneId,
          referenceNow: referenceNow,
          defaultDate: initialDate,
          defaultReminderMinutes: defaultReminderMinutes,
          availableTags: availableTags,
        ),
      );
      if (_disposed) return;
      if (requestId < _latestAcceptedRequestId ||
          text != textController.text.trim()) {
        return;
      }
      _latestAcceptedRequestId = requestId;
      _reconcileOverrides(next.proposal);
      _result = next;
      _hasAnalysisError = false;
    } catch (_) {
      if (_disposed) return;
      if (requestId < _latestAcceptedRequestId ||
          text != textController.text.trim()) {
        return;
      }
      _hasAnalysisError = true;
      _result = null;
    } finally {
      if (!_disposed &&
          requestId >= _latestAcceptedRequestId &&
          text == textController.text.trim()) {
        _isPlanning = false;
        notifyListeners();
      }
    }
  }

  void resolveAmbiguity(
    PlanningAmbiguity ambiguity,
    PlanningAmbiguityChoice choice,
  ) {
    switch (ambiguity.kind) {
      case PlanningAmbiguityKind.date:
        _dateOverride = choice.normalizedValue;
        _dateOverrideSource = _evidenceSourceFor(
          _result?.proposal,
          PlanningAmbiguityKind.date,
        );
        if (choice.normalizedValue.isEmpty) {
          _timeOverride = '';
          _timeOverrideSource = _evidenceSourceFor(
            _result?.proposal,
            PlanningAmbiguityKind.time,
          );
          _resolvedAmbiguityKinds.add(PlanningAmbiguityKind.time);
        }
        break;
      case PlanningAmbiguityKind.time:
        _timeOverride = choice.normalizedValue;
        _timeOverrideSource = _evidenceSourceFor(
          _result?.proposal,
          PlanningAmbiguityKind.time,
        );
        break;
      case PlanningAmbiguityKind.reminderTime:
        if (choice.normalizedValue == 'remove') {
          _reminderOverride = const ReminderDraftSet.explicitlyNone();
          _reminderOverrideSource = _evidenceSourceFor(
            _result?.proposal,
            PlanningAmbiguityKind.reminderTime,
          );
        }
        break;
      case PlanningAmbiguityKind.reminderDelivery:
        break;
    }
    _resolvedAmbiguityKinds.add(ambiguity.kind);
    notifyListeners();
  }

  void setDate(String value) {
    _dateOverride = value;
    _dateOverrideSource = _evidenceSourceFor(
      _result?.proposal,
      PlanningAmbiguityKind.date,
    );
    _resolvedAmbiguityKinds.add(PlanningAmbiguityKind.date);
    notifyListeners();
  }

  void setTime(String value) {
    _timeOverride = value;
    _timeOverrideSource = _evidenceSourceFor(
      _result?.proposal,
      PlanningAmbiguityKind.time,
    );
    _resolvedAmbiguityKinds.add(PlanningAmbiguityKind.time);
    notifyListeners();
  }

  void clearTime() => setTime('');

  void clearSchedule() {
    _dateOverride = '';
    _timeOverride = '';
    _dateOverrideSource = _evidenceSourceFor(
      _result?.proposal,
      PlanningAmbiguityKind.date,
    );
    _timeOverrideSource = _evidenceSourceFor(
      _result?.proposal,
      PlanningAmbiguityKind.time,
    );
    _resolvedAmbiguityKinds
      ..add(PlanningAmbiguityKind.date)
      ..add(PlanningAmbiguityKind.time);
    notifyListeners();
  }

  void removeReminders() {
    _reminderOverride = const ReminderDraftSet.explicitlyNone();
    _reminderOverrideSource = _evidenceSourceFor(
      _result?.proposal,
      PlanningAmbiguityKind.reminderTime,
    );
    notifyListeners();
  }

  void convertAlarmsToNotifications() {
    final current = proposal?.reminders;
    if (current == null || current.intent != ReminderDraftIntent.specified) {
      return;
    }
    _reminderOverride = ReminderDraftSet.specified(
      current.values
          .map(
            (item) => ReminderDraft(
              type: item.type,
              deliveryType: PlanningReminderDeliveryType.notification,
              offsetMinutes: item.offsetMinutes,
              dayOffset: item.dayOffset,
              timeOfDay: item.timeOfDay,
              absoluteAt: item.absoluteAt,
            ),
          )
          .toList(),
    );
    _reminderOverrideSource = _evidenceSourceFor(
      _result?.proposal,
      PlanningAmbiguityKind.reminderDelivery,
    );
    notifyListeners();
  }

  void _reconcileOverrides(PlanningProposal next) {
    final nextDateSource = _evidenceSourceFor(next, PlanningAmbiguityKind.date);
    if (_dateOverride != null && _dateOverrideSource != nextDateSource) {
      _dateOverride = null;
      _dateOverrideSource = null;
      _resolvedAmbiguityKinds.remove(PlanningAmbiguityKind.date);
    }
    final nextTimeSource = _evidenceSourceFor(next, PlanningAmbiguityKind.time);
    if (_timeOverride != null && _timeOverrideSource != nextTimeSource) {
      _timeOverride = null;
      _timeOverrideSource = null;
      _resolvedAmbiguityKinds.remove(PlanningAmbiguityKind.time);
    }
    final nextReminderSource = _evidenceSourceFor(
      next,
      PlanningAmbiguityKind.reminderTime,
    );
    if (_reminderOverride != null &&
        _reminderOverrideSource != nextReminderSource) {
      _reminderOverride = null;
      _reminderOverrideSource = null;
      _resolvedAmbiguityKinds
        ..remove(PlanningAmbiguityKind.reminderTime)
        ..remove(PlanningAmbiguityKind.reminderDelivery);
    }
  }

  String _evidenceSourceFor(
    PlanningProposal? value,
    PlanningAmbiguityKind kind,
  ) {
    if (value == null) return '';
    final evidenceKinds = switch (kind) {
      PlanningAmbiguityKind.date =>
        value.evidence.any((item) => item.kind == PlanningEvidenceKind.date)
            ? const <PlanningEvidenceKind>[PlanningEvidenceKind.date]
            : const <PlanningEvidenceKind>[PlanningEvidenceKind.time],
      PlanningAmbiguityKind.time => const <PlanningEvidenceKind>[
        PlanningEvidenceKind.time,
      ],
      PlanningAmbiguityKind.reminderTime ||
      PlanningAmbiguityKind.reminderDelivery => const <PlanningEvidenceKind>[
        PlanningEvidenceKind.reminder,
        PlanningEvidenceKind.reminderDelivery,
      ],
    };
    return value.evidence
        .where((item) => evidenceKinds.contains(item.kind))
        .map((item) => '${item.kind.name}:${item.sourceText}')
        .join('|');
  }

  void _clearOverrides() {
    _dateOverride = null;
    _timeOverride = null;
    _reminderOverride = null;
    _dateOverrideSource = null;
    _timeOverrideSource = null;
    _reminderOverrideSource = null;
    _resolvedAmbiguityKinds.clear();
  }

  PlanningDraft? createDraft({bool useRawTextAsTitle = false}) {
    final current = proposal;
    if (current == null) return null;
    return mapper.fromProposal(current, useRawTextAsTitle: useRawTextAsTitle);
  }

  PlanningDraft? createRawDraft() {
    final text = textController.text.trim();
    if (text.isEmpty) return null;
    return PlanningDraft(
      title: text,
      description: text,
      schedule: ScheduledDraft(localDate: initialDate, timeZoneId: timeZoneId),
      reminders: const ReminderDraftSet.unspecified(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    textController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }
}
