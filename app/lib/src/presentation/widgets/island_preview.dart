import 'package:flutter/material.dart';

import '../../application/island_payload.dart';
import '../../domain/entities.dart';
import '../../domain/island.dart';

/// Flutter replica of the collapsed Dynamic Island, used in Settings to show
/// what the island looks like with the current readings and choices. It is
/// also the only way to see the island on Windows and Linux.
class IslandPreview extends StatelessWidget {
  const IslandPreview({
    super.key,
    required this.metrics,
    required this.unit,
    required this.preferred,
    this.builder = const IslandPayloadBuilder(),
  });

  final IslandMetrics? metrics;
  final TemperatureUnit unit;
  final IslandPrimaryMetric preferred;
  final IslandPayloadBuilder builder;

  static const _notchWidth = 120.0;
  static const _height = 34.0;

  @override
  Widget build(BuildContext context) {
    final all = metrics == null ? const <IslandReading>[] : builder.readings(metrics!, unit);
    final left = builder.primary(all, preferred);
    final right = builder.secondary(all, left);
    return Semantics(
      label: 'Vista previa de la isla dinámica',
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Wing(reading: left),
            const SizedBox(width: _notchWidth),
            _Wing(reading: right, alignEnd: true),
          ],
        ),
      ),
    );
  }
}

Color islandAccent(MetricLevel level) => switch (level) {
      MetricLevel.normal => const Color(0xFF5CDB9E),
      MetricLevel.elevated => const Color(0xFFFFBD45),
      MetricLevel.critical => const Color(0xFFFF5C5C),
    };

IconData _icon(IslandPrimaryMetric metric) => switch (metric) {
      IslandPrimaryMetric.cpu => Icons.memory,
      IslandPrimaryMetric.memory => Icons.developer_board,
      IslandPrimaryMetric.temperature => Icons.thermostat,
      IslandPrimaryMetric.disk => Icons.storage,
    };

class _Wing extends StatelessWidget {
  const _Wing({required this.reading, this.alignEnd = false});

  final IslandReading? reading;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    if (r == null) {
      return const SizedBox(
        width: 64,
        child: Text('—', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
      );
    }
    final accent = islandAccent(r.level);
    return SizedBox(
      width: 64,
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: r.ratio.clamp(0.02, 1.0),
                strokeWidth: 2,
                color: accent,
                backgroundColor: Colors.white12,
              ),
              Icon(_icon(r.metric), size: 10, color: Colors.white70),
            ]),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              r.value,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: r.level == MetricLevel.normal ? Colors.white : accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
