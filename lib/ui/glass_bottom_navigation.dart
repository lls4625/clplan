import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_ui_features.dart';
import '../l10n/ui_text.dart';

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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: localizeUiText(context, '日历'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.task_alt_outlined),
            selectedIcon: const Icon(Icons.task_alt),
            label: localizeUiText(context, '计划'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: localizeUiText(context, '统计'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: localizeUiText(context, '设置'),
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
          tabs: [
            GlassTab(
              icon: const Icon(Icons.calendar_month_outlined),
              label: localizeUiText(context, '日历'),
            ),
            GlassTab(
              icon: const Icon(Icons.task_alt_outlined),
              label: localizeUiText(context, '计划'),
            ),
            GlassTab(
              icon: const Icon(Icons.bar_chart_outlined),
              label: localizeUiText(context, '统计'),
            ),
            GlassTab(
              icon: const Icon(Icons.tune_outlined),
              label: localizeUiText(context, '设置'),
            ),
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
