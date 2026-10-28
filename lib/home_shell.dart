import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import 'app_controller.dart';
import 'calendar_page.dart';
import 'developer_tip.dart';
import 'l10n/l10n.dart';
import 'l10n/ui_text.dart';
import 'plan_editor.dart';
import 'plans_page.dart';
import 'security/app_security_service.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'task_editor.dart';
import 'task_widgets.dart';
import 'ui/app_alert.dart';
import 'ui/glass_bottom_navigation.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    required this.securityService,
  });
  final AppController controller;
  final AppSecurityService securityService;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const pageTitles = ['日历', '计划', '统计', '设置'];

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final calendarKey = GlobalKey<CalendarPageState>();
  late final DeveloperTipController developerTipController;
  int index = 0;
  DateTime selectedDate = DateTime.now();
  late StatCriteria statCriteria;
  late PlanSearchCriteria planSearchCriteria;
  PlanCompletionFilter planFilter = PlanCompletionFilter.unfinished;
  bool openingNotificationTask = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    developerTipController = DeveloperTipController();
    developerTipController.hostReady = () => mounted;
    developerTipController.onLightFeedback = _showLightTipFeedback;
    statCriteria = StatCriteria.initial();
    planSearchCriteria = PlanSearchCriteria.initial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    developerTipController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshAfterResume();
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
            searchCriteria: planSearchCriteria,
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
          SettingsPage(
            controller: widget.controller,
            developerTipController: developerTipController,
            securityService: widget.securityService,
          ),
        ];
        return Scaffold(
          key: scaffoldKey,
          extendBody: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            leadingWidth: switch (index) {
              0 => 96,
              1 => 112,
              _ => null,
            },
            leading: switch (index) {
              0 => _calendarLeading(),
              1 => _planSummary(),
              2 when statCriteria.mode != StatMode.custom => IconButton(
                tooltip: localizeUiText(context, '回到当前'),
                onPressed: () {
                  setState(
                    () => statCriteria = statCriteria.copyWith(
                      anchor: DateTime.now(),
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt),
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
            1 => PlanSearchDrawer(
              controller: widget.controller,
              criteria: planSearchCriteria,
              onChanged: (value) => setState(() => planSearchCriteria = value),
            ),
            2 => StatsFilterDrawer(
              controller: widget.controller,
              criteria: statCriteria,
              onChanged: (value) => setState(() => statCriteria = value),
            ),
            _ => null,
          },
          body: IndexedStack(index: index, children: pages),
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: index,
            onSelected: (value) {
              if (value != index) setState(() => index = value);
            },
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
    final planId = widget.controller.takePendingPlanToOpen();
    if (planId != null) {
      openingNotificationTask = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final plan = widget.controller.planById(planId);
        if (mounted && plan != null) {
          await showPlanEditor(context, widget.controller, plan: plan);
        }
        openingNotificationTask = false;
      });
      return;
    }
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
        tooltip: context.l10n.tipMenuTitle,
        onPressed: () => showDeveloperTipPage(context, developerTipController),
        icon: const Icon(Icons.volunteer_activism_outlined),
      ),
      IconButton(
        tooltip: localizeUiText(context, '新建计划'),
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
        tooltip: localizeUiText(context, '新建计划'),
        onPressed: () => showPlanEditor(context, widget.controller),
        icon: const Icon(Icons.add),
      ),
      IconButton(
        tooltip: localizeUiText(context, '查询条件'),
        onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
        icon: const Icon(Icons.filter_alt_outlined),
      ),
    ],
    2 => [
      _StatsRefreshButton(onRefresh: widget.controller.reload),
      IconButton(
        tooltip: localizeUiText(context, '统计条件'),
        onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
        icon: const Icon(Icons.tune),
      ),
    ],
    _ => const [],
  };

  Widget _calendarLeading() => Row(
    children: [
      IconButton(
        tooltip: localizeUiText(context, '切换周卡片/月份视图'),
        onPressed: () => calendarKey.currentState?.toggleCalendarView(),
        icon: const Icon(Icons.grid_view_outlined),
      ),
      SizedBox.square(
        dimension: 48,
        child: Tooltip(
          message: '返回当前日期',
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(48),
            ),
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

  void _showLightTipFeedback(DeveloperTipCelebration celebration) {
    if (!mounted) return;
    unawaited(_presentLightTipFeedback(celebration));
  }

  Future<void> _presentLightTipFeedback(
    DeveloperTipCelebration celebration,
  ) async {
    await showDeveloperTipThanksDialog(context, celebration);
    developerTipController.dismiss(celebration.transactionId);
  }
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
        showAppAlert(context, title: '刷新失败', message: '统计数据刷新失败：$error');
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
