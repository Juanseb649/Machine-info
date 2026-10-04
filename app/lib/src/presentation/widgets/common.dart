import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../theme/glass_theme.dart';
import 'glass.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.icon, required this.children, this.trailing});

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GlassIconBadge(icon: icon, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
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
    final tokens = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.ratio, required this.caption});

  final double ratio;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final value = ratio.clamp(0.0, 1.0);
    final color = tokens.levelColor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 12,
            decoration: BoxDecoration(color: tokens.track, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Container(
                width: constraints.maxWidth * v,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.25)!, color]),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 32),
      children: [
        for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 18), child: child),
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
    final tokens = context.glass;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: GlassPanel(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: tokens.textTertiary),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
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
