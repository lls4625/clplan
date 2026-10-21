import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_controller.dart';
import 'contact_widgets.dart';
import 'models.dart';
import 'notification_service.dart';
import 'task_widgets.dart';

Future<bool?> showTaskEditor(
  BuildContext context,
  AppController controller, {
  TaskItem? task,
  String? initialDate,
  String? parentTaskId,
  String? originId,
  String? initialPlanId,
}) {
  final editor = TaskEditor(
    controller: controller,
    task: task,
    initialDate: initialDate,
    parentTaskId: parentTaskId,
    originId: originId,
    initialPlanId: initialPlanId,
  );
  if (task == null) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => editor),
    );
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: .94, child: editor),
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    required this.controller,
    this.task,
    this.initialDate,
    this.parentTaskId,
    this.originId,
    this.initialPlanId,
  });
  final AppController controller;
  final TaskItem? task;
  final String? initialDate;
  final String? parentTaskId;
  final String? originId;
  final String? initialPlanId;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController type;
  late final TextEditingController reason;
  late final TextEditingController followup;
  late final List<ContactEntry> selectedContacts;
  late final Set<String> selectedTags;
  late String statusId;
  late ProgressSnapshot progress;
  late String startDate;
  late String startTime;
  late List<TaskReminderRule> reminders;
  late bool reminderEnabled;
  String? selectedParentId;
  bool saving = false;

  bool get readOnly =>
      widget.task != null && widget.controller.isDone(widget.task!);
  bool get hasChildren =>
      widget.task != null &&
      widget.controller.childrenOf(widget.task!.id).isNotEmpty;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    title = TextEditingController(text: task?.title ?? '');
    description = TextEditingController(text: task?.description ?? '');
    type = TextEditingController(text: task?.type ?? '');
    selectedContacts = [...?task?.contacts];
    if (selectedContacts.isEmpty && (task?.contact ?? '').trim().isNotEmpty) {
      selectedContacts.add(
        ContactEntry(
          id: 'legacy-${task!.id}',
          name: task.contact.trim(),
          phone: '',
        ),
      );
    }
    selectedTags = {...?task?.tags};
    reason = TextEditingController(text: task?.reason ?? '');
    followup = TextEditingController();
    statusId =
        task?.statusId ??
        widget.controller.statuses
            .firstWhere(
              (value) => !value.completed,
              orElse: () => widget.controller.statuses.first,
            )
            .id;
    progress =
        task?.progress ??
        widget.controller.progressSnapshotForTask(
          task?.id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}',
        );
    startDate =
        task?.startDate ?? widget.initialDate ?? dateOnly(DateTime.now());
    startTime = task?.startTime ?? '';
    reminders = [...?task?.reminders];
    if (task == null &&
        startTime.isNotEmpty &&
        widget.controller.preferences.defaultReminderMinutes >= 0) {
      reminders.add(
        TaskReminderRule(
          id: 'reminder-${DateTime.now().microsecondsSinceEpoch}',
          taskId: 'draft',
          type: ReminderRuleType.relativeDuration,
          offsetMinutes: widget.controller.preferences.defaultReminderMinutes,
          sortOrder: 0,
        ),
      );
    }
    reminderEnabled = task?.reminderEnabled ?? reminders.isNotEmpty;
    selectedParentId = task?.parentTaskId ?? widget.parentTaskId;
  }

  @override
  void dispose() {
    for (final item in [title, description, type, reason, followup]) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: startDate.isEmpty ? DateTime.now() : dateFromText(startDate),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (value != null) setState(() => startDate = dateOnly(value));
  }

  Future<void> _pickTime() async {
    final initial = TimeOfDay(
      hour: startTime.isEmpty
          ? TimeOfDay.now().hour
          : int.parse(startTime.split(':')[0]),
      minute: startTime.isEmpty
          ? TimeOfDay.now().minute
          : int.parse(startTime.split(':')[1]),
    );
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value != null) {
      setState(() {
        startTime =
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        final defaultMinutes =
            widget.controller.preferences.defaultReminderMinutes;
        if (widget.task == null && reminders.isEmpty && defaultMinutes >= 0) {
          reminders.add(_relativeReminder(defaultMinutes));
          reminderEnabled = true;
        }
      });
    }
  }

  Future<void> _save({bool next = false, bool nextAsChild = false}) async {
    if (!readOnly && title.text.trim().isEmpty) {
      _message('请输入标题。');
      return;
    }
    if (startDate.isEmpty && startTime.isNotEmpty) {
      _message('设置时间前需要选择日期。');
      return;
    }
    if (reminderEnabled &&
        reminders.any(
          (item) =>
              item.type != ReminderRuleType.absolute &&
              (startDate.isEmpty || startTime.isEmpty),
        )) {
      _message('相对提醒需要先设置任务日期和时间。');
      return;
    }
    setState(() => saving = true);
    try {
      final old = widget.task;
      final now = DateTime.now();
      final nextNode = progress.currentNode;
      final nextCompleted = nextNode?.completed ?? false;
      final nextStatus = widget.controller.statuses.firstWhere(
        (value) => value.completed == nextCompleted,
        orElse: () => widget.controller.statusOf(statusId),
      );
      final history = <String>[];
      if (old != null && old.startDate != startDate)
        history.add(
          '开始日期：${old.startDate.isEmpty ? '未安排' : old.startDate} → ${startDate.isEmpty ? '未安排' : startDate}',
        );
      if (old != null && old.progress?.currentNodeId != progress.currentNodeId)
        history.add(
          '进度：${old.progress?.currentNode?.name ?? widget.controller.statusOf(old.statusId).name} → ${nextNode?.name ?? nextStatus.name}',
        );
      if (old != null && old.parentTaskId != selectedParentId)
        history.add('主任务关联已调整');
      if (old != null &&
          old.reminders
                  .map((item) => '${item.deliveryTypeName}:${item.label}')
                  .join('|') !=
              reminders
                  .map((item) => '${item.deliveryTypeName}:${item.label}')
                  .join('|')) {
        history.add('提醒设置已调整');
      }
      final wasDone = old != null && widget.controller.isDone(old);
      final orderedTags = readOnly ? old!.tags : _orderedSelectedTags();
      final tagSnapshots = readOnly
          ? old!.tagSnapshots
          : orderedTags.map((tagName) {
              final definition = widget.controller.tagDefinitionForName(
                tagName,
              );
              for (final snapshot
                  in old?.tagSnapshots ?? const <TaskTagSnapshot>[]) {
                if (snapshot.name == tagName && definition == null)
                  return snapshot;
              }
              return TaskTagSnapshot(
                sourceTagId: definition?.id,
                name: tagName,
                colorValue: definition?.colorValue ?? 0xff8e8e93,
                iconName: definition?.iconName ?? 'label',
              );
            }).toList();
      final item = TaskItem(
        id: old?.id ?? 'task-${now.microsecondsSinceEpoch}',
        title: readOnly ? old!.title : title.text.trim(),
        description: readOnly ? old!.description : description.text,
        type: readOnly ? old!.type : type.text.trim(),
        contact: readOnly
            ? old!.contact
            : selectedContacts
                  .map(
                    (contact) => contact.phone.isEmpty
                        ? contact.name
                        : '${contact.name} ${contact.phone}',
                  )
                  .join('、'),
        statusId: statusId,
        tags: orderedTags,
        startDate: readOnly ? old!.startDate : startDate,
        startTime: readOnly ? old!.startTime : startTime,
        reason: readOnly ? old!.reason : reason.text.trim(),
        completedAt: nextStatus.completed
            ? (wasDone ? old!.completedAt : now)
            : null,
        originId: old?.originId ?? widget.originId,
        parentTaskId: readOnly ? old!.parentTaskId : selectedParentId,
        updatedAt: now,
        sourceCategoryId: readOnly ? old!.sourceCategoryId : null,
        categoryColorValue: readOnly ? old!.categoryColorValue : 0xff8e8e93,
        categoryIconName: readOnly ? old!.categoryIconName : 'project',
        tagSnapshots: tagSnapshots,
        progress: progress,
        planId: old?.planId ?? widget.initialPlanId,
        recurrenceRuleId: old?.recurrenceRuleId,
        occurrenceDate: old?.occurrenceDate,
        detachedFromRule:
            old?.detachedFromRule == true || old?.recurrenceRuleId != null,
        contacts: readOnly ? old!.contacts : List.of(selectedContacts),
        reminderEnabled: readOnly
            ? old!.reminderEnabled
            : reminderEnabled && reminders.isNotEmpty,
        reminders: readOnly ? old!.reminders : List.of(reminders),
      );
      await widget.controller.saveTask(
        item,
        followup: readOnly ? null : followup.text,
        history: history,
      );
      if (!mounted) return;
      final hostContext = Navigator.of(context).context;
      Navigator.pop(context, true);
      if ((next || nextAsChild) && hostContext.mounted) {
        await showTaskEditor(
          hostContext,
          widget.controller,
          initialDate: item.startDate,
          parentTaskId: nextAsChild ? item.id : null,
          originId: next ? item.id : null,
          initialPlanId: item.planId,
        );
      }
    } catch (exception) {
      if (mounted)
        _message(exception.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  List<String> _orderedSelectedTags() {
    final activeNames = widget.controller.tagDefinitions
        .map((tag) => tag.name)
        .toSet();
    return [
      ...widget.controller.tagDefinitions
          .where((tag) => selectedTags.contains(tag.name))
          .map((tag) => tag.name),
      ...selectedTags.where((tag) => !activeNames.contains(tag)),
    ];
  }

  Future<void> _deleteTask() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除任务？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.controller.deleteTask(widget.task!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final effectivePlanId = widget.task?.planId ?? widget.initialPlanId;
    PlanItem? owningPlan;
    for (final plan in widget.controller.plans) {
      if (plan.id == effectivePlanId) owningPlan = plan;
    }
    final pageTitle = widget.task == null
        ? (selectedParentId == null ? '新建任务' : '新建子任务')
        : readOnly
        ? '完成记录'
        : '任务详情';
    return Scaffold(
      key: scaffoldKey,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          if (widget.task != null && !readOnly && !hasChildren)
            IconButton(
              tooltip: '删除任务',
              onPressed: _deleteTask,
              icon: const Icon(Icons.delete_outline),
            ),
          if (!readOnly)
            IconButton(
              tooltip: saving ? '保存中…' : '保存任务',
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
        ],
      ),
      endDrawer: _buildTagDrawer(context),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            if (owningPlan != null) ...[
              InputDecorator(
                decoration: const InputDecoration(labelText: '所属计划'),
                child: Text(owningPlan.name),
              ),
              const SizedBox(height: 10),
            ],
            if (readOnly) const _Notice(text: '完成记录只读。你可以更改状态，重新开启后再编辑内容。'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: readOnly ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(startDate.isEmpty ? '未安排日期' : startDate),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: readOnly || startDate.isEmpty ? null : _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(startTime.isEmpty ? '未设置时间' : startTime),
                  ),
                ),
                if (!readOnly && startDate.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() {
                      startDate = '';
                      startTime = '';
                      reminders.removeWhere(
                        (item) => item.type != ReminderRuleType.absolute,
                      );
                      reminderEnabled = reminders.isNotEmpty;
                    }),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildReminderCard(context),
            const SizedBox(height: 10),
            TextField(
              controller: title,
              readOnly: readOnly,
              maxLength: 100,
              scrollPadding: const EdgeInsets.only(bottom: 160),
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              readOnly: readOnly,
              maxLines: 3,
              maxLength: 200,
              scrollPadding: const EdgeInsets.only(bottom: 160),
              decoration: const InputDecoration(labelText: '内容'),
            ),
            const SizedBox(height: 10),
            _buildContacts(context),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue:
                  widget.controller.categoryDefinitions.any(
                    (item) => item.name == type.text,
                  )
                  ? type.text
                  : (type.text.isEmpty ? null : type.text),
              decoration: const InputDecoration(labelText: '分类'),
              items: [
                ...widget.controller.categoryDefinitions.map(
                  (category) => DropdownMenuItem(
                    value: category.name,
                    child: Row(
                      children: [
                        Icon(category.icon, color: category.color, size: 18),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  ),
                ),
                if (type.text.isNotEmpty &&
                    !widget.controller.categoryDefinitions.any(
                      (category) => category.name == type.text,
                    ))
                  DropdownMenuItem(
                    value: type.text,
                    child: Text('${type.text}（历史分类）'),
                  ),
              ],
              onChanged: readOnly
                  ? null
                  : (value) => setState(() => type.text = value ?? ''),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: progress.sourceTemplateId,
              decoration: const InputDecoration(labelText: '进度方案'),
              items: [
                ...widget.controller.progressTemplates.map(
                  (template) => DropdownMenuItem<String>(
                    value: template.id,
                    child: Text(template.name),
                  ),
                ),
                if (progress.sourceTemplateId != null &&
                    !widget.controller.progressTemplates.any(
                      (template) => template.id == progress.sourceTemplateId,
                    ))
                  DropdownMenuItem<String>(
                    value: progress.sourceTemplateId!,
                    child: Text('${progress.templateName}（历史方案）'),
                  ),
              ],
              onChanged: readOnly
                  ? null
                  : (value) => setState(() {
                      final id =
                          widget.task?.id ??
                          progress.instanceId.replaceFirst(
                            'task-progress-',
                            '',
                          );
                      progress = widget.controller.progressSnapshotForTask(
                        id,
                        templateId: value,
                      );
                    }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(
                '${progress.sourceTemplateId}-${progress.currentNodeId}',
              ),
              initialValue: progress.currentNodeId,
              decoration: const InputDecoration(labelText: '进度节点'),
              items: progress.nodes
                  .map(
                    (node) => DropdownMenuItem(
                      value: node.id,
                      child: Text(node.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                progress = progress.copyWith(currentNodeId: value);
                final completed = progress.completed;
                statusId = widget.controller.statuses
                    .firstWhere(
                      (status) => status.completed == completed,
                      orElse: () => widget.controller.statuses.first,
                    )
                    .id;
              }),
            ),
            const SizedBox(height: 10),
            if (widget.task?.parentTaskId != null) ...[
              InputDecorator(
                decoration: const InputDecoration(labelText: '历史上级任务'),
                child: Text(
                  widget.controller
                          .taskById(widget.task!.parentTaskId)
                          ?.title ??
                      '上级任务已不存在',
                ),
              ),
              const SizedBox(height: 10),
            ],
            _buildTags(context),
            if (!readOnly) ...[
              const SizedBox(height: 10),
              TextField(
                controller: reason,
                scrollPadding: const EdgeInsets.only(bottom: 160),
                decoration: const InputDecoration(labelText: '未完成主要原因'),
              ),
            ],
            if (widget.task != null) ...[
              const SizedBox(height: 20),
              Text(
                '跟进记录',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (widget.task!.followups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('还没有跟进记录'),
                ),
              ...widget.task!.followups.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.text),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(item.at.toLocal()),
                  ),
                ),
              ),
              if (!readOnly)
                TextField(
                  controller: followup,
                  maxLines: 2,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  decoration: const InputDecoration(labelText: '追加跟进'),
                ),
              if (widget.task!.history.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('变更历史（${widget.task!.history.length}）'),
                  children: widget.task!.history
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.text),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(item.at.toLocal()),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
            const SizedBox(height: 20),
            if (widget.task != null && !readOnly)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: saving ? null : () => _save(next: true),
                    child: const Text('保存并建下一项'),
                  ),
                ],
              ),
            if (readOnly) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? '保存中…' : '更改状态'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context) {
    final hasTaskTime = startDate.isNotEmpty && startTime.isNotEmpty;
    final permissionDisabled =
        widget.controller.reminderPermission ==
        ReminderPermissionState.disabled;
    final hasNotificationReminders = reminders.any(
      (item) => item.deliveryType == ReminderDeliveryType.notification,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: reminderEnabled,
              secondary: const Icon(Icons.notifications_none),
              title: const Text('提醒'),
              subtitle: Text(
                reminders.isEmpty
                    ? '可设置一次或多个提醒时间'
                    : '${reminders.length} 个提醒${permissionDisabled ? ' · 系统通知未开启' : ''}',
              ),
              onChanged: readOnly
                  ? null
                  : (value) => setState(() => reminderEnabled = value),
            ),
            if (reminderEnabled) ...[
              if (!hasTaskTime)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    '设置任务日期和时间后可使用快捷提醒；也可添加一个独立的指定时间。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: 5,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  mainAxisExtent: 44,
                ),
                itemBuilder: (context, index) {
                  const quickReminders = [
                    (0, '准时'),
                    (5, '5 分钟前'),
                    (30, '30 分钟前'),
                    (60, '1 小时前'),
                    (1440, '1 天前'),
                  ];
                  final entry = quickReminders[index];
                  return FilterChip(
                    label: Text(entry.$2),
                    selected: reminders.any(
                      (item) =>
                          item.type == ReminderRuleType.relativeDuration &&
                          item.offsetMinutes == entry.$1 &&
                          item.deliveryType ==
                              ReminderDeliveryType.notification,
                    ),
                    onSelected: readOnly || !hasTaskTime
                        ? null
                        : (_) => _toggleQuickReminder(entry.$1),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: readOnly
                          ? null
                          : () => _showAddReminder(
                              context,
                              ReminderDeliveryType.notification,
                            ),
                      icon: const Icon(Icons.notifications_none),
                      label: const Text('通知提醒'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: readOnly
                          ? null
                          : () => _showAddReminder(
                              context,
                              ReminderDeliveryType.alarm,
                            ),
                      icon: const Icon(Icons.alarm_outlined),
                      label: const Text('闹铃提醒'),
                    ),
                  ),
                ],
              ),
              if (reminders.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...reminders.map((rule) {
                  final fireAt = rule.fireDateFor(
                    startDate: startDate,
                    startTime: startTime,
                  );
                  final expired =
                      fireAt != null && fireAt.isBefore(DateTime.now());
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      rule.deliveryType == ReminderDeliveryType.alarm
                          ? Icons.alarm_outlined
                          : Icons.notifications_none,
                    ),
                    title: Text('${rule.deliveryLabel} · ${rule.label}'),
                    subtitle: fireAt == null
                        ? const Text('等待任务时间')
                        : Text(
                            expired
                                ? '已过期，不会再提醒'
                                : DateFormat('yyyy-MM-dd HH:mm').format(fireAt),
                          ),
                    trailing: readOnly
                        ? null
                        : IconButton(
                            tooltip: '删除提醒',
                            onPressed: () => setState(() {
                              reminders.remove(rule);
                              if (reminders.isEmpty) reminderEnabled = false;
                            }),
                            icon: const Icon(Icons.close),
                          ),
                  );
                }),
              ],
              if (permissionDisabled && hasNotificationReminders)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '提醒会保存，但需在系统设置中允许通知后才会生效。',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.controller.openReminderSettings,
                        child: const Text('去设置'),
                      ),
                    ],
                  ),
                ),
              if (reminders.any(
                (item) => item.deliveryType == ReminderDeliveryType.alarm,
              ))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.controller.alarmPermission ==
                            AlarmPermissionState.unsupported
                        ? '当前系统不支持闹铃提醒；规则会保留，但不会生效。'
                        : widget.controller.alarmPermission ==
                              AlarmPermissionState.denied
                        ? '闹铃权限未开启；规则会保留，但不会生效。'
                        : '闹铃提醒需要 iOS 26 或更高版本及独立授权。',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleQuickReminder(int minutes) {
    setState(() {
      final existing = reminders.where(
        (item) =>
            item.type == ReminderRuleType.relativeDuration &&
            item.offsetMinutes == minutes &&
            item.deliveryType == ReminderDeliveryType.notification,
      );
      if (existing.isNotEmpty) {
        reminders.remove(existing.first);
      } else {
        reminders.add(_relativeReminder(minutes));
      }
      reminderEnabled = reminders.isNotEmpty;
    });
  }

  TaskReminderRule _relativeReminder(
    int minutes, {
    ReminderDeliveryType deliveryType = ReminderDeliveryType.notification,
  }) => TaskReminderRule(
    id: 'reminder-${DateTime.now().microsecondsSinceEpoch}-$minutes',
    taskId: widget.task?.id ?? 'draft',
    type: ReminderRuleType.relativeDuration,
    offsetMinutes: minutes,
    sortOrder: reminders.length,
    deliveryType: deliveryType,
  );

  Future<void> _showAddReminder(
    BuildContext context,
    ReminderDeliveryType deliveryType,
  ) async {
    final type = await showModalBottomSheet<ReminderRuleType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '添加${deliveryType == ReminderDeliveryType.alarm ? '闹铃' : '通知'}提醒',
              ),
              subtitle: const Text('每条提醒可以选择独立的送达方式'),
            ),
            ListTile(
              enabled: startDate.isNotEmpty && startTime.isNotEmpty,
              leading: const Icon(Icons.timelapse),
              title: const Text('提前一段时间'),
              subtitle: const Text('例如提前 90 分钟'),
              onTap: () =>
                  Navigator.pop(context, ReminderRuleType.relativeDuration),
            ),
            ListTile(
              enabled: startDate.isNotEmpty && startTime.isNotEmpty,
              leading: const Icon(Icons.today_outlined),
              title: const Text('提前几天的指定时间'),
              subtitle: const Text('例如提前 2 天 09:00'),
              onTap: () =>
                  Navigator.pop(context, ReminderRuleType.relativeDayTime),
            ),
            ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('指定日期时间'),
              subtitle: const Text('设置一个独立的绝对提醒时间'),
              onTap: () => Navigator.pop(context, ReminderRuleType.absolute),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || type == null) return;
    switch (type) {
      case ReminderRuleType.relativeDuration:
        await _addCustomDuration(deliveryType);
        break;
      case ReminderRuleType.relativeDayTime:
        await _addRelativeDayTime(deliveryType);
        break;
      case ReminderRuleType.absolute:
        await _addAbsoluteReminder(deliveryType);
        break;
    }
  }

  Future<void> _addCustomDuration(ReminderDeliveryType deliveryType) async {
    final input = TextEditingController(text: '90');
    var unit = 1;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('提前一段时间'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '数值'),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: unit,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('分钟')),
                  DropdownMenuItem(value: 60, child: Text('小时')),
                  DropdownMenuItem(value: 1440, child: Text('天')),
                ],
                onChanged: (value) => setDialogState(() => unit = value ?? 1),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(input.text);
                Navigator.pop(
                  context,
                  value == null || value < 0 ? null : value * unit,
                );
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (!mounted || minutes == null) return;
    if (reminders.any(
      (item) =>
          item.type == ReminderRuleType.relativeDuration &&
          item.offsetMinutes == minutes &&
          item.deliveryType == deliveryType,
    )) {
      _message('这个提醒已经存在。');
      return;
    }
    setState(() {
      reminders.add(_relativeReminder(minutes, deliveryType: deliveryType));
      reminderEnabled = true;
    });
  }

  Future<void> _addRelativeDayTime(ReminderDeliveryType deliveryType) async {
    final input = TextEditingController(text: '2');
    var selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final result = await showDialog<(int, TimeOfDay)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('提前几天的指定时间'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: input,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '提前天数'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提醒时间'),
                trailing: Text(selectedTime.format(context)),
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (value != null) setDialogState(() => selectedTime = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final days = int.tryParse(input.text);
                Navigator.pop(
                  context,
                  days == null || days < 0 ? null : (days, selectedTime),
                );
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (!mounted || result == null) return;
    final time =
        '${result.$2.hour.toString().padLeft(2, '0')}:${result.$2.minute.toString().padLeft(2, '0')}';
    if (reminders.any(
      (item) =>
          item.type == ReminderRuleType.relativeDayTime &&
          item.dayOffset == result.$1 &&
          item.timeOfDay == time &&
          item.deliveryType == deliveryType,
    )) {
      _message('这个提醒已经存在。');
      return;
    }
    setState(() {
      reminders.add(
        TaskReminderRule(
          id: 'reminder-${DateTime.now().microsecondsSinceEpoch}',
          taskId: widget.task?.id ?? 'draft',
          type: ReminderRuleType.relativeDayTime,
          dayOffset: result.$1,
          timeOfDay: time,
          sortOrder: reminders.length,
          deliveryType: deliveryType,
        ),
      );
      reminderEnabled = true;
    });
  }

  Future<void> _addAbsoluteReminder(ReminderDeliveryType deliveryType) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 20),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (!mounted || time == null) return;
    final absolute = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!absolute.isAfter(now)) {
      _message('提醒时间必须晚于当前时间。');
      return;
    }
    if (reminders.any(
      (item) =>
          item.type == ReminderRuleType.absolute &&
          item.absoluteAt?.isAtSameMomentAs(absolute) == true &&
          item.deliveryType == deliveryType,
    )) {
      _message('这个提醒已经存在。');
      return;
    }
    setState(() {
      reminders.add(
        TaskReminderRule(
          id: 'reminder-${DateTime.now().microsecondsSinceEpoch}',
          taskId: widget.task?.id ?? 'draft',
          type: ReminderRuleType.absolute,
          absoluteAt: absolute,
          sortOrder: reminders.length,
          deliveryType: deliveryType,
        ),
      );
      reminderEnabled = true;
    });
  }

  Widget _buildTags(BuildContext context) {
    final activeNames = widget.controller.tagDefinitions
        .map((tag) => tag.name)
        .toSet();
    final historical = selectedTags
        .where((tag) => !activeNames.contains(tag))
        .toList();
    final labels = [
      ...widget.controller.tagDefinitions
          .where((tag) => selectedTags.contains(tag.name))
          .map((tag) => tag.name),
      ...historical,
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: readOnly ? null : () => scaffoldKey.currentState?.openEndDrawer(),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '标签',
          suffixIcon: Icon(Icons.chevron_right),
        ),
        child: Text(labels.isEmpty ? '' : labels.join('、')),
      ),
    );
  }

  Widget _buildTagDrawer(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text('标签', style: Theme.of(context).textTheme.titleLarge),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: readOnly
                        ? null
                        : () => setState(() {
                            selectedTags.addAll(
                              widget.controller.tagDefinitions
                                  .where((tag) => !tag.isQuadrant)
                                  .map((tag) => tag.name),
                            );
                          }),
                    child: const Text('全选'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: readOnly
                        ? null
                        : () => setState(selectedTags.clear),
                    child: const Text('清空'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...widget.controller.tagDefinitions.map(
                  (tag) => CheckboxListTile(
                    value: selectedTags.contains(tag.name),
                    secondary: Icon(tag.icon, color: tag.color),
                    title: Text(tag.name),
                    subtitle: tag.isQuadrant ? const Text('四象限 · 单选') : null,
                    onChanged: readOnly
                        ? null
                        : (value) => setState(() {
                            if (value != true) {
                              selectedTags.remove(tag.name);
                              return;
                            }
                            if (tag.isQuadrant) {
                              final quadrantNames = widget
                                  .controller
                                  .tagDefinitions
                                  .where((item) => item.isQuadrant)
                                  .map((item) => item.name)
                                  .toSet();
                              selectedTags.removeWhere(quadrantNames.contains);
                            }
                            selectedTags.add(tag.name);
                          }),
                  ),
                ),
                ...selectedTags
                    .where(
                      (name) => !widget.controller.tagDefinitions.any(
                        (tag) => tag.name == name,
                      ),
                    )
                    .map(
                      (name) => CheckboxListTile(
                        value: true,
                        secondary: const Icon(Icons.history),
                        title: Text(name),
                        onChanged: readOnly
                            ? null
                            : (_) => setState(() => selectedTags.remove(name)),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildContacts(BuildContext context) {
    return ContactSelectionField(
      controller: widget.controller,
      selectedContacts: selectedContacts,
      readOnly: readOnly,
      preserveSnapshots: widget.task != null,
      onChanged: (contacts) => setState(() {
        selectedContacts
          ..clear()
          ..addAll(contacts);
      }),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}
