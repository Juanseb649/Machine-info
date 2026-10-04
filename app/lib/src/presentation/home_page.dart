import 'package:flutter/material.dart';

import '../application/inventory_controller.dart';
import 'tabs/hardware_tabs.dart';
import 'tabs/software_tab.dart';
import 'widgets/common.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final InventoryController controller;

  static const _tabs = [
    Tab(icon: Icon(Icons.computer), text: 'Sistema'),
    Tab(icon: Icon(Icons.memory), text: 'CPU'),
    Tab(icon: Icon(Icons.developer_board), text: 'Memoria'),
    Tab(icon: Icon(Icons.storage), text: 'Almacenamiento'),
    Tab(icon: Icon(Icons.thermostat), text: 'Temperaturas'),
    Tab(icon: Icon(Icons.apps), text: 'Software'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Machine Info'),
            actions: [
              const Text('Auto'),
              Switch(value: controller.autoRefresh, onChanged: controller.setAutoRefresh),
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
                onPressed: controller.loadAll,
              ),
              const SizedBox(width: 8),
            ],
            bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: _tabs),
          ),
          body: Column(children: [
            if (controller.hardware.loading || controller.software.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: TabBarView(children: [..._hardwareTabs(), _softwareTab()])),
          ]),
        ),
      ),
    );
  }

  List<Widget> _hardwareTabs() {
    final state = controller.hardware;
    final snapshot = state.value;
    if (snapshot == null) {
      final placeholder = _placeholder(state.error, controller.refreshHardware);
      return List.filled(5, placeholder);
    }
    return [
      SystemTab(snapshot: snapshot),
      CpuTab(section: snapshot.cpu),
      MemoryTab(section: snapshot.memory),
      StorageTab(section: snapshot.disks),
      TemperaturesTab(section: snapshot.temperatures),
    ];
  }

  Widget _softwareTab() {
    final state = controller.software;
    final section = state.value;
    if (section == null) return _placeholder(state.error, controller.refreshSoftware);
    return SoftwareTab(section: section);
  }

  Widget _placeholder(Object? error, VoidCallback retry) {
    if (error == null) return const Center(child: CircularProgressIndicator());
    return CenteredMessage(
      icon: Icons.error_outline,
      message: 'No se pudo cargar la información.\n$error',
      action: FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
    );
  }
}
