import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/inventory_controller.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.controller,
    required this.child,
    this.minDuration = const Duration(milliseconds: 1600),
    this.maxDuration = const Duration(seconds: 12),
  });

  final InventoryController controller;
  final Widget child;
  final Duration minDuration;
  final Duration maxDuration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _minTimer;
  Timer? _maxTimer;
  bool _minElapsed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
    _minTimer = Timer(widget.minDuration, () {
      _minElapsed = true;
      _check();
    });
    _maxTimer = Timer(widget.maxDuration, _finish);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    _minTimer?.cancel();
    _maxTimer?.cancel();
    super.dispose();
  }

  void _check() {
    if (_done || !_minElapsed) return;
    final hardware = widget.controller.hardware;
    if (hardware.value != null || hardware.error != null) _finish();
  }

  void _finish() {
    if (_done || !mounted) return;
    _minTimer?.cancel();
    _maxTimer?.cancel();
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: _done
          ? KeyedSubtree(key: const ValueKey('home'), child: widget.child)
          : SplashScreen(key: const ValueKey('splash'), controller: widget.controller),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller});

  final InventoryController controller;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _introCurve = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
  late final Animation<double> _textCurve =
      CurvedAnimation(parent: _intro, curve: const Interval(0.35, 1, curve: Curves.easeOutCubic));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
      _intro.value = 1;
    } else {
      if (!_float.isAnimating) _float.repeat(reverse: true);
      if (_intro.value == 0) _intro.forward();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _intro.dispose();
    super.dispose();
  }

  String _status() {
    final hardware = widget.controller.hardware;
    if (hardware.error != null) return 'No se pudo leer el hardware';
    if (hardware.value != null) return 'Listo';
    return 'Leyendo hardware y software…';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final intro = _introCurve;
    final textIntro = _textCurve;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: intro,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1).animate(intro),
                  child: _FloatingMascot(animation: _float, tokens: tokens),
                ),
              ),
              const SizedBox(height: 40),
              FadeTransition(
                opacity: textIntro,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(textIntro),
                  child: Column(
                    children: [
                      Image.asset(
                        dark ? 'assets/branding/wordmark_dark.png' : 'assets/branding/wordmark_light.png',
                        width: 340,
                        filterQuality: FilterQuality.medium,
                        semanticLabel: 'Machine Info',
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Hardware y software, de un vistazo.',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['Consolas', 'Menlo', 'DejaVu Sans Mono'],
                          fontSize: 15,
                          letterSpacing: 0.2,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 44),
                      SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            color: tokens.accent,
                            backgroundColor: tokens.track,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) => Text(
                          _status(),
                          style: TextStyle(fontSize: 12.5, color: tokens.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingMascot extends StatelessWidget {
  const _FloatingMascot({required this.animation, required this.tokens});

  final Animation<double> animation;
  final GlassTokens tokens;

  static const _size = 170.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size * 2,
      height: _size * 1.55,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(animation.value);
          final glow = 0.75 + 0.25 * math.sin(t * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              _Glow(offset: const Offset(-58, -10), color: const Color(0xFF2E8C80), opacity: 0.38 * glow),
              _Glow(offset: const Offset(62, 26), color: const Color(0xFFE3A23B), opacity: 0.30 * glow),
              Positioned(
                bottom: 6 + 4 * t,
                child: Container(
                  width: _size * 0.62 - 10 * t,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: tokens.shadow, blurRadius: 18, spreadRadius: 2)],
                  ),
                ),
              ),
              Transform.translate(offset: Offset(0, -8 * t), child: child),
            ],
          );
        },
        child: Image.asset(
          'assets/branding/mascot.png',
          height: _size * 1.2,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Logo de Machine Info',
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.offset, required this.color, required this.opacity});

  final Offset offset;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 190,
        height: 190,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
