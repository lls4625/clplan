import 'package:flutter/material.dart' hide Text;

import 'app_controller.dart';
import 'contact_widgets.dart';
import 'models.dart';
import 'l10n/ui_text.dart';
import 'l10n/preset_text.dart';
import 'planning/planning_models.dart';
import 'planning/widgets/planning_composer.dart';
import 'reminder_form_widgets.dart';
import 'task_editor.dart';
import 'task_widgets.dart';
import 'ui/app_alert.dart';
import 'work_form_widgets.dart';

Future<bool?> showPlanEditor(
  BuildContext context,
  AppController controller, {
  PlanItem? plan,
  String? initialDate,
  PlanningDraft? initialDraft,
}) {
  if (plan == null && initialDraft == null) {
    final planningDate = initialDate ?? dateOnly(DateTime.now());
    return showPlanningComposer(
      context,
      controller,
      targetKind: PlanningTargetKind.plan,
      initialDate: planningDate,
      openEditor: (draft) => showPlanEditor(
        context,
        controller,
        initialDate: initialDate,
        initialDraft: draft,
      ),
    );
  }
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: plan == null,
      builder: (_) => PlanEditor(
        controller: controller,
        plan: plan,
        initialDate: initialDate,
        initialDraft: initialDraft,
      ),
    ),
  );
}

class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.controller,
    this.plan,
    this.initialDate,
    this.initialDraft,
  }) : assert(plan == null || initialDraft == null);

  final AppController controller;
  final PlanItem? plan;
  final String? initialDate;
  final PlanningDraft? initialDraft;

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
  String? sourceCategoryId;
  late ProgressSnapshot progress;
  late final List<PlanMilestone> milestones;
  late final List<RecurrenceRule> recurrenceRules;
  late final Set<String> selectedTags;
  late final List<ContactEntry> selectedContacts;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    final draft = plan == null ? widget.initialDraft : null;
    final today = widget.initialDate ?? dateOnly(DateTime.now());
    final draftDate = draft?.schedule.localDate ?? '';
    final initialPlanDate = draftDate.isEmpty ? today : draftDate;
    final id = plan?.id ?? 'plan-${DateTime.now().microsecondsSinceEpoch}';
    name = TextEditingController(text: plan?.name ?? draft?.title ?? '');
    description = TextEditingController(
      text: plan?.description ?? draft?.description ?? '',
    );
    startDate = plan?.startDate ?? initialPlanDate;
    targetDate = plan?.targetDate ?? initialPlanDate;
    calendarDisplayMode =
        plan?.calendarDisplayMode ?? PlanCalendarDisplayMode.wholePeriod;
    reminders = plan?.reminders.toList() ?? _remindersFromDraft(draft);
    reminderEnabled = plan?.reminderEnabled ?? reminders.isNotEmpty;
    categoryName = plan?.categoryName ?? '';
    sourceCategoryId = plan?.sourceCategoryId;
    if (widget.controller.categoryDefinitionForId(sourceCategoryId) == null) {
      sourceCategoryId = null;
    }
    progress =
        plan?.progress ??
        widget.controller.progressSnapshot('plan-progress-$id');
    milestones = [...?plan?.milestones];
    recurrenceRules = [...?plan?.rules];
    selectedTags = {...?plan?.tags.map((tag) => tag.name), ...?draft?.tags};
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
              tooltip: localizeUiText(context, '更多操作'),
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
                          decoration: InputDecoration(
                            labelText: localizeUiText(context, '计划名称'),
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
                          decoration: InputDecoration(
                            labelText: localizeUiText(context, '计划内容'),
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
                    WorkFormSection(
                      title: '里程碑',
                      icon: Icons.flag_outlined,
                      subtitle:
                          '${milestones.where((item) => item.completed).length}/${milestones.length} 已完成',
                      trailing: IconButton.filledTonal(
                        tooltip: localizeUiText(context, '新增里程碑'),
                        onPressed: _editMilestone,
                        icon: const Icon(Icons.add),
                      ),
                      children: milestones
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Checkbox(
                                value: item.completed,
                                onChanged: (value) => setState(() {
                                  final index = milestones.indexOf(item);
                                  milestones[index] = PlanMilestone(
                                    id: item.id,
                                    name: item.name,
                                    date: item.date,
                                    description: item.description,
                                    completed: value ?? false,
                                    sortOrder: item.sortOrder,
                                  );
                                }),
                              ),
                              title: RawText(item.name),
                              subtitle: RawText(
                                [item.date, item.description]
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                              ),
                              onTap: () => _editMilestone(item),
                              trailing: IconButton(
                                tooltip: localizeUiText(context, '删除里程碑'),
                                onPressed: () => setState(() {
                                  milestones.remove(item);
                                  _normalizeMilestones();
                                }),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    WorkFormSection(
                      title: '周期任务',
                      icon: Icons.repeat,
                      subtitle:
                          '${recurrenceRules.where((item) => item.enabled).length} 条已启用',
                      trailing: IconButton.filledTonal(
                        tooltip: localizeUiText(context, '新增周期任务'),
                        onPressed: _editRecurrenceRule,
                        icon: const Icon(Icons.add),
                      ),
                      children: recurrenceRules
                          .map(
                            (rule) => SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: rule.enabled,
                              title: RawText(rule.title),
                              subtitle: Text(_recurrenceSummary(context, rule)),
                              onChanged: (value) => setState(() {
                                final index = recurrenceRules.indexOf(rule);
                                recurrenceRules[index] = RecurrenceRule(
                                  id: rule.id,
                                  planId: rule.planId,
                                  title: rule.title,
                                  description: rule.description,
                                  startDate: rule.startDate,
                                  endDate: rule.endDate,
                                  startTime: rule.startTime,
                                  weekdays: rule.weekdays,
                                  enabled: value,
                                  progress: rule.progress,
                                );
                              }),
                              secondary: IconButton(
                                tooltip: localizeUiText(context, '编辑周期任务'),
                                onPressed: () => _editRecurrenceRule(rule),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                            ),
                          )
                          .toList(),
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
                          initialSelection:
                              sourceCategoryId ??
                              (categoryName.isEmpty
                                  ? null
                                  : 'history:$categoryName'),
                          dropdownMenuEntries: [
                            ...widget.controller.categoryDefinitions.map(
                              (item) => DropdownMenuEntry(
                                value: item.id,
                                label: categoryDefinitionName(
                                  item,
                                  Localizations.localeOf(context),
                                ),
                                leadingIcon: Icon(item.icon, color: item.color),
                              ),
                            ),
                            if (categoryName.isNotEmpty &&
                                sourceCategoryId == null &&
                                !widget.controller.categoryDefinitions.any(
                                  (item) => item.name == categoryName,
                                ))
                              DropdownMenuEntry(
                                value: 'history:$categoryName',
                                label: '$categoryName（历史分类）',
                              ),
                          ],
                          onSelected: (value) => setState(() {
                            if (value == null) {
                              sourceCategoryId = null;
                              categoryName = '';
                              return;
                            }
                            if (value.startsWith('history:')) {
                              sourceCategoryId = null;
                              categoryName = value.substring(8);
                              return;
                            }
                            final definition = widget.controller
                                .categoryDefinitionForId(value);
                            sourceCategoryId = definition?.id;
                            categoryName = definition == null
                                ? ''
                                : categoryDefinitionName(
                                    definition,
                                    Localizations.localeOf(context),
                                  );
                          }),
                        ),
                        DropdownMenu<String>(
                          expandedInsets: EdgeInsets.zero,
                          label: const Text('进度方案'),
                          initialSelection: progress.sourceTemplateId,
                          dropdownMenuEntries: [
                            ...widget.controller.progressTemplates.map(
                              (item) => DropdownMenuEntry(
                                value: item.id,
                                label: progressTemplateName(
                                  item,
                                  Localizations.localeOf(context),
                                ),
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
                                  label: progressNodeName(
                                    item,
                                    Localizations.localeOf(context),
                                  ),
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
                        tooltip: localizeUiText(context, '编辑标签'),
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
                          tooltip: localizeUiText(context, '新增任务'),
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

  Future<void> _editMilestone([PlanMilestone? existing]) async {
    final title = TextEditingController(text: existing?.name ?? '');
    final details = TextEditingController(text: existing?.description ?? '');
    var date = existing?.date ?? targetDate;
    final form = GlobalKey<FormState>();
    final result = await showDialog<PlanMilestone>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? '新增里程碑' : '编辑里程碑'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: localizeUiText(dialogContext, '名称'),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '请输入里程碑名称' : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('日期'),
                    subtitle: Text(date),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: _withinPlanRange(dateFromText(date)),
                        firstDate: dateFromText(startDate),
                        lastDate: dateFromText(targetDate),
                      );
                      if (selected != null) {
                        setDialogState(() => date = dateOnly(selected));
                      }
                    },
                  ),
                  TextFormField(
                    controller: details,
                    maxLength: 200,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: localizeUiText(dialogContext, '说明'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                Navigator.pop(
                  dialogContext,
                  PlanMilestone(
                    id:
                        existing?.id ??
                        'milestone-${DateTime.now().microsecondsSinceEpoch}',
                    name: title.text.trim(),
                    date: date,
                    description: details.text.trim(),
                    completed: existing?.completed ?? false,
                    sortOrder: existing?.sortOrder ?? milestones.length,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    details.dispose();
    if (!mounted || result == null) return;
    setState(() {
      final index = existing == null ? -1 : milestones.indexOf(existing);
      if (index < 0) {
        milestones.add(result);
      } else {
        milestones[index] = result;
      }
      _normalizeMilestones();
    });
  }

  void _normalizeMilestones() {
    for (var index = 0; index < milestones.length; index++) {
      final item = milestones[index];
      milestones[index] = PlanMilestone(
        id: item.id,
        name: item.name,
        date: item.date,
        description: item.description,
        completed: item.completed,
        sortOrder: index,
      );
    }
  }

  Future<void> _editRecurrenceRule([RecurrenceRule? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final details = TextEditingController(text: existing?.description ?? '');
    var ruleStart = existing?.startDate ?? startDate;
    var ruleEnd = existing?.endDate ?? targetDate;
    var time = existing?.startTime ?? '';
    var weekdays = {...?existing?.weekdays};
    final form = GlobalKey<FormState>();
    final result = await showDialog<_RecurrenceEditResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? '新增周期任务' : '编辑周期任务'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: title,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: localizeUiText(dialogContext, '任务名称'),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '请输入任务名称' : null,
                  ),
                  TextFormField(
                    controller: details,
                    maxLength: 200,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: localizeUiText(dialogContext, '任务内容'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开始日期'),
                    subtitle: Text(ruleStart),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: _withinPlanRange(dateFromText(ruleStart)),
                        firstDate: dateFromText(startDate),
                        lastDate: dateFromText(targetDate),
                      );
                      if (selected != null) {
                        setDialogState(() {
                          ruleStart = dateOnly(selected);
                          if (ruleEnd.compareTo(ruleStart) < 0) {
                            ruleEnd = ruleStart;
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('结束日期'),
                    subtitle: Text(ruleEnd),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate:
                            dateFromText(ruleEnd)
                                .isBefore(dateFromText(ruleStart))
                            ? dateFromText(ruleStart)
                            : _withinPlanRange(dateFromText(ruleEnd)),
                        firstDate: dateFromText(ruleStart),
                        lastDate: dateFromText(targetDate),
                      );
                      if (selected != null) {
                        setDialogState(() => ruleEnd = dateOnly(selected));
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('时间'),
                    subtitle: Text(time.isEmpty ? '未设置' : time),
                    trailing: time.isEmpty
                        ? const Icon(Icons.schedule_outlined)
                        : IconButton(
                            tooltip: localizeUiText(dialogContext, '清除时间'),
                            onPressed: () => setDialogState(() => time = ''),
                            icon: const Icon(Icons.clear),
                          ),
                    onTap: () async {
                      final parts = time.split(':');
                      final selected = await showTimePicker(
                        context: dialogContext,
                        initialTime: parts.length == 2
                            ? TimeOfDay(
                                hour: int.tryParse(parts[0]) ?? 9,
                                minute: int.tryParse(parts[1]) ?? 0,
                              )
                            : const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (selected != null) {
                        setDialogState(
                          () => time =
                              '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text('重复日期'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (index) {
                      final weekday = index + 1;
                      const labels = ['一', '二', '三', '四', '五', '六', '日'];
                      return FilterChip(
                        label: Text(labels[index]),
                        selected: weekdays.contains(weekday),
                        onSelected: (selected) => setDialogState(() {
                          selected
                              ? weekdays.add(weekday)
                              : weekdays.remove(weekday);
                        }),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  const _RecurrenceEditResult(delete: true),
                ),
                child: const Text('删除'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                final id =
                    existing?.id ??
                    'recurrence-${DateTime.now().microsecondsSinceEpoch}';
                final ruleProgress =
                    existing?.progress ??
                    widget.controller.progressSnapshot(
                      'rule-progress-$id',
                      templateId: progress.sourceTemplateId,
                    );
                Navigator.pop(
                  dialogContext,
                  _RecurrenceEditResult(
                    rule: RecurrenceRule(
                      id: id,
                      planId: widget.plan?.id ?? 'draft-plan',
                      title: title.text.trim(),
                      description: details.text.trim(),
                      startDate: ruleStart,
                      endDate: ruleEnd,
                      startTime: time,
                      weekdays: weekdays,
                      enabled: existing?.enabled ?? true,
                      progress: ruleProgress,
                    ),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    details.dispose();
    if (!mounted || result == null) return;
    setState(() {
      if (result.delete) {
        recurrenceRules.remove(existing);
        return;
      }
      final rule = result.rule!;
      final index = existing == null ? -1 : recurrenceRules.indexOf(existing);
      if (index < 0) {
        recurrenceRules.add(rule);
      } else {
        recurrenceRules[index] = rule;
      }
    });
  }

  String _recurrenceSummary(BuildContext context, RecurrenceRule rule) {
    final language = Localizations.localeOf(context).languageCode;
    final labels = switch (language) {
      'en' => const {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      },
      'ja' => const {1: '月', 2: '火', 3: '水', 4: '木', 5: '金', 6: '土', 7: '日'},
      'ko' => const {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'},
      _ => const {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'},
    };
    final orderedDays = (rule.weekdays.toList()..sort())
        .map((day) => labels[day])
        .join(language == 'en' || language == 'ko' ? ', ' : '、');
    final days = rule.weekdays.isEmpty
        ? switch (language) {
            'en' => 'Every day',
            'ja' => '毎日',
            'ko' => '매일',
            _ => '每天',
          }
        : switch (language) {
            'ja' => '$orderedDays曜日',
            'ko' => orderedDays,
            'en' => orderedDays,
            _ => '周$orderedDays',
          };
    return '${rule.startDate} — ${rule.endDate} · $days${rule.startTime.isEmpty ? '' : ' · ${rule.startTime}'}';
  }

  DateTime _withinPlanRange(DateTime value) {
    final minimum = dateFromText(startDate);
    final maximum = dateFromText(targetDate);
    if (value.isBefore(minimum)) return minimum;
    if (value.isAfter(maximum)) return maximum;
    return value;
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

  List<TaskReminderRule> _remindersFromDraft(PlanningDraft? draft) {
    if (draft == null ||
        draft.reminders.intent != ReminderDraftIntent.specified) {
      return <TaskReminderRule>[];
    }
    final mapped = <String, TaskReminderRule>{};
    for (final source in draft.reminders.values) {
      final absoluteAt = _absoluteReminderFromDraft(source, draft.schedule);
      if (absoluteAt == null) continue;
      final deliveryType = switch (source.deliveryType) {
        PlanningReminderDeliveryType.notification =>
          ReminderDeliveryType.notification,
        PlanningReminderDeliveryType.alarm => ReminderDeliveryType.alarm,
      };
      final key = '${deliveryType.name}:${absoluteAt.toIso8601String()}';
      mapped[key] = TaskReminderRule(
        id: 'plan-reminder-${DateTime.now().microsecondsSinceEpoch}-${mapped.length}',
        taskId: 'draft-plan',
        type: ReminderRuleType.absolute,
        absoluteAt: absoluteAt,
        sortOrder: mapped.length,
        deliveryType: deliveryType,
      );
    }
    return mapped.values.toList();
  }

  DateTime? _absoluteReminderFromDraft(
    ReminderDraft reminder,
    ScheduledDraft schedule,
  ) {
    if (reminder.type == PlanningReminderRuleType.absolute) {
      return reminder.absoluteAt?.toLocal();
    }
    if (!schedule.hasDate || !schedule.hasTime) return null;
    final scheduledAt = DateTime.tryParse(
      '${schedule.localDate}T${schedule.localTime}:00',
    );
    if (scheduledAt == null) return null;
    if (reminder.type == PlanningReminderRuleType.relativeDuration) {
      return scheduledAt.subtract(
        Duration(minutes: reminder.offsetMinutes ?? 0),
      );
    }
    final parts = (reminder.timeOfDay ?? '').split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final date = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    ).subtract(Duration(days: reminder.dayOffset ?? 0));
    return DateTime(date.year, date.month, date.day, hour, minute);
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
          label: RawText(
            definition == null
                ? name
                : tagDefinitionName(
                    definition,
                    Localizations.localeOf(context),
                  ),
          ),
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
                      tooltip: localizeUiText(context, '关闭'),
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
                    title: RawText(
                      tagDefinitionName(
                        tag,
                        Localizations.localeOf(context),
                      ),
                    ),
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
                        title: RawText(name),
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
      final category = widget.controller.categoryDefinitionForId(
        sourceCategoryId,
      );
      final savedCategoryName = category == null
          ? categoryName
          : category.name;
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
        categoryName: savedCategoryName,
        sourceCategoryId: category?.id,
        categoryColorValue: category?.colorValue ?? 0xff8e8e93,
        categoryIconName: category?.iconName ?? 'project',
        tags: tags,
        progress: progress,
        milestones: List.of(milestones),
        rules: List.of(recurrenceRules),
        updatedAt: now,
        completedAt: progress.completed ? old?.completedAt ?? now : null,
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
            content: RawText(
              localizeUiTextWithArguments(
                context,
                '确定删除“{0}”吗？存在任务的计划需要先清空任务。',
                [plan.name],
              ),
            ),
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
      showAppAlert(context, title: '无法完成操作', message: text);
}

class _RecurrenceEditResult {
  const _RecurrenceEditResult({this.rule, this.delete = false});

  final RecurrenceRule? rule;
  final bool delete;
}
