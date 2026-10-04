import 'dart:typed_data';

import '../domain/entities.dart';
import '../domain/software_manager.dart';

class SoftwareController {
  SoftwareController(this._manager);

  final SoftwareManager _manager;
  final Map<String, Future<Uint8List?>> _icons = {};
  final Map<String, Future<AppTechnology>> _technologies = {};
  final Map<String, Uint8List?> _resolvedIcons = {};

  bool isIconResolved(InstalledPackage package) => _resolvedIcons.containsKey(package.id);

  Uint8List? resolvedIcon(InstalledPackage package) => _resolvedIcons[package.id];

  Future<Uint8List?> icon(InstalledPackage package) => _icons.putIfAbsent(package.id, () async {
        Uint8List? bytes;
        try {
          bytes = package.hasIcon || package.installLocation.isNotEmpty ? await _manager.loadIcon(package) : null;
        } catch (_) {
          bytes = null;
        }
        _resolvedIcons[package.id] = bytes;
        return bytes;
      });

  Future<AppTechnology> technology(InstalledPackage package) => _technologies.putIfAbsent(
        package.id,
        () => _manager.detectTechnology(package).catchError((Object _) => AppTechnology.unknown),
      );

  Future<bool> openLocation(InstalledPackage package) => _manager.openLocation(package);

  Future<UninstallResult> uninstall(InstalledPackage package) async {
    try {
      return await _manager.uninstall(package);
    } catch (e) {
      return UninstallResult(UninstallOutcome.failed, '$e');
    }
  }
}
