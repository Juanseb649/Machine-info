import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/main.dart';
import 'package:machine_info/src/application/inventory_controller.dart';
import 'package:machine_info/src/application/island_controller.dart';
import 'package:machine_info/src/application/settings_controller.dart';
import 'package:machine_info/src/application/software_controller.dart';
import 'package:machine_info/src/domain/entities.dart';
import 'package:machine_info/src/domain/machine_info_repository.dart';
import 'package:machine_info/src/domain/settings_repository.dart';
import 'package:machine_info/src/domain/software_manager.dart';
import 'package:machine_info/src/infrastructure/unsupported_island_host.dart';
import 'package:machine_info/src/presentation/splash/splash_gate.dart';
import 'package:machine_info/src/presentation/widgets/island_preview.dart';

import 'island_controller_test.dart' show FakeIslandHost;

class FakeRepository implements MachineInfoRepository {
  @override
  Future<HardwareSnapshot> loadHardware() async => HardwareSnapshot(
        platform: 'fake',
        collectedAt: DateTime(2026),
        os: const SectionResult(
          SectionStatus.ok,
          OsInfo(
            name: 'FakeOS',
            version: '1.0',
            kernel: 'k',
            hostname: 'host',
            architecture: 'x86_64',
            uptime: Duration(minutes: 5),
          ),
        ),
        cpu: const SectionResult(SectionStatus.unsupported, null),
        memory: const SectionResult(SectionStatus.unsupported, null),
        disks: const SectionResult(SectionStatus.ok, []),
        temperatures: const SectionResult(SectionStatus.ok, [
          TemperatureReading(label: 'CPU Package', source: 'coretemp', celsius: 58, criticalCelsius: 100),
          TemperatureReading(label: 'Composite', source: 'nvme', celsius: 41),
        ]),
      );

  @override
  Future<SectionResult<List<InstalledPackage>>> loadSoftware() async => const SectionResult(
        SectionStatus.ok,
        [
          InstalledPackage(
            name: 'git',
            version: '2.45',
            publisher: 'Git',
            source: 'fake',
            installLocation: '/opt/git',
            uninstallCommand: 'remove git',
          ),
        ],
      );
}

class FakeSoftwareManager implements SoftwareManager {
  int uninstallCalls = 0;

  @override
  Future<AppTechnology> detectTechnology(InstalledPackage package) async =>
      const AppTechnology(language: 'Go', framework: '', evidence: ['git contiene "Go buildinf:"']);

  @override
  Future<Uint8List?> loadIcon(InstalledPackage package) async => null;

  @override
  Future<bool> openLocation(InstalledPackage package) async => true;

  @override
  Future<UninstallResult> uninstall(InstalledPackage package) async {
    uninstallCalls++;
    return const UninstallResult(UninstallOutcome.completed);
  }
}

class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository(this.value);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

Future<(InventoryController, SettingsController, FakeSoftwareManager)> _pumpApp(
  WidgetTester tester, {
  required bool onboardingCompleted,
  MemorySettingsRepository? repository,
  IslandController? Function(SettingsController settings)? island,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final settings = SettingsController(
    repository ?? MemorySettingsRepository(AppSettings(onboardingCompleted: onboardingCompleted)),
  );
  await settings.load();
  final controller = InventoryController(FakeRepository());
  final manager = FakeSoftwareManager();
  await tester.pumpWidget(MachineInfoApp(
    controller: controller,
    settings: settings,
    software: SoftwareController(manager),
    showSplash: false,
    island: island?.call(settings),
  ));
  await controller.loadAll();
  await tester.pumpAndSettle();
  return (controller, settings, manager);
}

void main() {
  testWidgets('first launch shows the tutorial and skipping it is remembered', (tester) async {
    final repository = MemorySettingsRepository(const AppSettings());
    await _pumpApp(tester, onboardingCompleted: false, repository: repository);

    expect(find.text('Bienvenido a Machine Info'), findsOneWidget);
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('Menú de secciones'), findsOneWidget);

    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.text('Menú de secciones'), findsNothing);
    expect(repository.value.onboardingCompleted, isTrue);
  });

  testWidgets('navigates sections, opens app details and uninstalls', (tester) async {
    final (_, _, manager) = await _pumpApp(tester, onboardingCompleted: true);

    expect(find.text('FakeOS'), findsOneWidget);

    await tester.tap(find.text('Temperaturas'));
    await tester.pumpAndSettle();
    expect(find.text('TEMPERATURA PRINCIPAL'), findsOneWidget);
    expect(find.text('Almacenamiento'), findsWidgets);

    await tester.tap(find.text('Software'));
    await tester.pumpAndSettle();
    expect(find.text('git'), findsOneWidget);

    await tester.tap(find.text('git'));
    await tester.pumpAndSettle();
    expect(find.text('Lenguaje y tecnología'), findsOneWidget);
    expect(find.text('Go'), findsOneWidget);
    expect(find.text('/opt/git'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Desinstalar').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Desinstalar git?'), findsOneWidget);
    await tester.tap(find.widgetWithText(InkWell, 'Desinstalar').last);
    await tester.pumpAndSettle();
    expect(manager.uninstallCalls, 1);
    expect(find.text('git se desinstaló correctamente.'), findsOneWidget);
  });

  testWidgets('settings switch between automatic and fixed theme', (tester) async {
    final (_, settings, _) = await _pumpApp(tester, onboardingCompleted: true);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.system);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(settings.settings.themePreference, isNot(ThemePreference.automatic));

    await tester.tap(find.text('Noche'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('shows the logo splash until the hardware is loaded', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final settings = SettingsController(MemorySettingsRepository(const AppSettings(onboardingCompleted: true)));
    await settings.load();
    final controller = InventoryController(FakeRepository());
    await tester.pumpWidget(MachineInfoApp(
      controller: controller,
      settings: settings,
      software: SoftwareController(FakeSoftwareManager()),
    ));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Hardware y software, de un vistazo.'), findsOneWidget);

    await controller.loadAll();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('island settings explain it is macOS only when unsupported', (tester) async {
    IslandController? island;
    await _pumpApp(tester, onboardingCompleted: true, island: (settings) {
      island = IslandController(
        host: const UnsupportedIslandHost(),
        settings: settings,
        repository: FakeRepository(),
      );
      return island;
    });
    await island!.start();

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Isla dinámica'), findsOneWidget);
    expect(find.text('Solo en macOS'), findsOneWidget);
    expect(find.byType(IslandPreview), findsOneWidget);
    final toggle = tester.widget<Switch>(find.descendant(
      of: find.ancestor(of: find.text('Mostrar al minimizar'), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    ));
    expect(toggle.onChanged, isNull);
    island!.dispose();
  });

  testWidgets('island settings change the reading next to the camera', (tester) async {
    IslandController? island;
    final (_, settings, _) = await _pumpApp(tester, onboardingCompleted: true, island: (settings) {
      island = IslandController(host: FakeIslandHost(), settings: settings, repository: FakeRepository());
      return island;
    });
    await island!.start();

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('macOS'), findsOneWidget);

    await tester.ensureVisible(find.text('Temp.'));
    await tester.tap(find.text('Temp.'));
    await tester.pumpAndSettle();
    expect(settings.settings.islandPrimaryMetric, IslandPrimaryMetric.temperature);
    // The fake hardware's hottest sensor is 58 °C.
    expect(find.descendant(of: find.byType(IslandPreview), matching: find.text('58°C')), findsOneWidget);

    await tester.tap(find.text('5 s'));
    await tester.pumpAndSettle();
    expect(settings.settings.islandRefreshSeconds, 5);
    island!.dispose();
  });
}
