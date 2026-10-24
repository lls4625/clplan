import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/l10n.dart';

const _tipGold = Color(0xffffc83d);
const _tipToolbarHeight = 64.0;
const _tipContentTopGap = 12.0;

class DeveloperTipProduct {
  const DeveloperTipProduct({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final String price;

  static DeveloperTipProduct? fromNative(Object? value) {
    if (value is! Map) return null;
    final id = value['id'] as String?;
    final name = value['name'] as String?;
    final price = value['price'] as String?;
    if (id == null || name == null || price == null) return null;
    return DeveloperTipProduct(id: id, name: name, price: price);
  }
}

class DeveloperTipCelebration {
  const DeveloperTipCelebration({
    required this.productId,
    required this.transactionId,
  });

  final String productId;
  final String transactionId;

  static DeveloperTipCelebration? fromNative(Object? value) {
    if (value is! Map) return null;
    final productId = value['productId'] as String?;
    final transactionId = value['transactionId'] as String?;
    if (productId == null || transactionId == null) return null;
    return DeveloperTipCelebration(
      productId: productId,
      transactionId: transactionId,
    );
  }
}

class DeveloperTipController extends ChangeNotifier
    with WidgetsBindingObserver {
  DeveloperTipController() {
    _channel.setMethodCallHandler(_onNativeCall);
    WidgetsBinding.instance.addObserver(this);
  }

  static const _channel = MethodChannel(
    'vip.ichiki.javalee.clplan/developer_tip',
  );
  static const displayOrder = <String>[
    'vip.ichiki.javalee.clplan.tip.medium',
    'vip.ichiki.javalee.clplan.tip.small',
    'vip.ichiki.javalee.clplan.tip.xlarge',
    'vip.ichiki.javalee.clplan.tip.large',
    'vip.ichiki.javalee.clplan.tip.strong',
    'vip.ichiki.javalee.clplan.tip.premium',
  ];

  final List<DeveloperTipProduct> _products = [];
  final Set<String> _retiredInstances = {};
  final Set<String> _seen = {};
  final Set<String> _revoked = {};
  final String _clientId =
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${math.Random.secure().nextInt(1 << 32)}';
  String? _instance;
  int _revision = -1;
  bool _initialized = false;
  bool _loading = false;
  bool _nativeBusy = false;
  bool _calling = false;
  bool _confirming = false;
  bool _canPay = false;
  bool _disposed = false;
  bool _foreground =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool _reconciling = false;
  bool _draining = false;
  bool _drainAgain = false;
  bool _hasUnresolved = false;
  bool _awaitingApproval = false;
  bool _transportUnknown = false;
  String _storage = 'initializing';
  String? _catalogMessageCode;
  String? _productLoadMessageCode;
  String? _operationMessageCode;
  String? _processingProductId;
  String? _requestId;
  String? _requestOutcome;
  String? _page;
  int _pageSequence = 0;
  bool Function()? _pageVisible;
  DeveloperTipCelebration? _celebration;
  Timer? _lightTimer;
  String? _lightId;

  bool Function()? hostReady;
  void Function(DeveloperTipCelebration)? onLightFeedback;
  VoidCallback? onLightDismiss;

  List<DeveloperTipProduct> get products => List.unmodifiable(_products);
  bool get initialized => _initialized;
  bool get loading => _loading;
  bool get busy => _nativeBusy || _calling || _confirming;
  bool get reconciling => _reconciling;
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get canPay => _canPay && _storage == 'healthy';
  bool get needsPurchaseConfirmation => _hasUnresolved || _transportUnknown;
  String? get processingProductId => _processingProductId;
  DeveloperTipCelebration? get celebration => _celebration;

  String? get messageCode {
    if (_storage == 'corrupted') return 'tipStorageCorrupt';
    if (_storage != 'healthy' && supported && _initialized) {
      return 'tipStorageError';
    }
    if (_transportUnknown) return 'tipUnresolved';
    if (_awaitingApproval) return 'tipPurchasePending';
    if (_hasUnresolved && !busy) return 'tipUnresolved';
    return _operationMessageCode ??
        _productLoadMessageCode ??
        _catalogMessageCode;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Object?> _invoke(String method, [Object? arguments]) => _channel
      .invokeMethod<Object?>(method, arguments)
      .timeout(const Duration(seconds: 15));

  void applyNativeState(Object? value) {
    if (_disposed || value is! Map) return;
    final instance = value['serviceInstanceId'] as String? ?? 'legacy';
    if (_retiredInstances.contains(instance)) return;
    if (instance != _instance) {
      if (_instance != null) _retiredInstances.add(_instance!);
      _instance = instance;
      _revision = -1;
    }
    final revision = (value['revision'] as num?)?.toInt() ?? -1;
    if (revision <= _revision) return;
    _revision = revision;
    _canPay = value['canPay'] == true;
    _storage = value['storage'] as String? ?? 'initializing';
    _nativeBusy = value['busy'] == true;
    _hasUnresolved = value['hasUnresolved'] == true;
    _awaitingApproval = value['awaitingApproval'] == true;
    final requests = value['requestStates'];
    final requestState = requests is Map ? requests[_requestId] : null;
    _requestOutcome = requestState is String ? requestState : null;
    _resolveTransportUncertainty();
    _catalogMessageCode = _messageKey(value['messageCode'] as String?);
    final raw = value['products'];
    if (raw is List) {
      final next =
          raw
              .map(DeveloperTipProduct.fromNative)
              .whereType<DeveloperTipProduct>()
              .toList()
            ..sort(
              (a, b) => displayOrder
                  .indexOf(a.id)
                  .compareTo(displayOrder.indexOf(b.id)),
            );
      _products
        ..clear()
        ..addAll(next);
      if ((next.isNotEmpty && value['messageCode'] == null) ||
          const {
            'purchase_products_unavailable',
            'purchase_products_load_failed',
          }.contains(value['messageCode'])) {
        _productLoadMessageCode = null;
      }
    }
    _initialized = true;
    _notify();
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (_disposed) return;
    if (call.method == 'state') applyNativeState(call.arguments);
    if (call.method == 'feedbackRevoked' && call.arguments is String) {
      final id = call.arguments as String;
      _revoked.add(id);
      dismiss(id);
    }
    if (call.method == 'feedbackAvailable' || call.method == 'state') {
      unawaited(_drain());
    }
  }

  void attachPage(String session, bool Function() visible) {
    _page = session;
    _pageVisible = visible;
    _operationMessageCode = null;
    unawaited(_syncPage());
  }

  void detachPage(String session) {
    if (_page != session) return;
    _page = null;
    _pageVisible = null;
    final event = _celebration;
    if (event != null) dismiss(event.transactionId);
    unawaited(_syncPage());
  }

  String? get _visiblePage =>
      _foreground && (_pageVisible?.call() ?? false) ? _page : null;

  Future<void> _syncPage() async {
    if (!supported || _disposed) return;
    try {
      await _invoke('setPage', {
        'page': _visiblePage,
        'client': _clientId,
        'sequence': ++_pageSequence,
      });
      await _drain();
    } catch (_) {
      // Reconnecting must not repeat a payment or an already claimed effect.
    }
  }

  void dismiss(String id) {
    if (_celebration?.transactionId == id) {
      _celebration = null;
      _notify();
    }
    if (_lightId == id) {
      _lightId = null;
      _lightTimer?.cancel();
      _lightTimer = null;
      onLightDismiss?.call();
    }
    if (!_disposed) unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_disposed ||
        !supported ||
        !_foreground ||
        _storage != 'healthy' ||
        !(hostReady?.call() ?? false)) {
      return;
    }
    if (_draining) {
      _drainAgain = true;
      return;
    }
    if (_celebration != null || _lightId != null) return;
    _draining = true;
    try {
      do {
        _drainAgain = false;
        final raw = await _invoke('listPendingFeedback');
        if (_disposed || !_foreground || raw is! List) return;
        for (final item in raw) {
          if (_celebration != null || _lightId != null) return;
          if (!_foreground || !(hostReady?.call() ?? false)) return;
          final id = item is Map ? item['transactionId'] as String? : null;
          if (id == null || _seen.contains(id) || _revoked.contains(id)) {
            continue;
          }
          final session = _visiblePage;
          final claimed = await _invoke('claimFeedback', {
            'transactionId': id,
            'page': session,
          });
          if (claimed is! Map) continue;
          final event = DeveloperTipCelebration.fromNative(claimed);
          if (event == null || !_seen.add(event.transactionId)) continue;
          if (_disposed ||
              !_foreground ||
              _revoked.contains(id) ||
              session != _visiblePage ||
              !(hostReady?.call() ?? false)) {
            return;
          }
          if (claimed['animated'] == true && session != null) {
            _celebration = event;
            _notify();
          } else {
            _lightId = id;
            onLightFeedback?.call(event);
            _lightTimer = Timer(const Duration(seconds: 4), () => dismiss(id));
          }
          return;
        }
      } while (_drainAgain && !_disposed);
    } catch (error) {
      _record(error);
      _drainAgain = false;
    } finally {
      _draining = false;
      if (_drainAgain && !_disposed) {
        _drainAgain = false;
        unawaited(_drain());
      }
    }
  }

  void _record(Object error, {bool productLoad = false}) {
    final message = _messageKey(
      error is PlatformException ? error.code : 'purchase_service_unavailable',
    );
    if (productLoad) {
      _productLoadMessageCode = message;
    } else {
      _operationMessageCode = message;
    }
    _notify();
  }

  void _resolveTransportUncertainty() {
    if (const {
      'succeeded',
      'cancelled',
      'failed',
      'awaitingApproval',
    }.contains(_requestOutcome)) {
      _transportUnknown = false;
    }
  }

  Future<void> reload() async {
    if (_disposed) return;
    if (!supported) {
      _initialized = true;
      _operationMessageCode = 'tipIosOnly';
      _notify();
      return;
    }
    try {
      applyNativeState(await _invoke('refresh'));
      await _syncPage();
    } catch (error) {
      _record(error);
    } finally {
      _initialized = true;
      _notify();
    }
    if (!_disposed && _products.isEmpty) unawaited(loadProducts());
  }

  Future<void> reconcile() async {
    if (_disposed || !supported || _reconciling) return;
    _reconciling = true;
    _operationMessageCode = null;
    _notify();
    try {
      applyNativeState(await _invoke('reconcile'));
      _resolveTransportUncertainty();
      await _syncPage();
    } catch (error) {
      if (_requestId != null) {
        _transportUnknown = true;
        _resolveTransportUncertainty();
      } else {
        _record(error);
      }
    } finally {
      _reconciling = false;
      _notify();
    }
  }

  Future<void> loadProducts() async {
    if (_disposed || !supported || _loading || busy) return;
    _loading = true;
    _productLoadMessageCode = null;
    _notify();
    try {
      applyNativeState(await _invoke('loadProducts'));
    } catch (error) {
      _record(error, productLoad: true);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> purchase(DeveloperTipProduct product) async {
    if (_disposed ||
        !supported ||
        busy ||
        !canPay ||
        !_products.any((item) => item.id == product.id)) {
      return;
    }
    _calling = true;
    _processingProductId = product.id;
    _operationMessageCode = null;
    _notify();
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${math.Random.secure().nextInt(1 << 32)}';
    _requestId = requestId;
    _requestOutcome = null;
    try {
      applyNativeState(
        await _invoke('purchase', {
          'productId': product.id,
          'requestId': requestId,
        }),
      );
      _transportUnknown = false;
    } catch (error) {
      final details = error is PlatformException ? error.details : null;
      final preflight =
          error is PlatformException &&
          (const {
                'purchase_busy',
                'purchase_product_invalid',
                'purchase_restricted',
              }.contains(error.code) ||
              (details is Map &&
                  details['paymentStarted'] == false &&
                  details['requestId'] == requestId));
      if (preflight) {
        _transportUnknown = false;
        _requestOutcome = 'failed';
        if (error.code != 'purchase_busy') _record(error);
        if (error.code == 'tip_storage_error') unawaited(reconcile());
      } else {
        _transportUnknown = true;
        _resolveTransportUncertainty();
        unawaited(reconcile());
      }
    } finally {
      _calling = false;
      _processingProductId = null;
      _notify();
      unawaited(_drain());
    }
  }

  Future<void> confirmAndPurchase(
    DeveloperTipProduct product,
    Future<bool> Function() confirm,
  ) async {
    if (busy || !canPay || _disposed) return;
    if (needsPurchaseConfirmation) {
      _confirming = true;
      _notify();
      var accepted = false;
      try {
        accepted = await confirm();
      } finally {
        _confirming = false;
        _notify();
      }
      if (!accepted || _disposed) return;
    }
    await purchase(product);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final id = _celebration?.transactionId ?? _lightId;
      if (id != null) dismiss(id);
      unawaited(_syncPage());
    }
    if (_foreground) {
      unawaited(_syncPage());
      unawaited(reconcile());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _lightTimer?.cancel();
    onLightDismiss?.call();
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

String? _messageKey(String? code) => switch (code) {
  null => null,
  'purchase_service_unavailable' => 'tipServiceUnavailable',
  'tip_storage_error' => 'tipStorageError',
  'tip_storage_corrupt' => 'tipStorageCorrupt',
  'tip_unresolved' => 'tipUnresolved',
  'purchase_ios_only' => 'tipIosOnly',
  'purchase_products_unavailable' => 'tipProductsUnavailable',
  'purchase_restricted' => 'tipPurchaseRestricted',
  'purchase_products_load_failed' => 'tipProductsLoadFailed',
  'purchase_busy' => 'tipPurchaseBusy',
  'purchase_product_invalid' => 'tipProductInvalid',
  'purchase_verification_failed' => 'tipVerificationFailed',
  'purchase_pending' => 'tipPurchasePending',
  _ => 'tipServiceUnavailable',
};

String _localizedMessage(BuildContext context, String key) => switch (key) {
  'tipServiceUnavailable' => context.l10n.tipServiceUnavailable,
  'tipStorageError' => context.l10n.tipStorageError,
  'tipStorageCorrupt' => context.l10n.tipStorageCorrupt,
  'tipUnresolved' => context.l10n.tipUnresolved,
  'tipIosOnly' => context.l10n.tipIosOnly,
  'tipProductsUnavailable' => context.l10n.tipProductsUnavailable,
  'tipPurchaseRestricted' => context.l10n.tipPurchaseRestricted,
  'tipProductsLoadFailed' => context.l10n.tipProductsLoadFailed,
  'tipPurchaseBusy' => context.l10n.tipPurchaseBusy,
  'tipProductInvalid' => context.l10n.tipProductInvalid,
  'tipVerificationFailed' => context.l10n.tipVerificationFailed,
  'tipPurchasePending' => context.l10n.tipPurchasePending,
  _ => context.l10n.tipServiceUnavailable,
};

String _productName(BuildContext context, String productId) =>
    switch (productId.split('.').last) {
      'small' => context.l10n.tipProductSmall,
      'medium' => context.l10n.tipProductMedium,
      'large' => context.l10n.tipProductLarge,
      'xlarge' => context.l10n.tipProductXLarge,
      'premium' => context.l10n.tipProductPremium,
      'strong' => context.l10n.tipProductStrong,
      _ => productId,
    };

Future<void> showDeveloperTipPage(
  BuildContext context,
  DeveloperTipController controller,
) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => DeveloperTipPage(controller: controller),
  ),
);

Future<void> showDeveloperTipThanksDialog(
  BuildContext context,
  DeveloperTipCelebration celebration,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.favorite_rounded, color: _tipGold, size: 38),
    title: Text(
      context.l10n.tipThanks(_productName(context, celebration.productId)),
      textAlign: TextAlign.center,
    ),
    content: Text(context.l10n.tipThanksStatic, textAlign: TextAlign.center),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.tipClose),
      ),
    ],
  ),
);

class DeveloperTipPage extends StatefulWidget {
  const DeveloperTipPage({super.key, required this.controller});

  final DeveloperTipController controller;

  @override
  State<DeveloperTipPage> createState() => _DeveloperTipPageState();
}

class _DeveloperTipPageState extends State<DeveloperTipPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fireworkController;
  Timer? _thanksTimer;
  String? _handledTransactionId;
  final String _session =
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${math.Random.secure().nextInt(1 << 32)}';
  _TipCelebrationLevel? _level;
  bool _staticThanks = false;

  DeveloperTipController get tip => widget.controller;

  @override
  void initState() {
    super.initState();
    _fireworkController = AnimationController(vsync: this);
    tip.addListener(_onTipChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tip.attachPage(
        _session,
        () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      );
      _onTipChanged();
      unawaited(tip.reload());
    });
  }

  void _onTipChanged() {
    final event = tip.celebration;
    if (event == null) {
      _thanksTimer?.cancel();
      _fireworkController.stop();
      if (mounted && _level != null) setState(() => _level = null);
      return;
    }
    if (!mounted || event.transactionId == _handledTransactionId) return;
    final level = _TipCelebrationLevel.forProduct(event.productId);
    if (level == null) return;
    _handledTransactionId = event.transactionId;
    _level = level;
    _staticThanks =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _thanksTimer?.cancel();
    _thanksTimer = Timer(const Duration(seconds: 5), () {
      if (_handledTransactionId == event.transactionId) _dismissCelebration();
    });
    if (!_staticThanks) {
      _fireworkController.duration = level.duration;
      _fireworkController.forward(from: 0);
    }
    setState(() {});
  }

  void _dismissCelebration() {
    _thanksTimer?.cancel();
    _thanksTimer = null;
    _fireworkController.stop();
    if (mounted) setState(() => _level = null);
    final id = _handledTransactionId;
    if (id != null) tip.dismiss(id);
  }

  @override
  void dispose() {
    tip.removeListener(_onTipChanged);
    tip.detachPage(_session);
    _thanksTimer?.cancel();
    _fireworkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) tip.detachPage(_session);
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: _tipToolbarHeight,
        backgroundColor: Colors.transparent,
        title: Text(context.l10n.tipTitle),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _TipBackground()),
          SafeArea(
            top: false,
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.paddingOf(context).top +
                        _tipToolbarHeight +
                        _tipContentTopGap,
                    20,
                    32,
                  ),
                  children: [
                    Text(
                      context.l10n.tipHeading,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 14),
                    _TipSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.tipMotivation),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.tipExplanation,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: tip,
                      builder: (context, _) => _TipProducts(controller: tip),
                    ),
                  ],
                ),
                if (_level != null)
                  Positioned.fill(
                    child: _FireworksOverlay(
                      level: _level!,
                      controller: _fireworkController,
                      staticThanks: _staticThanks,
                      onDismiss: _dismissCelebration,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TipBackground extends StatelessWidget {
  const _TipBackground();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xff20303f), Color(0xff111820), Color(0xff302e28)]
              : const [Color(0xffe6edf5), Color(0xfff3f5f7), Color(0xffeee4d2)],
        ),
      ),
    );
  }
}

class _TipSurface extends StatelessWidget {
  const _TipSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xff30343a).withValues(alpha: .82)
            : Colors.white.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _TipProducts extends StatelessWidget {
  const _TipProducts({required this.controller});

  final DeveloperTipController controller;

  @override
  Widget build(BuildContext context) {
    final waiting = !controller.initialized || controller.loading;
    final messageCode = controller.messageCode;
    final status = waiting
        ? context.l10n.tipLoadingProducts
        : messageCode != null
        ? _localizedMessage(context, messageCode)
        : controller.products.isEmpty
        ? context.l10n.tipNoProducts
        : controller.products.length <
              DeveloperTipController.displayOrder.length
        ? context.l10n.tipSomeProductsUnavailable
        : !controller.canPay
        ? context.l10n.tipPurchasesNotAllowed
        : null;

    return Column(
      children: [
        if (status != null) ...[
          _TipSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (waiting) ...[
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: Text(status)),
                  ],
                ),
                if (!waiting &&
                    controller.products.length <
                        DeveloperTipController.displayOrder.length) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: controller.busy ? null : controller.loadProducts,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.l10n.tipReloadProducts),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: controller.reconciling
                      ? null
                      : controller.reconcile,
                  child: Text(
                    controller.reconciling
                        ? context.l10n.tipChecking
                        : context.l10n.tipReconcile,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.24,
          ),
          itemBuilder: (context, index) {
            final product = controller.products[index];
            return _TipCard(
              product: product,
              enabled: !controller.busy && controller.canPay,
              processing: controller.processingProductId == product.id,
              onTap: () async {
                await controller.confirmAndPurchase(product, () async {
                  final accepted = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.l10n.tipBuyAgain),
                      content: Text(context.l10n.tipBuyAgainWarning),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.l10n.tipCancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(context.l10n.tipBuyAgain),
                        ),
                      ],
                    ),
                  );
                  return accepted == true && context.mounted;
                });
              },
            );
          },
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.product,
    required this.enabled,
    required this.processing,
    required this.onTap,
  });

  final DeveloperTipProduct product;
  final bool enabled;
  final bool processing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = _productName(context, product.id);
    final accent = Theme.of(context).brightness == Brightness.dark
        ? _tipGold
        : const Color(0xff805900);
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.tipProductSemantics(displayName, product.price),
      child: Opacity(
        opacity: enabled ? 1 : .55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: enabled ? onTap : null,
            child: _TipSurface(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (processing) ...[
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          product.price,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: accent),
                        ),
                      ],
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

enum _FireworkStyle { comet, heart, burst, waterfall, ring, finale }

class _TipCelebrationLevel {
  const _TipCelebrationLevel(
    this.productSuffix,
    this.style,
    this.bursts,
    this.particles,
    this.duration,
  );

  final String productSuffix;
  final _FireworkStyle style;
  final int bursts;
  final int particles;
  final Duration duration;

  static const all = <_TipCelebrationLevel>[
    _TipCelebrationLevel(
      'small',
      _FireworkStyle.comet,
      1,
      40,
      Duration(milliseconds: 1400),
    ),
    _TipCelebrationLevel(
      'medium',
      _FireworkStyle.heart,
      2,
      70,
      Duration(milliseconds: 1800),
    ),
    _TipCelebrationLevel(
      'large',
      _FireworkStyle.burst,
      3,
      110,
      Duration(milliseconds: 2200),
    ),
    _TipCelebrationLevel(
      'xlarge',
      _FireworkStyle.waterfall,
      5,
      170,
      Duration(milliseconds: 2800),
    ),
    _TipCelebrationLevel(
      'premium',
      _FireworkStyle.ring,
      7,
      240,
      Duration(milliseconds: 3400),
    ),
    _TipCelebrationLevel(
      'strong',
      _FireworkStyle.finale,
      10,
      360,
      Duration(milliseconds: 4500),
    ),
  ];

  static _TipCelebrationLevel? forProduct(String id) {
    for (final level in all) {
      if (id.endsWith('.${level.productSuffix}')) return level;
    }
    return null;
  }
}

class _FireworksOverlay extends StatefulWidget {
  const _FireworksOverlay({
    required this.level,
    required this.controller,
    required this.staticThanks,
    required this.onDismiss,
  });

  final _TipCelebrationLevel level;
  final AnimationController controller;
  final bool staticThanks;
  final VoidCallback onDismiss;

  @override
  State<_FireworksOverlay> createState() => _FireworksOverlayState();
}

class _FireworksOverlayState extends State<_FireworksOverlay> {
  late final List<_FireworkParticle> particles = _FireworkParticle.create(
    widget.level,
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: .58),
    child: Stack(
      children: [
        if (!widget.staticThanks)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FireworkPainter(
                  widget.controller,
                  widget.level.style,
                  particles,
                ),
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _TipSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded, size: 38, color: _tipGold),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.tipThanks(
                      _productName(
                        context,
                        'vip.ichiki.javalee.clplan.tip.${widget.level.productSuffix}',
                      ),
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.staticThanks
                        ? context.l10n.tipThanksStatic
                        : context.l10n.tipThanksEcho,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: widget.onDismiss,
                    child: Text(
                      widget.staticThanks
                          ? context.l10n.tipClose
                          : context.l10n.tipSkip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FireworkParticle {
  const _FireworkParticle(
    this.x,
    this.y,
    this.angle,
    this.distance,
    this.delay,
    this.color,
  );

  final double x;
  final double y;
  final double angle;
  final double distance;
  final double delay;
  final Color color;

  static List<_FireworkParticle> create(_TipCelebrationLevel level) {
    final random = math.Random(level.productSuffix.hashCode);
    const colors = <Color>[
      Color(0xffffd166),
      Color(0xffff7b7b),
      Color(0xff8de0d5),
      Color(0xffb8a1ff),
      Colors.white,
    ];
    return List.generate(level.particles, (index) {
      final burst = index % level.bursts;
      final x = level.bursts == 1
          ? .5
          : .15 + .7 * (burst / (level.bursts - 1));
      final y = level.style == _FireworkStyle.comet
          ? .18
          : .10 + random.nextDouble() * .16;
      return _FireworkParticle(
        x,
        y,
        random.nextDouble() * math.pi * 2,
        .06 + random.nextDouble() * .17,
        (burst / level.bursts) * .44 + random.nextDouble() * .08,
        colors[random.nextInt(colors.length)],
      );
    });
  }
}

class _FireworkPainter extends CustomPainter {
  const _FireworkPainter(this.progress, this.style, this.particles)
    : super(repaint: progress);

  final Animation<double> progress;
  final _FireworkStyle style;
  final List<_FireworkParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == _FireworkStyle.comet) _paintComet(canvas, size);
    for (final particle in particles) {
      final time = ((progress.value - particle.delay) / (1 - particle.delay))
          .clamp(0.0, 1.0)
          .toDouble();
      if (time <= 0 || time >= 1) continue;
      final point = switch (style) {
        _FireworkStyle.heart => _heartPoint(particle, time, size),
        _FireworkStyle.waterfall => _waterfallPoint(particle, time, size),
        _FireworkStyle.ring => _ringPoint(particle, time, size),
        _FireworkStyle.finale => _finalePoint(particle, time, size),
        _ => _burstPoint(particle, time, size),
      };
      final paint = Paint()
        ..color = particle.color.withValues(alpha: (1 - time) * .95);
      canvas.drawCircle(point, 1.6 + (1 - time) * 2.2, paint);
    }
  }

  Offset _burstPoint(_FireworkParticle particle, double time, Size size) {
    final dx = math.cos(particle.angle) * particle.distance * size.width * time;
    final dy =
        math.sin(particle.angle) * particle.distance * size.width * time +
        size.height * .11 * time * time;
    return Offset(particle.x * size.width + dx, particle.y * size.height + dy);
  }

  Offset _heartPoint(_FireworkParticle particle, double time, Size size) {
    final angle = particle.angle;
    final scale = .0085 * size.width * time;
    final x = (16 * math.pow(math.sin(angle), 3) * scale).toDouble();
    final y =
        (-(13 * math.cos(angle) -
                    5 * math.cos(2 * angle) -
                    2 * math.cos(3 * angle) -
                    math.cos(4 * angle)) *
                scale)
            .toDouble();
    final centerX = particle.x < .5 ? size.width * .32 : size.width * .68;
    return Offset(
      centerX + x,
      size.height * .18 + y + size.height * .08 * time * time,
    );
  }

  Offset _waterfallPoint(_FireworkParticle particle, double time, Size size) {
    final dx =
        math.cos(particle.angle) * particle.distance * size.width * .4 * time;
    return Offset(
      particle.x * size.width + dx,
      size.height * (.20 + .62 * time * time),
    );
  }

  Offset _ringPoint(_FireworkParticle particle, double time, Size size) {
    final radius = (.045 + particle.distance * .9) * size.width * time;
    return Offset(
      size.width * .5 + math.cos(particle.angle) * radius,
      size.height * .18 + math.sin(particle.angle) * radius,
    );
  }

  Offset _finalePoint(_FireworkParticle particle, double time, Size size) {
    final point = _burstPoint(particle, time, size);
    final shimmer = math.sin((particle.angle + time * 18) * 2) * 3;
    return Offset(
      point.dx + shimmer,
      point.dy + size.height * .17 * time * time,
    );
  }

  void _paintComet(Canvas canvas, Size size) {
    final flight = (progress.value / .4).clamp(0.0, 1.0).toDouble();
    final start = Offset(size.width * .5, size.height * .88);
    final end = Offset(size.width * .5, size.height * .18);
    final head = Offset.lerp(start, end, flight)!;
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0x00ffd166), Color(0xffffd166)],
      ).createShader(Rect.fromPoints(start, head));
    canvas.drawLine(start, head, paint);
    canvas.drawCircle(head, 5, Paint()..color = const Color(0xfffff3bf));
  }

  @override
  bool shouldRepaint(_FireworkPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.particles != particles;
}
