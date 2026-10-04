import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities.dart';

class _Rule {
  const _Rule(this.language, this.framework, this.matches);

  final String language;
  final String framework;
  final String? Function(String path, String base) matches;
}

String? _baseIs(String base, String path, List<String> names) => names.contains(base) ? path : null;

class TechnologyDetector {
  const TechnologyDetector();

  static final RegExp _pythonDll = RegExp(r'^(lib)?python3?\d*(\.\d+)?(\.dll|\.so(\.[\d.]+)?|\.dylib)$');
  static final RegExp _qtCore = RegExp(r'^(lib)?qt[56]core(\.dll|\.so(\.[\d.]+)?|\.dylib)$');

  static final List<_Rule> _rules = [
    _Rule('JavaScript / TypeScript', 'Electron', (p, b) {
      if (b == 'app.asar' || b == 'electron.asar' || p.contains('electron framework.framework')) return p;
      return null;
    }),
    _Rule('JavaScript', 'NW.js', (p, b) => _baseIs(b, p, ['nw.dll', 'nw_100_percent.pak', 'libnw.so'])),
    _Rule('Dart', 'Flutter', (p, b) {
      if (b == 'flutter_windows.dll' || b == 'libflutter_linux_gtk.so' || p.contains('fluttermacos.framework')) {
        return p;
      }
      return p.contains('flutter_assets') ? p : null;
    }),
    _Rule('C#', 'Unity', (p, b) {
      if (b == 'unityplayer.dll' || b == 'unityplayer.so' || b == 'unityplayer.dylib' || b == 'gameassembly.dll') {
        return p;
      }
      return null;
    }),
    _Rule('C++', 'Unreal Engine', (p, b) => p.contains('engine/binaries/') || b.endsWith('-shipping.exe') ? p : null),
    _Rule('GDScript / C#', 'Godot', (p, b) => b.endsWith('.pck') ? p : null),
    _Rule('Java / Kotlin', 'JVM', (p, b) {
      if (b.endsWith('.jar') || b == 'jvm.dll' || b == 'libjvm.so' || b == 'libjvm.dylib') return p;
      return null;
    }),
    _Rule('C#', '.NET', (p, b) {
      if (b.endsWith('.runtimeconfig.json') || b.endsWith('.deps.json') || b.endsWith('.exe.config')) return p;
      return _baseIs(b, p, ['coreclr.dll', 'system.private.corelib.dll', 'mscorlib.dll', 'libcoreclr.so']);
    }),
    _Rule('Python', '', (p, b) {
      if (b.endsWith('.pyd') || b == 'base_library.zip' || _pythonDll.hasMatch(b)) return p;
      return null;
    }),
    _Rule('C++', 'Qt', (p, b) => _qtCore.hasMatch(b) || p.contains('qtcore.framework') ? p : null),
    _Rule('C++', 'CEF (Chromium)', (p, b) {
      if (b == 'libcef.dll' || b == 'libcef.so' || p.contains('chromium embedded framework.framework')) return p;
      return null;
    }),
    _Rule('C', 'GTK', (p, b) => b.startsWith('libgtk-3') || b.startsWith('libgtk-4') ? p : null),
    _Rule('C++', 'wxWidgets', (p, b) => b.startsWith('wxbase') || b.startsWith('wxmsw') ? p : null),
    _Rule('Swift', 'Cocoa / SwiftUI', (p, b) => b == 'libswiftcore.dylib' ? p : null),
    _Rule('C++', 'Win32 (MSVC)', (p, b) => _baseIs(b, p, ['msvcp140.dll', 'vcruntime140.dll', 'mfc140u.dll'])),
  ];

  AppTechnology fromPaths(Iterable<String> paths) {
    final normalized = [for (final p in paths) p.replaceAll('\\', '/').toLowerCase()];
    for (final rule in _rules) {
      for (final path in normalized) {
        final slash = path.lastIndexOf('/');
        final base = slash >= 0 ? path.substring(slash + 1) : path;
        final hit = rule.matches(path, base);
        if (hit != null) {
          return AppTechnology(language: rule.language, framework: rule.framework, evidence: [hit]);
        }
      }
    }
    return AppTechnology.unknown;
  }

  AppTechnology fromExecutable(Uint8List head, {String name = ''}) {
    if (head.length >= 2 && head[0] == 0x23 && head[1] == 0x21) {
      final end = head.indexOf(0x0A);
      final line = latin1.decode(head.sublist(2, end < 0 ? head.length : end)).trim().toLowerCase();
      final evidence = ['#!$line'];
      if (line.contains('python')) return AppTechnology(language: 'Python', framework: 'Script', evidence: evidence);
      if (line.contains('node')) return AppTechnology(language: 'JavaScript', framework: 'Node.js', evidence: evidence);
      if (line.contains('perl')) return AppTechnology(language: 'Perl', framework: 'Script', evidence: evidence);
      if (line.contains('ruby')) return AppTechnology(language: 'Ruby', framework: 'Script', evidence: evidence);
      if (line.contains('sh')) return AppTechnology(language: 'Shell', framework: 'Script', evidence: evidence);
      return AppTechnology(language: 'Script', framework: '', evidence: evidence);
    }

    final isElf = head.length > 4 && head[0] == 0x7F && head[1] == 0x45 && head[2] == 0x4C && head[3] == 0x46;
    final isPe = head.length > 2 && head[0] == 0x4D && head[1] == 0x5A;
    final isMachO = head.length > 4 &&
        ((head[0] == 0xCF && head[1] == 0xFA && head[2] == 0xED && head[3] == 0xFE) ||
            (head[0] == 0xCA && head[1] == 0xFE && head[2] == 0xBA && head[3] == 0xBE));
    if (!isElf && !isPe && !isMachO) return AppTechnology.unknown;

    final text = latin1.decode(head, allowInvalid: true);
    final lower = text.toLowerCase();
    final label = name.isEmpty ? 'ejecutable' : name;
    AppTechnology found(String language, String framework, String marker) =>
        AppTechnology(language: language, framework: framework, evidence: ['$label contiene "$marker"']);

    if (text.contains('Go buildinf:')) return found('Go', '', 'Go buildinf:');
    if (text.contains('/rustc/') || text.contains('rust_panic')) return found('Rust', '', 'rustc');
    if (lower.contains('mscoree.dll')) return found('C#', '.NET Framework', 'mscoree.dll');
    if (lower.contains('libflutter_linux_gtk')) return found('Dart', 'Flutter', 'libflutter_linux_gtk');
    if (lower.contains('qt6core') || lower.contains('qt5core')) return found('C++', 'Qt', 'QtCore');
    if (lower.contains('libgtk-3') || lower.contains('libgtk-4')) return found('C', 'GTK', 'libgtk');
    if (lower.contains('libswiftcore')) return found('Swift', 'Cocoa / SwiftUI', 'libswiftCore');
    if (lower.contains('msvcp140') || lower.contains('libstdc++') || lower.contains('libc++')) {
      return found('C++', 'Nativo', lower.contains('msvcp140') ? 'msvcp140.dll' : 'libstdc++');
    }
    final format = isPe ? 'PE' : (isElf ? 'ELF' : 'Mach-O');
    return AppTechnology(language: 'C / C++', framework: 'Nativo', evidence: ['$label es un binario $format']);
  }
}
