import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.controller,
    required this.onTap,
    this.onAddTask,
    this.onDelete,
    this.detailed = false,
  });

  final PlanItem plan;
  final AppController controller;
  final VoidCallback onTap;
  final VoidCallback? onAddTask;
  final VoidCallback? onDelete;
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
                      _PlanStatusBadge(name: node.name, color: color)
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
                          '♙ ${[
                            plan.contacts.first.name,
                            plan.contacts.first.phone,
                          ].where((value) => value.trim().isNotEmpty).join(' ')}',
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
                          size: 16,
                          color: tagColor,
                        ),
                        label: Text(tag.name),
                        side: BorderSide(color: tagColor),
                        backgroundColor: tagColor.withAlpha(24),
                        visualDensity: VisualDensity.compact,
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

class _PlanStatusBadge extends StatelessWidget {
  const _PlanStatusBadge({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 90),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 11),
    ),
  );
}
