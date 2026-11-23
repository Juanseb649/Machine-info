import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/src/application/island_payload.dart';
import 'package:machine_info/src/domain/entities.dart';
import 'package:machine_info/src/domain/island.dart';

const _gb = 1024 * 1024 * 1024;

IslandMetrics _metrics({double? cpu = 0.3, double? celsius = 92}) => IslandMetrics(
      collectedAt: DateTime(2026, 11, 23, 9, 5, 7),
      hostname: 'mac-mini',
      cpuUsage: cpu,
      memoryUsedBytes: 8 * _gb,
      memoryTotalBytes: 16 * _gb,
      diskUsedBytes: 100 * _gb,
      diskTotalBytes: 500 * _gb,
      hottestCelsius: celsius,
      hottestLabel: 'CPU die',
      uptime: const Duration(hours: 2, minutes: 4),
    );

void main() {
  const builder = IslandPayloadBuilder();

  test('formats every available reading in a stable order', () {
    final readings = builder.readings(_metrics(), TemperatureUnit.celsius);
    expect(readings.map((r) => r.metric), [
      IslandPrimaryMetric.cpu,
      IslandPrimaryMetric.memory,
      IslandPrimaryMetric.temperature,
      IslandPrimaryMetric.disk,
    ]);
    expect(readings[0].value, '30%');
    expect(readings[1].detail, '8.0 GB de 16.0 GB');
    expect(readings[2].value, '92°C');
    expect(readings[2].level, MetricLevel.critical);
    expect(readings[3].detail, '400.0 GB libres');
  });

  test('uses Fahrenheit when the person prefers it', () {
    final temp = builder
        .readings(_metrics(celsius: 50), TemperatureUnit.fahrenheit)
        .firstWhere((r) => r.metric == IslandPrimaryMetric.temperature);
    expect(temp.value, '122°F');
  });

  test('puts the chosen metric left and the most urgent one right', () {
    final payload = builder.build(_metrics(),
        unit: TemperatureUnit.celsius, preferred: IslandPrimaryMetric.memory);
    expect((payload['primary'] as Map)['key'], 'memory');
    expect((payload['secondary'] as Map)['key'], 'temperature');
    expect(payload['level'], 'critical');
    expect(payload['updatedAt'], '09:05:07');
    expect(payload['uptime'], '2h 4m');
    expect((payload['readings'] as List).length, 4);
  });

  test('falls back to the first reading when the preferred one is missing', () {
    final payload = builder.build(_metrics(cpu: null, celsius: null),
        unit: TemperatureUnit.celsius, preferred: IslandPrimaryMetric.cpu);
    expect((payload['primary'] as Map)['key'], 'memory');
    expect((payload['secondary'] as Map)['key'], 'disk');
    expect(payload['level'], 'normal');
  });

  test('sends empty slots when nothing could be read', () {
    final payload = builder.build(IslandMetrics(collectedAt: DateTime(2026)),
        unit: TemperatureUnit.celsius, preferred: IslandPrimaryMetric.cpu);
    expect(payload['primary'], isNull);
    expect(payload['secondary'], isNull);
    expect(payload['readings'], isEmpty);
  });
}
