import 'dart:typed_data';

import 'entities.dart';

abstract interface class SoftwareManager {
  Future<Uint8List?> loadIcon(InstalledPackage package);
  Future<AppTechnology> detectTechnology(InstalledPackage package);
  Future<UninstallResult> uninstall(InstalledPackage package);
  Future<bool> openLocation(InstalledPackage package);
}
