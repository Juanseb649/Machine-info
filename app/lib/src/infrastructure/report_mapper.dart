import '../domain/entities.dart';

class ReportMapper {
  const ReportMapper();

  HardwareSnapshot hardware(Map<String, dynamic> json) {
    _ensureNoError(json);
    return HardwareSnapshot(
      platform: json['platform'] as String? ?? 'unknown',
      collectedAt: DateTime.fromMillisecondsSinceEpoch(_int(json['generatedAt']) * 1000),
      os: _section(json['os'], (d) => _os(d as Map<String, dynamic>)),
      cpu: _section(json['cpu'], (d) => _cpu(d as Map<String, dynamic>)),
      memory: _section(json['memory'], (d) => _memory(d as Map<String, dynamic>)),
      disks: _section(json['disks'], (d) => (d as List).cast<Map<String, dynamic>>().map(_disk).toList()),
      temperatures: _section(
        json['temperatures'],
        (d) => (d as List).cast<Map<String, dynamic>>().map(_temperature).toList(),
      ),
    );
  }

  SectionResult<List<InstalledPackage>> software(Map<String, dynamic> json) {
    _ensureNoError(json);
    return _section(
      json['software'],
      (d) => (d as List).cast<Map<String, dynamic>>().map(_package).toList(),
    );
  }

  void _ensureNoError(Map<String, dynamic> json) {
    final error = json['error'];
    if (error != null) throw StateError('machineinfo: $error');
  }

  SectionResult<T> _section<T>(Object? raw, T Function(Object data) map) {
    if (raw is! Map<String, dynamic>) return SectionResult<T>(SectionStatus.error, null);
    final status = _status(raw['status'] as String?);
    final data = raw['data'];
    return SectionResult(status, data == null ? null : map(data));
  }

  SectionStatus _status(String? value) => switch (value) {
        'ok' => SectionStatus.ok,
        'unsupported' => SectionStatus.unsupported,
        'permission_denied' => SectionStatus.permissionDenied,
        _ => SectionStatus.error,
      };

  OsInfo _os(Map<String, dynamic> d) => OsInfo(
        name: _str(d['name']),
        version: _str(d['version']),
        kernel: _str(d['kernel']),
        hostname: _str(d['hostname']),
        architecture: _str(d['architecture']),
        uptime: Duration(seconds: _int(d['uptimeSeconds'])),
      );

  CpuInfo _cpu(Map<String, dynamic> d) => CpuInfo(
        model: _str(d['model']),
        vendor: _str(d['vendor']),
        architecture: _str(d['architecture']),
        physicalCores: _int(d['physicalCores']),
        logicalCores: _int(d['logicalCores']),
        baseFrequencyMhz: _double(d['baseFrequencyMhz']),
        usagePercent: _double(d['usagePercent']),
      );

  MemoryInfo _memory(Map<String, dynamic> d) => MemoryInfo(
        totalBytes: _int(d['totalBytes']),
        availableBytes: _int(d['availableBytes']),
        usedBytes: _int(d['usedBytes']),
        swapTotalBytes: _int(d['swapTotalBytes']),
        swapUsedBytes: _int(d['swapUsedBytes']),
      );

  DiskInfo _disk(Map<String, dynamic> d) => DiskInfo(
        name: _str(d['name']),
        mountPoint: _str(d['mountPoint']),
        filesystem: _str(d['filesystem']),
        kind: DiskKind.values.firstWhere((k) => k.name == d['kind'], orElse: () => DiskKind.unknown),
        totalBytes: _int(d['totalBytes']),
        freeBytes: _int(d['freeBytes']),
        usedBytes: _int(d['usedBytes']),
      );

  TemperatureReading _temperature(Map<String, dynamic> d) => TemperatureReading(
        label: _str(d['label']),
        source: _str(d['source']),
        celsius: _double(d['celsius']),
        criticalCelsius: d['criticalCelsius'] == null ? null : _double(d['criticalCelsius']),
      );

  InstalledPackage _package(Map<String, dynamic> d) => InstalledPackage(
        name: _str(d['name']),
        version: _str(d['version']),
        publisher: _str(d['publisher']),
        source: _str(d['source']),
      );

  String _str(Object? v) => v as String? ?? '';
  int _int(Object? v) => (v as num?)?.toInt() ?? 0;
  double _double(Object? v) => (v as num?)?.toDouble() ?? 0;
}
