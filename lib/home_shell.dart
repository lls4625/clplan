import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'calendar_page.dart';
import 'plan_editor.dart';
import 'plans_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'task_editor.dart';
import 'task_widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const pageTitles = ['日历', '计划', '统计', '设置'];

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final calendarKey = GlobalKey<CalendarPageState>();
  int index = 0;
  DateTime selectedDate = DateTime.now();
  late StatCriteria statCriteria;
  PlanCompletionFilter planFilter = PlanCompletionFilter.unfinished;
  bool openingNotificationTask = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    statCriteria = StatCriteria.initial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        _openPendingNotificationTask();
        final pages = [
          CalendarPage(
            key: calendarKey,
            controller: widget.controller,
            selectedDate: selectedDate,
            onSelected: (date) => setState(() => selectedDate = date),
            onDayTap: _openCalendarDay,
          ),
          PlansPage(
            controller: widget.controller,
            filter: planFilter,
            onFilterChanged: (value) {
              if (value != planFilter) setState(() => planFilter = value);
            },
          ),
          StatsPage(
            controller: widget.controller,
            onOpenTasks: () => setState(() => index = 1),
            criteria: statCriteria,
            onCriteriaChanged: (value) => setState(() => statCriteria = value),
          ),
          SettingsPage(controller: widget.controller),
        ];
        return Scaffold(
          key: scaffoldKey,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            leadingWidth: switch (index) {
              0 => 132,
              1 => 112,
              _ => null,
            },
            leading: switch (index) {
              0 => _calendarLeading(),
              1 => _planSummary(),
              2 when statCriteria.mode != StatMode.custom => IconButton(
                tooltip: '回到当前',
                onPressed: () => setState(
                  () => statCriteria = statCriteria.copyWith(
                    anchor: DateTime.now(),
                  ),
                ),
                icon: const Icon(Icons.today_outlined),
              ),
              _ => null,
            },
            title: Text(
              pageTitles[index],
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 25),
            ),
            actions: _actions(context),
          ),
          endDrawer: switch (index) {
            2 => StatsFilterDrawer(
              controller: widget.controller,
              criteria: statCriteria,
              onChanged: (value) => setState(() => statCriteria = value),
            ),
            _ => null,
          },
          body: IndexedStack(index: index, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: '日历',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt),
                label: '计划',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: '统计',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: '设置',
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCalendarDay(DateTime _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index != 0) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CalendarDayPage(
            controller: widget.controller,
            date: selectedDate,
          ),
        ),
      );
    });
  }

  void _openPendingNotificationTask() {
    if (openingNotificationTask) return;
    final taskId = widget.controller.takePendingTaskToOpen();
    if (taskId == null) return;
    openingNotificationTask = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final task = widget.controller.taskById(taskId);
      if (mounted && task != null) {
        await showTaskEditor(context, widget.controller, task: task);
      }
      openingNotificationTask = false;
    });
  }

  List<Widget> _actions(BuildContext context) => switch (index) {
    0 => [
      IconButton(
        tooltip: '赞赏',
        onPressed: () => _tips(context),
        icon: const Icon(Icons.favorite_border),
      ),
      IconButton(
        tooltip: '新建计划',
        onPressed: () => showPlanEditor(
          context,
          widget.controller,
          initialDate: dateOnly(selectedDate),
        ),
        icon: const Icon(Icons.add),
      ),
    ],
    1 => [
      IconButton(
        tooltip: '新建计划',
        onPressed: () => showPlanEditor(context, widget.controller),
        icon: const Icon(Icons.add),
      ),
    ],
    2 => [
      _StatsRefreshButton(onRefresh: widget.controller.reload),
      IconButton(
        tooltip: '统计条件',
        onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
        icon: const Icon(Icons.tune),
      ),
    ],
    _ => const [],
  };

  Widget _calendarLeading() => Row(
    children: [
      IconButton(
        tooltip: '切换周卡片/月份视图',
        onPressed: () => calendarKey.currentState?.toggleCalendarView(),
        icon: const Icon(Icons.grid_view_outlined),
      ),
      Expanded(
        child: Tooltip(
          message: '返回当前日期',
          child: TextButton(
            onPressed: () => calendarKey.currentState?.goToToday(),
            child: Text('${DateTime.now().day}'),
          ),
        ),
      ),
    ],
  );

  Widget _planSummary() {
    final plans = widget.controller.plans.where(planFilter.matches).toList();
    final taskCount = widget.controller.tasks.where((task) {
      return switch (planFilter) {
        PlanCompletionFilter.unfinished => !widget.controller.isDone(task),
        PlanCompletionFilter.completed => widget.controller.isDone(task),
        PlanCompletionFilter.all => true,
      };
    }).length;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('计划：${plans.length}', style: style),
          Text('任务：$taskCount', style: style),
        ],
      ),
    );
  }

  void _tips(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('让好用的工具慢慢长大'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('赞赏功能即将开放。'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [6, 12, 30]
                .map(
                  (amount) => OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('赞赏功能即将开放'))),
                    child: Text('¥$amount'),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _StatsRefreshButton extends StatefulWidget {
  const _StatsRefreshButton({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<_StatsRefreshButton> createState() => _StatsRefreshButtonState();
}

class _StatsRefreshButtonState extends State<_StatsRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _rotationController.repeat();
    try {
      await widget.onRefresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('统计数据刷新失败：$error')));
      }
    } finally {
      if (mounted) {
        _rotationController
          ..stop()
          ..reset();
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _refreshing ? '正在刷新统计数据' : '刷新统计数据',
    onPressed: _refreshing ? null : _refresh,
    icon: RotationTransition(
      turns: _rotationController,
      child: const Icon(Icons.refresh),
    ),
  );
}
