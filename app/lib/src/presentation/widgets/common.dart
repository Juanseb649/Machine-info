import 'package:flutter/material.dart';

import '../../domain/entities.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(title, style: theme.textTheme.titleMedium),
            ]),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: SelectableText(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.ratio, required this.caption});

  final double ratio;
  final String caption;

  Color _color(ColorScheme scheme) {
    if (ratio >= 0.9) return scheme.error;
    if (ratio >= 0.75) return Colors.orange;
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1).toDouble(),
            minHeight: 10,
            color: _color(scheme),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class TabScaffold extends StatelessWidget {
  const TabScaffold({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
      ],
    );
  }
}

class CenteredMessage extends StatelessWidget {
  const CenteredMessage({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

String statusMessage(SectionStatus status) => switch (status) {
      SectionStatus.ok => '',
      SectionStatus.unsupported => 'Esta información no está disponible en este equipo o sistema operativo.',
      SectionStatus.permissionDenied => 'Se requieren permisos de administrador para leer esta información.',
      SectionStatus.error => 'Ocurrió un error al leer esta información.',
    };

class SectionView<T> extends StatelessWidget {
  const SectionView({super.key, required this.section, required this.builder});

  final SectionResult<T> section;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    final data = section.data;
    if (section.status != SectionStatus.ok || data == null) {
      return CenteredMessage(
        icon: section.status == SectionStatus.permissionDenied ? Icons.lock_outline : Icons.info_outline,
        message: statusMessage(section.status == SectionStatus.ok ? SectionStatus.unsupported : section.status),
      );
    }
    return builder(context, data);
  }
}
