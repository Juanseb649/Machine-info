import 'package:flutter/material.dart';

import '../../application/software_controller.dart';
import '../../domain/entities.dart';
import '../formatters.dart';
import '../theme/glass_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'app_detail_sheet.dart';

String sourceLabel(String source) => switch (source) {
      'system-x64' => 'Sistema · 64 bits',
      'system-x86' => 'Sistema · 32 bits',
      'user' => 'Usuario',
      'dpkg' => 'APT / dpkg',
      'rpm' => 'RPM',
      'pacman' => 'Pacman',
      'flatpak' => 'Flatpak',
      'snap' => 'Snap',
      'applications' => 'Aplicaciones',
      'system' => 'Sistema',
      'homebrew' => 'Homebrew',
      'homebrew-cask' => 'Homebrew Cask',
      _ => source,
    };

enum _SortMode { name, size, date }

class SoftwareTab extends StatefulWidget {
  const SoftwareTab({
    super.key,
    required this.section,
    required this.software,
    required this.onRefresh,
    this.platform = '',
  });

  final SectionResult<List<InstalledPackage>> section;
  final SoftwareController software;
  final Future<void> Function() onRefresh;
  final String platform;

  @override
  State<SoftwareTab> createState() => _SoftwareTabState();
}

class _SoftwareTabState extends State<SoftwareTab> {
  final _search = TextEditingController();
  String? _source;
  _SortMode _sort = _SortMode.name;
  late bool _appsOnly = widget.platform == 'linux';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InstalledPackage> _filter(List<InstalledPackage> all) {
    final query = _search.text.trim().toLowerCase();
    final visible = all.where((p) {
      if (_source != null && p.source != _source) return false;
      if (_appsOnly && !p.hasIcon) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) || p.publisher.toLowerCase().contains(query);
    }).toList();
    switch (_sort) {
      case _SortMode.name:
        break;
      case _SortMode.size:
        visible.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case _SortMode.date:
        visible.sort((a, b) => b.installDate.compareTo(a.installDate));
    }
    return visible;
  }

  Future<void> _open(InstalledPackage package) => showAppDetailSheet(
        context,
        package: package,
        software: widget.software,
        onRefresh: widget.onRefresh,
        platform: widget.platform,
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    return SectionView<List<InstalledPackage>>(
      section: widget.section,
      builder: (context, packages) {
        final sources = packages.map((p) => p.source).toSet().toList()..sort();
        final visible = _filter(packages);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassPanel(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Buscar por nombre o editor',
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(_search.clear),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<_SortMode>(
                      tooltip: 'Ordenar',
                      initialValue: _sort,
                      onSelected: (v) => setState(() => _sort = v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: _SortMode.name, child: Text('Nombre (A–Z)')),
                        PopupMenuItem(value: _SortMode.size, child: Text('Tamaño')),
                        PopupMenuItem(value: _SortMode.date, child: Text('Fecha de instalación')),
                      ],
                      child: GlassPill(
                        icon: Icons.sort,
                        label: switch (_sort) {
                          _SortMode.name => 'Nombre',
                          _SortMode.size => 'Tamaño',
                          _SortMode.date => 'Recientes',
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GlassPill(label: 'Todas', selected: _source == null, onTap: () => setState(() => _source = null)),
                      for (final s in sources)
                        GlassPill(
                          label: sourceLabel(s),
                          selected: _source == s,
                          onTap: () => setState(() => _source = _source == s ? null : s),
                        ),
                      Container(width: 1, height: 20, color: tokens.track),
                      GlassPill(
                        icon: Icons.apps,
                        label: 'Solo aplicaciones con logo',
                        selected: _appsOnly,
                        color: _appsOnly ? tokens.accent : null,
                        onTap: () => setState(() => _appsOnly = !_appsOnly),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
              child: Text(
                '${visible.length} de ${packages.length} programas',
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const CenteredMessage(icon: Icons.search_off, message: 'No hay programas que coincidan.')
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 32),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 340,
                        mainAxisExtent: 84,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, i) => _AppTile(
                        package: visible[i],
                        software: widget.software,
                        onTap: () => _open(visible[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.package, required this.software, required this.onTap});

  final InstalledPackage package;
  final SoftwareController software;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    final details = [
      if (package.publisher.isNotEmpty) package.publisher,
      if (package.version.isNotEmpty) 'v${package.version}',
    ].join(' · ');
    return GlassPanel(
      blur: false,
      shadow: false,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          AppIcon(package: package, software: software, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (details.isNotEmpty)
                  Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (package.sizeBytes > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(formatBytes(package.sizeBytes),
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.textTertiary)),
            ),
          Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
        ],
      ),
    );
  }
}
