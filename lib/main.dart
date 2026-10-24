import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_database.dart';
import 'home_shell.dart';
import 'l10n/generated/app_localizations.dart';
import 'welcome_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(AppDatabase.instance);
  await controller.initialize();
  runApp(ClPlanApp(controller: controller));
}

class ClPlanApp extends StatelessWidget {
  const ClPlanApp({super.key, required this.controller});
  final AppController controller;

  ThemeData _theme(Brightness brightness, double scale) {
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
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(fontSizeFactor: scale),
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
      final scale = switch (pref.font) {
        'small' => .88,
        'large' => 1.14,
        _ => 1.0,
      };
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ClPlan',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        themeMode: mode,
        theme: _theme(Brightness.light, scale),
        darkTheme: _theme(Brightness.dark, scale),
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
