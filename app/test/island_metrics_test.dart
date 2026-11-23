import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/src/domain/entities.dart';
import 'package:machine_info/src/domain/island.dart';

DiskInfo _disk(String mount, int total, int used, {DiskKind kind = DiskKind.fixed}) => DiskInfo(
      name: mount,
      mountPoint: mount,
      filesystem: 'apfs',
      kind: kind,
      totalBytes: total,
      freeBytes: total - used,
      usedBytes: used,
    );

HardwareSnapshot _snapshot({
  SectionResult<CpuInfo> cpu = const SectionResult(SectionStatus.unsupported, null),
  SectionResult<MemoryInfo> memory = const SectionResult(SectionStatus.unsupported, null),
  List<DiskInfo> disks = const [],
  List<TemperatureReading> temps = const [],
}) =>
    HardwareSnapshot(
      platform: 'test',
      collectedAt: DateTime(2026, 11, 23),
      os: const SectionResult(
        SectionStatus.ok,
        OsInfo(
          name: 'macOS',
          version: '26',
          kernel: 'Darwin',
          hostname: 'mac-mini',
          architecture: 'arm64',
          uptime: Duration(hours: 3),
        ),
      ),
      cpu: cpu,
      memory: memory,
      disks: SectionResult(SectionStatus.ok, disks),
      temperatures: SectionResult(SectionStatus.ok, temps),
    );

void main() {
  group('levelFor', () {
    test('classifies values against both thresholds', () {
      expect(levelFor(0.2, elevated: 0.6, critical: 0.85), MetricLevel.normal);
      expect(levelFor(0.6, elevated: 0.6, critical: 0.85), MetricLevel.elevated);
      expect(levelFor(0.9, elevated: 0.6, critical: 0.85), MetricLevel.critical);
      expect(levelFor(double.nan, elevated: 0.6, critical: 0.85), MetricLevel.normal);
    });
  });

  group('IslandMetrics.fromSnapshot', () {
    test('reads CPU, memory, system disk and hottest sensor', () {
      final metrics = IslandMetrics.fromSnapshot(_snapshot(
        cpu: const SectionResult(
          SectionStatus.ok,
          CpuInfo(
            model: 'M4',
            vendor: 'Apple',
            architecture: 'arm64',
            physicalCores: 10,
            logicalCores: 10,
            baseFrequencyMhz: 0,
            usagePercent: 42,
          ),
        ),
        memory: const SectionResult(
          SectionStatus.ok,
          MemoryInfo(totalBytes: 16, availableBytes: 4, usedBytes: 12, swapTotalBytes: 0, swapUsedBytes: 0),
        ),
        disks: [_disk('/Volumes/USB', 4000, 100, kind: DiskKind.removable), _disk('/', 1000, 250)],
        temps: const [
          TemperatureReading(label: 'SSD', source: 'smc', celsius: 38),
          TemperatureReading(label: 'CPU', source: 'smc', celsius: 61),
          TemperatureReading(label: 'Broken', source: 'smc', celsius: 400),
        ],
      ));

      expect(metrics.hostname, 'mac-mini');
      expect(metrics.cpuUsage, closeTo(0.42, 1e-9));
      expect(metrics.memoryRatio, closeTo(0.75, 1e-9));
      expect(metrics.diskRatio, closeTo(0.25, 1e-9));
      expect(metrics.hottestCelsius, 61);
      expect(metrics.hottestLabel, 'CPU');
      expect(metrics.uptime, const Duration(hours: 3));
      expect(metrics.isEmpty, isFalse);
    });

    test('leaves unsupported sections empty', () {
      final metrics = IslandMetrics.fromSnapshot(_snapshot());
      expect(metrics.cpuUsage, isNull);
      expect(metrics.memoryRatio, isNull);
      expect(metrics.diskRatio, isNull);
      expect(metrics.hottestCelsius, isNull);
      expect(metrics.isEmpty, isTrue);
    });
  });

  group('primaryDisk', () {
    test('falls back to the largest fixed disk without a system mount', () {
      final disk = primaryDisk([
        _disk('/data', 500, 10),
        _disk('/big', 2000, 10),
        _disk('/net', 9000, 10, kind: DiskKind.network),
      ]);
      expect(disk?.mountPoint, '/big');
    });

    test('recognises the Windows system drive', () {
      expect(primaryDisk([_disk(r'D:\', 9000, 1), _disk(r'C:\', 500, 1)])?.mountPoint, r'C:\');
    });

    test('returns null when nothing is usable', () {
      expect(primaryDisk([_disk('/', 0, 0)]), isNull);
    });
  });
}
