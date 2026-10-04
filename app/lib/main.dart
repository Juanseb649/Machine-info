import 'package:flutter/material.dart';

import 'src/application/inventory_controller.dart';
import 'src/infrastructure/ffi_machine_info_repository.dart';
import 'src/presentation/home_page.dart';

void main() {
  final controller = InventoryController(const FfiMachineInfoRepository())..loadAll();
  runApp(MachineInfoApp(controller: controller));
}

class MachineInfoApp extends StatelessWidget {
  const MachineInfoApp({super.key, required this.controller});

  final InventoryController controller;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6FED);
    return MaterialApp(
      title: 'Machine Info',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: HomePage(controller: controller),
    );
  }
}
