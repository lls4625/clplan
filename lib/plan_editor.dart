import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'contact_widgets.dart';
import 'models.dart';
import 'task_editor.dart';
import 'task_widgets.dart';

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
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        title: Text(plan == null ? '新增计划' : '计划详情'),
        actions: [
          if (plan != null)
            IconButton(
              tooltip: '删除计划',
              onPressed: saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
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
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: '开始日期',
                    value: startDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: '目标日期',
                    value: targetDate,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PlanCalendarDisplayMode>(
              initialValue: calendarDisplayMode,
              decoration: const InputDecoration(labelText: '日历显示'),
              items: PlanCalendarDisplayMode.values
                  .map(
                    (mode) =>
                        DropdownMenuItem(value: mode, child: Text(mode.label)),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => calendarDisplayMode =
                    value ?? PlanCalendarDisplayMode.wholePeriod,
              ),
            ),
            const SizedBox(height: 10),
            _buildReminderCard(context),
            const SizedBox(height: 10),
            TextField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '计划名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '计划内容'),
            ),
            const SizedBox(height: 10),
            _buildContacts(context),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue:
                  widget.controller.categoryDefinitions.any(
                    (category) => category.name == categoryName,
                  )
                  ? categoryName
                  : null,
              decoration: const InputDecoration(labelText: '分类'),
              items: widget.controller.categoryDefinitions
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.name,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => categoryName = value ?? ''),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: progress.sourceTemplateId,
              decoration: const InputDecoration(labelText: '进度方案'),
              items: widget.controller.progressTemplates
                  .map(
                    (template) => DropdownMenuItem(
                      value: template.id,
                      child: Text(template.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                final id =
                    plan?.id ??
                    'draft-${DateTime.now().microsecondsSinceEpoch}';
                progress = widget.controller.progressSnapshot(
                  'plan-progress-$id',
                  templateId: value,
                );
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(progress.currentNodeId),
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
              onChanged: (value) => setState(
                () => progress = progress.copyWith(currentNodeId: value),
              ),
            ),
            const SizedBox(height: 10),
            _buildTags(context),
            if (plan != null) ...[
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '任务（${tasks.length}）',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: '新增任务',
                    onPressed: () => _addTask(plan),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('该计划还没有任务')),
                )
              else
                ...tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TaskCard(
                      task: task,
                      controller: widget.controller,
                      nested: task.parentTaskId != null,
                      onTap: () => _editTask(task),
                      onAddSubtask: task.parentTaskId == null
                          ? () => _addSubtask(task)
                          : null,
                    ),
                  ),
                ),
            ],
          ],
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

  Widget _buildReminderCard(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: reminderEnabled,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('提醒与闹铃'),
            subtitle: Text(
              reminders.isEmpty ? '可在计划期间内设置多个提醒' : '${reminders.length} 个提醒',
            ),
            onChanged: (value) => setState(() => reminderEnabled = value),
          ),
          if (reminderEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _addPlanReminder(ReminderDeliveryType.notification),
                    icon: const Icon(Icons.notifications_none),
                    label: const Text('通知提醒'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _addPlanReminder(ReminderDeliveryType.alarm),
                    icon: const Icon(Icons.alarm_outlined),
                    label: const Text('闹铃提醒'),
                  ),
                ),
              ],
            ),
            if (reminders.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...reminders.map(
                (rule) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    rule.deliveryType == ReminderDeliveryType.alarm
                        ? Icons.alarm_outlined
                        : Icons.notifications_none,
                  ),
                  title: Text('${rule.deliveryLabel} · ${rule.label}'),
                  subtitle:
                      rule.absoluteAt != null &&
                          rule.absoluteAt!.isBefore(DateTime.now())
                      ? const Text('已过期，不会再提醒')
                      : null,
                  trailing: IconButton(
                    tooltip: '删除提醒',
                    onPressed: () => setState(() {
                      reminders.remove(rule);
                      if (reminders.isEmpty) reminderEnabled = false;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
            if (reminders.any(
              (item) => item.deliveryType == ReminderDeliveryType.alarm,
            ))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.controller.alarmPermission ==
                          AlarmPermissionState.unsupported
                      ? '当前系统不支持 AlarmKit；闹铃规则会保留。'
                      : '闹铃需要 iOS 26 或更高版本及独立授权。',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    ),
  );

  Future<void> _addPlanReminder(ReminderDeliveryType deliveryType) async {
    final now = DateTime.now();
    final start = dateFromText(startDate);
    final initial = start.isAfter(now) ? start : now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2200),
      helpText: deliveryType == ReminderDeliveryType.alarm
          ? '选择闹铃日期'
          : '选择通知日期',
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: deliveryType == ReminderDeliveryType.alarm
          ? '选择闹铃时间'
          : '选择通知时间',
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
      reminders.sort(
        (a, b) => (a.absoluteAt ?? DateTime(2200)).compareTo(
          b.absoluteAt ?? DateTime(2200),
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
      onTap: () => scaffoldKey.currentState?.openEndDrawer(),
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
    if (name.text.trim().isEmpty) {
      _message('请输入计划名称。');
      return;
    }
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

  Widget _buildContacts(BuildContext context) {
    return ContactSelectionField(
      controller: widget.controller,
      selectedContacts: selectedContacts,
      preserveSnapshots: widget.plan != null,
      onChanged: (contacts) => setState(() {
        selectedContacts
          ..clear()
          ..addAll(contacts);
      }),
    );
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(value),
    ),
  );
}
