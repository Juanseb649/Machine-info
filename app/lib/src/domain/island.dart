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
