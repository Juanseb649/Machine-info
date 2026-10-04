enum SectionStatus { ok, unsupported, permissionDenied, error }

class SectionResult<T> {
  const SectionResult(this.status, this.data);

  final SectionStatus status;
  final T? data;

  bool get hasData => data != null;
}

class OsInfo {
  const OsInfo({
    required this.name,
    required this.version,
    required this.kernel,
    required this.hostname,
    required this.architecture,
    required this.uptime,
  });

  final String name;
  final String version;
  final String kernel;
  final String hostname;
  final String architecture;
  final Duration uptime;
}

class CpuInfo {
  const CpuInfo({
    required this.model,
    required this.vendor,
    required this.architecture,
    required this.physicalCores,
    required this.logicalCores,
    required this.baseFrequencyMhz,
    required this.usagePercent,
  });

  final String model;
  final String vendor;
  final String architecture;
  final int physicalCores;
  final int logicalCores;
  final double baseFrequencyMhz;
  final double usagePercent;
}

class MemoryInfo {
  const MemoryInfo({
    required this.totalBytes,
    required this.availableBytes,
    required this.usedBytes,
    required this.swapTotalBytes,
    required this.swapUsedBytes,
  });

  final int totalBytes;
  final int availableBytes;
  final int usedBytes;
  final int swapTotalBytes;
  final int swapUsedBytes;

  double get usedRatio => totalBytes == 0 ? 0 : usedBytes / totalBytes;
  double get swapRatio => swapTotalBytes == 0 ? 0 : swapUsedBytes / swapTotalBytes;
}

enum DiskKind { fixed, removable, network, optical, ram, unknown }

class DiskInfo {
  const DiskInfo({
    required this.name,
    required this.mountPoint,
    required this.filesystem,
    required this.kind,
    required this.totalBytes,
    required this.freeBytes,
    required this.usedBytes,
  });

  final String name;
  final String mountPoint;
  final String filesystem;
  final DiskKind kind;
  final int totalBytes;
  final int freeBytes;
  final int usedBytes;

  double get usedRatio => totalBytes == 0 ? 0 : usedBytes / totalBytes;
}

class TemperatureReading {
  const TemperatureReading({
    required this.label,
    required this.source,
    required this.celsius,
    this.criticalCelsius,
  });

  final String label;
  final String source;
  final double celsius;
  final double? criticalCelsius;
}

class InstalledPackage {
  const InstalledPackage({
    required this.name,
    required this.version,
    required this.publisher,
    required this.source,
    this.installLocation = '',
    this.iconPath = '',
    this.uninstallCommand = '',
    this.installDate = '',
    this.sizeBytes = 0,
  });

  final String name;
  final String version;
  final String publisher;
  final String source;
  final String installLocation;
  final String iconPath;
  final String uninstallCommand;
  final String installDate;
  final int sizeBytes;

  String get id => '$source|$name|$version';
  bool get canUninstall => uninstallCommand.isNotEmpty;
  bool get hasIcon => iconPath.isNotEmpty;
}

class AppTechnology {
  const AppTechnology({required this.language, required this.framework, this.evidence = const []});

  static const unknown = AppTechnology(language: 'No determinado', framework: '');

  final String language;
  final String framework;
  final List<String> evidence;

  bool get isKnown => language != unknown.language;
}

enum UninstallOutcome { launched, completed, cancelled, unsupported, failed }

class UninstallResult {
  const UninstallResult(this.outcome, [this.message = '']);

  final UninstallOutcome outcome;
  final String message;
}

enum ThemePreference { automatic, light, dark }

enum AutoThemeSource { system, schedule }

enum TemperatureUnit { celsius, fahrenheit }

class AppSettings {
  const AppSettings({
    this.themePreference = ThemePreference.automatic,
    this.autoThemeSource = AutoThemeSource.system,
    this.dayStartHour = 7,
    this.nightStartHour = 19,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.onboardingCompleted = false,
  });

  final ThemePreference themePreference;
  final AutoThemeSource autoThemeSource;
  final int dayStartHour;
  final int nightStartHour;
  final TemperatureUnit temperatureUnit;
  final bool onboardingCompleted;

  AppSettings copyWith({
    ThemePreference? themePreference,
    AutoThemeSource? autoThemeSource,
    int? dayStartHour,
    int? nightStartHour,
    TemperatureUnit? temperatureUnit,
    bool? onboardingCompleted,
  }) =>
      AppSettings(
        themePreference: themePreference ?? this.themePreference,
        autoThemeSource: autoThemeSource ?? this.autoThemeSource,
        dayStartHour: dayStartHour ?? this.dayStartHour,
        nightStartHour: nightStartHour ?? this.nightStartHour,
        temperatureUnit: temperatureUnit ?? this.temperatureUnit,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );
}

class HardwareSnapshot {
  const HardwareSnapshot({
    required this.platform,
    required this.collectedAt,
    required this.os,
    required this.cpu,
    required this.memory,
    required this.disks,
    required this.temperatures,
  });

  final String platform;
  final DateTime collectedAt;
  final SectionResult<OsInfo> os;
  final SectionResult<CpuInfo> cpu;
  final SectionResult<MemoryInfo> memory;
  final SectionResult<List<DiskInfo>> disks;
  final SectionResult<List<TemperatureReading>> temperatures;
}
