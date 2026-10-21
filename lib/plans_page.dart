import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'plan_editor.dart';
import 'plan_widgets.dart';
import 'task_editor.dart';
import 'task_widgets.dart';

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

class PlansPage extends StatefulWidget {
  const PlansPage({
    super.key,
    required this.controller,
    required this.filter,
    required this.onFilterChanged,
  });

  final AppController controller;
  final PlanCompletionFilter filter;
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
            child: Row(
              children: PlanCompletionFilter.values
                  .map(
                    (filter) => Expanded(
                      child: _PlanFilterTab(
                        label: filter.label,
                        selected: widget.filter == filter,
                        onTap: () => _selectFilter(filter),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => widget.onFilterChanged(
              PlanCompletionFilter.values[index],
            ),
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

  Widget _buildPlanList(
    BuildContext context,
    PlanCompletionFilter filter,
  ) {
    final plans = widget.controller.plans.where(filter.matches).toList()
      ..sort((a, b) {
        final date = a.startDate.compareTo(b.startDate);
        return date != 0 ? date : a.name.compareTo(b.name);
      });
    final legacyTasks =
        widget.controller.tasks.where((task) => task.planId == null).toList()
          ..sort(widget.controller.compareTasks);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
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
            child: PlanCard(
              plan: plan,
              controller: widget.controller,
              onTap: () => showPlanEditor(
                context,
                widget.controller,
                plan: plan,
              ),
              onAddTask: () => showTaskEditor(
                context,
                widget.controller,
                initialDate: plan.startDate,
                initialPlanId: plan.id,
              ),
              onDelete: () => _deletePlan(context, plan),
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
                onTap: () => showTaskEditor(
                  context,
                  widget.controller,
                  task: task,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _deletePlan(BuildContext context, PlanItem plan) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除计划？'),
            content: Text('确定删除“${plan.name}”吗？存在任务的计划需要先清空任务。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await widget.controller.deletePlan(plan.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }
}

class _PlanFilterTab extends StatelessWidget {
  const _PlanFilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 13, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              decoration: BoxDecoration(
                color: selected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
