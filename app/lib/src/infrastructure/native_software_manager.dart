import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:machine_info_native/machine_info_native.dart';

import '../domain/entities.dart';
import '../domain/software_manager.dart';
import 'icns_reader.dart';
import 'technology_detector.dart';

class NativeSoftwareManager implements SoftwareManager {
  NativeSoftwareManager({int maxConcurrentIcons = 4}) : _slots = maxConcurrentIcons;

  int _slots;
  final _waiting = <Completer<void>>[];

  Future<T> _limited<T>(Future<T> Function() task) async {
    if (_slots == 0) {
      final ticket = Completer<void>();
      _waiting.add(ticket);
      await ticket.future;
    } else {
      _slots--;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _slots++;
      }
    }
  }

  @override
  Future<Uint8List?> loadIcon(InstalledPackage package) {
    final iconPath = package.iconPath;
    final location = package.installLocation;
    final name = package.name;
    return _limited(() => Isolate.run(() => _loadIconSync(iconPath, location, name)));
  }

  @override
  Future<AppTechnology> detectTechnology(InstalledPackage package) {
    final location = package.installLocation;
    final iconPath = package.iconPath;
    final name = package.name;
    return Isolate.run(() => _detectSync(location, iconPath, name));
  }

  @override
  Future<UninstallResult> uninstall(InstalledPackage package) async {
    final command = package.uninstallCommand;
    if (command.isEmpty) {
      return const UninstallResult(UninstallOutcome.unsupported, 'Este programa no registra un desinstalador.');
    }
    if (Platform.isWindows) {
      final code = await Isolate.run(() => MachineInfoNative.instance.launchUninstaller(command));
      return switch (code) {
        0 => const UninstallResult(UninstallOutcome.launched),
        4 => const UninstallResult(UninstallOutcome.cancelled, 'Se canceló la solicitud de permisos.'),
        1 => const UninstallResult(UninstallOutcome.unsupported),
        _ => const UninstallResult(UninstallOutcome.failed, 'No se pudo abrir el desinstalador.'),
      };
    }
    final result = await Process.run('/bin/sh', ['-c', command]);
    if (result.exitCode == 0) return const UninstallResult(UninstallOutcome.completed);
    if (result.exitCode == 126 || (result.exitCode == 127 && command.startsWith('pkexec'))) {
      return const UninstallResult(UninstallOutcome.cancelled, 'Se canceló la autenticación.');
    }
    final error = '${result.stderr}'.trim();
    return UninstallResult(UninstallOutcome.failed, error.isEmpty ? 'Código de salida ${result.exitCode}' : error);
  }

  @override
  Future<bool> openLocation(InstalledPackage package) async {
    final location = _resolveLocation(package.installLocation, package.iconPath);
    if (location == null) return false;
    try {
      if (Platform.isWindows) {
        final isFile = FileSystemEntity.isFileSync(location);
        await Process.start('explorer.exe', isFile ? ['/select,', location] : [location]);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', location]);
      } else {
        final target = FileSystemEntity.isFileSync(location) ? File(location).parent.path : location;
        await Process.start('xdg-open', [target]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

const _systemRoots = {
  '/',
  '/usr',
  '/usr/bin',
  '/usr/lib',
  '/usr/share',
  '/opt',
  '/applications',
  '/system/applications',
  'c:/',
  'c:/windows',
  'c:/windows/system32',
  'c:/program files',
  'c:/program files (x86)',
};

String _stripIconIndex(String iconPath) {
  var path = iconPath.trim();
  if (path.startsWith('"')) {
    final close = path.indexOf('"', 1);
    if (close > 0) path = path.substring(1, close);
  }
  final match = RegExp(r',\s*-?\d+$').firstMatch(path);
  if (match != null) path = path.substring(0, match.start);
  return path.trim();
}

String? _resolveLocation(String installLocation, String iconPath) {
  if (installLocation.isNotEmpty && FileSystemEntity.typeSync(installLocation) != FileSystemEntityType.notFound) {
    return installLocation;
  }
  if (iconPath.isEmpty) return null;
  final file = _stripIconIndex(iconPath);
  if (file.isEmpty || !File(file).existsSync()) return null;
  final lower = file.toLowerCase().replaceAll('\\', '/');
  if (lower.contains('/windows/installer/')) return null;
  return File(file).parent.path;
}

bool _isSystemRoot(String path) {
  var normalized = path.replaceAll('\\', '/').toLowerCase();
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.length == 2 && normalized.endsWith(':')) return true;
  return _systemRoots.contains(normalized);
}

String _alnum(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

const _helperWords = ['unins', 'uninst', 'update', 'crash', 'helper', 'setup', 'install', 'elevat', 'notif', 'report'];

File? _mainExecutable(Directory dir, String appName) {
  final List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } catch (_) {
    return null;
  }
  final words = appName.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 1).toList();
  final compact = _alnum(appName);
  File? best;
  var bestScore = -1;
  for (final entry in entries) {
    if (entry is! File) continue;
    final base = entry.uri.pathSegments.last.toLowerCase();
    final isCandidate = Platform.isWindows ? base.endsWith('.exe') : !base.contains('.');
    if (!isCandidate) continue;
    final stem = _alnum(base.endsWith('.exe') ? base.substring(0, base.length - 4) : base);
    if (_helperWords.any(stem.contains)) continue;
    var score = 0;
    if (stem.isNotEmpty && compact.contains(stem)) score += 4;
    if (words.isNotEmpty && stem.contains(words.first)) score += 3;
    score += words.where(stem.contains).length;
    if (score > bestScore) {
      bestScore = score;
      best = entry;
    }
  }
  return best;
}

Uint8List? _loadIconSync(String iconPath, String installLocation, String name) {
  if (Platform.isWindows) {
    var reference = iconPath;
    if (reference.isEmpty || _stripIconIndex(reference).toLowerCase().endsWith('.msi')) {
      final location = _resolveLocation(installLocation, '');
      if (location == null || !FileSystemEntity.isDirectorySync(location)) return null;
      final exe = _mainExecutable(Directory(location), name);
      if (exe == null) return null;
      reference = exe.path;
    }
    final encoded = MachineInfoNative.instance.appIconPngBase64(reference, size: 64);
    return encoded == null ? null : base64Decode(encoded);
  }
  if (iconPath.isEmpty) return null;
  final file = File(iconPath);
  if (!file.existsSync()) return null;
  final bytes = file.readAsBytesSync();
  if (iconPath.toLowerCase().endsWith('.icns')) return const IcnsReader().extractPng(bytes);
  return bytes;
}

List<String> _listRelative(Directory root, {int maxDepth = 3, int maxEntries = 5000}) {
  final result = <String>[];
  final rootPath = root.path;
  void walk(Directory dir, int depth) {
    if (result.length >= maxEntries) return;
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final entry in entries) {
      if (result.length >= maxEntries) return;
      final relative = entry.path.length > rootPath.length ? entry.path.substring(rootPath.length + 1) : entry.path;
      result.add(relative);
      if (entry is Directory && depth < maxDepth) walk(entry, depth + 1);
    }
  }

  walk(root, 0);
  return result;
}

Uint8List _readHead(File file, {int limit = 8 * 1024 * 1024}) {
  final handle = file.openSync();
  try {
    final length = handle.lengthSync();
    return handle.readSync(length < limit ? length : limit);
  } finally {
    handle.closeSync();
  }
}

AppTechnology _detectSync(String installLocation, String iconPath, String name) {
  const detector = TechnologyDetector();
  final location = _resolveLocation(installLocation, iconPath);
  if (location == null || _isSystemRoot(location)) return AppTechnology.unknown;

  if (FileSystemEntity.isFileSync(location)) {
    try {
      final file = File(location);
      return detector.fromExecutable(_readHead(file), name: file.uri.pathSegments.last);
    } catch (_) {
      return AppTechnology.unknown;
    }
  }

  final dir = Directory(location);
  final fromFiles = detector.fromPaths(_listRelative(dir));
  if (fromFiles.isKnown && fromFiles.framework != 'Win32 (MSVC)') return fromFiles;

  var exeDir = dir;
  final macBinaries = Directory('${dir.path}/Contents/MacOS');
  if (Platform.isMacOS && macBinaries.existsSync()) exeDir = macBinaries;
  final exe = _mainExecutable(exeDir, name);
  if (exe != null) {
    try {
      final fromBinary = detector.fromExecutable(_readHead(exe), name: exe.uri.pathSegments.last);
      if (fromBinary.isKnown && (fromBinary.framework != 'Nativo' || !fromFiles.isKnown)) return fromBinary;
    } catch (_) {}
  }
  return fromFiles;
}
