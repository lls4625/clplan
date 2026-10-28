import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';

import 'app_controller.dart';
import 'models.dart';
import 'l10n/preset_text.dart';
import 'l10n/ui_text.dart';
import 'tag_summary.dart';
import 'ui/app_alert.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.controller,
    required this.onTap,
    this.onAddSubtask,
    this.nested = false,
  });
  final TaskItem task;
  final AppController controller;
  final VoidCallback onTap;
  final VoidCallback? onAddSubtask;
  final bool nested;

  Future<void> _deleteTask(BuildContext context) async {
    if (controller.childrenOf(task.id).isNotEmpty) {
      showAppAlert(context, title: '无法删除任务', message: '请先删除或移走该主任务下的子任务。');
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除任务？'),
            content: RawText(
              localizeUiTextWithArguments(
                dialogContext,
                '确定删除“{0}”吗？',
                [task.title],
              ),
            ),
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
      await controller.deleteTask(task);
    } catch (error) {
      if (!context.mounted) return;
      showAppAlert(
        context,
        title: '删除失败',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final legacyStatus = controller.statusOf(task.statusId);
    final progressNode = task.progress?.currentNode;
    final parent = controller.taskById(task.parentTaskId);
    final contactText = task.contacts.isEmpty
        ? task.contact.trim()
        : task.contacts
              .map(
                (contact) => [
                  contact.name,
                  contact.phone,
                ].where((value) => value.trim().isNotEmpty).join(' '),
              )
              .where((value) => value.isNotEmpty)
              .join('、');
    final snapshotsByName = {
      for (final snapshot in task.tagSnapshots) snapshot.name: snapshot,
    };
    final tagItems =
        orderedSelectedTagNames(
          selectedNames: task.tags,
          definitionOrder: controller.tagDefinitions.map((tag) => tag.name),
        ).map((name) {
          final snapshot = snapshotsByName[name];
          final definition = controller.tagDefinitionForName(name);
          return CardTagItem(
            name: snapshot != null
                ? controller.displayTagName(
                    snapshot,
                    Localizations.localeOf(context),
                  )
                : definition == null
                ? name
                : tagDefinitionName(
                    definition,
                    Localizations.localeOf(context),
                  ),
            icon: snapshot == null
                ? definition?.icon ?? Icons.history
                : taskTagIcons[snapshot.iconName] ?? Icons.history,
            color: snapshot == null
                ? definition?.color
                : Color(snapshot.colorValue),
          );
        }).toList();
    return Padding(
      padding: EdgeInsets.only(left: nested ? 20 : 0, bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
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
                    if (nested)
                      const Padding(
                        padding: EdgeInsets.only(right: 8, top: 2),
                        child: Icon(Icons.subdirectory_arrow_right, size: 18),
                      ),
                    if (task.reminderEnabled && task.reminders.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 7, top: 1),
                        child: Icon(
                          task.reminders.any(
                                (item) =>
                                    item.deliveryType ==
                                    ReminderDeliveryType.alarm,
                              )
                              ? Icons.alarm_outlined
                              : Icons.notifications_none,
                          size: 19,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    Expanded(
                      child: RawText(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      name: progressNode == null
                          ? controller.displayStatusName(
                              legacyStatus,
                              Localizations.localeOf(context),
                            )
                          : controller.displayProgressNodeName(
                              progressNode,
                              Localizations.localeOf(context),
                            ),
                      color: progressNode?.color ?? legacyStatus.color,
                    ),
                  ],
                ),
                if (parent != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Text(
                          '主任务：',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Expanded(
                          child: RawText(
                            parent.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (task.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: RawText(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (task.type.isNotEmpty || contactText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 12,
                      children: [
                        if (task.type.isNotEmpty)
                          RawText(
                            '◇ ${controller.displayCategoryName(task.sourceCategoryId, task.type, Localizations.localeOf(context))}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (contactText.isNotEmpty)
                          RawText(
                            '♙ $contactText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                if (tagItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CardTagSummary(items: tagItems),
                  ),
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
                              task.startDate.isEmpty
                                  ? '尚未安排日期'
                                  : '${task.startDate}${task.startTime.isEmpty ? '' : ' ${task.startTime}'}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                            if (task.completedAt != null)
                              Text(
                                '完成于 ${DateFormat('yyyy-MM-dd HH:mm').format(task.completedAt!.toLocal())}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (onAddSubtask != null &&
                          task.parentTaskId == null &&
                          !controller.isDone(task))
                        IconButton(
                          tooltip: localizeUiText(context, '新增子任务'),
                          visualDensity: VisualDensity.compact,
                          onPressed: onAddSubtask,
                          icon: const Icon(Icons.add_task_outlined, size: 20),
                        ),
                      IconButton(
                        tooltip: localizeUiText(context, '删除任务'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteTask(context),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.name, required this.color});
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
    child: RawText(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 11),
    ),
  );
}

String dateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dateFromText(String value) =>
    DateTime.tryParse(value) ?? DateTime.now();
