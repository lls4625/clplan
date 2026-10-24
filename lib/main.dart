import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_controller.dart';
import 'app_database.dart';
import 'home_shell.dart';
import 'l10n/generated/app_localizations.dart';
import 'welcome_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  final controller = AppController(AppDatabase.instance);
  await controller.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      adaptiveQuality: true,
      brightnessResolver: Theme.maybeBrightnessOf,
      theme: const GlassThemeData.ios27(),
      child: ClPlanApp(controller: controller),
    ),
  );
}

class ClPlanApp extends StatelessWidget {
  const ClPlanApp({super.key, required this.controller});
  final AppController controller;

  ThemeData _theme(Brightness brightness) {
    const accent = Color(0xffde583f);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff6f6f8)
          : const Color(0xff08090b),
      textTheme: ThemeData(brightness: brightness).textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final pref = controller.preferences;
      final mode = switch (pref.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final locale = switch (pref.language) {
        'zh' => const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        'tw' => const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
        'ja' => const Locale('ja'),
        'ko' => const Locale('ko'),
        'en' => const Locale('en'),
        _ => null,
      };
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ClPlan',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        themeMode: mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        builder: (context, child) {
          if (pref.followSystemFontScale) {
            return child ?? const SizedBox.shrink();
          }
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(pref.fontScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: controller.loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : controller.error != null
            ? Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('本地数据库加载失败：\n${controller.error}'),
                  ),
                ),
              )
            : WelcomePage(child: HomeShell(controller: controller)),
      );
    },
  );
}
