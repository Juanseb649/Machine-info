import '../domain/entities.dart';
import '../domain/island.dart';
import '../presentation/formatters.dart';

/// One formatted reading, ready to be drawn by any island renderer.
class IslandReading {
  const IslandReading({
    required this.metric,
    required this.label,
    required this.value,
    required this.detail,
    required this.ratio,
    required this.level,
    required this.symbol,
  });

  final IslandPrimaryMetric metric;
  final String label;
  final String value;
  final String detail;

  /// Fill of the ring, between 0 and 1.
  final double ratio;
  final MetricLevel level;

  /// SF Symbol name used by the native macOS island.
  final String symbol;

  Map<String, Object?> toMap() => {
        'key': metric.name,
        'label': label,
        'value': value,
        'detail': detail,
        'ratio': ratio,
        'level': level.name,
        'symbol': symbol,
      };
}

/// Turns raw [IslandMetrics] into the strings and levels the island shows.
/// Keeping the formatting here lets the native side stay a dumb renderer and
/// keeps units and wording identical to the rest of the app.
class IslandPayloadBuilder {
  const IslandPayloadBuilder();

  List<IslandReading> readings(IslandMetrics m, TemperatureUnit unit) => [
        if (m.cpuUsage case final cpu?)
          IslandReading(
            metric: IslandPrimaryMetric.cpu,
            label: 'CPU',
            value: '${(cpu * 100).round()}%',
            detail: 'Carga total',
            ratio: cpu,
            level: levelFor(cpu,
                elevated: IslandThresholds.cpuElevated, critical: IslandThresholds.cpuCritical),
            symbol: 'cpu',
          ),
        if (m.memoryRatio case final ram?)
          IslandReading(
            metric: IslandPrimaryMetric.memory,
            label: 'RAM',
            value: '${(ram * 100).round()}%',
            detail: '${formatBytes(m.memoryUsedBytes!)} de ${formatBytes(m.memoryTotalBytes!)}',
            ratio: ram,
            level: levelFor(ram,
                elevated: IslandThresholds.memoryElevated, critical: IslandThresholds.memoryCritical),
            symbol: 'memorychip',
          ),
        if (m.hottestCelsius case final celsius?)
          IslandReading(
            metric: IslandPrimaryMetric.temperature,
            label: 'Temp',
            value: formatTemperature(celsius, unit),
            detail: m.hottestLabel.isEmpty ? 'Sensor más caliente' : m.hottestLabel,
            ratio: (celsius / 100).clamp(0.0, 1.0),
            level: levelFor(celsius,
                elevated: IslandThresholds.temperatureElevated,
                critical: IslandThresholds.temperatureCritical),
            symbol: 'thermometer.medium',
          ),
        if (m.diskRatio case final disk?)
          IslandReading(
            metric: IslandPrimaryMetric.disk,
            label: 'Disco',
            value: '${(disk * 100).round()}%',
            detail: '${formatBytes(m.diskTotalBytes! - m.diskUsedBytes!)} libres',
            ratio: disk,
            level: levelFor(disk,
                elevated: IslandThresholds.diskElevated, critical: IslandThresholds.diskCritical),
            symbol: 'internaldrive',
          ),
      ];

  /// The reading shown on the left of the camera: the one the person chose,
  /// or the first available one when that section is unsupported.
  IslandReading? primary(List<IslandReading> all, IslandPrimaryMetric preferred) {
    if (all.isEmpty) return null;
    for (final r in all) {
      if (r.metric == preferred) return r;
    }
    return all.first;
  }

  /// The reading shown on the right of the camera: the most urgent of the
  /// others, so a hot sensor or full disk surfaces without opening the island.
  IslandReading? secondary(List<IslandReading> all, IslandReading? primary) {
    IslandReading? best;
    for (final r in all) {
      if (identical(r, primary)) continue;
      if (best == null || r.level.index > best.level.index) best = r;
    }
    return best;
  }

  Map<String, Object?> build(
    IslandMetrics metrics, {
    required TemperatureUnit unit,
    required IslandPrimaryMetric preferred,
  }) {
    final all = readings(metrics, unit);
    final left = primary(all, preferred);
    final right = secondary(all, left);
    final worst = all.fold<MetricLevel>(
        MetricLevel.normal, (acc, r) => r.level.index > acc.index ? r.level : acc);
    return {
      'title': 'Machine Info',
      'hostname': metrics.hostname,
      'uptime': metrics.uptime == null ? '' : formatDuration(metrics.uptime!),
      'updatedAt': _clock(metrics.collectedAt),
      'level': worst.name,
      'primary': left?.toMap(),
      'secondary': right?.toMap(),
      'readings': [for (final r in all) r.toMap()],
    };
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
