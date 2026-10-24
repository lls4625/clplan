import 'package:flutter/material.dart' hide Text;

import 'app_controller.dart';
import 'models.dart';
import 'l10n/ui_text.dart';
import 'plan_widgets.dart';
import 'stable_filter_chip.dart';
import 'task_editor.dart';
import 'task_widgets.dart';
import 'ui/glass_bottom_navigation.dart';

enum PlanCompletionFilter { unfinished, completed, all }

extension PlanCompletionFilterLabel on PlanCompletionFilter {
  String get label => switch (this) {
    PlanCompletionFilter.unfinished => '未完成',
    PlanCompletionFilter.completed => '已完成',
    PlanCompletionFilter.all => '全部',
  };

  bool matches(PlanItem plan) => switch (this) {
    PlanCompletionFilter.unfinished => !plan.progress.completed,
    PlanCompletionFilter.completed => plan.progress.completed,
    PlanCompletionFilter.all => true,
  };
}

class PlanSearchCriteria {
  const PlanSearchCriteria({
    required this.year,
    required this.month,
    this.categoryName = '',
    this.progressTemplateName = '',
    this.progressNodeName = '',
    this.planKeyword = '',
    this.taskKeyword = '',
    this.tags = const <String>{},
  });

  factory PlanSearchCriteria.initial() {
    final now = DateTime.now();
    return PlanSearchCriteria(year: now.year, month: now.month);
  }

  final int year;
  final int month;
  final String categoryName;
  final String progressTemplateName;
  final String progressNodeName;
  final String planKeyword;
  final String taskKeyword;
  final Set<String> tags;

  PlanSearchCriteria copyWith({
    int? year,
    int? month,
    String? categoryName,
    String? progressTemplateName,
    String? progressNodeName,
    String? planKeyword,
    String? taskKeyword,
    Set<String>? tags,
  }) => PlanSearchCriteria(
    year: year ?? this.year,
    month: month ?? this.month,
    categoryName: categoryName ?? this.categoryName,
    progressTemplateName: progressTemplateName ?? this.progressTemplateName,
    progressNodeName: progressNodeName ?? this.progressNodeName,
    planKeyword: planKeyword ?? this.planKeyword,
    taskKeyword: taskKeyword ?? this.taskKeyword,
    tags: tags ?? this.tags,
  );

  bool matchesPlan(PlanItem plan, AppController controller) {
    final monthStart = _dateText(DateTime(year, month, 1));
    final monthEnd = _dateText(DateTime(year, month + 1, 0));
    if (plan.startDate.compareTo(monthEnd) > 0 ||
        plan.targetDate.compareTo(monthStart) < 0) {
      return false;
    }
    if (categoryName.isNotEmpty && plan.categoryName != categoryName) {
      return false;
    }
    if (progressTemplateName.isNotEmpty &&
        plan.progress.templateName != progressTemplateName) {
      return false;
    }
    if (progressNodeName.isNotEmpty &&
        plan.progress.currentNode?.name != progressNodeName) {
      return false;
    }
    final normalizedPlanKeyword = planKeyword.trim().toLowerCase();
    if (normalizedPlanKeyword.isNotEmpty &&
        !plan.name.toLowerCase().contains(normalizedPlanKeyword)) {
      return false;
    }
    final normalizedTaskKeyword = taskKeyword.trim().toLowerCase();
    if (normalizedTaskKeyword.isNotEmpty &&
        !controller.tasks.any(
          (task) =>
              task.planId == plan.id &&
              task.title.toLowerCase().contains(normalizedTaskKeyword),
        )) {
      return false;
    }
    if (tags.isNotEmpty && !plan.tags.any((tag) => tags.contains(tag.name))) {
      return false;
    }
    return true;
  }

  bool matchesLegacyTask(TaskItem task) {
    if (planKeyword.trim().isNotEmpty) return false;
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}';
    if (!task.startDate.startsWith(monthPrefix)) return false;
    if (categoryName.isNotEmpty && task.type != categoryName) return false;
    if (progressTemplateName.isNotEmpty &&
        task.progress?.templateName != progressTemplateName) {
      return false;
    }
    if (progressNodeName.isNotEmpty &&
        task.progress?.currentNode?.name != progressNodeName) {
      return false;
    }
    final normalizedTaskKeyword = taskKeyword.trim().toLowerCase();
    if (normalizedTaskKeyword.isNotEmpty &&
        !task.title.toLowerCase().contains(normalizedTaskKeyword)) {
      return false;
    }
    if (tags.isNotEmpty && !tags.any(task.tags.contains)) return false;
    return true;
  }
}

String _dateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class PlansPage extends StatefulWidget {
  const PlansPage({
    super.key,
    required this.controller,
    required this.filter,
    required this.searchCriteria,
    required this.onFilterChanged,
  });

  final AppController controller;
  final PlanCompletionFilter filter;
  final PlanSearchCriteria searchCriteria;
  final ValueChanged<PlanCompletionFilter> onFilterChanged;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  late final PageController _pageController = PageController(
    initialPage: widget.filter.index,
  );
  @override
  void didUpdateWidget(covariant PlansPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != oldWidget.filter &&
        _pageController.hasClients &&
        _pageController.page?.round() != widget.filter.index) {
      _pageController.animateToPage(
        widget.filter.index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: SegmentedButton<PlanCompletionFilter>(
                segments: PlanCompletionFilter.values
                    .map(
                      (filter) => ButtonSegment(
                        value: filter,
                        label: Text(filter.label),
                      ),
                    )
                    .toList(),
                selected: {widget.filter},
                showSelectedIcon: false,
                onSelectionChanged: (selected) => _selectFilter(selected.first),
              ),
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) =>
                widget.onFilterChanged(PlanCompletionFilter.values[index]),
            children: PlanCompletionFilter.values
                .map((filter) => _buildPlanList(context, filter))
                .toList(),
          ),
        ),
      ],
    );
  }

  void _selectFilter(PlanCompletionFilter filter) {
    widget.onFilterChanged(filter);
  }

  Widget _buildPlanList(BuildContext context, PlanCompletionFilter filter) {
    final plans =
        widget.controller.plans
            .where(filter.matches)
            .where(
              (plan) =>
                  widget.searchCriteria.matchesPlan(plan, widget.controller),
            )
            .toList()
          ..sort((a, b) {
            final date = a.startDate.compareTo(b.startDate);
            return date != 0 ? date : a.name.compareTo(b.name);
          });
    final legacyTasks =
        widget.controller.tasks
            .where((task) => task.planId == null)
            .where(widget.searchCriteria.matchesLegacyTask)
            .toList()
          ..sort(widget.controller.compareTasks);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        AppBottomNavigation.contentBottomPadding(context),
      ),
      children: [
        if (plans.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 42),
            child: Center(
              child: Text(
                filter == PlanCompletionFilter.all
                    ? '暂无计划'
                    : '暂无${filter.label}计划',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ...plans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EditablePlanCard(
              key: ValueKey(plan.id),
              plan: plan,
              controller: widget.controller,
            ),
          ),
        ),
        if (filter == PlanCompletionFilter.all && legacyTasks.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            '未归属计划的历史任务',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '这些是旧版本创建的数据，仅保留查看和编辑入口；新任务必须从计划详情中新增。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ...legacyTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskCard(
                task: task,
                controller: widget.controller,
                nested: task.parentTaskId != null,
                onTap: () =>
                    showTaskEditor(context, widget.controller, task: task),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class PlanSearchDrawer extends StatefulWidget {
  const PlanSearchDrawer({
    super.key,
    required this.controller,
    required this.criteria,
    required this.onChanged,
  });

  final AppController controller;
  final PlanSearchCriteria criteria;
  final ValueChanged<PlanSearchCriteria> onChanged;

  @override
  State<PlanSearchDrawer> createState() => _PlanSearchDrawerState();
}

class _PlanSearchDrawerState extends State<PlanSearchDrawer> {
  late final TextEditingController _planController;
  late final TextEditingController _taskController;

  @override
  void initState() {
    super.initState();
    _planController = TextEditingController(text: widget.criteria.planKeyword);
    _taskController = TextEditingController(text: widget.criteria.taskKeyword);
  }

  @override
  void dispose() {
    _planController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = <int>{
      currentYear,
      ...widget.controller.plans.expand(
        (plan) => [
          int.tryParse(plan.startDate.split('-').first) ?? currentYear,
          int.tryParse(plan.targetDate.split('-').first) ?? currentYear,
        ],
      ),
    }.toList()..sort((a, b) => b.compareTo(a));
    final categories = widget.controller.orderedCategoryNames([
      ...widget.controller.plans
          .map((plan) => plan.categoryName)
          .where((name) => name.isNotEmpty),
    ]);
    final templates = widget.controller.orderedProgressTemplateNames([
      ...widget.controller.plans
          .map((plan) => plan.progress.templateName)
          .where((name) => name.isNotEmpty),
    ]);
    final nodes = widget.controller.progressNodeNamesForTemplate(
      widget.criteria.progressTemplateName,
      [
        ...widget.controller.plans.map((plan) => plan.progress),
        ...widget.controller.tasks
            .map((task) => task.progress)
            .whereType<ProgressSnapshot>(),
      ],
    );
    final tags = widget.controller.orderedTagNames([
      ...widget.controller.plans.expand(
        (plan) => plan.tags.map((tag) => tag.name),
      ),
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
                      '查询条件',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: localizeUiText(context, '恢复默认条件'),
                        onPressed: () {
                          _planController.clear();
                          _taskController.clear();
                          widget.onChanged(PlanSearchCriteria.initial());
                        },
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
                  TextField(
                    controller: _planController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => widget.onChanged(
                      widget.criteria.copyWith(planKeyword: value),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: localizeUiText(context, '计划名称'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taskController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => widget.onChanged(
                      widget.criteria.copyWith(taskKeyword: value),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.task_alt_outlined),
                      labelText: localizeUiText(context, '任务名称'),
                    ),
                  ),
                  const Divider(height: 30),
                  Text('查询日期', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('plan-year-${widget.criteria.year}'),
                          initialValue: widget.criteria.year,
                          decoration: InputDecoration(
                            labelText: localizeUiText(context, '年度'),
                          ),
                          items: years
                              .map(
                                (year) => DropdownMenuItem(
                                  value: year,
                                  child: Text('$year 年'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              widget.onChanged(
                                widget.criteria.copyWith(year: value),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('plan-month-${widget.criteria.month}'),
                          initialValue: widget.criteria.month,
                          decoration: InputDecoration(
                            labelText: localizeUiText(context, '月份'),
                          ),
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1} 月'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              widget.onChanged(
                                widget.criteria.copyWith(month: value),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'plan-category-${widget.criteria.categoryName}',
                    ),
                    initialValue: widget.criteria.categoryName,
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
                    onChanged: (value) => widget.onChanged(
                      widget.criteria.copyWith(categoryName: value ?? ''),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'plan-template-${widget.criteria.progressTemplateName}',
                    ),
                    initialValue: widget.criteria.progressTemplateName,
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
                    onChanged: (value) => widget.onChanged(
                      widget.criteria.copyWith(
                        progressTemplateName: value ?? '',
                        progressNodeName: '',
                      ),
                    ),
                  ),
                  if (widget.criteria.progressTemplateName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'plan-node-${widget.criteria.progressTemplateName}-'
                        '${widget.criteria.progressNodeName}',
                      ),
                      initialValue: widget.criteria.progressNodeName,
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
                      onChanged: (value) => widget.onChanged(
                        widget.criteria.copyWith(progressNodeName: value ?? ''),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text('标签', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (tags.isEmpty)
                    Text('暂无标签', style: Theme.of(context).textTheme.bodySmall)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final selected = widget.criteria.tags.contains(tag);
                        return StableFilterChip(
                          label: tag,
                          selected: selected,
                          onSelected: (value) {
                            final next = {...widget.criteria.tags};
                            value ? next.add(tag) : next.remove(tag);
                            widget.onChanged(
                              widget.criteria.copyWith(tags: next),
                            );
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
}
