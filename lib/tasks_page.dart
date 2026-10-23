import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'task_editor.dart';
import 'task_widgets.dart';

enum TaskTab { open, done, all }

enum TaskScope { month, previous, undated, allOpen }

class TaskSearchCriteria {
  const TaskSearchCriteria({
    this.titleKeyword = '',
    this.contentKeyword = '',
    this.statusId = '',
    this.categoryName = '',
    this.progressTemplateName = '',
    this.progressNodeName = '',
    this.planId = '',
    this.tags = const <String>{},
  });

  final String titleKeyword;
  final String contentKeyword;
  final String statusId;
  final String categoryName;
  final String progressTemplateName;
  final String progressNodeName;
  final String planId;
  final Set<String> tags;

  bool get isActive =>
      titleKeyword.trim().isNotEmpty ||
      contentKeyword.trim().isNotEmpty ||
      statusId.isNotEmpty ||
      categoryName.isNotEmpty ||
      progressTemplateName.isNotEmpty ||
      progressNodeName.isNotEmpty ||
      planId.isNotEmpty ||
      tags.isNotEmpty;
}

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.controller,
    required this.searchCriteria,
  });
  final AppController controller;
  final TaskSearchCriteria searchCriteria;
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with AutomaticKeepAliveClientMixin {
  TaskTab tab = TaskTab.open;
  TaskScope scope = TaskScope.month;
  late DateTime month;

  @override
  void initState() {
    super.initState();
    month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  bool get wantKeepAlive => true;

  List<TaskItem> get filtered {
    final monthText = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final monthStart = '$monthText-01';
    final titleKeyword = widget.searchCriteria.titleKeyword
        .trim()
        .toLowerCase();
    final contentKeyword = widget.searchCriteria.contentKeyword
        .trim()
        .toLowerCase();
    final result = widget.controller.tasks.where((task) {
      final done = widget.controller.isDone(task);
      if (tab == TaskTab.open && done) return false;
      if (tab == TaskTab.done && !done) return false;
      if (tab == TaskTab.open) {
        if (scope == TaskScope.month && !task.startDate.startsWith(monthText))
          return false;
        if (scope == TaskScope.previous &&
            (task.startDate.isEmpty ||
                task.startDate.compareTo(monthStart) >= 0))
          return false;
        if (scope == TaskScope.undated && task.startDate.isNotEmpty)
          return false;
      }
      if (titleKeyword.isNotEmpty &&
          !task.title.toLowerCase().contains(titleKeyword))
        return false;
      if (contentKeyword.isNotEmpty &&
          !task.description.toLowerCase().contains(contentKeyword))
        return false;
      if (widget.searchCriteria.statusId.isNotEmpty &&
          task.statusId != widget.searchCriteria.statusId)
        return false;
      if (widget.searchCriteria.categoryName.isNotEmpty &&
          task.type != widget.searchCriteria.categoryName)
        return false;
      if (widget.searchCriteria.progressTemplateName.isNotEmpty &&
          task.progress?.templateName !=
              widget.searchCriteria.progressTemplateName)
        return false;
      if (widget.searchCriteria.progressNodeName.isNotEmpty &&
          task.progress?.currentNode?.name !=
              widget.searchCriteria.progressNodeName)
        return false;
      if (widget.searchCriteria.planId.isNotEmpty &&
          task.planId != widget.searchCriteria.planId)
        return false;
      if (widget.searchCriteria.tags.isNotEmpty &&
          !widget.searchCriteria.tags.any(task.tags.contains))
        return false;
      return true;
    }).toList();
    if (tab == TaskTab.done) {
      result.sort(
        (a, b) => (b.completedAt ?? DateTime(1900)).compareTo(
          a.completedAt ?? DateTime(1900),
        ),
      );
    } else {
      result.sort(widget.controller.compareTasks);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tasks = filtered;
    final visibleIds = tasks.map((task) => task.id).toSet();
    final ordered = <TaskItem>[];
    for (final root in tasks.where((task) => task.parentTaskId == null)) {
      ordered.add(root);
      ordered.addAll(
        widget.controller
            .childrenOf(root.id)
            .where((child) => visibleIds.contains(child.id)),
      );
    }
    ordered.addAll(
      tasks.where(
        (task) => task.parentTaskId != null && !ordered.contains(task),
      ),
    );
    final monthText = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final previous = widget.controller.tasks
        .where(
          (task) =>
              !widget.controller.isDone(task) &&
              task.startDate.isNotEmpty &&
              task.startDate.compareTo('$monthText-01') < 0,
        )
        .length;
    final undated = widget.controller.tasks
        .where(
          (task) => !widget.controller.isDone(task) && task.startDate.isEmpty,
        )
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
      children: [
        const Text(
          'A LITTLE MORE CLARITY',
          style: TextStyle(fontSize: 11, letterSpacing: 1.8),
        ),
        Text(
          '每件事，都有下一步。',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        SegmentedButton<TaskTab>(
          segments: const [
            ButtonSegment(value: TaskTab.open, label: Text('未完成')),
            ButtonSegment(value: TaskTab.done, label: Text('已完成')),
            ButtonSegment(value: TaskTab.all, label: Text('全部')),
          ],
          selected: {tab},
          onSelectionChanged: (value) => setState(() => tab = value.first),
        ),
        if (widget.searchCriteria.isActive) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const Icon(Icons.filter_alt, size: 18),
              label: const Text('已启用查询条件'),
            ),
          ),
        ],
        if (tab == TaskTab.open) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${month.year}-${month.month.toString().padLeft(2, '0')}',
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => setState(() => scope = TaskScope.allOpen),
                style: OutlinedButton.styleFrom(
                  backgroundColor: scope == TaskScope.allOpen
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  foregroundColor: scope == TaskScope.allOpen
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.primary,
                ),
                child: const Text('所有未完成'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _scopeButton(
                label: '本月安排',
                value: TaskScope.month,
              ),
              const SizedBox(width: 6),
              _scopeButton(
                label: '往期未完成 $previous',
                value: TaskScope.previous,
              ),
              const SizedBox(width: 6),
              _scopeButton(
                label: '未安排日期 $undated',
                value: TaskScope.undated,
              ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            '${tasks.length} 项 · ${tab == TaskTab.done ? '按完成时间从新到旧' : '按开始日期、时间排序'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (ordered.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text('这里没有匹配的计划。'),
            ),
          ),
        ...ordered.map(
          (task) => Column(
            children: [
              TaskCard(
                task: task,
                controller: widget.controller,
                nested: task.parentTaskId != null,
                onTap: () =>
                    showTaskEditor(context, widget.controller, task: task),
                onAddSubtask: () => showTaskEditor(
                  context,
                  widget.controller,
                  parentTaskId: task.id,
                  initialDate: task.startDate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickMonth() async {
    final value = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (value != null)
      setState(() {
        month = DateTime(value.year, value.month);
        scope = TaskScope.month;
      });
  }

  Widget _scopeButton({required String label, required TaskScope value}) {
    final selected = scope == value;
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: () => setState(() => scope = value),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            backgroundColor: selected
                ? colors.primaryContainer
                : Colors.transparent,
            foregroundColor: selected
                ? colors.onPrimaryContainer
                : colors.onSurface,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                child: selected
                    ? const Icon(Icons.check, size: 16)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskSearchDrawer extends StatefulWidget {
  const TaskSearchDrawer({
    super.key,
    required this.controller,
    required this.criteria,
    required this.onChanged,
  });

  final AppController controller;
  final TaskSearchCriteria criteria;
  final ValueChanged<TaskSearchCriteria> onChanged;

  @override
  State<TaskSearchDrawer> createState() => _TaskSearchDrawerState();
}

class _TaskSearchDrawerState extends State<TaskSearchDrawer> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.criteria.titleKeyword);
    contentController = TextEditingController(
      text: widget.criteria.contentKeyword,
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void _update({
    String? statusId,
    String? categoryName,
    String? progressTemplateName,
    String? progressNodeName,
    String? planId,
    Set<String>? tags,
  }) {
    widget.onChanged(
      TaskSearchCriteria(
        titleKeyword: titleController.text,
        contentKeyword: contentController.text,
        statusId: statusId ?? widget.criteria.statusId,
        categoryName: categoryName ?? widget.criteria.categoryName,
        progressTemplateName:
            progressTemplateName ?? widget.criteria.progressTemplateName,
        progressNodeName: progressNodeName ?? widget.criteria.progressNodeName,
        planId: planId ?? widget.criteria.planId,
        tags: tags ?? widget.criteria.tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = <String>{
      ...widget.controller.tagDefinitions.map((tag) => tag.name),
      ...widget.controller.tasks.expand((task) => task.tags),
    }.toList()..sort();
    final categories = <String>{
      ...widget.controller.categoryDefinitions.map((item) => item.name),
      ...widget.controller.tasks
          .map((task) => task.type)
          .where((name) => name.isNotEmpty),
    }.toList()..sort();
    final progressTemplates = <String>{
      ...widget.controller.progressTemplates.map((item) => item.name),
      ...widget.controller.tasks
          .map((task) => task.progress?.templateName ?? '')
          .where((name) => name.isNotEmpty),
    }.toList()..sort();
    final progressNodes = widget.controller.progressNodeNamesForTemplate(
      widget.criteria.progressTemplateName,
      widget.controller.tasks
          .map((task) => task.progress)
          .whereType<ProgressSnapshot>(),
    );
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '查询计划',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              onChanged: (_) => _update(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.title),
                labelText: '模糊查询标题',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: contentController,
              onChanged: (_) => _update(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.notes),
                labelText: '模糊查询内容',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(widget.criteria.categoryName),
              initialValue: widget.criteria.categoryName,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.folder_outlined),
                labelText: '分类',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部分类')),
                ...categories.map(
                  (name) => DropdownMenuItem(value: name, child: Text(name)),
                ),
              ],
              onChanged: (value) => _update(categoryName: value ?? ''),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(widget.criteria.progressTemplateName),
              initialValue: widget.criteria.progressTemplateName,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.route_outlined),
                labelText: '进度方案',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部进度方案')),
                ...progressTemplates.map(
                  (name) => DropdownMenuItem(value: name, child: Text(name)),
                ),
              ],
              onChanged: (value) => _update(
                progressTemplateName: value ?? '',
                progressNodeName: '',
              ),
            ),
            if (widget.criteria.progressTemplateName.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'task-node-${widget.criteria.progressTemplateName}-'
                  '${widget.criteria.progressNodeName}',
                ),
                initialValue: widget.criteria.progressNodeName,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.flag_outlined),
                  labelText: '进度节点',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('该方案全部节点'),
                  ),
                  ...progressNodes.map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  ),
                ],
                onChanged: (value) => _update(
                  progressNodeName: value ?? '',
                ),
              ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(widget.criteria.planId),
              initialValue: widget.criteria.planId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.route_outlined),
                labelText: '所属计划',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部计划')),
                ...widget.controller.plans.map(
                  (plan) =>
                      DropdownMenuItem(value: plan.id, child: Text(plan.name)),
                ),
                ...widget.controller.tasks
                    .map((task) => task.planId)
                    .whereType<String>()
                    .toSet()
                    .where(
                      (id) =>
                          !widget.controller.plans.any((plan) => plan.id == id),
                    )
                    .map(
                      (id) =>
                          DropdownMenuItem(value: id, child: Text('$id（历史计划）')),
                    ),
              ],
              onChanged: (value) => _update(planId: value ?? ''),
            ),
            const SizedBox(height: 22),
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
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (value) {
                      final selectedTags = {...widget.criteria.tags};
                      value ? selectedTags.add(tag) : selectedTags.remove(tag);
                      _update(tags: selectedTags);
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                titleController.clear();
                contentController.clear();
                widget.onChanged(const TaskSearchCriteria());
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('清空查询条件'),
            ),
          ],
        ),
      ),
    );
  }
}
