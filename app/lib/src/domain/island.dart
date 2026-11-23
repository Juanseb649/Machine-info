/// Severity of a live reading, used to tint the Dynamic Island.
enum MetricLevel { normal, elevated, critical }

/// Classifies [value] against two thresholds. Values at or above [critical]
/// are critical, at or above [elevated] are elevated, the rest are normal.
MetricLevel levelFor(double value, {required double elevated, required double critical}) {
  if (value.isNaN) return MetricLevel.normal;
  if (value >= critical) return MetricLevel.critical;
  if (value >= elevated) return MetricLevel.elevated;
  return MetricLevel.normal;
}

/// Thresholds shared by the Flutter preview and the native island.
abstract final class IslandThresholds {
  static const cpuElevated = 0.60;
  static const cpuCritical = 0.85;
  static const memoryElevated = 0.75;
  static const memoryCritical = 0.90;
  static const diskElevated = 0.80;
  static const diskCritical = 0.92;
  static const temperatureElevated = 75.0;
  static const temperatureCritical = 90.0;
}

/// The handful of live readings the Dynamic Island shows while the main
/// window is minimized. Every field is optional because each section of the
/// hardware report can be unsupported on a given platform.
class IslandMetrics {
  const IslandMetrics({
    required this.collectedAt,
    this.hostname = '',
    this.cpuUsage,
    this.memoryUsedBytes,
    this.memoryTotalBytes,
    this.diskUsedBytes,
    this.diskTotalBytes,
    this.hottestCelsius,
    this.hottestLabel = '',
    this.uptime,
  });

  final DateTime collectedAt;
  final String hostname;

  /// CPU usage between 0 and 1.
  final double? cpuUsage;
  final int? memoryUsedBytes;
  final int? memoryTotalBytes;
  final int? diskUsedBytes;
  final int? diskTotalBytes;
  final double? hottestCelsius;
  final String hottestLabel;
  final Duration? uptime;

  double? get memoryRatio => _ratio(memoryUsedBytes, memoryTotalBytes);
  double? get diskRatio => _ratio(diskUsedBytes, diskTotalBytes);

  bool get isEmpty =>
      cpuUsage == null && memoryRatio == null && diskRatio == null && hottestCelsius == null;

  static double? _ratio(int? used, int? total) {
    if (used == null || total == null || total <= 0) return null;
    return (used / total).clamp(0.0, 1.0);
  }
}
