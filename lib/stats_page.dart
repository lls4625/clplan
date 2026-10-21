import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'plan_editor.dart';
import 'plan_widgets.dart';
import 'task_editor.dart';
import 'task_widgets.dart';

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
    this.planId = '',
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
  final String planId;
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
    String? planId,
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
    planId: planId ?? this.planId,
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
                  )) &&
              (widget.criteria.planId.isEmpty ||
                  task.planId == widget.criteria.planId),
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
                  )) &&
              (widget.criteria.planId.isEmpty ||
                  plan.id == widget.criteria.planId),
        )
        .toList();
    final completedPlans = planCohort
        .where((plan) => plan.progress.completed)
        .toList();
    final unfinishedPlans = planCohort
        .where((plan) => !plan.progress.completed)
        .toList();
    final reasonCounts = <String, int>{};
    for (final task in unfinished) {
      final key = task.reason.isEmpty ? '未填写' : task.reason;
      reasonCounts[key] = (reasonCounts[key] ?? 0) + 1;
    }
    final buckets = _buckets(start, end, cohort);
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
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: _buildQuadrantStats(context, planCohort, cohort),
                );
              }
              return ListView(
                key: PageStorageKey(pageView),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
                children: [
                  if (pageView == StatView.plans) ...[
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      childAspectRatio: .9,
                      children: [
                        _Metric(
                          label: '计划',
                          value: '${planCohort.length}',
                          onTap: () => _showPlans(planCohort, '本周期计划'),
                        ),
                        _Metric(
                          label: '已完成',
                          value: '${completedPlans.length}',
                          onTap: () => _showPlans(completedPlans, '已完成计划'),
                        ),
                        _Metric(
                          label: '进行中',
                          value: '${unfinishedPlans.length}',
                          onTap: () => _showPlans(unfinishedPlans, '进行中计划'),
                        ),
                        _Metric(
                          label: '完成率',
                          value: planCohort.isEmpty
                              ? '—'
                              : '${(completedPlans.length / planCohort.length * 100).round()}%',
                          onTap: () => _showPlans(planCohort, '本周期计划'),
                        ),
                      ],
                    ),
                    _Panel(
                      title: '计划清单',
                      child: planCohort.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('本周期没有计划')),
                            )
                          : Column(
                              children: planCohort
                                  .map(
                                    (plan) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: PlanCard(
                                        plan: plan,
                                        controller: widget.controller,
                                        onTap: () => showPlanEditor(
                                          context,
                                          widget.controller,
                                          plan: plan,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        '计划按时间范围与当前统计周期是否重叠计算。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  if (pageView == StatView.tasks) ...[
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      childAspectRatio: .9,
                      children: [
                        _Metric(
                          label: '安排',
                          value: '${cohort.length}',
                          onTap: () => _showTasks(cohort, '本周期安排'),
                        ),
                        _Metric(
                          label: '已完成',
                          value: '${complete.length}',
                          onTap: () => _showTasks(complete, '本周期已完成'),
                        ),
                        _Metric(
                          label: '未完成',
                          value: '${unfinished.length}',
                          onTap: () => _showTasks(unfinished, '本周期未完成'),
                        ),
                        _Metric(
                          label: '完成率',
                          value: cohort.isEmpty
                              ? '—'
                              : '${(complete.length / cohort.length * 100).round()}%',
                          onTap: () => _showTasks(cohort, '本周期安排'),
                        ),
                      ],
                    ),
                    _Panel(
                      title: '完成趋势',
                      child: _TrendChart(buckets: buckets),
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
                                onTap: () => _showTasks(
                                  unfinished
                                      .where(
                                        (task) =>
                                            (task.progress?.currentNode?.name ??
                                                widget.controller
                                                    .statusOf(task.statusId)
                                                    .name) ==
                                            statusName,
                                      )
                                      .toList(),
                                  statusName,
                                ),
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
                                      onTap: () => _showTasks(
                                        unfinished
                                            .where(
                                              (task) =>
                                                  (task.reason.isEmpty
                                                      ? '未填写'
                                                      : task.reason) ==
                                                  entry.key,
                                            )
                                            .toList(),
                                        entry.key,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    OutlinedButton(
                      onPressed: () => _showTasks(
                        widget.controller.tasks
                            .where((task) => task.startDate.isEmpty)
                            .toList(),
                        '未安排日期',
                      ),
                      child: Text(
                        '未安排日期：${widget.controller.tasks.where((task) => task.startDate.isEmpty).length} 项（不计入周期）',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        '任务统计使用现在的状态，不是历史快照；自然周为周一至周日，半年为 1–6 / 7–12 月。',
                        style: TextStyle(fontSize: 12),
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
      return _QuadrantGroup(
        definition: definition,
        entries: matchingEntries,
      );
    }).toList();
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: groups.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: (constraints.maxHeight - 10) / 2,
        ),
        itemBuilder: (context, index) {
          final group = groups[index];
          return _QuadrantCard(
            group: group,
            emptyLabel: _emptyScopeLabel,
            onOpenAll: () => _showEntries(
              group.entries,
              group.definition.name,
            ),
            onOpenEntry: _openEntry,
          );
        },
      ),
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
    final definitionIds = widget.controller.tagDefinitions
        .map((tag) => tag.id)
        .toSet();
    final historicalNames = <String>{};
    for (final entry in entries) {
      for (final snapshot in entry.tags) {
        if (!quadrantTagNames.contains(snapshot.name) &&
            (snapshot.sourceTagId == null ||
                !definitionIds.contains(snapshot.sourceTagId))) {
          historicalNames.add(snapshot.name);
        }
      }
      for (final name in entry.tagNames) {
        final hasSnapshot = entry.tags.any((item) => item.name == name);
        final hasDefinition = widget.controller.tagDefinitions.any(
          (item) => item.name == name,
        );
        if (!hasSnapshot &&
            !hasDefinition &&
            !quadrantTagNames.contains(name)) {
          historicalNames.add(name);
        }
      }
    }
    final stats =
        <_OtherTagStat>[
          ...definitions.map((definition) {
            final matchingEntries = entries
                .where((entry) => _entryHasTagDefinition(entry, definition))
                .toList();
            return _OtherTagStat(
              name: definition.name,
              color: definition.color,
              icon: definition.icon,
              entries: matchingEntries,
              unfinished: matchingEntries
                  .where((entry) => !entry.completed)
                  .length,
            );
          }),
          ...historicalNames.map((name) {
            final matchingEntries = entries
                .where((entry) => entry.tagNames.contains(name))
                .toList();
            TaskTagSnapshot? snapshot;
            for (final entry in matchingEntries) {
              for (final item in entry.tags) {
                if (item.name == name) snapshot ??= item;
              }
            }
            return _OtherTagStat(
              name: name,
              color: snapshot == null ? null : Color(snapshot.colorValue),
              icon: snapshot == null
                  ? Icons.history
                  : taskTagIcons[snapshot.iconName],
              entries: matchingEntries,
              unfinished: matchingEntries
                  .where((entry) => !entry.completed)
                  .length,
            );
          }),
        ]..sort((a, b) {
          final countCompare = b.entries.length.compareTo(a.entries.length);
          return countCompare != 0 ? countCompare : a.name.compareTo(b.name);
        });
    return _Panel(
      title: '其他标签统计',
      child: stats.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('本周期没有其他标签数据。'),
            )
          : Column(
              children: [
                ...stats.map(
                  (stat) => _OtherTagStatRow(
                    stat: stat,
                    onTap: () => _showEntries(stat.entries, stat.name),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '右侧数字为未完成/总数；${_scopeItemText}可计入多个普通标签。',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
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

  bool _entryHasTagDefinition(
    _StatEntry entry,
    TaskTagDefinition definition,
  ) {
    for (final snapshot in entry.tags) {
      if (snapshot.sourceTagId == definition.id ||
          (snapshot.sourceTagId == null && snapshot.name == definition.name)) {
        return true;
      }
    }
    return entry.tagNames.contains(definition.name);
  }

  List<_StatEntry> _statEntries(
    List<PlanItem> plans,
    List<TaskItem> tasks,
  ) => [
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

  List<_Bucket> _buckets(DateTime start, DateTime end, List<TaskItem> tasks) {
    final daily =
        widget.criteria.mode == StatMode.week ||
        widget.criteria.mode == StatMode.month ||
        (widget.criteria.mode == StatMode.custom &&
            end.difference(start).inDays <= 31);
    final result = <_Bucket>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final bucketStart = dateOnly(cursor);
      final bucketEndDate = daily
          ? cursor
          : DateTime(cursor.year, cursor.month + 1, 0);
      final bucketEnd = dateOnly(
        bucketEndDate.isAfter(end) ? end : bucketEndDate,
      );
      final items = tasks
          .where(
            (task) =>
                task.startDate.compareTo(bucketStart) >= 0 &&
                task.startDate.compareTo(bucketEnd) <= 0,
          )
          .toList();
      result.add(
        _Bucket(
          label: daily ? '${cursor.day}' : '${cursor.month}月',
          total: items.length,
          done: items.where(widget.controller.isDone).length,
        ),
      );
      cursor = daily
          ? cursor.add(const Duration(days: 1))
          : DateTime(cursor.year, cursor.month + 1);
    }
    return result;
  }

  void _showTasks(List<TaskItem> tasks, String title) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .8,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(18),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text('没有任务')),
                ),
              ...tasks.map(
                (task) => TaskCard(
                  task: task,
                  controller: widget.controller,
                  nested: task.parentTaskId != null,
                  onTap: () =>
                      showTaskEditor(context, widget.controller, task: task),
                ),
              ),
            ],
          ),
        ),
      );

  void _showPlans(List<PlanItem> plans, String title) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .8,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(18),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              if (plans.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text('没有计划')),
                ),
              ...plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PlanCard(
                    plan: plan,
                    controller: widget.controller,
                    onTap: () =>
                        showPlanEditor(context, widget.controller, plan: plan),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  void _showEntries(List<_StatEntry> entries, String title) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .8,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(18),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(child: Text(_emptyScopeLabel)),
                ),
              ...entries.map((entry) {
                final plan = entry.plan;
                if (plan != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PlanCard(
                      plan: plan,
                      controller: widget.controller,
                      onTap: () => showPlanEditor(
                        context,
                        widget.controller,
                        plan: plan,
                      ),
                    ),
                  );
                }
                final task = entry.task!;
                return TaskCard(
                  task: task,
                  controller: widget.controller,
                  nested: task.parentTaskId != null,
                  onTap: () =>
                      showTaskEditor(context, widget.controller, task: task),
                );
              }),
            ],
          ),
        ),
      );
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
    required this.onOpenAll,
    required this.onOpenEntry,
  });

  final _QuadrantGroup group;
  final String emptyLabel;
  final VoidCallback onOpenAll;
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
            InkWell(
              onTap: onOpenAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
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
                        return InkWell(
                          onTap: () => onOpenEntry(entry),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  done
                                      ? Icons.check_circle_outline
                                      : Icons.radio_button_unchecked,
                                  size: 12,
                                  color: done
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                      : group.definition.color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      decoration: done
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: done
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
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
    required this.unfinished,
  });

  final String name;
  final Color? color;
  final IconData? icon;
  final List<_StatEntry> entries;
  final int unfinished;
}

class _OtherTagStatRow extends StatelessWidget {
  const _OtherTagStatRow({required this.stat, required this.onTap});

  final _OtherTagStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(stat.icon ?? Icons.label_outline, size: 16, color: stat.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stat.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            '${stat.unfinished}/${stat.entries.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
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
    final categories = <String>{
      ...controller.categoryDefinitions.map((item) => item.name),
      ...controller.plans
          .map((plan) => plan.categoryName)
          .where((name) => name.isNotEmpty),
      ...controller.tasks
          .map((task) => task.type)
          .where((name) => name.isNotEmpty),
    }.toList()..sort();
    final templates = <String>{
      ...controller.progressTemplates.map((item) => item.name),
      ...controller.plans
          .map((plan) => plan.progress.templateName)
          .where((name) => name.isNotEmpty),
      ...controller.tasks
          .map((task) => task.progress?.templateName ?? '')
          .where((name) => name.isNotEmpty),
    }.toList()..sort();
    final nodes = <String>{
      ...controller.plans
          .map((plan) => plan.progress.currentNode?.name ?? '')
          .where((name) => name.isNotEmpty),
      ...controller.tasks
          .map((task) => task.progress?.currentNode?.name ?? '')
          .where((name) => name.isNotEmpty),
    }.toList()..sort();
    final tags = <String>{
      ...controller.tagDefinitions.map((item) => item.name),
      ...controller.plans.expand(
        (plan) => plan.tags.map((tag) => tag.name),
      ),
      ...controller.tasks.expand((task) => task.tags),
    }.toList()..sort();
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
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: '关闭',
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
                  ...StatScope.values.map(
                    (scope) => RadioListTile<StatScope>(
                      value: scope,
                      groupValue: criteria.scope,
                      title: Text(scopeLabels[scope]!),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        if (value != null) {
                          onChanged(criteria.copyWith(scope: value));
                        }
                      },
                    ),
                  ),
                  const Divider(height: 28),
                  Text(
                    '统计周期',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...StatMode.values.map(
                    (mode) => RadioListTile<StatMode>(
                      value: mode,
                      groupValue: criteria.mode,
                      title: Text(labels[mode]!),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        if (value != null) {
                          onChanged(criteria.copyWith(mode: value));
                        }
                      },
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
                    initialValue: criteria.categoryName,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('全部分类'),
                      ),
                      ...categories.map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      ),
                    ],
                    onChanged: (value) => onChanged(
                      criteria.copyWith(categoryName: value ?? ''),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: criteria.progressTemplateName,
                    decoration: const InputDecoration(labelText: '进度方案'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('全部进度方案'),
                      ),
                      ...templates.map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      ),
                    ],
                    onChanged: (value) => onChanged(
                      criteria.copyWith(progressTemplateName: value ?? ''),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: criteria.progressNodeName,
                    decoration: const InputDecoration(labelText: '进度节点'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('全部进度节点'),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: criteria.planId,
                    decoration: const InputDecoration(labelText: '所属计划'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('全部计划'),
                      ),
                      ...controller.plans.map(
                        (plan) => DropdownMenuItem(
                          value: plan.id,
                          child: Text(plan.name),
                        ),
                      ),
                      ...controller.tasks
                          .map((task) => task.planId)
                          .whereType<String>()
                          .toSet()
                          .where(
                            (id) => !controller.plans.any(
                              (plan) => plan.id == id,
                            ),
                          )
                          .map(
                            (id) => DropdownMenuItem(
                              value: id,
                              child: Text('$id（历史计划）'),
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        onChanged(criteria.copyWith(planId: value ?? '')),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '标签',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final selected = criteria.tags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: selected,
                        onSelected: (value) {
                          final next = {...criteria.tags};
                          value ? next.add(tag) : next.remove(tag);
                          onChanged(criteria.copyWith(tags: next));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => onChanged(
                      StatCriteria.initial().copyWith(
                        mode: criteria.mode,
                        anchor: criteria.anchor,
                        customStart: criteria.customStart,
                        customEnd: criteria.customEnd,
                      ),
                    ),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('清空业务条件'),
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
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
    required this.onTap,
  });
  final String label;
  final int count;
  final int total;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Text('$count'),
        ],
      ),
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
  final List<_Bucket> buckets;
  @override
  Widget build(BuildContext context) {
    final maximum = buckets.fold<int>(
      1,
      (value, bucket) => bucket.total > value ? bucket.total : value,
    );
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets
            .map(
              (bucket) => Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (bucket.total > 0)
                      Text(
                        '${bucket.total}',
                        style: const TextStyle(fontSize: 9),
                      ),
                    Container(
                      height: (bucket.total - bucket.done) / maximum * 105,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: const Color(0xff487bca),
                    ),
                    Container(
                      height: bucket.done / maximum * 105,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: const Color(0xff3f9875),
                    ),
                    Text(bucket.label, style: const TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
