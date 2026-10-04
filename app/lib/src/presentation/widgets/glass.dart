import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

class LiquidBackground extends StatelessWidget {
  const LiquidBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _BlobPainter(tokens: context.glass))),
        child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.tokens});

  final GlassTokens tokens;

  static const _anchors = [Offset(0.16, 0.20), Offset(0.84, 0.28), Offset(0.56, 0.90)];
  static const _radii = [0.42, 0.36, 0.40];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.backgroundTop, tokens.backgroundBottom],
        ).createShader(rect),
    );

    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    for (var i = 0; i < tokens.blobs.length && i < _anchors.length; i++) {
      final center = Offset(_anchors[i].dx * size.width, _anchors[i].dy * size.height);
      final radius = _radii[i] * diag;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [tokens.blobs[i], tokens.blobs[i].withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) => oldDelegate.tokens != tokens;
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.blur = true,
    this.strong = false,
    this.tint,
    this.onTap,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final bool strong;
  final Color? tint;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final borderRadius = BorderRadius.circular(radius);
    final fill = strong ? tokens.glassFillStrong : tokens.glassFill;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tokens.glassEdgeDark, fill),
            fill,
            if (tint != null) Color.alphaBlend(tint!.withValues(alpha: 0.10), fill) else fill,
          ],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _GlassEdgePainter(radius: radius, light: tokens.glassEdgeLight, dark: tokens.glassEdgeDark),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap != null) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          hoverColor: tokens.accentSoft.withValues(alpha: 0.08),
          splashColor: tokens.accentSoft,
          child: surface,
        ),
      );
    }

    Widget clipped = ClipRRect(
      borderRadius: borderRadius,
      child: blur ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: surface) : surface,
    );

    if (shadow) {
      clipped = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [BoxShadow(color: tokens.shadow, blurRadius: 30, offset: const Offset(0, 12), spreadRadius: -6)],
        ),
        child: clipped,
      );
    }
    return clipped;
  }
}

class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({required this.radius, required this.light, required this.dark});

  final double radius;
  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark, dark, light.withValues(alpha: light.a * 0.5)],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) => old.light != light || old.dark != dark || old.radius != radius;
}

class GlassIconBadge extends StatelessWidget {
  const GlassIconBadge({super.key, required this.icon, this.color, this.size = 36});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final base = color ?? tokens.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.withValues(alpha: 0.95), Color.lerp(base, Colors.black, 0.18)!],
        ),
        boxShadow: [BoxShadow(color: base.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, size: size * 0.55, color: onColor(base)),
    );
  }
}

class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.label, this.icon, this.color, this.selected = false, this.onTap});

  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final accent = color ?? tokens.accent;
    final foreground = selected ? onColor(accent) : (color ?? tokens.textSecondary);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? accent : (color != null ? accent.withValues(alpha: 0.12) : tokens.glassFill),
            border: Border.all(color: selected ? Colors.transparent : tokens.glassEdgeLight.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: foreground), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final base = color ?? tokens.accent;
    final enabled = onPressed != null;
    final foreground = filled ? onColor(base) : base;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: filled
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(base, Colors.white, 0.12)!, base],
                    )
                  : null,
              color: filled ? null : base.withValues(alpha: 0.10),
              border: Border.all(color: filled ? Colors.white.withValues(alpha: 0.25) : base.withValues(alpha: 0.25)),
              boxShadow: filled && enabled
                  ? [BoxShadow(color: base.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: foreground), const SizedBox(width: 8)],
                Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassSegment<T> {
  const GlassSegment(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({super.key, required this.segments, required this.value, required this.onChanged});

  final List<GlassSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final index = segments.indexWhere((s) => s.value == value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.track,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth.isFinite ? constraints.maxWidth / segments.length : 120.0;
          return SizedBox(
            width: segmentWidth * segments.length,
            height: 36,
            child: Stack(
              children: [
                if (index >= 0)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: segmentWidth * index,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.glassFillStrong,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.glassEdgeLight),
                        boxShadow: [BoxShadow(color: tokens.shadow, blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (final segment in segments)
                      SizedBox(
                        width: segmentWidth,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: onChanged == null ? null : () => onChanged!(segment.value),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (segment.icon != null) ...[
                                  Icon(segment.icon, size: 16, color: _fg(tokens, segment)),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    segment.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _fg(tokens, segment),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _fg(GlassTokens tokens, GlassSegment<T> segment) =>
      segment.value == value ? tokens.textPrimary : tokens.textSecondary;
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.child});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.glassFill,
              border: Border.all(color: tokens.glassEdgeLight.withValues(alpha: 0.7)),
            ),
            child: Center(child: child ?? Icon(icon, size: 20, color: tokens.textPrimary)),
          ),
        ),
      ),
    );
  }
}
