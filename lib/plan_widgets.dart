import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'plan_editor.dart';
import 'task_editor.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.controller,
    required this.onTap,
    this.onAddTask,
    this.onDelete,
    this.onProgressTap,
    this.progressUpdating = false,
    this.detailed = false,
  });

  final PlanItem plan;
  final AppController controller;
  final VoidCallback onTap;
  final VoidCallback? onAddTask;
  final VoidCallback? onDelete;
  final VoidCallback? onProgressTap;
  final bool progressUpdating;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final node = plan.progress.currentNode;
    final tasks = controller.tasks
        .where((task) => task.planId == plan.id)
        .toList();
    final completedTasks = tasks.where(controller.isDone).length;
    final color = node?.color ?? Color(plan.categoryColorValue);
    final managementMode = onAddTask != null || onDelete != null;
    final detailedMode = detailed || managementMode;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (node != null) const SizedBox(width: 8),
                  if (node != null)
                    if (detailedMode)
                      _PlanStatusBadge(
                        name: node.name,
                        color: color,
                        onTap: progressUpdating ? null : onProgressTap,
                        updating: progressUpdating,
                      )
                    else
                      Text(
                        node.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                ],
              ),
              if (plan.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plan.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (detailedMode &&
                  (plan.categoryName.isNotEmpty || plan.contacts.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      if (plan.categoryName.isNotEmpty)
                        Text(
                          '◇ ${plan.categoryName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (plan.contacts.isNotEmpty)
                        Text(
                          '♙ ${[plan.contacts.first.name, plan.contacts.first.phone].where((value) => value.trim().isNotEmpty).join(' ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              if (detailedMode && plan.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: plan.tags.take(4).map((tag) {
                      final tagColor = Color(tag.colorValue);
                      return Chip(
                        avatar: Icon(
                          taskTagIcons[tag.iconName] ?? Icons.label_outline,
                          size: 14,
                          color: tagColor,
                        ),
                        label: Text(tag.name),
                        labelStyle: const TextStyle(fontSize: 12),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        side: BorderSide(color: tagColor),
                        backgroundColor: tagColor.withAlpha(24),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ),
              if (detailedMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${plan.startDate} — ${plan.targetDate}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$completedTasks/${tasks.length} 项任务',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (onAddTask != null)
                        IconButton(
                          tooltip: '新增任务',
                          visualDensity: VisualDensity.compact,
                          onPressed: onAddTask,
                          icon: const Icon(Icons.add_task_outlined, size: 20),
                        ),
                      if (onDelete != null)
                        IconButton(
                          tooltip: '删除计划',
                          visualDensity: VisualDensity.compact,
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                    ],
                  ),
                )
              else ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.date_range_outlined, size: 15),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${plan.startDate} — ${plan.targetDate}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '$completedTasks/${tasks.length} 项任务',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditablePlanCard extends StatefulWidget {
  const EditablePlanCard({
    super.key,
    required this.plan,
    required this.controller,
  });

  final PlanItem plan;
  final AppController controller;

  @override
  State<EditablePlanCard> createState() => _EditablePlanCardState();
}

class _EditablePlanCardState extends State<EditablePlanCard> {
  bool _progressUpdating = false;

  @override
  Widget build(BuildContext context) => PlanCard(
    plan: widget.plan,
    controller: widget.controller,
    progressUpdating: _progressUpdating,
    onProgressTap: () => _showProgressPicker(context),
    onTap: () => showPlanEditor(context, widget.controller, plan: widget.plan),
    onAddTask: () => showTaskEditor(
      context,
      widget.controller,
      initialDate: widget.plan.startDate,
      initialPlanId: widget.plan.id,
    ),
    onDelete: () => _deletePlan(context),
  );

  Future<void> _showProgressPicker(BuildContext context) async {
    if (_progressUpdating) return;
    final nodes = [...widget.plan.progress.nodes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final selectedNodeId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '更新计划进度',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ...nodes.map((node) {
              final selected = node.id == widget.plan.progress.currentNodeId;
              final color = node.color;
              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(node.name),
                trailing: selected
                    ? Icon(Icons.check_circle, color: color)
                    : null,
                selected: selected,
                onTap: () => Navigator.pop(sheetContext, node.id),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted ||
        selectedNodeId == null ||
        selectedNodeId == widget.plan.progress.currentNodeId) {
      return;
    }
    await _saveProgressChange(context, selectedNodeId);
  }

  Future<void> _saveProgressChange(BuildContext context, String nodeId) async {
    if (_progressUpdating) return;
    setState(() => _progressUpdating = true);
    try {
      await widget.controller.savePlan(
        widget.plan.copyWith(
          progress: widget.plan.progress.copyWith(currentNodeId: nodeId),
          updatedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      if (context.mounted) _showMessage(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _progressUpdating = false);
    }
  }

  Future<void> _deletePlan(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除计划？'),
            content: Text('确定删除“${widget.plan.name}”吗？存在任务的计划需要先清空任务。'),
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
      await widget.controller.deletePlan(widget.plan.id);
    } catch (error) {
      if (context.mounted) _showMessage(context, _errorMessage(error));
    }
  }

  void _showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
}

class _PlanStatusBadge extends StatelessWidget {
  const _PlanStatusBadge({
    required this.name,
    required this.color,
    this.onTap,
    this.updating = false,
  });

  final String name;
  final Color color;
  final VoidCallback? onTap;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
          if (onTap != null || updating) ...[
            const SizedBox(width: 2),
            if (updating)
              SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ],
      ),
    );
    if (onTap == null) return badge;
    return Semantics(
      button: true,
      label: '修改计划进度，当前$name',
      child: Tooltip(
        message: '修改计划进度',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          excludeFromSemantics: true,
          onTap: onTap,
          child: badge,
        ),
      ),
    );
  }
}
