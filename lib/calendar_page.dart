import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'plan_editor.dart';
import 'plan_widgets.dart';
import 'task_widgets.dart';

const double _calendarMonthHeaderExtent = 56;
const double _calendarMonthFooterExtent = 10;
const double _calendarMonthFixedExtent =
    _calendarMonthHeaderExtent + _calendarMonthFooterExtent;

class _CalendarScrollController extends ScrollController {
  bool _userScrollLocked = false;

  void setUserScrollLocked(bool locked) {
    if (_userScrollLocked == locked) return;
    _userScrollLocked = locked;
    for (final position in positions) {
      if (position is _CalendarScrollPosition) {
        position.setUserScrollLocked(locked);
      }
    }
  }

  void applyHandoffUserOffset(double delta) {
    for (final position in positions) {
      if (position is _CalendarScrollPosition) {
        position.applyHandoffUserOffset(delta);
      }
    }
  }

  void correctToOnNextDimensions(double pixels) {
    for (final position in positions) {
      if (position is _CalendarScrollPosition) {
        position.pendingPixels = pixels;
      }
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _CalendarScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
    userScrollLocked: _userScrollLocked,
  );
}

class _CalendarScrollPosition extends ScrollPositionWithSingleContext {
  _CalendarScrollPosition({
    required ScrollPhysics physics,
    required ScrollContext context,
    double? initialPixels,
    bool keepScrollOffset = true,
    ScrollPosition? oldPosition,
    String? debugLabel,
    required bool userScrollLocked,
  }) : super(
         physics: physics,
         context: context,
         initialPixels: initialPixels,
         keepScrollOffset: keepScrollOffset,
         oldPosition: oldPosition,
         debugLabel: debugLabel,
       ) {
    _userScrollLocked = userScrollLocked;
    if (oldPosition is _CalendarScrollPosition) {
      pendingPixels = oldPosition.pendingPixels;
    }
  }

  late bool _userScrollLocked;
  double? pendingPixels;

  void setUserScrollLocked(bool locked) {
    _userScrollLocked = locked;
    if (locked) goIdle();
  }

  void applyHandoffUserOffset(double delta) {
    super.applyUserOffset(delta);
  }

  @override
  void applyUserOffset(double delta) {
    if (_userScrollLocked) return;
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (_userScrollLocked) {
      goIdle();
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    final requestedPixels = pendingPixels;
    if (requestedPixels != null) {
      pendingPixels = null;
      final correctedPixels = requestedPixels
          .clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent)
          .toDouble();
      if ((correctedPixels - pixels).abs() > .0001) {
        correctPixels(correctedPixels);
        return false;
      }
    }
    return super.correctForNewDimensions(oldPosition, newPosition);
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.controller,
    required this.selectedDate,
    required this.onSelected,
    required this.onDayTap,
  });
  final AppController controller;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onDayTap;
  @override
  State<CalendarPage> createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage>
    with AutomaticKeepAliveClientMixin {
  late int year;
  late int jumpMonth;
  late int visibleMonth;
  late double rowHeight;
  late double preferenceHeightSeen;
  double scaleStartHeight = 0;
  double scaleStartDistance = 0;
  double scaleAnchorDocumentY = 0;
  int scaleDirection = 0;
  bool scaling = false;
  bool pinchSessionActive = false;
  bool saveRowHeightAfterPinch = false;
  bool scaleFrameScheduled = false;
  bool weeklyCardView = false;
  final scalePointers = <int, Offset>{};
  int? handoffPointer;
  double? handoffPointerY;
  bool handoffMoved = false;
  int pinchSessionGeneration = 0;
  final scroll = _CalendarScrollController();
  final listKey = GlobalKey();
  final todayKey = GlobalKey();
  final monthKeys = List.generate(12, (_) => GlobalKey());
  final weekKeys = List.generate(54, (_) => GlobalKey());
  int revealGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    year = now.year;
    jumpMonth = now.month;
    visibleMonth = now.month;
    rowHeight = widget.controller.preferences.calendarRowHeight;
    preferenceHeightSeen = rowHeight;
    scroll.addListener(_syncVisibleMonth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealKey(todayKey, now.month - 1, alignment: .2, animate: false);
    });
  }

  @override
  void dispose() {
    scroll.removeListener(_syncVisibleMonth);
    scroll.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void goToToday() {
    final now = DateTime.now();
    setState(() {
      year = now.year;
      jumpMonth = now.month;
      visibleMonth = now.month;
    });
    widget.onSelected(now);
    if (weeklyCardView) {
      _revealCurrentWeek();
    } else {
      _revealKey(todayKey, now.month - 1, alignment: .25);
    }
  }

  void toggleCalendarView() {
    final showWeeklyCards = !weeklyCardView;
    final now = DateTime.now();
    setState(() {
      weeklyCardView = showWeeklyCards;
      if (showWeeklyCards) {
        year = now.year;
        jumpMonth = now.month;
        visibleMonth = now.month;
      }
    });
    if (showWeeklyCards) {
      widget.onSelected(now);
      _revealCurrentWeek(animate: false);
    } else {
      _revealKey(todayKey, now.month - 1, alignment: .25, animate: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final preferenceHeight = widget.controller.preferences.calendarRowHeight;
    if (!scaling && preferenceHeight != preferenceHeightSeen) {
      rowHeight = preferenceHeight;
      preferenceHeightSeen = preferenceHeight;
    }
    final allYear = widget.controller.plans
        .where(
          (plan) =>
              plan.startDate.compareTo('$year-12-31') <= 0 &&
              plan.targetDate.compareTo('$year-01-01') >= 0,
        )
        .toList();
    final completed = allYear.where((plan) => plan.progress.completed).length;
    final selected = dateOnly(widget.selectedDate);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$year 年安排 ${allYear.length} 项 · 本年完成 $completed 项',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$visibleMonth月',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: year,
                      items:
                          List.generate(
                                31,
                                (index) => DateTime.now().year - 15 + index,
                              )
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('$value 年'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => setState(() => year = value!),
                    ),
                    const SizedBox(width: 14),
                    DropdownButton<int>(
                      value: jumpMonth,
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1} 月'),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => jumpMonth = value!);
                        _scrollToMonth(value!);
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (final day in ['一', '二', '三', '四', '五', '六', '日'])
                      Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => weeklyCardView
                ? ListView(
                    key: listKey,
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 110),
                    children: [
                      _WeeklyCardCalendar(
                        year: year,
                        controller: widget.controller,
                        selected: selected,
                        weekKeys: weekKeys,
                        todayKey: todayKey,
                        viewportHeight: constraints.maxHeight,
                        onSelected: _selectDate,
                      ),
                    ],
                  )
                : _buildZoomableMonthCalendar(selected),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomableMonthCalendar(String selected) {
    final calendar = CustomScrollView(
      key: listKey,
      controller: scroll,
      slivers: _buildMonthSlivers(selected),
    );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: calendar,
    );
  }

  void _selectDate(DateTime date) {
    if (pinchSessionActive) return;
    widget.onSelected(date);
    setState(() {
      jumpMonth = date.month;
      visibleMonth = date.month;
    });
    widget.onDayTap(date);
  }

  List<Widget> _buildMonthSlivers(String selected) => [
    for (var month = 1; month <= 12; month++) ...[
      SliverToBoxAdapter(
        child: SizedBox(
          key: monthKeys[month - 1],
          height: _calendarMonthHeaderExtent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                '$month月',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        sliver: SliverFixedExtentList(
          itemExtent: rowHeight,
          delegate: SliverChildBuilderDelegate(
            (context, week) => _CalendarWeekRow(
              year: year,
              month: month,
              week: week,
              controller: widget.controller,
              selected: selected,
              rowHeight: rowHeight,
              todayKey: todayKey,
              onSelected: _selectDate,
            ),
            childCount: _monthWeekCount(year, month),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(height: _calendarMonthFooterExtent),
      ),
    ],
    const SliverToBoxAdapter(child: SizedBox(height: 110)),
  ];

  void _syncVisibleMonth() {
    if (!mounted ||
        weeklyCardView ||
        pinchSessionActive ||
        !scroll.hasClients) {
      return;
    }
    var offset = scroll.offset;
    for (var month = 1; month <= 12; month++) {
      final monthExtent =
          _calendarMonthFixedExtent + _monthWeekCount(year, month) * rowHeight;
      if (offset < monthExtent) {
        if (month != visibleMonth) setState(() => visibleMonth = month);
        return;
      }
      offset -= monthExtent;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    scalePointers[event.pointer] = event.position;
    if (scalePointers.length != 2 || !scroll.hasClients) return;
    handoffPointer = null;
    handoffPointerY = null;
    handoffMoved = false;
    _beginPinchSession();
    scaleStartDistance = _pointerDistance();
    scaleStartHeight = rowHeight;
    scaleDirection = 0;
    final focalY = _scaleFocalViewportY();
    if (focalY == null) return;
    scaleAnchorDocumentY = scroll.offset + focalY;
    scaling = true;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!scalePointers.containsKey(event.pointer)) return;
    scalePointers[event.pointer] = event.position;
    if (!scaling && event.pointer == handoffPointer) {
      final previousY = handoffPointerY;
      handoffPointerY = event.position.dy;
      if (previousY != null) {
        final delta = event.position.dy - previousY;
        if (delta.abs() > .0001) {
          handoffMoved = true;
          scroll.applyHandoffUserOffset(delta);
        }
      }
      return;
    }
    if (!scaling || scalePointers.length < 2 || scaleStartDistance == 0) return;
    _schedulePointerScaleFrame();
  }

  void _handlePointerEnd(PointerEvent event) {
    scalePointers.remove(event.pointer);
    if (scalePointers.length < 2) {
      _stopScaleInput();
      if (scalePointers.isNotEmpty) {
        final remainingPointer = scalePointers.entries.first;
        handoffPointer = remainingPointer.key;
        handoffPointerY = remainingPointer.value.dy;
      }
    }
    if (!scalePointers.isEmpty) return;
    handoffPointer = null;
    handoffPointerY = null;
    _completeScaleComputation();
    _endPinchSessionAfterFrame();
  }

  void _beginPinchSession() {
    if (!pinchSessionActive) {
      pinchSessionGeneration++;
      pinchSessionActive = true;
      saveRowHeightAfterPinch = false;
    }
    scroll.setUserScrollLocked(true);
  }

  void _stopScaleInput() {
    if (!scaling) return;
    scaling = false;
    scaleStartDistance = 0;
    scaleDirection = 0;
  }

  void _completeScaleComputation() {
    saveRowHeightAfterPinch =
        saveRowHeightAfterPinch ||
        (rowHeight - preferenceHeightSeen).abs() > .0001;
    preferenceHeightSeen = rowHeight;
  }

  void _endPinchSessionAfterFrame() {
    if (!pinchSessionActive) return;
    final generation = pinchSessionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != pinchSessionGeneration ||
          scalePointers.isNotEmpty) {
        return;
      }
      pinchSessionActive = false;
      scroll.setUserScrollLocked(false);
      if (handoffMoved) {
        handoffMoved = false;
        _syncVisibleMonth();
      }
      if (saveRowHeightAfterPinch) {
        saveRowHeightAfterPinch = false;
        _saveScaledRowHeight();
      }
    });
  }

  double _pointerDistance() {
    final points = scalePointers.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  double? _scaleFocalViewportY() {
    final viewport = listKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final points = scalePointers.values.take(2).toList();
    if (points.length < 2) return null;
    final globalFocalPoint = (points[0] + points[1]) / 2;
    return viewport.globalToLocal(globalFocalPoint).dy;
  }

  double _mapDocumentYForRowHeight(
    double documentY, {
    required double fromHeight,
    required double toHeight,
  }) {
    var oldY = documentY;
    var newY = 0.0;
    for (var month = 1; month <= 12; month++) {
      final weekCount = _monthWeekCount(year, month);
      final oldGridExtent = weekCount * fromHeight;
      final newGridExtent = weekCount * toHeight;
      final oldMonthExtent = _calendarMonthFixedExtent + oldGridExtent;
      final newMonthExtent = _calendarMonthFixedExtent + newGridExtent;
      if (oldY <= oldMonthExtent) {
        if (oldY <= _calendarMonthHeaderExtent) return newY + oldY;
        final gridY = oldY - _calendarMonthHeaderExtent;
        if (gridY <= oldGridExtent) {
          return newY +
              _calendarMonthHeaderExtent +
              gridY * (toHeight / fromHeight);
        }
        return newY +
            _calendarMonthHeaderExtent +
            newGridExtent +
            (gridY - oldGridExtent);
      }
      oldY -= oldMonthExtent;
      newY += newMonthExtent;
    }
    return newY + oldY;
  }

  double _boundedScaleHeight(double rawHeight) => rawHeight
      .clamp(
        AppPreferences.minimumCalendarRowHeight,
        AppPreferences.maximumCalendarRowHeight,
      )
      .toDouble();

  double _snapScaleHeightToPhysicalPixel(double height) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return (height * devicePixelRatio).round() / devicePixelRatio;
  }

  double? _sampleScaleHeight() {
    if (scalePointers.length < 2 || scaleStartDistance == 0) return null;
    return _sampleScaleHeightForRatio(_pointerDistance() / scaleStartDistance);
  }

  double? _sampleScaleHeightForRatio(double scaleRatio) {
    final rawHeight = scaleStartHeight * scaleRatio;
    final nextHeight = _snapScaleHeightToPhysicalPixel(
      _boundedScaleHeight(rawHeight),
    );
    final delta = nextHeight - rowHeight;
    if (delta.abs() < .0001) return null;

    final nextDirection = delta > 0 ? 1 : -1;
    const reversalThreshold = .75;
    if (scaleDirection != 0 &&
        nextDirection != scaleDirection &&
        delta.abs() < reversalThreshold) {
      return null;
    }
    scaleDirection = nextDirection;
    return nextHeight;
  }

  void _schedulePointerScaleFrame() {
    if (scaleFrameScheduled) return;
    scaleFrameScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      scaleFrameScheduled = false;
      if (!mounted || !scaling) return;
      final height = _sampleScaleHeight();
      final focalY = _scaleFocalViewportY();
      if (height != null && focalY != null) {
        _applyScaleHeight(height, focalY);
      }
    });
  }

  void _applyScaleHeight(double height, double focalY) {
    if (height == rowHeight) return;
    final anchorDocumentY = _mapDocumentYForRowHeight(
      scaleAnchorDocumentY,
      fromHeight: scaleStartHeight,
      toHeight: height,
    );
    final targetOffset = anchorDocumentY - focalY;
    scroll.correctToOnNextDimensions(targetOffset);
    final nextVisibleMonth = _monthForOffset(targetOffset, height);
    setState(() {
      rowHeight = height;
      visibleMonth = nextVisibleMonth;
    });
  }

  int _monthForOffset(double targetOffset, double height) {
    var offset = targetOffset < 0 ? 0.0 : targetOffset;
    for (var month = 1; month <= 12; month++) {
      final monthExtent =
          _calendarMonthFixedExtent + _monthWeekCount(year, month) * height;
      if (offset < monthExtent) return month;
      offset -= monthExtent;
    }
    return 12;
  }

  Future<void> _saveScaledRowHeight() async {
    final preferences = widget.controller.preferences;
    await widget.controller.saveCalendarDensityHeights(
      small: preferences.calendarDensity == 'small'
          ? rowHeight
          : preferences.calendarSmallHeight,
      medium: preferences.calendarDensity == 'medium'
          ? rowHeight
          : preferences.calendarMediumHeight,
      large: preferences.calendarDensity == 'large'
          ? rowHeight
          : preferences.calendarLargeHeight,
    );
  }

  void _scrollToMonth(int month) {
    if (weeklyCardView) {
      final target = DateTime(year, month);
      final index = _weekIndexForDate(year, target);
      _revealKey(weekKeys[index], index, alignment: 0);
    } else {
      _revealKey(monthKeys[month - 1], month - 1, alignment: .05);
    }
  }

  void _revealCurrentWeek({bool animate = true}) {
    final now = DateTime.now();
    final index = _weekIndexForDate(now.year, now);
    _revealKey(weekKeys[index], index, alignment: 0, animate: animate);
  }

  Future<void> _revealKey(
    GlobalKey targetKey,
    int targetMonthIndex, {
    required double alignment,
    bool animate = true,
  }) async {
    final generation = ++revealGeneration;
    for (var attempt = 0; attempt < 30; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !scroll.hasClients || generation != revealGeneration)
        return;
      final targetContext = targetKey.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: animate ? const Duration(milliseconds: 240) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: alignment,
        );
        return;
      }

      final visibleMonths = <int>[
        for (var index = 0; index < monthKeys.length; index++)
          if (monthKeys[index].currentContext != null) index,
      ];
      final direction = visibleMonths.isEmpty
          ? (targetMonthIndex >= 6 ? 1 : -1)
          : targetMonthIndex < visibleMonths.first
          ? -1
          : 1;
      final position = scroll.position;
      final nextOffset =
          (position.pixels + direction * position.viewportDimension * .85)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
      if ((nextOffset - position.pixels).abs() < 1) return;
      scroll.jumpTo(nextOffset);
    }
  }
}

class _WeeklyCardCalendar extends StatelessWidget {
  const _WeeklyCardCalendar({
    required this.year,
    required this.controller,
    required this.selected,
    required this.weekKeys,
    required this.todayKey,
    required this.viewportHeight,
    required this.onSelected,
  });

  final int year;
  final AppController controller;
  final String selected;
  final List<GlobalKey> weekKeys;
  final GlobalKey todayKey;
  final double viewportHeight;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final firstWeekStart = _startOfWeek(DateTime(year));
    final lastWeekStart = _startOfWeek(DateTime(year, 12, 31));
    final weekCount = lastWeekStart.difference(firstWeekStart).inDays ~/ 7 + 1;
    return Column(
      children: List.generate(weekCount, (weekIndex) {
        final weekStart = firstWeekStart.add(Duration(days: weekIndex * 7));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return SizedBox(
          key: weekKeys[weekIndex],
          height: viewportHeight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekStart.month}月${weekStart.day}日 — ${weekEnd.month}月${weekEnd.day}日',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardHeight = (constraints.maxHeight - 30) / 4;
                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        primary: false,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: cardHeight,
                        ),
                        itemCount: 7,
                        itemBuilder: (context, dayIndex) {
                          final date = weekStart.add(Duration(days: dayIndex));
                          return _WeeklyDayCard(
                            key: dateOnly(DateTime.now()) == dateOnly(date)
                                ? todayKey
                                : null,
                            date: date,
                            inYear: date.year == year,
                            selected: selected == dateOnly(date),
                            controller: controller,
                            onTap: () => onSelected(date),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _WeeklyDayCard extends StatelessWidget {
  const _WeeklyDayCard({
    super.key,
    required this.date,
    required this.inYear,
    required this.selected,
    required this.controller,
    required this.onTap,
  });

  final DateTime date;
  final bool inYear;
  final bool selected;
  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plans =
        controller.plans
            .where((plan) => _planIncludesDate(plan, dateOnly(date)))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final incomplete = plans.where((plan) => !plan.progress.completed).length;
    final colorScheme = Theme.of(context).colorScheme;
    final weekday = const [
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日',
    ][date.weekday - 1];
    final isToday = dateOnly(date) == dateOnly(DateTime.now());
    return Opacity(
      opacity: inYear ? 1 : .45,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: selected ? colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? colorScheme.primary : null,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isToday ? colorScheme.onPrimary : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      weekday,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (plans.isNotEmpty)
                      Text(
                        '$incomplete/${plans.length}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ),
                if (plans.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...plans
                      .take(3)
                      .map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color:
                                      plan.progress.currentNode?.color ??
                                      Color(plan.categoryColorValue),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: _CalendarPlanLabel(
                                  plan: plan,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (plans.length > 3)
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        '+${plans.length - 3} 项',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _startOfWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

int _monthWeekCount(int year, int month) {
  final days = DateTime(year, month + 1, 0).day;
  final leadingDays = DateTime(year, month, 1).weekday - 1;
  return (leadingDays + days + 6) ~/ 7;
}

int _weekIndexForDate(int year, DateTime date) =>
    _startOfWeek(date).difference(_startOfWeek(DateTime(year))).inDays ~/ 7;

class _CalendarWeekRow extends StatelessWidget {
  const _CalendarWeekRow({
    required this.year,
    required this.month,
    required this.week,
    required this.controller,
    required this.selected,
    required this.rowHeight,
    required this.todayKey,
    required this.onSelected,
  });
  final int year;
  final int month;
  final int week;
  final AppController controller;
  final String selected;
  final double rowHeight;
  final GlobalKey todayKey;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(year, month + 1, 0).day;
    final offset = DateTime(year, month, 1).weekday - 1;
    final height = rowHeight;
    final planLimit = AppPreferences.estimatedCalendarItemCount(height);
    final markerSize = (height - 6).clamp(14, 25).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(7, (weekday) {
        final index = week * 7 + weekday;
        final day = index - offset + 1;
        if (day < 1 || day > days) return const Expanded(child: SizedBox());
        final date = DateTime(year, month, day);
        final text = dateOnly(date);
        final plans =
            controller.plans
                .where((plan) => _planIncludesDate(plan, text))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        final today = dateOnly(DateTime.now()) == text;
        final active = selected == text;
        return Expanded(
          child: InkWell(
            key: today ? todayKey : null,
            onTap: () => onSelected(date),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: today
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: today
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                          fontSize: markerSize < 20
                              ? 9
                              : plans.isEmpty
                              ? 15
                              : 12,
                        ),
                      ),
                    ),
                  ),
                  if (planLimit == 0 && plans.isNotEmpty && height >= 32)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Align(
                        alignment: Alignment.center,
                        child: Wrap(
                          spacing: 3,
                          children: plans.take(4).map((plan) {
                            final color =
                                plan.progress.currentNode?.color ??
                                Color(plan.categoryColorValue);
                            return Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ...plans.take(planLimit).map((plan) {
                    final color =
                        plan.progress.currentNode?.color ??
                        Color(plan.categoryColorValue);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _CalendarPlanLabel(
                        plan: plan,
                        style: const TextStyle(fontSize: 8),
                      ),
                    );
                  }),
                  if (plans.length > planLimit && height >= 42)
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        '+${plans.length - planLimit} 项',
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CalendarPlanLabel extends StatelessWidget {
  const _CalendarPlanLabel({required this.plan, required this.style});

  final PlanItem plan;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final completed = plan.progress.completed;
    final completedColor = Theme.of(context).colorScheme.onSurfaceVariant
        .withAlpha(210);
    final textStyle = completed
        ? (style ?? DefaultTextStyle.of(context).style).copyWith(
            color: completedColor,
          )
        : style;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Text(
          plan.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
        if (completed)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: Container(height: 1, color: completedColor),
              ),
            ),
          ),
      ],
    );
  }
}

class CalendarDayPage extends StatelessWidget {
  const CalendarDayPage({
    super.key,
    required this.controller,
    required this.date,
  });

  final AppController controller;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final dateText = dateOnly(date);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('${date.month}月${date.day}日'),
        actions: [
          IconButton(
            tooltip: '新增计划',
            onPressed: () =>
                showPlanEditor(context, controller, initialDate: dateText),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final plans =
              controller.plans
                  .where((plan) => _planIncludesDate(plan, dateText))
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));
          return SafeArea(
            child: plans.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 38,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 10),
                          const Text('这一天还没有计划'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => showPlanEditor(
                              context,
                              controller,
                              initialDate: dateText,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('新增计划'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: plans.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Text(
                          '${date.year}年 · ${plans.length} 项计划',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        );
                      }
                      final plan = plans[index - 1];
                      return PlanCard(
                        plan: plan,
                        controller: controller,
                        detailed: true,
                        onTap: () =>
                            showPlanEditor(context, controller, plan: plan),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

bool _planIncludesDate(PlanItem plan, String date) =>
    switch (plan.calendarDisplayMode) {
      PlanCalendarDisplayMode.wholePeriod =>
        plan.startDate.compareTo(date) <= 0 &&
            plan.targetDate.compareTo(date) >= 0,
      PlanCalendarDisplayMode.endpoints =>
        date == plan.startDate || date == plan.targetDate,
      PlanCalendarDisplayMode.startOnly => date == plan.startDate,
      PlanCalendarDisplayMode.targetOnly => date == plan.targetDate,
    };
