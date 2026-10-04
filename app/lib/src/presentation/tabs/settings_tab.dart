import 'package:flutter/material.dart';

import '../../application/inventory_controller.dart';
import '../../application/settings_controller.dart';
import '../../domain/entities.dart';
import '../theme/glass_theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.settings, required this.inventory, this.nativeVersion = ''});

  final SettingsController settings;
  final InventoryController inventory;
  final String nativeVersion;

  @override
  Widget build(BuildContext context) {
    final s = settings.settings;
    final theme = Theme.of(context);
    final tokens = context.glass;
    final automatic = s.themePreference == ThemePreference.automatic;
    final isDark = theme.brightness == Brightness.dark;

    return TabScaffold(children: [
      InfoCard(
        title: 'Apariencia',
        icon: Icons.palette_outlined,
        trailing: GlassPill(
          label: isDark ? 'Modo noche activo' : 'Modo día activo',
          icon: isDark ? Icons.dark_mode : Icons.light_mode,
        ),
        children: [
          _SettingRow(
            title: 'Cambio automático',
            subtitle: 'Alterna entre modo día y noche sin que tengas que hacer nada.',
            trailing: Switch(
              value: automatic,
              onChanged: (v) => settings.setAutomatic(v, current: theme.brightness),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: automatic ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Activar según'),
                GlassSegmented<AutoThemeSource>(
                  value: s.autoThemeSource,
                  onChanged: settings.setAutoThemeSource,
                  segments: const [
                    GlassSegment(AutoThemeSource.system, 'El sistema', icon: Icons.desktop_windows_outlined),
                    GlassSegment(AutoThemeSource.schedule, 'La hora del día', icon: Icons.schedule),
                  ],
                ),
                if (s.autoThemeSource == AutoThemeSource.schedule) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _HourPicker(
                        icon: Icons.light_mode_outlined,
                        label: 'Día desde',
                        value: s.dayStartHour,
                        onChanged: (h) => settings.setSchedule(dayStartHour: h),
                      ),
                      _HourPicker(
                        icon: Icons.dark_mode_outlined,
                        label: 'Noche desde',
                        value: s.nightStartHour,
                        onChanged: (h) => settings.setSchedule(nightStartHour: h),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Modo fijo'),
                GlassSegmented<ThemePreference>(
                  value: s.themePreference == ThemePreference.automatic ? ThemePreference.light : s.themePreference,
                  onChanged: settings.setThemePreference,
                  segments: const [
                    GlassSegment(ThemePreference.light, 'Día', icon: Icons.light_mode),
                    GlassSegment(ThemePreference.dark, 'Noche', icon: Icons.dark_mode),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      InfoCard(
        title: 'Monitoreo',
        icon: Icons.monitor_heart_outlined,
        children: [
          _SettingRow(
            title: 'Actualización en vivo',
            subtitle: 'Vuelve a leer el hardware cada ${inventory.refreshInterval.inSeconds} segundos.',
            trailing: Switch(value: inventory.autoRefresh, onChanged: inventory.setAutoRefresh),
          ),
          const SizedBox(height: 16),
          const _Label('Unidad de temperatura'),
          SizedBox(
            width: 320,
            child: GlassSegmented<TemperatureUnit>(
              value: s.temperatureUnit,
              onChanged: settings.setTemperatureUnit,
              segments: const [
                GlassSegment(TemperatureUnit.celsius, 'Celsius (°C)'),
                GlassSegment(TemperatureUnit.fahrenheit, 'Fahrenheit (°F)'),
              ],
            ),
          ),
        ],
      ),
      InfoCard(
        title: 'Tutorial',
        icon: Icons.school_outlined,
        children: [
          Text(
            'Repasa el recorrido guiado por las secciones de la aplicación.',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: GlassButton(
              label: 'Ver tutorial de nuevo',
              icon: Icons.play_arrow_rounded,
              onPressed: settings.restartOnboarding,
            ),
          ),
        ],
      ),
      InfoCard(
        title: 'Acerca de',
        icon: Icons.info_outline,
        children: [
          const InfoRow('Aplicación', 'Machine Info 0.2.0'),
          InfoRow('Núcleo nativo', nativeVersion.isEmpty ? 'N/D' : 'machineinfo $nativeVersion'),
          const InfoRow('Atajos', 'Ctrl + R actualizar · Ctrl + 1…7 cambiar de sección'),
        ],
      ),
    ]);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.subtitle, required this.trailing});

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 16),
        trailing,
      ],
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({required this.icon, required this.label, required this.value, required this.onChanged});

  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: tokens.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.glassEdgeLight.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: tokens.textSecondary)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            dropdownColor: tokens.popover,
            menuMaxHeight: 320,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
            ],
          ),
        ],
      ),
    );
  }
}
