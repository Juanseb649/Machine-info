import 'package:flutter/material.dart';
import 'package:machine_info_native/machine_info_native.dart';

import 'src/application/inventory_controller.dart';
import 'src/application/settings_controller.dart';
import 'src/application/software_controller.dart';
import 'src/infrastructure/ffi_machine_info_repository.dart';
import 'src/infrastructure/native_software_manager.dart';
import 'src/infrastructure/shared_prefs_settings_repository.dart';
import 'src/presentation/home_page.dart';
import 'src/presentation/theme/glass_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController(const SharedPrefsSettingsRepository());
  await settings.load();
  final controller = InventoryController(const FfiMachineInfoRepository())..loadAll();
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
  ));
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
  });

  final InventoryController controller;
  final SettingsController settings;
  final SoftwareController software;
  final String nativeVersion;

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
        home: HomePage(
          controller: controller,
          settings: settings,
          software: software,
          nativeVersion: nativeVersion,
        ),
      ),
    );
  }
}
