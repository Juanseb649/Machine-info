import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../widgets/common.dart';

class SoftwareTab extends StatefulWidget {
  const SoftwareTab({super.key, required this.section});

  final SectionResult<List<InstalledPackage>> section;

  @override
  State<SoftwareTab> createState() => _SoftwareTabState();
}

class _SoftwareTabState extends State<SoftwareTab> {
  final _search = TextEditingController();
  String? _source;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InstalledPackage> _filter(List<InstalledPackage> all) {
    final query = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (_source != null && p.source != _source) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) || p.publisher.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SectionView<List<InstalledPackage>>(
      section: widget.section,
      builder: (context, packages) {
        final sources = packages.map((p) => p.source).toSet().toList()..sort();
        final visible = _filter(packages);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nombre o editor',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String?>(
                  value: _source,
                  hint: const Text('Todas las fuentes'),
                  onChanged: (v) => setState(() => _source = v),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas las fuentes')),
                    for (final s in sources) DropdownMenuItem(value: s, child: Text(s)),
                  ],
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${visible.length} de ${packages.length} programas',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = visible[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.name),
                    subtitle: p.publisher.isEmpty ? null : Text(p.publisher, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(p.version.isEmpty ? '—' : p.version),
                      const SizedBox(width: 12),
                      Chip(label: Text(p.source), visualDensity: VisualDensity.compact),
                    ]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
