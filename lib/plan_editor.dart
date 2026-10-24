import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'contact_widgets.dart';
import 'models.dart';
import 'reminder_form_widgets.dart';
import 'task_editor.dart';
import 'task_widgets.dart';
import 'work_form_widgets.dart';

Future<bool?> showPlanEditor(
  BuildContext context,
  AppController controller, {
  PlanItem? plan,
  String? initialDate,
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    fullscreenDialog: plan == null,
    builder: (_) => PlanEditor(
      controller: controller,
      plan: plan,
      initialDate: initialDate,
    ),
  ),
);

class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.controller,
    this.plan,
    this.initialDate,
  });

  final AppController controller;
  final PlanItem? plan;
  final String? initialDate;

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController description;
  late String startDate;
  late String targetDate;
  late PlanCalendarDisplayMode calendarDisplayMode;
  late List<TaskReminderRule> reminders;
  late bool reminderEnabled;
  late String categoryName;
  late ProgressSnapshot progress;
  late final Set<String> selectedTags;
  late final List<ContactEntry> selectedContacts;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    final today = widget.initialDate ?? dateOnly(DateTime.now());
    final id = plan?.id ?? 'plan-${DateTime.now().microsecondsSinceEpoch}';
    name = TextEditingController(text: plan?.name ?? '');
    description = TextEditingController(text: plan?.description ?? '');
    startDate = plan?.startDate ?? today;
    targetDate = plan?.targetDate ?? today;
    calendarDisplayMode =
        plan?.calendarDisplayMode ?? PlanCalendarDisplayMode.wholePeriod;
    reminders = [...?plan?.reminders];
    reminderEnabled = plan?.reminderEnabled ?? reminders.isNotEmpty;
    categoryName = plan?.categoryName ?? '';
    progress =
        plan?.progress ??
        widget.controller.progressSnapshot('plan-progress-$id');
    selectedTags = {...?plan?.tags.map((tag) => tag.name)};
    selectedContacts = [...?plan?.contacts];
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final planTasks = plan == null
        ? const <TaskItem>[]
        : (widget.controller.tasks
              .where((task) => task.planId == plan.id)
              .toList()
            ..sort(widget.controller.compareTasks));
    final tasks = <TaskItem>[];
    for (final root in planTasks.where((task) => task.parentTaskId == null)) {
      tasks.add(root);
      tasks.addAll(planTasks.where((task) => task.parentTaskId == root.id));
    }
    tasks.addAll(planTasks.where((task) => !tasks.contains(task)));
    final taskCompleted = tasks.where(widget.controller.isDone).length;
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        title: Text(plan == null ? '新增计划' : '计划详情'),
        actions: [
          if (plan != null)
            PopupMenuButton<String>(
              tooltip: '更多操作',
              enabled: !saving,
              onSelected: (value) {
                if (value == 'delete') _delete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 10),
                      Text('删除计划'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: saving ? '保存中…' : '保存计划',
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
                    WorkFormSection(
                      title: '基本信息',
                      icon: Icons.description_outlined,
                      children: [
                        TextFormField(
                          controller: name,
                          maxLength: 100,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '计划名称',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ? '请输入计划名称' : null,
                        ),
                        TextFormField(
                          controller: description,
                          maxLength: 200,
                          minLines: 3,
                          maxLines: null,
                          decoration: const InputDecoration(
                            labelText: '计划内容',
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
                        _buildDateRangeFields(context),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('日历显示'),
                          subtitle: Text(
                            _calendarDisplayDescription(calendarDisplayMode),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                calendarDisplayMode.label,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: _showCalendarDisplayPicker,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ReminderFormSection(
                      controller: widget.controller,
                      reminders: reminders,
                      enabled: reminderEnabled,
                      onEnabledChanged: (value) =>
                          setState(() => reminderEnabled = value),
                      onAdd: _addPlanReminder,
                      onRemove: (rule) => setState(() {
                        reminders.remove(rule);
                        if (reminders.isEmpty) reminderEnabled = false;
                      }),
                    ),
                    const SizedBox(height: 16),
                    ContactFormSection(
                      controller: widget.controller,
                      selectedContacts: selectedContacts,
                      preserveSnapshots: widget.plan != null,
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
                        DropdownMenu<String>(
                          expandedInsets: EdgeInsets.zero,
                          label: const Text('分类'),
                          initialSelection: categoryName.isEmpty
                              ? null
                              : categoryName,
                          dropdownMenuEntries: [
                            ...widget.controller.categoryDefinitions.map(
                              (item) => DropdownMenuEntry(
                                value: item.name,
                                label: item.name,
                                leadingIcon: Icon(item.icon, color: item.color),
                              ),
                            ),
                            if (categoryName.isNotEmpty &&
                                !widget.controller.categoryDefinitions.any(
                                  (item) => item.name == categoryName,
                                ))
                              DropdownMenuEntry(
                                value: categoryName,
                                label: '$categoryName（历史分类）',
                              ),
                          ],
                          onSelected: (value) =>
                              setState(() => categoryName = value ?? ''),
                        ),
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
                                plan?.id ??
                                'draft-${DateTime.now().microsecondsSinceEpoch}';
                            progress = widget.controller.progressSnapshot(
                              'plan-progress-$id',
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
                          onSelected: (value) => setState(
                            () => progress = progress.copyWith(
                              currentNodeId: value,
                            ),
                          ),
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
                      trailing: IconButton(
                        tooltip: '编辑标签',
                        onPressed: () =>
                            scaffoldKey.currentState?.openEndDrawer(),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      children: selectedTags.isEmpty
                          ? const []
                          : [_buildTags(context)],
                    ),
                    if (plan != null) ...[
                      const SizedBox(height: 16),
                      WorkFormSection(
                        title: '任务',
                        icon: Icons.checklist_outlined,
                        subtitle: '$taskCompleted/${tasks.length} 已完成',
                        trailing: IconButton.filledTonal(
                          tooltip: '新增任务',
                          onPressed: () => _addTask(plan),
                          icon: const Icon(Icons.add),
                        ),
                        children: tasks
                            .map(
                              (task) => TaskCard(
                                task: task,
                                controller: widget.controller,
                                nested: task.parentTaskId != null,
                                onTap: () => _editTask(task),
                                onAddSubtask: task.parentTaskId == null
                                    ? () => _addSubtask(task)
                                    : null,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = DateTime.parse(isStart ? startDate : targetDate);
    final value = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (value == null || !mounted) return;
    setState(() {
      final text = dateOnly(value);
      if (isStart) {
        startDate = text;
        if (targetDate.compareTo(text) < 0) targetDate = text;
      } else {
        targetDate = text;
      }
    });
  }

  Widget _buildDateRangeFields(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final useVerticalLayout =
          constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final startField = WorkValueField(
        label: '开始日期',
        value: startDate,
        icon: Icons.event_outlined,
        onTap: () => _pickDate(isStart: true),
      );
      final targetField = WorkValueField(
        label: '目标日期',
        value: targetDate,
        icon: Icons.flag_outlined,
        onTap: () => _pickDate(isStart: false),
      );
      if (useVerticalLayout) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [startField, const SizedBox(height: 12), targetField],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: startField),
          const SizedBox(width: 12),
          Expanded(child: targetField),
        ],
      );
    },
  );

  String _calendarDisplayDescription(PlanCalendarDisplayMode mode) =>
      switch (mode) {
        PlanCalendarDisplayMode.wholePeriod => '开始日至目标日每天都显示',
        PlanCalendarDisplayMode.endpoints => '只在开始日和目标日显示',
        PlanCalendarDisplayMode.startOnly => '只在计划启动当天显示',
        PlanCalendarDisplayMode.targetOnly => '只在计划目标当天显示',
      };

  Future<void> _showCalendarDisplayPicker() async {
    final selected = await showModalBottomSheet<PlanCalendarDisplayMode>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '日历显示范围',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '决定计划会出现在日历的哪些日期，不会修改开始日期和目标日期。',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              RadioGroup<PlanCalendarDisplayMode>(
                groupValue: calendarDisplayMode,
                onChanged: (value) {
                  if (value != null) Navigator.pop(sheetContext, value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: PlanCalendarDisplayMode.values
                      .map(
                        (mode) => RadioListTile<PlanCalendarDisplayMode>(
                          value: mode,
                          title: Text(mode.label),
                          subtitle: Text(_calendarDisplayDescription(mode)),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          selected: mode == calendarDisplayMode,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null || selected == calendarDisplayMode) {
      return;
    }
    setState(() => calendarDisplayMode = selected);
  }

  Future<void> _addPlanReminder(ReminderDeliveryType deliveryType) async {
    final absolute = await showReminderDateTimePicker(
      context,
      deliveryType,
      initialDate: dateFromText(startDate),
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
          id: 'plan-reminder-${DateTime.now().microsecondsSinceEpoch}',
          taskId: widget.plan?.id ?? 'draft-plan',
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
          onDeleted: () => setState(() => selectedTags.remove(name)),
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
                    onPressed: () => setState(() {
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
                    onPressed: () => setState(selectedTags.clear),
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
                    onChanged: (value) => setState(() {
                      if (value != true) {
                        selectedTags.remove(tag.name);
                        return;
                      }
                      if (tag.isQuadrant) {
                        final quadrantNames = widget.controller.tagDefinitions
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
                        onChanged: (_) =>
                            setState(() => selectedTags.remove(name)),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final old = widget.plan;
      final now = DateTime.now();
      final category = widget.controller.categoryDefinitionForName(
        categoryName,
      );
      final tags = selectedTags.map((tagName) {
        final definition = widget.controller.tagDefinitionForName(tagName);
        for (final snapshot in old?.tags ?? const <TaskTagSnapshot>[]) {
          if (snapshot.name == tagName && definition == null) return snapshot;
        }
        return TaskTagSnapshot(
          sourceTagId: definition?.id,
          name: tagName,
          colorValue: definition?.colorValue ?? 0xff8e8e93,
          iconName: definition?.iconName ?? 'label',
        );
      }).toList();
      final item = PlanItem(
        id: old?.id ?? 'plan-${now.microsecondsSinceEpoch}',
        name: name.text.trim(),
        description: description.text,
        startDate: startDate,
        targetDate: targetDate,
        categoryName: categoryName,
        categoryColorValue: category?.colorValue ?? 0xff8e8e93,
        categoryIconName: category?.iconName ?? 'project',
        tags: tags,
        progress: progress,
        milestones: old?.milestones ?? const [],
        rules: old?.rules ?? const [],
        updatedAt: now,
        calendarDisplayMode: calendarDisplayMode,
        reminderEnabled: reminderEnabled && reminders.isNotEmpty,
        reminders: List.of(reminders),
        contacts: List.of(selectedContacts),
      );
      await widget.controller.savePlan(item);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      _message(exception.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete() async {
    final plan = widget.plan!;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除计划？'),
            content: Text('确定删除“${plan.name}”吗？存在任务的计划需要先清空任务。'),
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
    setState(() => saving = true);
    try {
      await widget.controller.deletePlan(plan.id);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      _message(exception.toString().replaceFirst('Bad state: ', ''));
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _addTask(PlanItem plan) async {
    await showTaskEditor(
      context,
      widget.controller,
      initialDate: plan.startDate,
      initialPlanId: plan.id,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editTask(TaskItem task) async {
    await showTaskEditor(context, widget.controller, task: task);
    if (mounted) setState(() {});
  }

  Future<void> _addSubtask(TaskItem task) async {
    await showTaskEditor(
      context,
      widget.controller,
      initialDate: task.startDate,
      parentTaskId: task.id,
      initialPlanId: task.planId,
    );
    if (mounted) setState(() {});
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
