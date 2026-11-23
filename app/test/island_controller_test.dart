import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/src/application/island_controller.dart';
import 'package:machine_info/src/application/settings_controller.dart';
import 'package:machine_info/src/domain/entities.dart';
import 'package:machine_info/src/domain/island_host.dart';
import 'package:machine_info/src/domain/machine_info_repository.dart';
import 'package:machine_info/src/domain/settings_repository.dart';

class FakeIslandHost implements IslandHost {
  FakeIslandHost({this.supported = true});

  final bool supported;
  final _events = StreamController<IslandEvent>.broadcast();
  final List<String> calls = [];
  final List<Map<String, Object?>> payloads = [];

  void emit(IslandEvent event) => _events.add(event);

  @override
  Stream<IslandEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> update(Map<String, Object?> payload) async => payloads.add(payload);
}

class _Settings implements SettingsRepository {
  AppSettings value = const AppSettings();

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

class _Hardware implements MachineInfoRepository {
  int loads = 0;
  double cpu = 40;

  @override
  Future<HardwareSnapshot> loadHardware() async {
    loads++;
    return HardwareSnapshot(
      platform: 'test',
      collectedAt: DateTime(2026, 11, 23),
      os: const SectionResult(SectionStatus.unsupported, null),
      cpu: SectionResult(
        SectionStatus.ok,
        CpuInfo(
          model: 'M',
          vendor: 'A',
          architecture: 'arm64',
          physicalCores: 8,
          logicalCores: 8,
          baseFrequencyMhz: 0,
          usagePercent: cpu,
        ),
      ),
      memory: const SectionResult(SectionStatus.unsupported, null),
      disks: const SectionResult(SectionStatus.ok, []),
      temperatures: const SectionResult(SectionStatus.ok, []),
    );
  }

  @override
  Future<SectionResult<List<InstalledPackage>>> loadSoftware() async =>
      const SectionResult(SectionStatus.ok, []);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeIslandHost host;
  late SettingsController settings;
  late _Hardware hardware;
  late IslandController controller;

  Future<void> setUpWith({bool supported = true}) async {
    host = FakeIslandHost(supported: supported);
    settings = SettingsController(_Settings());
    await settings.load();
    hardware = _Hardware();
    controller = IslandController(host: host, settings: settings, repository: hardware);
    await controller.start();
  }

  tearDown(() {
    controller.dispose();
    settings.dispose();
  });

  test('shows on minimize with fresh readings and hides on restore', () async {
    await setUpWith();
    host.emit(IslandEvent.windowMinimized);
    await _settle();
    await _settle();

    expect(controller.visible, isTrue);
    expect(host.calls, ['show']);
    expect(hardware.loads, 1);
    expect((host.payloads.last['primary'] as Map)['value'], '40%');

    host.emit(IslandEvent.windowRestored);
    await _settle();
    expect(controller.visible, isFalse);
    expect(host.calls, ['show', 'hide']);
  });

  test('stays hidden when the platform cannot draw it', () async {
    await setUpWith(supported: false);
    host.emit(IslandEvent.windowMinimized);
    await _settle();
    expect(controller.supported, isFalse);
    expect(host.calls, isEmpty);
  });

  test('respects the setting and the dismiss action', () async {
    await setUpWith();
    await settings.setIslandEnabled(false);
    host.emit(IslandEvent.windowMinimized);
    await _settle();
    expect(host.calls, isEmpty);

    await settings.setIslandEnabled(true);
    await _settle();
    expect(host.calls, ['show']);

    host.emit(IslandEvent.islandDismissed);
    await _settle();
    expect(host.calls, ['show', 'hide']);

    host.emit(IslandEvent.windowRestored);
    host.emit(IslandEvent.windowMinimized);
    await _settle();
    expect(host.calls, ['show', 'hide', 'show']);
  });

  test('re-sends readings when the preferred metric changes', () async {
    await setUpWith();
    host.emit(IslandEvent.windowMinimized);
    await _settle();
    await _settle();
    final before = host.payloads.length;
    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    expect(host.payloads.length, greaterThan(before));
  });

  test('a seeded snapshot is sent before the first sample', () async {
    await setUpWith();
    controller.seed(await hardware.loadHardware());
    hardware.loads = 0;
    host.emit(IslandEvent.windowMinimized);
    await _settle();
    expect(host.payloads, isNotEmpty);
  });
}
