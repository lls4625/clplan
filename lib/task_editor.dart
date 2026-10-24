import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_controller.dart';
import 'contact_widgets.dart';
import 'models.dart';
import 'planning/planning_models.dart';
import 'planning/widgets/planning_composer.dart';
import 'reminder_form_widgets.dart';
import 'task_widgets.dart';
import 'ui/app_alert.dart';
import 'work_form_widgets.dart';

Future<bool?> showTaskEditor(
  BuildContext context,
  AppController controller, {
  TaskItem? task,
  String? initialDate,
  String? parentTaskId,
  String? originId,
  String? initialPlanId,
  PlanningDraft? initialDraft,
}) {
  if (task == null && initialDraft == null) {
    final planningDate = initialDate ?? dateOnly(DateTime.now());
    return showPlanningComposer(
      context,
      controller,
      targetKind: PlanningTargetKind.task,
      initialDate: planningDate,
      openEditor: (draft) => showTaskEditor(
        context,
        controller,
        initialDate: initialDate,
        parentTaskId: parentTaskId,
        originId: originId,
        initialPlanId: initialPlanId,
        initialDraft: draft,
      ),
    );
  }
  final editor = TaskEditor(
    controller: controller,
    task: task,
    initialDate: initialDate,
    parentTaskId: parentTaskId,
    originId: originId,
    initialPlanId: initialPlanId,
    initialDraft: initialDraft,
  );
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => editor),
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
    this.initialDraft,
  }) : assert(task == null || initialDraft == null);
  final AppController controller;
  final TaskItem? task;
  final String? initialDate;
  final String? parentTaskId;
  final String? originId;
  final String? initialPlanId;
  final PlanningDraft? initialDraft;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
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
    final draft = task == null ? widget.initialDraft : null;
    title = TextEditingController(text: task?.title ?? draft?.title ?? '');
    description = TextEditingController(
      text: task?.description ?? draft?.description ?? '',
    );
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
    selectedTags = {...?task?.tags, ...?draft?.tags};
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
        task?.startDate ??
        draft?.schedule.localDate ??
        widget.initialDate ??
        dateOnly(DateTime.now());
    startTime = task?.startTime ?? draft?.schedule.localTime ?? '';
    reminders = task?.reminders.toList() ?? _remindersFromDraft(draft);
    if (task == null &&
        (draft == null ||
            draft.reminders.intent == ReminderDraftIntent.unspecified) &&
        startTime.isNotEmpty &&
        widget.controller.preferences.defaultReminderMinutes >= 0) {
      reminders.add(
        _relativeReminder(widget.controller.preferences.defaultReminderMinutes),
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

  void _clearSchedule() => setState(() {
    startDate = '';
    startTime = '';
    reminders.removeWhere((item) => item.type != ReminderRuleType.absolute);
    reminderEnabled = reminders.isNotEmpty;
  });

  Future<void> _save({bool next = false, bool nextAsChild = false}) async {
    if (!readOnly && !(formKey.currentState?.validate() ?? false)) return;
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
      showAppAlert(context, title: '无法完成操作', message: text);

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
        centerTitle: true,
        title: Text(pageTitle),
        actions: [
          if (widget.task != null && !readOnly && !hasChildren)
            PopupMenuButton<String>(
              tooltip: '更多操作',
              enabled: !saving,
              onSelected: (value) {
                if (value == 'delete') _deleteTask();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 10),
                      Text('删除任务'),
                    ],
                  ),
                ),
              ],
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
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUnfocus,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  28 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: [
                    if (readOnly) ...[
                      const _Notice(text: '完成记录只读。可更改进度节点重新开启后再编辑。'),
                      const SizedBox(height: 16),
                    ],
                    WorkFormSection(
                      title: '基本信息',
                      icon: Icons.description_outlined,
                      children: [
                        if (owningPlan != null)
                          WorkValueField(
                            label: '所属计划',
                            value: owningPlan.name,
                            icon: Icons.folder_outlined,
                          ),
                        if (widget.task?.parentTaskId != null)
                          WorkValueField(
                            label: '上级任务',
                            value:
                                widget.controller
                                    .taskById(widget.task!.parentTaskId)
                                    ?.title ??
                                '上级任务已不存在',
                            icon: Icons.account_tree_outlined,
                          ),
                        if (readOnly)
                          WorkValueField(label: '标题', value: title.text)
                        else
                          TextFormField(
                            controller: title,
                            maxLength: 100,
                            textInputAction: TextInputAction.next,
                            scrollPadding: const EdgeInsets.only(bottom: 160),
                            decoration: const InputDecoration(
                              labelText: '标题',
                              alignLabelWithHint: true,
                            ),
                            validator: (value) =>
                                (value ?? '').trim().isEmpty ? '请输入标题' : null,
                          ),
                        if (readOnly)
                          WorkValueField(label: '内容', value: description.text)
                        else
                          TextFormField(
                            controller: description,
                            minLines: 3,
                            maxLines: null,
                            maxLength: 200,
                            scrollPadding: const EdgeInsets.only(bottom: 160),
                            decoration: const InputDecoration(
                              labelText: '内容',
                              alignLabelWithHint: true,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    WorkFormSection(
                      title: '时间与日历',
                      icon: Icons.calendar_month_outlined,
                      children: [
                        ResponsiveFieldPair(
                          first: WorkValueField(
                            label: '日期',
                            value: startDate,
                            icon: Icons.event_outlined,
                            enabled: !readOnly,
                            onTap: readOnly ? null : _pickDate,
                          ),
                          second: WorkValueField(
                            label: '时间',
                            value: startTime,
                            icon: Icons.schedule_outlined,
                            enabled: !readOnly && startDate.isNotEmpty,
                            onTap: readOnly || startDate.isEmpty
                                ? null
                                : _pickTime,
                          ),
                        ),
                        if (!readOnly && startDate.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _clearSchedule,
                              icon: const Icon(Icons.event_busy_outlined),
                              label: const Text('清除日期和时间'),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ReminderFormSection(
                      controller: widget.controller,
                      reminders: reminders,
                      enabled: reminderEnabled,
                      readOnly: readOnly,
                      onEnabledChanged: (value) =>
                          setState(() => reminderEnabled = value),
                      onAdd: _addReminder,
                      onRemove: (rule) => setState(() {
                        reminders.remove(rule);
                        if (reminders.isEmpty) reminderEnabled = false;
                      }),
                      resolveFireAt: (rule) => rule.fireDateFor(
                        startDate: startDate,
                        startTime: startTime,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ContactFormSection(
                      controller: widget.controller,
                      selectedContacts: selectedContacts,
                      readOnly: readOnly,
                      preserveSnapshots: widget.task != null,
                      onChanged: (contacts) => setState(() {
                        selectedContacts
                          ..clear()
                          ..addAll(contacts);
                      }),
                    ),
                    const SizedBox(height: 16),
                    WorkFormSection(
                      title: '分类与进度',
                      icon: Icons.account_tree_outlined,
                      children: [
                        if (readOnly)
                          WorkValueField(label: '分类', value: type.text)
                        else
                          DropdownMenu<String>(
                            expandedInsets: EdgeInsets.zero,
                            label: const Text('分类'),
                            initialSelection: type.text.isEmpty
                                ? null
                                : type.text,
                            dropdownMenuEntries: [
                              ...widget.controller.categoryDefinitions.map(
                                (item) => DropdownMenuEntry(
                                  value: item.name,
                                  label: item.name,
                                  leadingIcon: Icon(
                                    item.icon,
                                    color: item.color,
                                  ),
                                ),
                              ),
                              if (type.text.isNotEmpty &&
                                  !widget.controller.categoryDefinitions.any(
                                    (item) => item.name == type.text,
                                  ))
                                DropdownMenuEntry(
                                  value: type.text,
                                  label: '${type.text}（历史分类）',
                                ),
                            ],
                            onSelected: (value) =>
                                setState(() => type.text = value ?? ''),
                          ),
                        if (readOnly)
                          WorkValueField(
                            label: '进度方案',
                            value: progress.templateName,
                          )
                        else
                          DropdownMenu<String>(
                            expandedInsets: EdgeInsets.zero,
                            label: const Text('进度方案'),
                            initialSelection: progress.sourceTemplateId,
                            dropdownMenuEntries: [
                              ...widget.controller.progressTemplates.map(
                                (item) => DropdownMenuEntry(
                                  value: item.id,
                                  label: item.name,
                                ),
                              ),
                              if (progress.sourceTemplateId != null &&
                                  !widget.controller.progressTemplates.any(
                                    (item) =>
                                        item.id == progress.sourceTemplateId,
                                  ))
                                DropdownMenuEntry(
                                  value: progress.sourceTemplateId!,
                                  label: '${progress.templateName}（历史方案）',
                                ),
                            ],
                            onSelected: (value) => setState(() {
                              final id =
                                  widget.task?.id ??
                                  progress.instanceId.replaceFirst(
                                    'task-progress-',
                                    '',
                                  );
                              progress = widget.controller
                                  .progressSnapshotForTask(
                                    id,
                                    templateId: value,
                                  );
                            }),
                          ),
                        DropdownMenu<String>(
                          key: ValueKey(
                            '${progress.sourceTemplateId}-${progress.currentNodeId}',
                          ),
                          expandedInsets: EdgeInsets.zero,
                          label: const Text('进度节点'),
                          initialSelection: progress.currentNodeId,
                          dropdownMenuEntries: progress.nodes
                              .map(
                                (item) => DropdownMenuEntry(
                                  value: item.id,
                                  label: item.name,
                                ),
                              )
                              .toList(),
                          onSelected: (value) => setState(() {
                            progress = progress.copyWith(currentNodeId: value);
                            final completed = progress.completed;
                            statusId = widget.controller.statuses
                                .firstWhere(
                                  (status) => status.completed == completed,
                                  orElse: () =>
                                      widget.controller.statuses.first,
                                )
                                .id;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    WorkFormSection(
                      title: '标签',
                      icon: Icons.sell_outlined,
                      subtitle: selectedTags.isEmpty
                          ? '未选择'
                          : '${selectedTags.length} 个标签',
                      trailing: readOnly
                          ? null
                          : IconButton(
                              tooltip: '编辑标签',
                              onPressed: () =>
                                  scaffoldKey.currentState?.openEndDrawer(),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                      children: selectedTags.isEmpty
                          ? const []
                          : [_buildTags(context)],
                    ),
                    const SizedBox(height: 16),
                    WorkFormSection(
                      title: '执行补充',
                      icon: Icons.assignment_late_outlined,
                      children: [
                        if (readOnly)
                          WorkValueField(label: '未完成主要原因', value: reason.text)
                        else
                          TextFormField(
                            controller: reason,
                            minLines: 2,
                            maxLines: null,
                            scrollPadding: const EdgeInsets.only(bottom: 160),
                            decoration: const InputDecoration(
                              labelText: '未完成主要原因',
                              alignLabelWithHint: true,
                            ),
                          ),
                      ],
                    ),
                    if (widget.task != null) ...[
                      const SizedBox(height: 16),
                      WorkFormSection(
                        title: '跟进记录',
                        icon: Icons.forum_outlined,
                        subtitle: '${widget.task!.followups.length} 条',
                        children: [
                          ...widget.task!.followups.map(
                            (item) => WorkActivityItem(
                              text: item.text,
                              time: DateFormat('yyyy-MM-dd HH:mm')
                                  .format(item.at.toLocal()),
                            ),
                          ),
                          if (!readOnly)
                            TextFormField(
                              controller: followup,
                              minLines: 2,
                              maxLines: null,
                              scrollPadding: const EdgeInsets.only(bottom: 160),
                              decoration: const InputDecoration(
                                labelText: '追加跟进',
                                alignLabelWithHint: true,
                              ),
                            ),
                        ],
                      ),
                      if (widget.task!.history.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        WorkFormSection(
                          title: '变更历史',
                          icon: Icons.history_outlined,
                          subtitle: '${widget.task!.history.length} 条',
                          children: widget.task!.history
                              .map(
                                (item) => WorkActivityItem(
                                  text: item.text,
                                  time: DateFormat('yyyy-MM-dd HH:mm')
                                      .format(item.at.toLocal()),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    if (widget.task != null && !readOnly)
                      OutlinedButton.icon(
                        onPressed: saving ? null : () => _save(next: true),
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('保存并建下一项'),
                      ),
                    if (readOnly)
                      FilledButton(
                        onPressed: saving ? null : _save,
                        child: Text(saving ? '保存中…' : '更改状态'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addReminder(ReminderDeliveryType deliveryType) async {
    final absolute = await showReminderDateTimePicker(
      context,
      deliveryType,
      initialDate: startDate.isEmpty ? null : dateFromText(startDate),
    );
    if (!mounted || absolute == null) return;
    if (!absolute.isAfter(DateTime.now())) {
      _message('提醒时间必须晚于当前时间。');
      return;
    }
    if (reminders.any(
      (item) =>
          item.type == ReminderRuleType.absolute &&
          item.deliveryType == deliveryType &&
          item.absoluteAt?.isAtSameMomentAs(absolute) == true,
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

  List<TaskReminderRule> _remindersFromDraft(PlanningDraft? draft) {
    if (draft == null ||
        draft.reminders.intent != ReminderDraftIntent.specified) {
      return <TaskReminderRule>[];
    }
    final mapped = <String, TaskReminderRule>{};
    for (final source in draft.reminders.values) {
      final type = switch (source.type) {
        PlanningReminderRuleType.relativeDuration =>
          ReminderRuleType.relativeDuration,
        PlanningReminderRuleType.relativeDayTime =>
          ReminderRuleType.relativeDayTime,
        PlanningReminderRuleType.absolute => ReminderRuleType.absolute,
      };
      final deliveryType = switch (source.deliveryType) {
        PlanningReminderDeliveryType.notification =>
          ReminderDeliveryType.notification,
        PlanningReminderDeliveryType.alarm => ReminderDeliveryType.alarm,
      };
      final key =
          '${deliveryType.name}:${type.name}:${source.offsetMinutes}:'
          '${source.dayOffset}:${source.timeOfDay}:${source.absoluteAt}';
      mapped[key] = TaskReminderRule(
        id: 'reminder-${DateTime.now().microsecondsSinceEpoch}-${mapped.length}',
        taskId: 'draft',
        type: type,
        offsetMinutes: source.offsetMinutes,
        dayOffset: source.dayOffset,
        timeOfDay: source.timeOfDay,
        absoluteAt: source.absoluteAt,
        sortOrder: mapped.length,
        deliveryType: deliveryType,
      );
    }
    return mapped.values.toList();
  }

  TaskReminderRule _relativeReminder(int minutes) => TaskReminderRule(
    id: 'reminder-${DateTime.now().microsecondsSinceEpoch}-$minutes',
    taskId: widget.task?.id ?? 'draft',
    type: ReminderRuleType.relativeDuration,
    offsetMinutes: minutes,
    sortOrder: reminders.length,
  );

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.map((name) {
        final definition = widget.controller.tagDefinitionForName(name);
        return InputChip(
          avatar: Icon(
            definition?.icon ?? Icons.label_outline,
            size: 18,
            color: definition?.color,
          ),
          label: Text(name),
          onDeleted: readOnly
              ? null
              : () => setState(() => selectedTags.remove(name)),
        );
      }).toList(),
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
