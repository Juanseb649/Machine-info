import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../formatters.dart';
import '../widgets/common.dart';
import '../widgets/gauges.dart';

class SystemTab extends StatelessWidget {
  const SystemTab({super.key, required this.snapshot});

  final HardwareSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SectionView<OsInfo>(
      section: snapshot.os,
      builder: (context, os) => TabScaffold(children: [
        InfoCard(title: 'Sistema operativo', icon: Icons.computer, children: [
          InfoRow('Nombre', orNa(os.name)),
          InfoRow('Versión', orNa(os.version)),
          InfoRow('Kernel', orNa(os.kernel)),
          InfoRow('Arquitectura', orNa(os.architecture)),
        ]),
        InfoCard(title: 'Equipo', icon: Icons.dns_outlined, children: [
          InfoRow('Nombre del equipo', orNa(os.hostname)),
          InfoRow('Tiempo encendido', formatDuration(os.uptime)),
          InfoRow('Plataforma', snapshot.platform),
          InfoRow('Última lectura', TimeOfDay.fromDateTime(snapshot.collectedAt).format(context)),
        ]),
      ]),
    );
  }
}

class CpuTab extends StatelessWidget {
  const CpuTab({super.key, required this.section});

  final SectionResult<CpuInfo> section;

  @override
  Widget build(BuildContext context) {
    return SectionView<CpuInfo>(
      section: section,
      builder: (context, cpu) => TabScaffold(children: [
        InfoCard(title: 'Procesador', icon: Icons.memory, children: [
          InfoRow('Modelo', orNa(cpu.model)),
          InfoRow('Fabricante', orNa(cpu.vendor)),
          InfoRow('Arquitectura', orNa(cpu.architecture)),
          InfoRow('Núcleos físicos', '${cpu.physicalCores}'),
          InfoRow('Hilos lógicos', '${cpu.logicalCores}'),
          InfoRow('Frecuencia base', formatMhz(cpu.baseFrequencyMhz)),
        ]),
        InfoCard(title: 'Uso actual', icon: Icons.speed, children: [
          Row(children: [
            ArcGauge(
              ratio: cpu.usagePercent / 100,
              size: 150,
              strokeWidth: 12,
              ticks: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  cpu.usagePercent.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text('% en uso', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InfoRow('Núcleos activos', '${cpu.physicalCores} físicos · ${cpu.logicalCores} hilos'),
                InfoRow('Frecuencia base', formatMhz(cpu.baseFrequencyMhz)),
                const SizedBox(height: 8),
                UsageBar(ratio: cpu.usagePercent / 100, caption: '${cpu.usagePercent.toStringAsFixed(1)} % de carga total'),
              ]),
            ),
          ]),
        ]),
      ]),
    );
  }
}

class MemoryTab extends StatelessWidget {
  const MemoryTab({super.key, required this.section});

  final SectionResult<MemoryInfo> section;

  @override
  Widget build(BuildContext context) {
    return SectionView<MemoryInfo>(
      section: section,
      builder: (context, m) => TabScaffold(children: [
        InfoCard(title: 'Memoria RAM', icon: Icons.developer_board, children: [
          UsageBar(
            ratio: m.usedRatio,
            caption: '${formatBytes(m.usedBytes)} de ${formatBytes(m.totalBytes)} (${formatPercent(m.usedRatio)})',
          ),
          const SizedBox(height: 12),
          InfoRow('Total', formatBytes(m.totalBytes)),
          InfoRow('En uso', formatBytes(m.usedBytes)),
          InfoRow('Disponible', formatBytes(m.availableBytes)),
        ]),
        InfoCard(title: 'Memoria virtual (swap / paginación)', icon: Icons.swap_horiz, children: [
          if (m.swapTotalBytes == 0)
            const InfoRow('Estado', 'Sin memoria virtual configurada')
          else ...[
            UsageBar(
              ratio: m.swapRatio,
              caption: '${formatBytes(m.swapUsedBytes)} de ${formatBytes(m.swapTotalBytes)}',
            ),
            const SizedBox(height: 12),
            InfoRow('Total', formatBytes(m.swapTotalBytes)),
            InfoRow('En uso', formatBytes(m.swapUsedBytes)),
          ],
        ]),
      ]),
    );
  }
}

class StorageTab extends StatelessWidget {
  const StorageTab({super.key, required this.section});

  final SectionResult<List<DiskInfo>> section;

  static const _kindLabels = {
    DiskKind.fixed: 'Interno',
    DiskKind.removable: 'Extraíble',
    DiskKind.network: 'Red',
    DiskKind.optical: 'Óptico',
    DiskKind.ram: 'RAM disk',
    DiskKind.unknown: 'Desconocido',
  };

  static const _kindIcons = {
    DiskKind.fixed: Icons.storage,
    DiskKind.removable: Icons.usb,
    DiskKind.network: Icons.lan_outlined,
    DiskKind.optical: Icons.album_outlined,
    DiskKind.ram: Icons.flash_on,
    DiskKind.unknown: Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    return SectionView<List<DiskInfo>>(
      section: section,
      builder: (context, disks) {
        if (disks.isEmpty) {
          return const CenteredMessage(icon: Icons.storage, message: 'No se encontraron unidades montadas.');
        }
        return TabScaffold(children: [
          for (final d in disks)
            InfoCard(title: '${d.name}  ·  ${d.mountPoint}', icon: _kindIcons[d.kind]!, children: [
              UsageBar(
                ratio: d.usedRatio,
                caption: '${formatBytes(d.freeBytes)} libres de ${formatBytes(d.totalBytes)} (${formatPercent(d.usedRatio)} usado)',
              ),
              const SizedBox(height: 12),
              InfoRow('Tipo', _kindLabels[d.kind]!),
              InfoRow('Sistema de archivos', orNa(d.filesystem)),
              InfoRow('Usado', formatBytes(d.usedBytes)),
            ]),
        ]);
      },
    );
  }
}
