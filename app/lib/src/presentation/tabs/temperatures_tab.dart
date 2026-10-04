import 'package:flutter/material.dart';

import '../../application/inventory_controller.dart';
import '../../domain/entities.dart';
import '../formatters.dart';
import '../theme/glass_theme.dart';
import '../widgets/common.dart';
import '../widgets/gauges.dart';
import '../widgets/glass.dart';

enum SensorCategory {
  cpu('Procesador', Icons.memory, 100),
  gpu('Gráficos', Icons.videogame_asset_outlined, 95),
  storage('Almacenamiento', Icons.storage, 75),
  system('Placa y sistema', Icons.developer_board, 90),
  battery('Batería', Icons.battery_charging_full, 60),
  other('Otros sensores', Icons.sensors, 100);

  const SensorCategory(this.label, this.icon, this.defaultCritical);

  final String label;
  final IconData icon;
  final double defaultCritical;

  static SensorCategory of(TemperatureReading t) {
    final text = '${t.label} ${t.source}'.toLowerCase();
    bool any(List<String> words) => words.any(text.contains);
    if (any(['nvme', 'ssd', 'hdd', 'disk', 'drive', 'sata', 'composite'])) return storage;
    if (any(['gpu', 'amdgpu', 'radeon', 'nvidia', 'nouveau', 'geforce', 'junction', 'i915', 'edge'])) return gpu;
    if (any(['cpu', 'core', 'package', 'tctl', 'tdie', 'tccd', 'k10temp', 'coretemp', 'zenpower', 'x86_pkg', 'soc'])) {
      return cpu;
    }
    if (any(['battery', 'bat0', 'bat1'])) return battery;
    if (any(['acpi', 'thermal', 'zone', 'tz', 'pch', 'board', 'chipset', 'mainboard', 'sys'])) return system;
    return other;
  }
}

class _Sensor {
  _Sensor(this.reading, this.history)
      : category = SensorCategory.of(reading),
        critical = reading.criticalCelsius ?? SensorCategory.of(reading).defaultCritical;

  final TemperatureReading reading;
  final SensorHistory history;
  final SensorCategory category;
  final double critical;

  double get ratio => reading.celsius / critical;
}

String _statusLabel(double ratio) {
  if (ratio < 0.5) return 'Óptima';
  if (ratio < 0.7) return 'Normal';
  if (ratio < 0.85) return 'Elevada';
  return 'Crítica';
}

class TemperaturesTab extends StatelessWidget {
  const TemperaturesTab({
    super.key,
    required this.section,
    required this.controller,
    required this.unit,
    required this.collectedAt,
  });

  final SectionResult<List<TemperatureReading>> section;
  final InventoryController controller;
  final TemperatureUnit unit;
  final DateTime collectedAt;

  @override
  Widget build(BuildContext context) {
    return SectionView<List<TemperatureReading>>(
      section: section,
      builder: (context, readings) {
        if (readings.isEmpty) {
          return const CenteredMessage(
            icon: Icons.thermostat,
            message: 'Este equipo no expone sensores de temperatura.\n'
                'En Windows algunos sensores requieren ejecutar como administrador.',
          );
        }
        final sensors = [for (final r in readings) _Sensor(r, controller.historyFor(r))];
        final primary = _pickPrimary(sensors);
        final grouped = <SensorCategory, List<_Sensor>>{};
        for (final s in sensors) {
          grouped.putIfAbsent(s.category, () => []).add(s);
        }
        final categories = SensorCategory.values.where(grouped.containsKey).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 32),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final hero = _HeroGauge(sensor: primary, unit: unit);
                final history = _HistoryPanel(
                  sensor: primary,
                  sensors: sensors,
                  unit: unit,
                  live: controller.autoRefresh,
                  onToggleLive: () => controller.setAutoRefresh(!controller.autoRefresh),
                );
                if (constraints.maxWidth < 900) {
                  return Column(children: [hero, const SizedBox(height: 18), history]);
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 360, child: hero),
                      const SizedBox(width: 18),
                      Expanded(child: history),
                    ],
                  ),
                );
              },
            ),
            for (final category in categories) ...[
              const SizedBox(height: 26),
              _CategoryHeader(category: category, count: grouped[category]!.length),
              const SizedBox(height: 12),
              _SensorGrid(sensors: grouped[category]!, unit: unit, primary: primary),
            ],
          ],
        );
      },
    );
  }

  _Sensor _pickPrimary(List<_Sensor> sensors) {
    const preferred = ['package', 'tctl', 'tdie', 'cpu'];
    final cpu = sensors.where((s) => s.category == SensorCategory.cpu).toList();
    for (final word in preferred) {
      for (final s in cpu) {
        if (s.reading.label.toLowerCase().contains(word)) return s;
      }
    }
    final pool = cpu.isNotEmpty ? cpu : sensors;
    return pool.reduce((a, b) => a.reading.celsius >= b.reading.celsius ? a : b);
  }
}

class _HeroGauge extends StatelessWidget {
  const _HeroGauge({required this.sensor, required this.unit});

  final _Sensor sensor;
  final TemperatureUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    final color = heatColor(tokens, sensor.ratio);
    final value = convertTemperature(sensor.reading.celsius, unit);
    final history = sensor.history;
    return GlassPanel(
      strong: true,
      radius: 28,
      tint: color,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        children: [
          Row(children: [
            GlassIconBadge(icon: sensor.category.icon, color: color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TEMPERATURA PRINCIPAL', style: theme.textTheme.labelSmall),
                Text(sensor.reading.label, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ArcGauge(
            ratio: sensor.ratio,
            size: 240,
            strokeWidth: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: value),
                      duration: const Duration(milliseconds: 700),
                      builder: (context, v, _) => Text(
                        v.toStringAsFixed(0),
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(temperatureSuffix(unit), style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GlassPill(label: _statusLabel(sensor.ratio), color: color, selected: true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Stat(label: 'Mín.', value: _fmt(history.min), color: tokens.info),
              _Stat(label: 'Máx.', value: _fmt(history.max), color: tokens.warning),
              _Stat(label: 'Crítico', value: formatTemperature(sensor.critical, unit), color: tokens.danger),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double celsius) => celsius.isFinite ? formatTemperature(celsius, unit) : '—';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.sensor,
    required this.sensors,
    required this.unit,
    required this.live,
    required this.onToggleLive,
  });

  final _Sensor sensor;
  final List<_Sensor> sensors;
  final TemperatureUnit unit;
  final bool live;
  final VoidCallback onToggleLive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    final hottest = sensors.reduce((a, b) => a.reading.celsius >= b.reading.celsius ? a : b);
    final average = sensors.map((s) => s.reading.celsius).reduce((a, b) => a + b) / sensors.length;
    final samples = [for (final v in sensor.history.samples) convertTemperature(v, unit)];
    return GlassPanel(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HISTORIAL', style: theme.textTheme.labelSmall),
                Text(sensor.reading.label, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
              ]),
            ),
            GlassPill(
              label: live ? 'En vivo' : 'Iniciar monitoreo',
              icon: live ? Icons.circle : Icons.play_arrow_rounded,
              color: live ? tokens.success : tokens.accent,
              selected: live,
              onTap: onToggleLive,
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: samples.length < 2
                  ? Center(
                      child: Text(
                        live ? 'Recolectando lecturas…' : 'Activa el monitoreo para ver la evolución en el tiempo.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : HistoryChart(
                      samples: samples,
                      color: heatColor(tokens, sensor.ratio),
                      threshold: convertTemperature(sensor.critical, unit),
                      formatValue: (v) => '${v.toStringAsFixed(0)}°',
                      height: 210,
                    ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(icon: Icons.sensors, label: 'Sensores', value: '${sensors.length}'),
              _SummaryChip(icon: Icons.functions, label: 'Promedio', value: formatTemperature(average, unit)),
              _SummaryChip(
                icon: Icons.local_fire_department_outlined,
                label: 'Más caliente',
                value: '${hottest.reading.label} · ${formatTemperature(hottest.reading.celsius, unit)}',
                color: heatColor(tokens, hottest.ratio),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label, required this.value, this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.glassEdgeLight.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color ?? tokens.textSecondary),
        const SizedBox(width: 8),
        Text('$label  ', style: theme.textTheme.bodySmall),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.count});

  final SensorCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    return Row(children: [
      Icon(category.icon, size: 18, color: tokens.textSecondary),
      const SizedBox(width: 8),
      Text(category.label, style: theme.textTheme.titleMedium),
      const SizedBox(width: 8),
      Text('$count', style: theme.textTheme.bodySmall?.copyWith(color: tokens.textTertiary)),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: tokens.track)),
    ]);
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.sensors, required this.unit, required this.primary});

  final List<_Sensor> sensors;
  final TemperatureUnit unit;
  final _Sensor primary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 14.0;
      const minTile = 270.0;
      final columns = ((constraints.maxWidth + spacing) / (minTile + spacing)).floor().clamp(1, 6);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final s in sensors)
            SizedBox(width: width, child: _SensorTile(sensor: s, unit: unit, highlighted: identical(s, primary))),
        ],
      );
    });
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.sensor, required this.unit, required this.highlighted});

  final _Sensor sensor;
  final TemperatureUnit unit;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    final color = heatColor(tokens, sensor.ratio);
    final h = sensor.history;
    String fmt(double c) => c.isFinite ? formatTemperature(c, unit) : '—';
    return GlassPanel(
      blur: false,
      shadow: false,
      radius: 20,
      tint: highlighted ? color : null,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ArcGauge(
              ratio: sensor.ratio,
              size: 68,
              strokeWidth: 7,
              ticks: false,
              child: Text(
                convertTemperature(sensor.reading.celsius, unit).toStringAsFixed(0),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sensor.reading.label,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(sensor.reading.source.isEmpty ? sensor.category.label : sensor.reading.source,
                    style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Text(formatTemperature(sensor.reading.celsius, unit, decimals: 1),
                      style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _statusLabel(sensor.ratio),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Sparkline(samples: h.samples, color: color, height: 30),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in [
                'Mín. ${fmt(h.min)}',
                'Máx. ${fmt(h.max)}',
                'Crít. ${formatTemperature(sensor.critical, unit)}',
              ])
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
