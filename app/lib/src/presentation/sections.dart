import 'package:flutter/material.dart';

enum AppSection {
  system('Sistema', 'Sistema operativo y equipo', Icons.computer),
  cpu('CPU', 'Procesador y uso en tiempo real', Icons.memory),
  memory('Memoria', 'RAM y memoria virtual', Icons.developer_board),
  storage('Almacenamiento', 'Unidades y espacio disponible', Icons.storage),
  temperatures('Temperaturas', 'Sensores térmicos del equipo', Icons.thermostat),
  software('Software', 'Programas instalados', Icons.apps),
  settings('Ajustes', 'Apariencia y preferencias', Icons.settings_outlined);

  const AppSection(this.label, this.subtitle, this.icon);

  final String label;
  final String subtitle;
  final IconData icon;

  static const navigation = [system, cpu, memory, storage, temperatures, software];
}
