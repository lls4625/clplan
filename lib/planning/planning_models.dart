/// The planning mode requested by the caller.
enum PlanningMode { basic, auto, model }

/// The entity that will receive an accepted planning draft.
enum PlanningTargetKind { plan, task }

/// The engine family that produced a planning result.
enum PlanningEngineKind { basic, model }

/// The source of the proposal ultimately returned to the caller.
enum PlanningSource { basic, model }

/// Why the orchestrator used the basic planner instead of a model planner.
enum PlanningFallbackReason {
  modelNotInstalled,
  modelUnsupported,
  modelUnavailable,
  modelFailed,
  invalidModelOutput,
}

/// The current usability of a planning engine.
enum PlanningAvailabilityState {
  available,
  notInstalled,
  unsupported,
  unavailable,
}

/// A framework-independent engine availability result.
class PlanningAvailability {
  const PlanningAvailability({required this.state, this.reasonCode});

  const PlanningAvailability.available()
    : state = PlanningAvailabilityState.available,
      reasonCode = null;

  final PlanningAvailabilityState state;

  /// A stable code that the presentation layer can map to localized text.
  final String? reasonCode;

  bool get isAvailable => state == PlanningAvailabilityState.available;
}

/// All context required to produce one planning proposal.
class PlanningRequest {
  const PlanningRequest({
    required this.requestId,
    required this.rawText,
    required this.localeTag,
    required this.timeZoneId,
    required this.referenceNow,
    required this.defaultDate,
    required this.defaultReminderMinutes,
    this.availableTags = const <String>{},
    this.mode = PlanningMode.basic,
  });

  final int requestId;
  final String rawText;
  final String localeTag;
  final String timeZoneId;

  /// A fixed clock value for the whole request. Engines must not call now().
  final DateTime referenceNow;

  final String defaultDate;
  final int defaultReminderMinutes;
  final Set<String> availableTags;
  final PlanningMode mode;
}

/// A local scheduled value whose time-zone identity is retained explicitly.
class ScheduledDraft {
  const ScheduledDraft({
    this.localDate = '',
    this.localTime = '',
    required this.timeZoneId,
  });

  /// yyyy-MM-dd, or an empty string when no date was specified.
  final String localDate;

  /// HH:mm, or an empty string when no time was specified.
  final String localTime;

  final String timeZoneId;

  bool get hasDate => localDate.isNotEmpty;
  bool get hasTime => localTime.isNotEmpty;
}

/// Rule types used before a reminder is converted to a persisted entity.
enum PlanningReminderRuleType { relativeDuration, relativeDayTime, absolute }

/// Delivery types used before a reminder is converted to the platform model.
enum PlanningReminderDeliveryType { notification, alarm }

/// A reminder suggestion without persistence-only identity and ordering fields.
class ReminderDraft {
  const ReminderDraft({
    required this.type,
    this.deliveryType = PlanningReminderDeliveryType.notification,
    this.offsetMinutes,
    this.dayOffset,
    this.timeOfDay,
    this.absoluteAt,
  });

  final PlanningReminderRuleType type;
  final PlanningReminderDeliveryType deliveryType;
  final int? offsetMinutes;
  final int? dayOffset;
  final String? timeOfDay;
  final DateTime? absoluteAt;
}

/// Distinguishes absent reminder language from an explicit user removal.
enum ReminderDraftIntent { unspecified, explicitlyNone, specified }

class ReminderDraftSet {
  const ReminderDraftSet.unspecified()
    : intent = ReminderDraftIntent.unspecified,
      values = const <ReminderDraft>[];

  const ReminderDraftSet.explicitlyNone()
    : intent = ReminderDraftIntent.explicitlyNone,
      values = const <ReminderDraft>[];

  const ReminderDraftSet.specified(this.values)
    : intent = ReminderDraftIntent.specified,
      assert(values.length > 0);

  final ReminderDraftIntent intent;
  final List<ReminderDraft> values;
}

enum PlanningEvidenceKind { date, time, reminder, reminderDelivery, tag }

/// A recognized source range. Offsets use UTF-16 code units.
class PlanningEvidence {
  const PlanningEvidence({
    required this.id,
    required this.kind,
    required this.startCodeUnit,
    required this.endCodeUnit,
    required this.sourceText,
    required this.normalizedValue,
    required this.ruleId,
  }) : assert(startCodeUnit >= 0),
       assert(endCodeUnit >= startCodeUnit);

  final String id;
  final PlanningEvidenceKind kind;
  final int startCodeUnit;
  final int endCodeUnit;
  final String sourceText;
  final String normalizedValue;
  final String ruleId;
}

enum PlanningAmbiguityKind { date, time, reminderTime, reminderDelivery }

/// One machine-readable resolution offered for an ambiguity.
class PlanningAmbiguityChoice {
  const PlanningAmbiguityChoice({
    required this.id,
    required this.labelKey,
    required this.normalizedValue,
  });

  final String id;

  /// A localization key rather than display text.
  final String labelKey;
  final String normalizedValue;
}

/// A decision that may need user confirmation before continuing.
class PlanningAmbiguity {
  const PlanningAmbiguity({
    required this.id,
    required this.kind,
    required this.messageKey,
    required this.choices,
    this.requiresResolution = true,
    this.evidenceId,
  });

  final String id;
  final PlanningAmbiguityKind kind;
  final String messageKey;
  final List<PlanningAmbiguityChoice> choices;
  final bool requiresResolution;
  final String? evidenceId;
}

enum PlanningWarningCode {
  inputTooLong,
  pastSchedule,
  pastReminder,
  missingDateForTime,
  missingScheduleForRelativeReminder,
  unsupportedAlarm,
  unsupportedExpression,
  emptyTitle,
}

enum PlanningWarningSeverity { advisory, blocking }

/// A localized-at-the-edge issue found while validating a proposal.
class PlanningWarning {
  const PlanningWarning({
    required this.code,
    required this.messageKey,
    this.severity = PlanningWarningSeverity.advisory,
    this.evidenceId,
  });

  final PlanningWarningCode code;
  final String messageKey;
  final PlanningWarningSeverity severity;
  final String? evidenceId;

  bool get isBlocking => severity == PlanningWarningSeverity.blocking;
}

/// A reviewable planning suggestion. It is never persisted directly.
class PlanningProposal {
  const PlanningProposal({
    this.schemaVersion = 1,
    required this.rawText,
    required this.title,
    required this.schedule,
    required this.reminders,
    this.tags = const <String>{},
    this.evidence = const <PlanningEvidence>[],
    this.ambiguities = const <PlanningAmbiguity>[],
    this.warnings = const <PlanningWarning>[],
  });

  final int schemaVersion;
  final String rawText;
  final String title;
  final ScheduledDraft schedule;
  final ReminderDraftSet reminders;
  final Set<String> tags;
  final List<PlanningEvidence> evidence;
  final List<PlanningAmbiguity> ambiguities;
  final List<PlanningWarning> warnings;
}

class PlanningExecutionMetadata {
  const PlanningExecutionMetadata({
    required this.requestId,
    required this.requestedMode,
    required this.actualEngineId,
    required this.source,
    required this.elapsed,
    this.fallbackReason,
    this.modelVersion,
  });

  final int requestId;
  final PlanningMode requestedMode;
  final String actualEngineId;
  final PlanningSource source;
  final PlanningFallbackReason? fallbackReason;
  final Duration elapsed;
  final String? modelVersion;
}

class PlanningResult {
  const PlanningResult({required this.proposal, required this.metadata});

  final PlanningProposal proposal;
  final PlanningExecutionMetadata metadata;
}

/// Shared accepted values passed to a plan or task editor before persistence.
class PlanningDraft {
  const PlanningDraft({
    required this.title,
    required this.description,
    required this.schedule,
    required this.reminders,
    this.tags = const <String>{},
  });

  final String title;
  final String description;
  final ScheduledDraft schedule;
  final ReminderDraftSet reminders;
  final Set<String> tags;
}
