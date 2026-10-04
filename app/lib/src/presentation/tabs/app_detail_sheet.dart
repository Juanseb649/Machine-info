import 'package:flutter/material.dart';

import '../../application/software_controller.dart';
import '../../domain/entities.dart';
import '../formatters.dart';
import '../theme/glass_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/glass.dart';
import 'software_tab.dart';

Future<void> showAppDetailSheet(
  BuildContext context, {
  required InstalledPackage package,
  required SoftwareController software,
  required Future<void> Function() onRefresh,
  required String platform,
}) {
  final tokens = context.glass;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: tokens.scrim.withValues(alpha: tokens.scrim.a * 0.6),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 480,
          child: _AppDetailSheet(package: package, software: software, onRefresh: onRefresh, platform: platform),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AppDetailSheet extends StatefulWidget {
  const _AppDetailSheet({
    required this.package,
    required this.software,
    required this.onRefresh,
    required this.platform,
  });

  final InstalledPackage package;
  final SoftwareController software;
  final Future<void> Function() onRefresh;
  final String platform;

  @override
  State<_AppDetailSheet> createState() => _AppDetailSheetState();
}

class _AppDetailSheetState extends State<_AppDetailSheet> {
  bool _uninstalling = false;

  InstalledPackage get _p => widget.package;

  Future<void> _openLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.software.openLocation(_p);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir la ubicación de instalación.')));
    }
  }

  Future<void> _uninstall() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmUninstall(package: _p, software: widget.software, platform: widget.platform),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uninstalling = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await widget.software.uninstall(_p);
    if (!mounted) return;
    setState(() => _uninstalling = false);

    switch (result.outcome) {
      case UninstallOutcome.completed:
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text('${_p.name} se desinstaló correctamente.')));
        widget.onRefresh();
      case UninstallOutcome.launched:
        navigator.pop();
        messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Se abrió el desinstalador de ${_p.name}. Sigue sus pasos y luego actualiza la lista.'),
          action: SnackBarAction(label: 'Actualizar', onPressed: widget.onRefresh),
        ));
      case UninstallOutcome.cancelled:
        messenger.showSnackBar(SnackBar(content: Text(result.message.isEmpty ? 'Operación cancelada.' : result.message)));
      case UninstallOutcome.unsupported:
        messenger.showSnackBar(const SnackBar(content: Text('Este programa no se puede desinstalar desde aquí.')));
      case UninstallOutcome.failed:
        messenger.showSnackBar(SnackBar(content: Text('No se pudo desinstalar: ${result.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    return Material(
      type: MaterialType.transparency,
      child: GlassPanel(
        strong: true,
        radius: 30,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(package: _p, software: widget.software, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        SelectableText(_p.name, style: theme.textTheme.titleLarge),
                        if (_p.publisher.isNotEmpty)
                          Text(_p.publisher, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          if (_p.version.isNotEmpty) GlassPill(label: 'v${_p.version}', icon: Icons.sell_outlined),
                          GlassPill(label: sourceLabel(_p.source), icon: Icons.inventory_2_outlined),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  _Section(
                    icon: Icons.folder_outlined,
                    title: 'Instalación',
                    children: [
                      _DetailLine(
                        label: 'Ubicación',
                        value: _p.installLocation.isEmpty ? 'No registrada' : _p.installLocation,
                        monospace: _p.installLocation.isNotEmpty,
                      ),
                      if (_p.sizeBytes > 0) _DetailLine(label: 'Tamaño', value: formatBytes(_p.sizeBytes)),
                      if (_p.installDate.isNotEmpty)
                        _DetailLine(label: 'Instalado el', value: formatInstallDate(_p.installDate)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GlassButton(
                          label: 'Abrir ubicación',
                          icon: Icons.folder_open,
                          filled: false,
                          onPressed: _p.installLocation.isEmpty && _p.iconPath.isEmpty ? null : _openLocation,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    icon: Icons.code,
                    title: 'Lenguaje y tecnología',
                    children: [_TechnologyView(future: widget.software.technology(_p))],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    icon: Icons.delete_outline,
                    title: 'Desinstalar',
                    accent: tokens.danger,
                    children: [
                      Text(
                        _p.canUninstall
                            ? 'Comando registrado por el instalador:'
                            : 'Este programa no registró un desinstalador.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_p.canUninstall) ...[
                        const SizedBox(height: 8),
                        _CodeBox(text: _p.uninstallCommand),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _uninstalling
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: tokens.danger),
                                ),
                                const SizedBox(width: 10),
                                Text('Desinstalando…', style: theme.textTheme.bodyMedium),
                              ])
                            : GlassButton(
                                label: 'Desinstalar',
                                icon: Icons.delete_forever_outlined,
                                color: tokens.danger,
                                onPressed: _p.canUninstall ? _uninstall : null,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children, this.accent});

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: tokens.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.glassEdgeLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: accent ?? tokens.accent),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value, this.monospace = false});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: tokens.textTertiary)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: monospace ? 'monospace' : null,
              fontFamilyFallback: monospace ? const ['Consolas', 'Menlo', 'DejaVu Sans Mono'] : null,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tokens.track, borderRadius: BorderRadius.circular(12)),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Consolas', 'Menlo', 'DejaVu Sans Mono'],
          fontSize: 12,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class _TechnologyView extends StatelessWidget {
  const _TechnologyView({required this.future});

  final Future<AppTechnology> future;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    return FutureBuilder<AppTechnology>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Row(children: [
            SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent)),
            const SizedBox(width: 10),
            Text('Analizando los archivos del programa…', style: theme.textTheme.bodySmall),
          ]);
        }
        final tech = snapshot.data ?? AppTechnology.unknown;
        if (!tech.isKnown) {
          return Text(
            'No se pudo determinar a partir de los archivos instalados.',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(tech.language, style: theme.textTheme.titleLarge),
                if (tech.framework.isNotEmpty) GlassPill(label: tech.framework, color: tokens.accent, selected: true),
              ],
            ),
            if (tech.evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Detectado por: ${tech.evidence.first}',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.textTertiary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ConfirmUninstall extends StatelessWidget {
  const _ConfirmUninstall({required this.package, required this.software, required this.platform});

  final InstalledPackage package;
  final SoftwareController software;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    final hint = switch (platform) {
      'windows' => 'Se abrirá el desinstalador del programa. Windows puede pedirte permisos de administrador.',
      'linux' => 'Se te pedirá la contraseña de administrador para quitar el paquete.',
      'macos' => 'La aplicación se moverá a la Papelera.',
      _ => 'Se ejecutará el desinstalador registrado por el programa.',
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          type: MaterialType.transparency,
          child: GlassPanel(
            strong: true,
            radius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(package: package, software: software, size: 64),
                const SizedBox(height: 16),
                Text('¿Desinstalar ${package.name}?', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancelar', style: TextStyle(color: tokens.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    GlassButton(
                      label: 'Desinstalar',
                      icon: Icons.delete_forever_outlined,
                      color: tokens.danger,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
