import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sections.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass.dart';

class OnboardingStep {
  const OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
    this.targets = const [],
    this.section,
    this.finalStep = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<GlobalKey> targets;
  final AppSection? section;
  final bool finalStep;
}

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({super.key, required this.steps, required this.onFinish, required this.onSectionChange});

  final List<OnboardingStep> steps;
  final VoidCallback onFinish;
  final ValueChanged<AppSection> onSectionChange;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> with SingleTickerProviderStateMixin {
  static const _cardWidth = 380.0;
  static const _cardHeight = 250.0;

  final _focus = FocusNode();
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
  int _index = 0;
  Rect? _target;

  OnboardingStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _measure();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0) return;
    if (index >= widget.steps.length) {
      _finish();
      return;
    }
    setState(() => _index = index);
    final section = widget.steps[index].section;
    if (section != null) widget.onSectionChange(section);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _finish() async {
    await _entrance.reverse();
    widget.onFinish();
  }

  void _measure() {
    if (!mounted) return;
    final overlayBox = context.findRenderObject() as RenderBox?;
    Rect? union;
    for (final key in _step.targets) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || overlayBox == null) continue;
      final rect = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
      union = union == null ? rect : union.expandToInclude(rect);
    }
    if (union != _target) setState(() => _target = union);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _go(_index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _go(_index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _finish();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
            final hole = _step.targets.isEmpty || _target == null ? null : _target!.inflate(8);
            final card = _cardRect(size, hole);
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _go(_index + 1),
                    child: TweenAnimationBuilder<Rect?>(
                      tween: RectTween(end: hole ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeInOutCubic,
                      builder: (context, rect, _) => CustomPaint(
                        size: size,
                        painter: _SpotlightPainter(
                          hole: rect,
                          scrim: tokens.scrim,
                          glow: tokens.accent,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  left: card.left,
                  top: card.top,
                  width: card.width,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.94, end: 1.0)
                        .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack)),
                    child: _StepCard(
                      step: _step,
                      index: _index,
                      total: widget.steps.length,
                      onNext: () => _go(_index + 1),
                      onBack: _index == 0 ? null : () => _go(_index - 1),
                      onSkip: _finish,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Rect _cardRect(Size size, Rect? hole) {
    final maxWidth = math.max(240.0, size.width - 32);
    final width = math.min(_cardWidth, maxWidth);
    if (hole == null) {
      final w = math.min(_cardWidth + 60, maxWidth);
      return Rect.fromLTWH((size.width - w) / 2, math.max(16.0, (size.height - _cardHeight) / 2), w, _cardHeight);
    }
    double clampTop(double top) => math.max(16.0, math.min(top, size.height - _cardHeight - 16));
    double clampLeft(double left) => math.max(16.0, math.min(left, size.width - width - 16));

    if (hole.right + 24 + width <= size.width - 16) {
      return Rect.fromLTWH(hole.right + 24, clampTop(hole.center.dy - _cardHeight / 2), width, _cardHeight);
    }
    if (hole.bottom + 24 + _cardHeight <= size.height - 16) {
      return Rect.fromLTWH(clampLeft(hole.right - width), hole.bottom + 20, width, _cardHeight);
    }
    if (hole.left - 24 - width >= 16) {
      return Rect.fromLTWH(hole.left - 24 - width, clampTop(hole.center.dy - _cardHeight / 2), width, _cardHeight);
    }
    return Rect.fromLTWH(clampLeft(hole.center.dx - width / 2), clampTop(hole.top - _cardHeight - 20), width, _cardHeight);
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.scrim, required this.glow});

  final Rect? hole;
  final Color scrim;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final rect = hole;
    if (rect == null || rect.width < 1) {
      canvas.drawPath(full, Paint()..color = scrim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final cutout = Path.combine(PathOperation.difference, full, Path()..addRRect(rrect));
    canvas.drawPath(cutout, Paint()..color = scrim);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = glow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = glow,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole || old.scrim != scrim || old.glow != glow;
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final OnboardingStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    return GlassPanel(
      strong: true,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: SizedBox(
        height: 250 - 38,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Column(
            key: ValueKey(index),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GlassIconBadge(icon: step.icon, size: 38),
                  const Spacer(),
                  for (var i = 0; i < total; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(left: 5),
                      width: i == index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == index ? tokens.accent : tokens.track,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(step.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  step.body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary, height: 1.4),
                  overflow: TextOverflow.fade,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${index + 1} de $total',
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!step.finalStep)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: onSkip,
                      child: Text('Omitir', style: TextStyle(color: tokens.textSecondary)),
                    ),
                  if (onBack != null && !step.finalStep)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Anterior',
                      onPressed: onBack,
                      icon: Icon(Icons.chevron_left, color: tokens.textSecondary),
                    ),
                  const SizedBox(width: 4),
                  GlassButton(
                    label: step.finalStep ? 'Comenzar' : (index == 0 ? 'Empezar' : 'Siguiente'),
                    icon: step.finalStep ? Icons.check : null,
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
