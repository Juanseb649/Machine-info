import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

List<Color> heatRamp(GlassTokens tokens) => [tokens.info, tokens.success, tokens.warning, tokens.danger];

Color heatColor(GlassTokens tokens, double ratio) {
  final r = ratio.clamp(0.0, 1.0);
  final ramp = heatRamp(tokens);
  const stops = [0.0, 0.5, 0.75, 1.0];
  for (var i = 1; i < stops.length; i++) {
    if (r <= stops[i]) {
      final local = (r - stops[i - 1]) / (stops[i] - stops[i - 1]);
      return Color.lerp(ramp[i - 1], ramp[i], local)!;
    }
  }
  return ramp.last;
}

class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.ratio,
    required this.size,
    this.strokeWidth = 14,
    this.child,
    this.ticks = true,
    this.colors,
  });

  final double ratio;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final bool ticks;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: ratio.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ArcGaugePainter(
            ratio: value,
            strokeWidth: strokeWidth,
            track: tokens.track,
            colors: colors ?? heatRamp(tokens),
            tickColor: tokens.textTertiary,
            ticks: ticks,
            glow: heatColor(tokens, value),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  _ArcGaugePainter({
    required this.ratio,
    required this.strokeWidth,
    required this.track,
    required this.colors,
    required this.tickColor,
    required this.ticks,
    required this.glow,
  });

  static const _start = 3 * math.pi / 4;
  static const _sweep = 3 * math.pi / 2;
  static const _pad = 0.14;

  final double ratio;
  final double strokeWidth;
  final Color track;
  final List<Color> colors;
  final Color tickColor;
  final bool ticks;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2 - (ticks ? strokeWidth * 0.9 : 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    if (ticks) {
      final tickPaint = Paint()
        ..color = tickColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      const count = 40;
      for (var i = 0; i <= count; i++) {
        final angle = _start + _sweep * i / count;
        final major = i % 5 == 0;
        final outer = radius + strokeWidth * 0.5 + strokeWidth * 0.75;
        final inner = outer - (major ? strokeWidth * 0.55 : strokeWidth * 0.3);
        final dir = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(center + dir * inner, center + dir * outer, tickPaint);
      }
    }

    if (ratio <= 0) return;
    final sweep = _sweep * ratio;
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: _sweep + _pad,
      colors: colors,
      transform: const GradientRotation(_start - _pad),
    ).createShader(rect);

    canvas.drawArc(
      rect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 8
        ..strokeCap = StrokeCap.round
        ..shader = gradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawArc(
      rect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = gradient,
    );

    final endAngle = _start + sweep;
    final dot = center + Offset(math.cos(endAngle), math.sin(endAngle)) * radius;
    canvas.drawCircle(dot, strokeWidth * 0.9, Paint()..color = glow.withValues(alpha: 0.35));
    canvas.drawCircle(dot, strokeWidth * 0.42, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.ratio != ratio || old.track != track || old.glow != glow || old.tickColor != tickColor;
}

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.samples, required this.color, this.height = 36});

  final List<double> samples;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(List.of(samples), color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.samples, this.color);

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) {
      final y = size.height / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      );
      return;
    }
    var lo = samples.reduce(math.min);
    var hi = samples.reduce(math.max);
    if (hi - lo < 2) {
      lo -= 1;
      hi += 1;
    }
    final path = _smoothPath(samples, size, lo, hi);
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => true;
}

Path _smoothPath(List<double> samples, Size size, double lo, double hi, {double topPad = 2, double bottomPad = 2}) {
  final span = hi - lo;
  final usable = size.height - topPad - bottomPad;
  Offset point(int i) => Offset(
        size.width * i / (samples.length - 1),
        topPad + usable * (1 - (samples[i] - lo) / span),
      );
  final path = Path()..moveTo(point(0).dx, point(0).dy);
  for (var i = 1; i < samples.length; i++) {
    final prev = point(i - 1);
    final current = point(i);
    final midX = (prev.dx + current.dx) / 2;
    path.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
  }
  return path;
}

class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.samples,
    required this.color,
    required this.formatValue,
    this.threshold,
    this.height = 180,
  });

  final List<double> samples;
  final Color color;
  final String Function(double value) formatValue;
  final double? threshold;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _HistoryPainter(
          samples: List.of(samples),
          color: color,
          grid: tokens.track,
          label: tokens.textTertiary,
          danger: tokens.danger,
          threshold: threshold,
          formatValue: formatValue,
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.samples,
    required this.color,
    required this.grid,
    required this.label,
    required this.danger,
    required this.threshold,
    required this.formatValue,
  });

  final List<double> samples;
  final Color color;
  final Color grid;
  final Color label;
  final Color danger;
  final double? threshold;
  final String Function(double value) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    const labelWidth = 44.0;
    final chart = Rect.fromLTWH(labelWidth, 8, size.width - labelWidth, size.height - 16);

    var lo = samples.isEmpty ? 30.0 : samples.reduce(math.min) - 6;
    var hi = samples.isEmpty ? 80.0 : samples.reduce(math.max) + 6;
    final limit = threshold;
    if (limit != null && limit < hi + 15) hi = math.max(hi, limit + 4);
    lo = (lo / 10).floorToDouble() * 10;
    hi = (hi / 10).ceilToDouble() * 10;
    if (hi - lo < 20) hi = lo + 20;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final step = (hi - lo) > 60 ? 20.0 : 10.0;
    for (var v = lo; v <= hi + 0.01; v += step) {
      final y = chart.bottom - chart.height * (v - lo) / (hi - lo);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: formatValue(v), style: TextStyle(color: label, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 6);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (limit != null && limit > lo && limit < hi) {
      final y = chart.bottom - chart.height * (limit - lo) / (hi - lo);
      final dash = Paint()
        ..color = danger.withValues(alpha: 0.7)
        ..strokeWidth = 1.4;
      for (var x = chart.left; x < chart.right; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, chart.right), y), dash);
      }
    }

    if (samples.length < 2) return;
    canvas.save();
    canvas.translate(chart.left, chart.top);
    final area = Size(chart.width, chart.height);
    final path = _smoothPath(samples, area, lo, hi, topPad: 0, bottomPad: 0);
    final fill = Path.from(path)
      ..lineTo(area.width, area.height)
      ..lineTo(0, area.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & area),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    final last = Offset(area.width, area.height * (1 - (samples.last - lo) / (hi - lo)));
    canvas.drawCircle(last, 9, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(last, 4.5, Paint()..color = color);
    canvas.drawCircle(last, 2, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HistoryPainter old) => true;
}
