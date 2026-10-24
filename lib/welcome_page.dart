import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import 'l10n/ui_text.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.child});

  final Widget child;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  Timer? _timer;
  int _secondsRemaining = 5;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entered) return;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _entered) return;
        if (_secondsRemaining <= 1) {
          _enterApp();
        } else {
          setState(() => _secondsRemaining--);
        }
      });
    });
  }

  void _enterApp() {
    if (!mounted || _entered) return;
    _timer?.cancel();
    setState(() => _entered = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_entered) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0.0, viewport.maxHeight - 56),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
                        'Icon-App-1024x1024@1x.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '计划有序，\n行动从容。',
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1.18),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '从一个目标、一项任务开始，让计划清晰落地，让每一步都有方向。',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_secondsRemaining 秒后自动进入',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _enterApp,
                        child: const Text('开始规划'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '无需账号 · 计划与任务数据保存在本机',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
