import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_ui_features.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static double contentBottomPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 16;

  @override
  Widget build(BuildContext context) {
    if (!AppUiFeatures.useLiquidGlassBottomBar) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: onSelected,
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
      );
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: const EdgeInsets.only(bottom: 8),
      maintainBottomViewPadding: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GlassTabBar.bottom(
          tabs: const [
            GlassTab(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
            GlassTab(icon: Icon(Icons.task_alt_outlined), label: '计划'),
            GlassTab(icon: Icon(Icons.bar_chart_outlined), label: '统计'),
            GlassTab(icon: Icon(Icons.tune_outlined), label: '设置'),
          ],
          selectedIndex: selectedIndex,
          onTabSelected: onSelected,
          quality: GlassQuality.premium,
          backgroundQuality: GlassQuality.standard,
          barHeight: 64,
          horizontalPadding: 16,
          verticalPadding: 0,
          indicatorBorderRadius: 999,
          indicatorExpansion: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          magnification: 1.12,
          enableBlend: true,
          adaptiveBrightness: true,
        ),
      ),
    );
  }
}
