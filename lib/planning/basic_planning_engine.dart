import 'package:characters/characters.dart';

import 'planning_engine.dart';
import 'planning_models.dart';
import 'planning_validator.dart';

class BasicPlanningEngine implements PlanningEngine {
  const BasicPlanningEngine({
    this.validator = const PlanningProposalValidator(),
  });

  final PlanningProposalValidator validator;

  @override
  String get id => 'basic.zh-hans-cn.v1';

  @override
  PlanningEngineKind get kind => PlanningEngineKind.basic;

  @override
  Future<PlanningAvailability> checkAvailability() async =>
      const PlanningAvailability.available();

  @override
  Future<PlanningResult> generate(PlanningRequest request) async {
    final stopwatch = Stopwatch()..start();
    final parsed = _parse(request);
    stopwatch.stop();
    return PlanningResult(
      proposal: parsed,
      metadata: PlanningExecutionMetadata(
        requestId: request.requestId,
        requestedMode: request.mode,
        actualEngineId: id,
        source: PlanningSource.basic,
        elapsed: stopwatch.elapsed,
      ),
    );
  }

  PlanningProposal _parse(PlanningRequest request) {
    final text = request.rawText.trim();
    final evidence = <PlanningEvidence>[];
    final ambiguities = <PlanningAmbiguity>[];
    final warnings = <PlanningWarning>[];
    var nextEvidenceId = 0;

    PlanningEvidence addEvidence({
      required PlanningEvidenceKind kind,
      required Match match,
      required String normalizedValue,
      required String ruleId,
    }) {
      final item = PlanningEvidence(
        id: 'e${nextEvidenceId++}',
        kind: kind,
        startCodeUnit: match.start,
        endCodeUnit: match.end,
        sourceText: match.group(0) ?? '',
        normalizedValue: normalizedValue,
        ruleId: ruleId,
      );
      evidence.add(item);
      return item;
    }

    if (!request.localeTag.toLowerCase().startsWith('zh')) {
      warnings.add(
        const PlanningWarning(
          code: PlanningWarningCode.unsupportedExpression,
          messageKey: 'planning.warning.localeNotSupported',
        ),
      );
    }
    if (text.characters.length > 100) {
      warnings.add(
        const PlanningWarning(
          code: PlanningWarningCode.inputTooLong,
          messageKey: 'planning.warning.inputTooLong',
          severity: PlanningWarningSeverity.blocking,
        ),
      );
    }
    final hasComplexTimeExpression =
        _timeExpressionPattern().allMatches(text).length > 1 ||
        _dateExpressionPattern().allMatches(text).length > 1;
    if (hasComplexTimeExpression) {
      warnings.add(
        const PlanningWarning(
          code: PlanningWarningCode.unsupportedExpression,
          messageKey: 'planning.warning.unsupportedComplexTime',
          severity: PlanningWarningSeverity.blocking,
        ),
      );
    }

    final dateResult = _parseDate(text, request.referenceNow);
    var localDate = dateResult?.value ?? '';
    if (dateResult != null) {
      addEvidence(
        kind: PlanningEvidenceKind.date,
        match: dateResult.match,
        normalizedValue: localDate,
        ruleId: dateResult.ruleId,
      );
    }

    final timeResult = _parseTime(text);
    var localTime = timeResult?.value ?? '';
    if (timeResult != null) {
      final timeEvidence = addEvidence(
        kind: PlanningEvidenceKind.time,
        match: timeResult.match,
        normalizedValue: localTime,
        ruleId: timeResult.ruleId,
      );
      if (timeResult.alternatives.isNotEmpty) {
        localTime = '';
        ambiguities.add(
          PlanningAmbiguity(
            id: 'time-${timeEvidence.id}',
            kind: PlanningAmbiguityKind.time,
            messageKey: 'planning.ambiguity.bareHour',
            evidenceId: timeEvidence.id,
            choices: [
              ...timeResult.alternatives.map(
                (value) => PlanningAmbiguityChoice(
                  id: 'time-$value',
                  labelKey: value,
                  normalizedValue: value,
                ),
              ),
              const PlanningAmbiguityChoice(
                id: 'time-none',
                labelKey: 'planning.choice.noTime',
                normalizedValue: '',
              ),
            ],
          ),
        );
      }
    }

    if (dateResult == null && timeResult != null) {
      localDate = '';
      final candidate = _timeOnlyDateCandidate(
        request.referenceNow,
        timeResult,
      );
      final dateChoices = timeResult.alternatives.isEmpty
          ? <String>[candidate]
          : <String>[
              _dateText(request.referenceNow),
              _dateText(request.referenceNow.add(const Duration(days: 1))),
            ];
      ambiguities.add(
        PlanningAmbiguity(
          id: 'date-for-time',
          kind: PlanningAmbiguityKind.date,
          messageKey: 'planning.ambiguity.timeNeedsDate',
          choices: [
            ...dateChoices.toSet().map(
              (value) => PlanningAmbiguityChoice(
                id: 'date-$value',
                labelKey: value,
                normalizedValue: value,
              ),
            ),
            const PlanningAmbiguityChoice(
              id: 'date-none',
              labelKey: 'planning.choice.noDate',
              normalizedValue: '',
            ),
          ],
        ),
      );
    } else if (dateResult == null && timeResult == null) {
      localDate = request.defaultDate;
    }

    final reminders = _parseReminders(text, addEvidence);
    if (dateResult == null &&
        timeResult == null &&
        reminders.intent == ReminderDraftIntent.specified) {
      localDate = '';
    }
    final tags = <String>{};
    final tagPattern = RegExp(r'#([^\s#，。！？、,;；]+)');
    for (final match in tagPattern.allMatches(text)) {
      final name = match.group(1) ?? '';
      if (request.availableTags.contains(name)) {
        tags.add(name);
        addEvidence(
          kind: PlanningEvidenceKind.tag,
          match: match,
          normalizedValue: name,
          ruleId: 'tag.existing',
        );
      }
    }

    final title = hasComplexTimeExpression ? text : _buildTitle(text, evidence);
    var proposal = PlanningProposal(
      rawText: text,
      title: title,
      schedule: ScheduledDraft(
        localDate: localDate,
        localTime: localTime,
        timeZoneId: request.timeZoneId,
      ),
      reminders: reminders,
      tags: tags,
      evidence: evidence,
      ambiguities: ambiguities,
      warnings: warnings,
    );
    proposal = PlanningProposal(
      schemaVersion: proposal.schemaVersion,
      rawText: proposal.rawText,
      title: proposal.title,
      schedule: proposal.schedule,
      reminders: proposal.reminders,
      tags: proposal.tags,
      evidence: proposal.evidence,
      ambiguities: proposal.ambiguities,
      warnings: [
        ...proposal.warnings,
        ...validator.validate(proposal, referenceNow: request.referenceNow),
      ],
    );
    return proposal;
  }

  _ParsedDate? _parseDate(String text, DateTime now) {
    final relativePatterns = <(RegExp, int, String)>[
      (RegExp(r'今天|今日'), 0, 'date.today'),
      (RegExp(r'明天|明日'), 1, 'date.tomorrow'),
      (RegExp(r'后天'), 2, 'date.dayAfterTomorrow'),
    ];
    for (final item in relativePatterns) {
      final match = item.$1.firstMatch(text);
      if (match != null) {
        return _ParsedDate(
          match: match,
          value: _dateText(now.add(Duration(days: item.$2))),
          ruleId: item.$3,
        );
      }
    }

    final weekdayMatch = RegExp(r'(本周|下周|周|星期)([一二三四五六日天])').firstMatch(text);
    if (weekdayMatch != null) {
      final targetWeekday = _weekdayNumber(weekdayMatch.group(2)!);
      final prefix = weekdayMatch.group(1)!;
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      var target = monday.add(Duration(days: targetWeekday - 1));
      if (prefix == '下周') {
        target = target.add(const Duration(days: 7));
      } else if ((prefix == '周' || prefix == '星期') &&
          target.isBefore(DateTime(now.year, now.month, now.day))) {
        target = target.add(const Duration(days: 7));
      }
      return _ParsedDate(
        match: weekdayMatch,
        value: _dateText(target),
        ruleId: prefix == '本周'
            ? 'date.thisWeekday'
            : prefix == '下周'
            ? 'date.nextWeekday'
            : 'date.nearestWeekday',
      );
    }

    final absolute = RegExp(
      r'(?:(\d{4})\s*[年/\-])?(\d{1,2})\s*[月/\-](\d{1,2})\s*日?',
    ).firstMatch(text);
    if (absolute == null) return null;
    final year = int.tryParse(absolute.group(1) ?? '') ?? now.year;
    final month = int.tryParse(absolute.group(2) ?? '');
    final day = int.tryParse(absolute.group(3) ?? '');
    if (month == null || day == null) return null;
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return _ParsedDate(
      match: absolute,
      value: _dateText(value),
      ruleId: 'date.absolute',
    );
  }

  _ParsedTime? _parseTime(String text) {
    final match = _timeExpressionPattern().firstMatch(text);
    if (match == null) return null;
    final dayPart = match.group(1);
    var hour = _parseNumber(match.group(2) ?? '');
    var minute = match.group(5) != null
        ? 30
        : _parseNumber(match.group(3) ?? '0');
    if (hour == null || minute == null || minute > 59) return null;
    if (dayPart == '下午' || dayPart == '傍晚' || dayPart == '晚上') {
      if (hour < 12) hour += 12;
    } else if (dayPart == '中午') {
      if (hour < 11) hour += 12;
    } else if (dayPart == '凌晨' && hour == 12) {
      hour = 0;
    }
    if (hour > 23) return null;
    final value = _timeText(hour, minute);
    final alternatives = <String>[];
    if (dayPart == null && hour > 0 && hour <= 12) {
      alternatives.add(_timeText(hour, minute));
      if (hour < 12) alternatives.add(_timeText(hour + 12, minute));
    }
    return _ParsedTime(
      match: match,
      value: value,
      ruleId: dayPart == null ? 'time.clock' : 'time.dayPart',
      alternatives: alternatives,
    );
  }

  ReminderDraftSet _parseReminders(
    String text,
    PlanningEvidence Function({
      required PlanningEvidenceKind kind,
      required Match match,
      required String normalizedValue,
      required String ruleId,
    })
    addEvidence,
  ) {
    final noneMatch = RegExp(r'不提醒|无需提醒|不用提醒').firstMatch(text);
    if (noneMatch != null) {
      addEvidence(
        kind: PlanningEvidenceKind.reminder,
        match: noneMatch,
        normalizedValue: 'none',
        ruleId: 'reminder.none',
      );
      return const ReminderDraftSet.explicitlyNone();
    }

    final alarmMatch = RegExp(r'闹铃|闹钟').firstMatch(text);
    final deliveryType = alarmMatch == null
        ? PlanningReminderDeliveryType.notification
        : PlanningReminderDeliveryType.alarm;
    if (alarmMatch != null) {
      addEvidence(
        kind: PlanningEvidenceKind.reminderDelivery,
        match: alarmMatch,
        normalizedValue: deliveryType.name,
        ruleId: 'reminder.delivery.alarm',
      );
    }

    final reminderWords = RegExp(r'提醒我?|通知我?|闹铃提醒我?').allMatches(text);
    final offsetMatches = RegExp(r'提前\s*([零〇一二两三四五六七八九十百\d]+)\s*(分钟|分|小时|钟头|天)')
        .allMatches(text)
        .toList();
    final reminderValues = <ReminderDraft>[];
    for (final match in offsetMatches) {
      final amount = _parseNumber(match.group(1) ?? '');
      if (amount == null || amount < 0) continue;
      final unit = match.group(2)!;
      final minutes = unit == '天'
          ? amount * 1440
          : unit == '小时' || unit == '钟头'
          ? amount * 60
          : amount;
      addEvidence(
        kind: PlanningEvidenceKind.reminder,
        match: match,
        normalizedValue: 'offset:$minutes',
        ruleId: 'reminder.offset',
      );
      reminderValues.add(
        ReminderDraft(
          type: PlanningReminderRuleType.relativeDuration,
          deliveryType: deliveryType,
          offsetMinutes: minutes,
        ),
      );
    }

    final punctual = RegExp(r'准时\s*(?:提醒|通知)?').firstMatch(text);
    Match? genericReminder;
    for (final word in reminderWords) {
      final belongsToOffset = offsetMatches.any(
        (offset) => word.start >= offset.start && word.start <= offset.end + 3,
      );
      if (belongsToOffset) {
        addEvidence(
          kind: PlanningEvidenceKind.reminder,
          match: word,
          normalizedValue: 'reminder',
          ruleId: 'reminder.word',
        );
      }
    }
    for (final word in reminderWords) {
      final belongsToOffset = offsetMatches.any(
        (offset) => word.start >= offset.start && word.start <= offset.end + 3,
      );
      if (!belongsToOffset) {
        genericReminder = word;
        break;
      }
    }
    if (punctual != null || genericReminder != null) {
      final match = punctual ?? genericReminder!;
      addEvidence(
        kind: PlanningEvidenceKind.reminder,
        match: match,
        normalizedValue: 'offset:0',
        ruleId: 'reminder.punctual',
      );
      reminderValues.add(
        ReminderDraft(
          type: PlanningReminderRuleType.relativeDuration,
          deliveryType: deliveryType,
          offsetMinutes: 0,
        ),
      );
    }

    if (reminderValues.isEmpty) return const ReminderDraftSet.unspecified();
    final deduplicated = <String, ReminderDraft>{};
    for (final reminder in reminderValues) {
      final key =
          '${reminder.deliveryType.name}:${reminder.type.name}:'
          '${reminder.offsetMinutes}:${reminder.dayOffset}:'
          '${reminder.timeOfDay}:${reminder.absoluteAt}';
      deduplicated[key] = reminder;
    }
    return ReminderDraftSet.specified(deduplicated.values.toList());
  }

  String _buildTitle(String text, List<PlanningEvidence> evidence) {
    if (text.isEmpty) return '';
    final ordered = evidence.toList()
      ..sort((a, b) => a.startCodeUnit.compareTo(b.startCodeUnit));
    final buffer = StringBuffer();
    var cursor = 0;
    for (final item in ordered) {
      final start = item.startCodeUnit < cursor
          ? cursor
          : item.startCodeUnit > text.length
          ? text.length
          : item.startCodeUnit;
      final end = item.endCodeUnit < start
          ? start
          : item.endCodeUnit > text.length
          ? text.length
          : item.endCodeUnit;
      if (start > cursor) buffer.write(text.substring(cursor, start));
      if (end > cursor) cursor = end;
    }
    if (cursor < text.length) buffer.write(text.substring(cursor));
    final cleaned = buffer
        .toString()
        .replaceAll(RegExp(r'^[\s，。！？、,;；:：]+'), '')
        .replaceAll(RegExp(r'[\s，。！？、,;；:：]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? text : cleaned;
  }

  String _timeOnlyDateCandidate(DateTime now, _ParsedTime result) {
    final candidateTime = result.alternatives.isNotEmpty
        ? result.alternatives.last
        : result.value;
    final parts = candidateTime.split(':');
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return _dateText(
      candidate.isAfter(now)
          ? candidate
          : candidate.add(const Duration(days: 1)),
    );
  }

  int _weekdayNumber(String value) => switch (value) {
    '一' => DateTime.monday,
    '二' => DateTime.tuesday,
    '三' => DateTime.wednesday,
    '四' => DateTime.thursday,
    '五' => DateTime.friday,
    '六' => DateTime.saturday,
    _ => DateTime.sunday,
  };

  RegExp _timeExpressionPattern() => RegExp(
    r'(凌晨|早上|上午|中午|下午|傍晚|晚上)?\s*([零〇一二两三四五六七八九十\d]{1,3})(?::|点|時)([零〇一二三四五六七八九十\d]{1,2})?(分)?(半)?',
  );

  RegExp _dateExpressionPattern() => RegExp(
    r'今天|今日|明天|明日|后天|(?:本周|下周|周|星期)[一二三四五六日天]|(?:(?:\d{4})\s*[年/\-])?(?:\d{1,2})\s*[月/\-](?:\d{1,2})\s*日?',
  );

  int? _parseNumber(String value) {
    final direct = int.tryParse(value);
    if (direct != null) return direct;
    const digits = {
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    if (value == '十') return 10;
    if (value.contains('百')) {
      final parts = value.split('百');
      final hundreds = digits[parts.first] ?? 1;
      final rest = parts.length > 1 && parts[1].isNotEmpty
          ? _parseNumber(parts[1]) ?? 0
          : 0;
      return hundreds * 100 + rest;
    }
    if (value.contains('十')) {
      final parts = value.split('十');
      final tens = parts.first.isEmpty ? 1 : digits[parts.first];
      final ones = parts.length > 1 && parts[1].isNotEmpty
          ? digits[parts[1]]
          : 0;
      if (tens == null || ones == null) return null;
      return tens * 10 + ones;
    }
    var result = 0;
    for (final character in value.characters) {
      final digit = digits[character];
      if (digit == null) return null;
      result = result * 10 + digit;
    }
    return result;
  }

  String _dateText(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _timeText(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

class _ParsedDate {
  const _ParsedDate({
    required this.match,
    required this.value,
    required this.ruleId,
  });

  final Match match;
  final String value;
  final String ruleId;
}

class _ParsedTime {
  const _ParsedTime({
    required this.match,
    required this.value,
    required this.ruleId,
    this.alternatives = const <String>[],
  });

  final Match match;
  final String value;
  final String ruleId;
  final List<String> alternatives;
}
