import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import 'app_controller.dart';
import 'models.dart';
import 'l10n/ui_text.dart';
import 'plan_editor.dart';
import 'stable_filter_chip.dart';
import 'task_editor.dart';
import 'task_widgets.dart';
import 'ui/glass_bottom_navigation.dart';

enum StatMode { week, month, quarter, half, year, custom }

enum StatView { plans, tasks, quadrant, tags }

enum StatScope { plans, tasks, both }

class StatCriteria {
  StatCriteria({
    required this.mode,
    required this.anchor,
    required this.customStart,
    required this.customEnd,
    this.categoryName = '',
    this.progressTemplateName = '',
    this.progressNodeName = '',
    this.tags = const <String>{},
    this.scope = StatScope.plans,
  });

  factory StatCriteria.initial() {
    final now = DateTime.now();
    return StatCriteria(
      mode: StatMode.month,
      anchor: now,
      customStart: DateTime(now.year, now.month, 1),
      customEnd: DateTime(now.year, now.month + 1, 0),
    );
  }

  final StatMode mode;
  final DateTime anchor;
  final DateTime customStart;
  final DateTime customEnd;
  final String categoryName;
  final String progressTemplateName;
  final String progressNodeName;
  final Set<String> tags;
  final StatScope scope;

  StatCriteria copyWith({
    StatMode? mode,
    DateTime? anchor,
    DateTime? customStart,
    DateTime? customEnd,
    String? categoryName,
    String? progressTemplateName,
    String? progressNodeName,
    Set<String>? tags,
    StatScope? scope,
  }) => StatCriteria(
    mode: mode ?? this.mode,
    anchor: anchor ?? this.anchor,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    categoryName: categoryName ?? this.categoryName,
    progressTemplateName: progressTemplateName ?? this.progressTemplateName,
    progressNodeName: progressNodeName ?? this.progressNodeName,
    tags: tags ?? this.tags,
    scope: scope ?? this.scope,
  );
}

class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    required this.controller,
    required this.onOpenTasks,
    required this.criteria,
    required this.onCriteriaChanged,
  });
  final AppController controller;
  final VoidCallback onOpenTasks;
  final StatCriteria criteria;
  final ValueChanged<StatCriteria> onCriteriaChanged;
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with AutomaticKeepAliveClientMixin {
  StatView view = StatView.plans;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: view.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _selectView(StatView nextView) {
    if (nextView == view) return;
    setState(() => view = nextView);
    _pageController.animateToPage(
      nextView.index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  (DateTime, DateTime) get period {
    final date = widget.criteria.anchor;
    return switch (widget.criteria.mode) {
      StatMode.week => (
        date.subtract(Duration(days: date.weekday - 1)),
        date.add(Duration(days: 7 - date.weekday)),
      ),
      StatMode.month => (
        DateTime(date.year, date.month),
        DateTime(date.year, date.month + 1, 0),
      ),
      StatMode.quarter => (
        DateTime(date.year, ((date.month - 1) ~/ 3) * 3 + 1),
        DateTime(date.year, ((date.month - 1) ~/ 3) * 3 + 4, 0),
      ),
      StatMode.half => (
        DateTime(date.year, date.month <= 6 ? 1 : 7),
        DateTime(date.year, date.month <= 6 ? 7 : 13, 0),
      ),
      StatMode.year => (DateTime(date.year), DateTime(date.year, 12, 31)),
      StatMode.custom => (
        widget.criteria.customStart,
        widget.criteria.customEnd,
      ),
    };
  }

  void _move(int step) {
    final anchor = widget.criteria.anchor;
    widget.onCriteriaChanged(
      widget.criteria.copyWith(
        anchor: switch (widget.criteria.mode) {
          StatMode.week => anchor.add(Duration(days: step * 7)),
          StatMode.month => DateTime(
            anchor.year,
            anchor.month + step,
            anchor.day,
          ),
          StatMode.quarter => DateTime(
            anchor.year,
            anchor.month + step * 3,
            anchor.day,
          ),
          StatMode.half => DateTime(
            anchor.year,
            anchor.month + step * 6,
            anchor.day,
          ),
          StatMode.year => DateTime(
            anchor.year + step,
            anchor.month,
            anchor.day,
          ),
          StatMode.custom => anchor,
        },
      ),
    );
  }

  String _monthText(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _periodText(DateTime start, DateTime end) =>
      switch (widget.criteria.mode) {
        StatMode.week ||
        StatMode.custom => '${dateOnly(start)} — ${dateOnly(end)}',
        StatMode.month => _monthText(start),
        StatMode.quarter ||
        StatMode.half => '${_monthText(start)} — ${_monthText(end)}',
        StatMode.year => '${start.year}',
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final (start, end) = period;
    final startText = dateOnly(start);
    final endText = dateOnly(end);
    final cohort = widget.controller.tasks
        .where(
          (task) =>
              task.startDate.isNotEmpty &&
              task.startDate.compareTo(startText) >= 0 &&
              task.startDate.compareTo(endText) <= 0 &&
              (widget.criteria.categoryName.isEmpty ||
                  task.type == widget.criteria.categoryName) &&
              (widget.criteria.progressTemplateName.isEmpty ||
                  task.progress?.templateName ==
                      widget.criteria.progressTemplateName) &&
              (widget.criteria.progressNodeName.isEmpty ||
                  task.progress?.currentNode?.name ==
                      widget.criteria.progressNodeName) &&
              (widget.criteria.tags.isEmpty ||
                  widget.criteria.tags.any(
                    (name) => _taskMatchesSelectedTag(task, name),
                  )),
        )
        .toList();
    final complete = cohort.where(widget.controller.isDone).toList();
    final unfinished = cohort
        .where((task) => !widget.controller.isDone(task))
        .toList();
    final planCohort = widget.controller.plans
        .where(
          (plan) =>
              plan.startDate.compareTo(endText) <= 0 &&
              plan.targetDate.compareTo(startText) >= 0 &&
              (widget.criteria.categoryName.isEmpty ||
                  plan.categoryName == widget.criteria.categoryName) &&
              (widget.criteria.progressTemplateName.isEmpty ||
                  plan.progress.templateName ==
                      widget.criteria.progressTemplateName) &&
              (widget.criteria.progressNodeName.isEmpty ||
                  plan.progress.currentNode?.name ==
                      widget.criteria.progressNodeName) &&
              (widget.criteria.tags.isEmpty ||
                  widget.criteria.tags.any(
                    (name) => _planMatchesSelectedTag(plan, name),
                  )),
        )
        .toList();
    final reasonCounts = <String, int>{};
    for (final task in unfinished) {
      final key = task.reason.isEmpty ? '未填写' : task.reason;
      reasonCounts[key] = (reasonCounts[key] ?? 0) + 1;
    }
    final planCompletionBuckets = _planCompletionBuckets(
      start,
      end,
      planCohort,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Column(
            children: [
              SegmentedButton<StatView>(
                segments: const [
                  ButtonSegment(value: StatView.plans, label: Text('计划')),
                  ButtonSegment(value: StatView.tasks, label: Text('任务')),
                  ButtonSegment(value: StatView.quadrant, label: Text('四象限')),
                  ButtonSegment(value: StatView.tags, label: Text('标签')),
                ],
                selected: {view},
                showSelectedIcon: false,
                onSelectionChanged: (selected) => _selectView(selected.first),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: widget.criteria.mode == StatMode.custom
                        ? null
                        : () => _move(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _periodText(start, end),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: widget.criteria.mode == StatMode.custom
                        ? null
                        : () => _move(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              final nextView = StatView.values[index];
              if (nextView != view) setState(() => view = nextView);
            },
            children: StatView.values.map((pageView) {
              if (pageView == StatView.quadrant) {
                return Padding(
                  key: const PageStorageKey(StatView.quadrant),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: _buildQuadrantStats(context, planCohort, cohort),
                );
              }
              return ListView(
                key: PageStorageKey(pageView),
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  AppBottomNavigation.contentBottomPadding(context),
                ),
                children: [
                  if (pageView == StatView.plans) ...[
                    ..._buildPlanStats(
                      context,
                      planCohort,
                      startText,
                      endText,
                      planCompletionBuckets,
                    ),
                  ],
                  if (pageView == StatView.tasks) ...[
                    _StatisticsOverview(
                      statistics: [
                        _OverviewStatistic(
                          label: '安排',
                          value: '${cohort.length}',
                        ),
                        _OverviewStatistic(
                          label: '已完成',
                          value: '${complete.length}',
                        ),
                        _OverviewStatistic(
                          label: '未完成',
                          value: '${unfinished.length}',
                        ),
                        _OverviewStatistic(
                          label: '完成率',
                          value: cohort.isEmpty
                              ? '—'
                              : '${(complete.length / cohort.length * 100).round()}%',
                        ),
                      ],
                    ),
                    _Panel(
                      title: '未完成 · 当前状态',
                      child: Column(
                        children:
                            <String>{
                              ...unfinished.map(
                                (task) =>
                                    task.progress?.currentNode?.name ??
                                    widget.controller
                                        .statusOf(task.statusId)
                                        .name,
                              ),
                            }.map((statusName) {
                              final count = unfinished
                                  .where(
                                    (task) =>
                                        (task.progress?.currentNode?.name ??
                                            widget.controller
                                                .statusOf(task.statusId)
                                                .name) ==
                                        statusName,
                                  )
                                  .length;
                              final matching = unfinished.firstWhere(
                                (task) =>
                                    (task.progress?.currentNode?.name ??
                                        widget.controller
                                            .statusOf(task.statusId)
                                            .name) ==
                                    statusName,
                              );
                              return _Distribution(
                                label: statusName,
                                count: count,
                                total: unfinished.length,
                                color:
                                    matching.progress?.currentNode?.color ??
                                    widget.controller
                                        .statusOf(matching.statusId)
                                        .color,
                              );
                            }).toList(),
                      ),
                    ),
                    _Panel(
                      title: '未完成 · 主要原因',
                      child: reasonCounts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('这段时间没有未完成任务。'),
                            )
                          : Column(
                              children: reasonCounts.entries
                                  .map(
                                    (entry) => _Distribution(
                                      label: entry.key,
                                      count: entry.value,
                                      total: unfinished.length,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                  if (pageView == StatView.tags)
                    _buildOtherTagStats(context, planCohort, cohort),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPlanStats(
    BuildContext context,
    List<PlanItem> plans,
    String periodStart,
    String periodEnd,
    List<_Bucket> planCompletionBuckets,
  ) {
    final completed = plans.where((plan) => plan.progress.completed).length;
    final progressGroups = <String, _PlanProgressStat>{};
    for (final plan in plans) {
      final node = plan.progress.currentNode;
      final label = node?.name ?? '未设置进度';
      final current = progressGroups[label];
      progressGroups[label] = _PlanProgressStat(
        label: label,
        count: (current?.count ?? 0) + 1,
        color:
            current?.color ??
            node?.color ??
            Theme.of(context).colorScheme.outline,
      );
    }
    final progressStats = progressGroups.values.toList()
      ..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        return countCompare != 0 ? countCompare : a.label.compareTo(b.label);
      });

    final periodCounts = <_PlanPeriodType, int>{
      for (final type in _PlanPeriodType.values) type: 0,
    };
    for (final plan in plans) {
      final startsInPeriod = plan.startDate.compareTo(periodStart) >= 0;
      final endsInPeriod = plan.targetDate.compareTo(periodEnd) <= 0;
      final type = switch ((startsInPeriod, endsInPeriod)) {
        (true, true) => _PlanPeriodType.within,
        (false, true) => _PlanPeriodType.carriedIn,
        (true, false) => _PlanPeriodType.carriedOut,
        (false, false) => _PlanPeriodType.spanning,
      };
      periodCounts[type] = periodCounts[type]! + 1;
    }

    final categoryGroups = <String, List<PlanItem>>{};
    for (final plan in plans) {
      final name = plan.categoryName.isEmpty ? '未分类' : plan.categoryName;
      categoryGroups.putIfAbsent(name, () => []).add(plan);
    }
    final categoryStats =
        categoryGroups.entries.map((entry) {
          final items = entry.value;
          return _PlanCategoryStat(
            label: entry.key,
            count: items.length,
            completed: items.where((plan) => plan.progress.completed).length,
            color: Color(items.first.categoryColorValue),
          );
        }).toList()..sort((a, b) {
          final countCompare = b.count.compareTo(a.count);
          return countCompare != 0 ? countCompare : a.label.compareTo(b.label);
        });
    final visibleCategoryStats = categoryStats.length <= 5
        ? categoryStats
        : <_PlanCategoryStat>[
            ...categoryStats.take(5),
            _PlanCategoryStat(
              label: '其他',
              count: categoryStats
                  .skip(5)
                  .fold(0, (sum, stat) => sum + stat.count),
              completed: categoryStats
                  .skip(5)
                  .fold(0, (sum, stat) => sum + stat.completed),
              color: Theme.of(context).colorScheme.outline,
            ),
          ];

    return [
      _CompletionOverview(
        title: '计划完成概览',
        total: plans.length,
        completed: completed,
        itemLabel: '个计划',
      ),
      _Panel(
        title: '计划完成趋势',
        child: _TrendChart(buckets: planCompletionBuckets),
      ),
      _Panel(
        title: '当前进度分布',
        child: progressStats.isEmpty
            ? const _StatisticsEmpty(label: '本周期暂无计划数据')
            : Column(
                children: progressStats
                    .map(
                      (stat) => _Distribution(
                        label: stat.label,
                        count: stat.count,
                        total: plans.length,
                        color: stat.color,
                      ),
                    )
                    .toList(),
              ),
      ),
      _Panel(
        title: '计划与本周期的关系',
        child: _PlanPeriodGrid(counts: periodCounts, total: plans.length),
      ),
      _Panel(
        title: '分类分布',
        child: visibleCategoryStats.isEmpty
            ? const _StatisticsEmpty(label: '本周期暂无分类数据')
            : Column(
                children: visibleCategoryStats
                    .map(
                      (stat) => _CategoryDistribution(
                        stat: stat,
                        total: plans.length,
                      ),
                    )
                    .toList(),
              ),
      ),
    ];
  }

  Widget _buildQuadrantStats(
    BuildContext context,
    List<PlanItem> plans,
    List<TaskItem> tasks,
  ) {
    final entries = _statEntries(plans, tasks);
    final groups = defaultQuadrantTags.map((fallback) {
      var definition = fallback;
      for (final tag in widget.controller.tagDefinitions) {
        if (tag.id == fallback.id || tag.name == fallback.name) {
          definition = tag;
          break;
        }
      }
      final matchingEntries =
          entries
              .where((entry) => _entryHasTagDefinition(entry, definition))
              .toList()
            ..sort((a, b) {
              final doneCompare = (a.completed ? 1 : 0).compareTo(
                b.completed ? 1 : 0,
              );
              return doneCompare != 0
                  ? doneCompare
                  : a.title.compareTo(b.title);
            });
      return _QuadrantGroup(definition: definition, entries: matchingEntries);
    }).toList();
    final classifiedEntries = groups.expand((group) => group.entries).toSet();
    final completed = classifiedEntries
        .where((entry) => entry.completed)
        .length;
    return Column(
      children: [
        _QuadrantOverview(
          total: classifiedEntries.length,
          completed: completed,
          itemLabel: '象限事项',
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.paddingOf(context).bottom;
              final usableHeight = math.max(
                0.0,
                constraints.maxHeight - bottomInset,
              );
              final fittedCardExtent = (usableHeight - 10) / 2;
              final cardExtent = math.max(220.0, fittedCardExtent);
              return GridView.builder(
                padding: EdgeInsets.only(bottom: bottomInset),
                itemCount: groups.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: cardExtent,
                ),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _QuadrantCard(
                    group: group,
                    emptyLabel: _emptyScopeLabel,
                    completionStyles:
                        widget.controller.preferences.quadrantCompletionStyles,
                    onOpenEntry: _openEntry,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOtherTagStats(
    BuildContext context,
    List<PlanItem> plans,
    List<TaskItem> tasks,
  ) {
    final entries = _statEntries(plans, tasks);
    final definitions = widget.controller.tagDefinitions
        .where((tag) => !tag.isQuadrant)
        .toList();
    final stats = definitions.map((definition) {
      final matchingEntries = entries
          .where((entry) => _entryHasTagDefinition(entry, definition))
          .toList();
      return _OtherTagStat(
        name: definition.name,
        color: definition.color,
        icon: definition.icon,
        entries: matchingEntries,
        completed: matchingEntries.where((entry) => entry.completed).length,
      );
    }).toList();
    final taggedEntries = stats.expand((stat) => stat.entries).toSet();
    final completed = taggedEntries.where((entry) => entry.completed).length;
    return Column(
      children: [
        _QuadrantOverview(
          total: taggedEntries.length,
          completed: completed,
          itemLabel: '标签事项',
        ),
        _Panel(
          title: '其他标签统计',
          child: stats.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('当前没有自定义标签，可先前往设置添加标签。'),
                )
              : Column(
                  children: [
                    ...stats.map((stat) => _OtherTagStatRow(stat: stat)),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '右侧数字为已完成/总数；$_scopeItemText可计入多个普通标签。',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  bool _taskHasTagDefinition(TaskItem task, TaskTagDefinition definition) {
    for (final snapshot in task.tagSnapshots) {
      if (snapshot.sourceTagId == definition.id ||
          (snapshot.sourceTagId == null && snapshot.name == definition.name)) {
        return true;
      }
    }
    return task.tags.contains(definition.name);
  }

  bool _entryHasTagDefinition(_StatEntry entry, TaskTagDefinition definition) {
    for (final snapshot in entry.tags) {
      if (snapshot.sourceTagId == definition.id ||
          (snapshot.sourceTagId == null && snapshot.name == definition.name)) {
        return true;
      }
    }
    return entry.tagNames.contains(definition.name);
  }

  List<_StatEntry> _statEntries(List<PlanItem> plans, List<TaskItem> tasks) => [
    if (widget.criteria.scope != StatScope.tasks)
      ...plans.map(_StatEntry.fromPlan),
    if (widget.criteria.scope != StatScope.plans)
      ...tasks.map(
        (task) => _StatEntry.fromTask(
          task,
          completed: widget.controller.isDone(task),
        ),
      ),
  ];

  String get _emptyScopeLabel => switch (widget.criteria.scope) {
    StatScope.plans => '暂无计划',
    StatScope.tasks => '暂无任务',
    StatScope.both => '暂无计划或任务',
  };

  String get _scopeItemText => switch (widget.criteria.scope) {
    StatScope.plans => '一个计划',
    StatScope.tasks => '一个任务',
    StatScope.both => '一个计划或任务',
  };

  void _openEntry(_StatEntry entry) {
    final plan = entry.plan;
    if (plan != null) {
      showPlanEditor(context, widget.controller, plan: plan);
      return;
    }
    final task = entry.task;
    if (task != null) {
      showTaskEditor(context, widget.controller, task: task);
    }
  }

  bool _taskMatchesSelectedTag(TaskItem task, String name) {
    final definition = widget.controller.tagDefinitionForName(name);
    return definition == null
        ? task.tags.contains(name)
        : _taskHasTagDefinition(task, definition);
  }

  bool _planMatchesSelectedTag(PlanItem plan, String name) {
    final definition = widget.controller.tagDefinitionForName(name);
    return plan.tags.any(
      (item) =>
          item.name == name ||
          (definition != null && item.sourceTagId == definition.id),
    );
  }

  List<_Bucket> _planCompletionBuckets(
    DateTime start,
    DateTime end,
    List<PlanItem> plans,
  ) {
    final daily =
        widget.criteria.mode == StatMode.week ||
        widget.criteria.mode == StatMode.month ||
        (widget.criteria.mode == StatMode.custom &&
            end.difference(start).inDays <= 31);
    final result = <_Bucket>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final bucketEndDate = daily
          ? cursor
          : DateTime(cursor.year, cursor.month + 1, 0);
      final boundedEnd = bucketEndDate.isAfter(end) ? end : bucketEndDate;
      final bucketEnd = dateOnly(boundedEnd);
      final activePlans = plans
          .where((plan) => plan.startDate.compareTo(bucketEnd) <= 0)
          .toList();
      final completed = activePlans.where((plan) {
        if (!plan.progress.completed) return false;
        final completedAt = plan.completedAt ?? plan.updatedAt;
        return dateOnly(completedAt.toLocal()).compareTo(bucketEnd) <= 0;
      }).length;
      result.add(
        _Bucket(
          label: daily ? '${cursor.day}' : '${cursor.month}月',
          total: activePlans.length,
          done: completed,
        ),
      );
      cursor = daily
          ? cursor.add(const Duration(days: 1))
          : DateTime(cursor.year, cursor.month + 1);
    }
    return result;
  }
}

class _StatEntry {
  const _StatEntry._({
    required this.title,
    required this.completed,
    required this.tags,
    required this.tagNames,
    this.plan,
    this.task,
  });

  factory _StatEntry.fromPlan(PlanItem plan) => _StatEntry._(
    title: plan.name,
    completed: plan.progress.completed,
    tags: plan.tags,
    tagNames: plan.tags.map((tag) => tag.name).toList(),
    plan: plan,
  );

  factory _StatEntry.fromTask(TaskItem task, {required bool completed}) =>
      _StatEntry._(
        title: task.title,
        completed: completed,
        tags: task.tagSnapshots,
        tagNames: task.tags,
        task: task,
      );

  final String title;
  final bool completed;
  final List<TaskTagSnapshot> tags;
  final List<String> tagNames;
  final PlanItem? plan;
  final TaskItem? task;
}

class _QuadrantGroup {
  const _QuadrantGroup({required this.definition, required this.entries});

  final TaskTagDefinition definition;
  final List<_StatEntry> entries;
}

class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({
    required this.group,
    required this.emptyLabel,
    required this.completionStyles,
    required this.onOpenEntry,
  });

  final _QuadrantGroup group;
  final String emptyLabel;
  final Set<PlanCompletionStyle> completionStyles;
  final ValueChanged<_StatEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final completed = group.entries.where((entry) => entry.completed).length;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: group.definition.color.withAlpha(96)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    group.definition.icon,
                    size: 15,
                    color: group.definition.color,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      group.definition.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: group.definition.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$completed/${group.entries.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 10),
            Expanded(
              child: group.entries.isEmpty
                  ? Center(
                      child: Text(
                        emptyLabel,
                        style: const TextStyle(fontSize: 11),
                      ),
                    )
                  : ListView.separated(
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: group.entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 1),
                      itemBuilder: (context, index) {
                        final entry = group.entries[index];
                        final done = entry.completed;
                        final showCheck =
                            done &&
                            completionStyles.contains(
                              PlanCompletionStyle.check,
                            );
                        final dimText =
                            done &&
                            completionStyles.contains(
                              PlanCompletionStyle.dimText,
                            );
                        final showBorder =
                            done &&
                            completionStyles.contains(
                              PlanCompletionStyle.border,
                            );
                        final showStrikethrough =
                            done &&
                            completionStyles.contains(
                              PlanCompletionStyle.strikethrough,
                            );
                        final completedColor = Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant;
                        final title = Text(
                          entry.title,
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: dimText ? completedColor : null,
                            decoration: showStrikethrough
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: showStrikethrough
                                ? completedColor
                                : null,
                            decorationThickness: showStrikethrough
                                ? 0.75
                                : null,
                          ),
                        );
                        return Semantics(
                          label: entry.title,
                          value: done ? '已完成' : '未完成',
                          button: true,
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: () => onOpenEntry(entry),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    showCheck
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 12,
                                    color: group.definition.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Container(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      padding: showBorder
                                          ? const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            )
                                          : EdgeInsets.zero,
                                      decoration: showBorder
                                          ? BoxDecoration(
                                              border: Border.all(
                                                color: completedColor.withAlpha(
                                                  120,
                                                ),
                                                width: .8,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            )
                                          : null,
                                      child: title,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtherTagStat {
  const _OtherTagStat({
    required this.name,
    required this.color,
    required this.icon,
    required this.entries,
    required this.completed,
  });

  final String name;
  final Color? color;
  final IconData? icon;
  final List<_StatEntry> entries;
  final int completed;
}

class _OtherTagStatRow extends StatelessWidget {
  const _OtherTagStatRow({required this.stat});

  final _OtherTagStat stat;

  @override
  Widget build(BuildContext context) {
    final color = stat.color ?? Theme.of(context).colorScheme.primary;
    final total = stat.entries.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              Icon(stat.icon ?? Icons.label_outline, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stat.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '${stat.completed}/$total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Semantics(
            label: '${stat.name}完成率',
            value: total == 0
                ? '无数据'
                : '${(stat.completed / total * 100).round()}%',
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : stat.completed / total,
              color: color,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionOverview extends StatelessWidget {
  const _CompletionOverview({
    required this.title,
    required this.total,
    required this.completed,
    required this.itemLabel,
  });

  final String title;
  final int total;
  final int completed;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    final percentage = total == 0 ? '—' : '${(ratio * 100).round()}%';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  percentage,
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      total == 0
                          ? '本周期暂无计划数据'
                          : '$completed 已完成 / $total $itemLabel',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsEmpty extends StatelessWidget {
  const _StatisticsEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Center(
      child: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

class _PlanProgressStat {
  const _PlanProgressStat({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

enum _PlanPeriodType { within, carriedIn, carriedOut, spanning }

extension on _PlanPeriodType {
  String get label => switch (this) {
    _PlanPeriodType.within => '本期内',
    _PlanPeriodType.carriedIn => '前期延续',
    _PlanPeriodType.carriedOut => '后期延续',
    _PlanPeriodType.spanning => '跨越整期',
  };

  String get description => switch (this) {
    _PlanPeriodType.within => '本期开始并收尾',
    _PlanPeriodType.carriedIn => '前期开始，本期收尾',
    _PlanPeriodType.carriedOut => '本期开始，后续持续',
    _PlanPeriodType.spanning => '覆盖整个统计周期',
  };
}

class _PlanPeriodGrid extends StatelessWidget {
  const _PlanPeriodGrid({required this.counts, required this.total});

  final Map<_PlanPeriodType, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 620 ? 4 : 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: columns == 4 ? 1.55 : 1.9,
        children: _PlanPeriodType.values.map((type) {
          final count = counts[type] ?? 0;
          final percentage = total == 0 ? 0 : (count / total * 100).round();
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          type.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$count',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$percentage% · ${type.description}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class _PlanCategoryStat {
  const _PlanCategoryStat({
    required this.label,
    required this.count,
    required this.completed,
    required this.color,
  });

  final String label;
  final int count;
  final int completed;
  final Color color;
}

class _CategoryDistribution extends StatelessWidget {
  const _CategoryDistribution({required this.stat, required this.total});

  final _PlanCategoryStat stat;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : stat.count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(stat.label, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Semantics(
                  label: '${stat.label}计划占比',
                  value: '${(share * 100).round()}%',
                  child: LinearProgressIndicator(
                    value: share,
                    color: stat.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 82,
                child: Text(
                  '${stat.count} · ${stat.completed}/${stat.count}完成',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuadrantOverview extends StatelessWidget {
  const _QuadrantOverview({
    required this.total,
    required this.completed,
    required this.itemLabel,
  });

  final int total;
  final int completed;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final incomplete = total - completed;
    final ratio = total == 0 ? 0.0 : completed / total;
    final percentage = '${(ratio * 100).round()}%';
    return _StatisticsOverview(
      statistics: [
        _OverviewStatistic(value: '$incomplete', label: '未完成'),
        _OverviewStatistic(value: '$completed', label: '已完成'),
        _OverviewStatistic(value: '$total', label: itemLabel),
        _OverviewStatistic(value: percentage, label: '完成率'),
      ],
    );
  }
}

class _OverviewStatistic {
  const _OverviewStatistic({required this.value, required this.label});

  final String value;
  final String label;
}

class _StatisticsOverview extends StatelessWidget {
  const _StatisticsOverview({required this.statistics});

  final List<_OverviewStatistic> statistics;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: statistics
              .map(
                (statistic) => Expanded(
                  child: _CompactStatistic(
                    value: statistic.value,
                    label: statistic.label,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CompactStatistic extends StatelessWidget {
  const _CompactStatistic({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class StatsFilterDrawer extends StatelessWidget {
  const StatsFilterDrawer({
    super.key,
    required this.criteria,
    required this.onChanged,
    required this.controller,
  });

  final StatCriteria criteria;
  final ValueChanged<StatCriteria> onChanged;
  final AppController controller;

  static const labels = {
    StatMode.week: '周',
    StatMode.month: '月',
    StatMode.quarter: '季度',
    StatMode.half: '半年',
    StatMode.year: '年度',
    StatMode.custom: '自定义时间段',
  };

  static const scopeLabels = {
    StatScope.plans: '计划',
    StatScope.tasks: '任务',
    StatScope.both: '计划 + 任务',
  };

  @override
  Widget build(BuildContext context) {
    final categories = controller.orderedCategoryNames([
      ...controller.plans
          .map((plan) => plan.categoryName)
          .where((name) => name.isNotEmpty),
      ...controller.tasks
          .map((task) => task.type)
          .where((name) => name.isNotEmpty),
    ]);
    final templates = controller.orderedProgressTemplateNames([
      ...controller.plans
          .map((plan) => plan.progress.templateName)
          .where((name) => name.isNotEmpty),
      ...controller.tasks
          .map((task) => task.progress?.templateName ?? '')
          .where((name) => name.isNotEmpty),
    ]);
    final nodes = controller.progressNodeNamesForTemplate(
      criteria.progressTemplateName,
      [
        ...controller.plans.map((plan) => plan.progress),
        ...controller.tasks
            .map((task) => task.progress)
            .whereType<ProgressSnapshot>(),
      ],
    );
    final tags = controller.orderedTagNames([
      ...controller.plans.expand((plan) => plan.tags.map((tag) => tag.name)),
      ...controller.tasks.expand((task) => task.tags),
    ]);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '统计条件',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: localizeUiText(context, '恢复默认条件'),
                        onPressed: () => onChanged(StatCriteria.initial()),
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: localizeUiText(context, '关闭'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Text(
                    '四象限与标签统计对象',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  RadioGroup<StatScope>(
                    groupValue: criteria.scope,
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(criteria.copyWith(scope: value));
                      }
                    },
                    child: Column(
                      children: StatScope.values
                          .map(
                            (scope) => RadioListTile<StatScope>(
                              value: scope,
                              title: Text(scopeLabels[scope]!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const Divider(height: 28),
                  Text('统计周期', style: Theme.of(context).textTheme.titleMedium),
                  RadioGroup<StatMode>(
                    groupValue: criteria.mode,
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(criteria.copyWith(mode: value));
                      }
                    },
                    child: Column(
                      children: StatMode.values
                          .map(
                            (mode) => RadioListTile<StatMode>(
                              value: mode,
                              title: Text(labels[mode]!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (criteria.mode == StatMode.custom) ...[
                    const Divider(height: 28),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('开始日期'),
                      subtitle: Text(dateOnly(criteria.customStart)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickStart(context),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('结束日期'),
                      subtitle: Text(dateOnly(criteria.customEnd)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickEnd(context),
                    ),
                  ],
                  const Divider(height: 28),
                  DropdownButtonFormField<String>(
                    key: ValueKey('stat-category-${criteria.categoryName}'),
                    initialValue: criteria.categoryName,
                    decoration: InputDecoration(
                      labelText: localizeUiText(context, '分类'),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部分类')),
                      ...categories.map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      ),
                    ],
                    onChanged: (value) =>
                        onChanged(criteria.copyWith(categoryName: value ?? '')),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'stat-template-${criteria.progressTemplateName}',
                    ),
                    initialValue: criteria.progressTemplateName,
                    decoration: InputDecoration(
                      labelText: localizeUiText(context, '进度方案'),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部进度方案')),
                      ...templates.map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      ),
                    ],
                    onChanged: (value) => onChanged(
                      criteria.copyWith(
                        progressTemplateName: value ?? '',
                        progressNodeName: '',
                      ),
                    ),
                  ),
                  if (criteria.progressTemplateName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'stat-node-${criteria.progressTemplateName}-'
                        '${criteria.progressNodeName}',
                      ),
                      initialValue: criteria.progressNodeName,
                      decoration: InputDecoration(
                        labelText: localizeUiText(context, '进度节点'),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('该方案全部节点'),
                        ),
                        ...nodes.map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        ),
                      ],
                      onChanged: (value) => onChanged(
                        criteria.copyWith(progressNodeName: value ?? ''),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text('标签', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final selected = criteria.tags.contains(tag);
                      return StableFilterChip(
                        label: tag,
                        selected: selected,
                        onSelected: (value) {
                          final next = {...criteria.tags};
                          value ? next.add(tag) : next.remove(tag);
                          onChanged(criteria.copyWith(tags: next));
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final value = await showDatePicker(
      context: context,
      initialDate: criteria.customStart,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (value == null) return;
    onChanged(
      criteria.copyWith(
        mode: StatMode.custom,
        customStart: value,
        customEnd: value.isAfter(criteria.customEnd)
            ? value
            : criteria.customEnd,
      ),
    );
  }

  Future<void> _pickEnd(BuildContext context) async {
    final value = await showDatePicker(
      context: context,
      initialDate: criteria.customEnd,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (value == null) return;
    onChanged(
      criteria.copyWith(
        mode: StatMode.custom,
        customStart: value.isBefore(criteria.customStart)
            ? value
            : criteria.customStart,
        customEnd: value,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _Distribution extends StatelessWidget {
  const _Distribution({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: Semantics(
            label: label,
            value: total == 0
                ? '无数据'
                : '$count，${(count / total * 100).round()}%',
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          total == 0 ? '$count' : '$count  ${(count / total * 100).round()}%',
        ),
      ],
    ),
  );
}

class _Bucket {
  const _Bucket({required this.label, required this.total, required this.done});
  final String label;
  final int total;
  final int done;
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.buckets});

  static const completedColor = Color(0xff3f9875);
  static const unfinishedColor = Color(0xff487bca);

  final List<_Bucket> buckets;

  Widget _legendItem(Color color, String label, int value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text('$label $value', style: const TextStyle(fontSize: 11)),
    ],
  );

  bool _showLabel(int index) {
    if (buckets.length <= 14) return true;
    final ordinal = index + 1;
    return index == 0 || ordinal % 5 == 0 || index == buckets.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final total = buckets.isEmpty ? 0 : buckets.last.total;
    if (total == 0) {
      return Semantics(
        label: '计划完成趋势',
        value: '本周期暂无计划数据',
        excludeSemantics: true,
        child: const _StatisticsEmpty(label: '本周期暂无计划数据'),
      );
    }
    final completed = buckets.last.done;
    final unfinished = total - completed;
    final maximum = buckets.fold<int>(
      1,
      (value, bucket) => bucket.total > value ? bucket.total : value,
    );
    return Semantics(
      label: '计划完成趋势',
      value: '本周期共 $total 个计划，$completed 个已完成，$unfinished 个未完成',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legendItem(completedColor, '已完成', completed),
              const SizedBox(width: 14),
              _legendItem(unfinishedColor, '未完成', unfinished),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.asMap().entries.map((entry) {
                final index = entry.key;
                final bucket = entry.value;
                return Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableHeight = math.max(
                              0.0,
                              constraints.maxHeight - 14,
                            );
                            final completedHeight =
                                bucket.done / maximum * availableHeight;
                            final unfinishedHeight =
                                (bucket.total - bucket.done) /
                                maximum *
                                availableHeight;
                            final barHeight =
                                completedHeight + unfinishedHeight;
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                if (bucket.total > 0)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      widthFactor: .62,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: SizedBox(
                                          height: barHeight,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              SizedBox(
                                                height: unfinishedHeight,
                                                child: const ColoredBox(
                                                  color: unfinishedColor,
                                                ),
                                              ),
                                              SizedBox(
                                                height: completedHeight,
                                                child: const ColoredBox(
                                                  color: completedColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (bucket.total > 0 && _showLabel(index))
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: barHeight + 2,
                                    child: Text(
                                      '${bucket.total}',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 12,
                        child: Text(
                          _showLabel(index) ? bucket.label : '',
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
