import 'package:flutter/material.dart';
import 'package:machine_info_native/machine_info_native.dart';

import 'src/application/inventory_controller.dart';
import 'src/application/island_controller.dart';
import 'src/application/settings_controller.dart';
import 'src/application/software_controller.dart';
import 'src/infrastructure/ffi_machine_info_repository.dart';
import 'src/infrastructure/native_software_manager.dart';
import 'src/infrastructure/shared_prefs_settings_repository.dart';
import 'src/infrastructure/unsupported_island_host.dart';
import 'src/presentation/home_page.dart';
import 'src/presentation/splash/splash_gate.dart';
import 'src/presentation/theme/glass_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController(const SharedPrefsSettingsRepository());
  await settings.load();
  const repository = FfiMachineInfoRepository();
  final controller = InventoryController(repository)..loadAll();
  final island = IslandController(host: createIslandHost(), settings: settings, repository: repository);
  controller.addListener(() => island.seed(controller.hardware.value));
  await island.start();
  _pauseLiveRefreshWhileIslandIsUp(island, controller);
  String nativeVersion;
  try {
    nativeVersion = MachineInfoNative.instance.version;
  } catch (_) {
    nativeVersion = '';
  }
  runApp(MachineInfoApp(
    controller: controller,
    settings: settings,
    software: SoftwareController(NativeSoftwareManager()),
    nativeVersion: nativeVersion,
    island: island,
  ));
}

/// While the island is on screen it samples the hardware itself, so the
/// main window's live refresh is paused and resumed when the window returns.
void _pauseLiveRefreshWhileIslandIsUp(IslandController island, InventoryController inventory) {
  var resume = false;
  island.addListener(() {
    if (island.visible && inventory.autoRefresh) {
      resume = true;
      inventory.setAutoRefresh(false);
    } else if (!island.visible && resume) {
      resume = false;
      inventory.setAutoRefresh(true);
      inventory.refreshHardware();
    }
  });
}

final _lightTheme = buildGlassTheme(Brightness.light);
final _darkTheme = buildGlassTheme(Brightness.dark);

class MachineInfoApp extends StatelessWidget {
  const MachineInfoApp({
    super.key,
    required this.controller,
    required this.settings,
    required this.software,
    this.nativeVersion = '',
    this.showSplash = true,
    this.island,
  });

  final InventoryController controller;
  final SettingsController settings;
  final SoftwareController software;
  final String nativeVersion;
  final bool showSplash;
  final IslandController? island;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Machine Info',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: settings.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 450),
        themeAnimationCurve: Curves.easeInOutCubic,
        home: showSplash ? SplashGate(controller: controller, child: _home()) : _home(),
      ),
    );
  }

  Widget _home() => HomePage(
        controller: controller,
        settings: settings,
        software: software,
        nativeVersion: nativeVersion,
        island: island,
      );
}
