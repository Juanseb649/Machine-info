import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _CollectNative = Pointer<Utf8> Function(Pointer<Utf8> section);
typedef _FreeNative = Void Function(Pointer<Utf8> value);
typedef _FreeDart = void Function(Pointer<Utf8> value);
typedef _VersionNative = Pointer<Utf8> Function();
typedef _IconNative = Pointer<Utf8> Function(Pointer<Utf8> path, Int32 size);
typedef _IconDart = Pointer<Utf8> Function(Pointer<Utf8> path, int size);
typedef _UninstallNative = Int32 Function(Pointer<Utf8> command);
typedef _UninstallDart = int Function(Pointer<Utf8> command);

class MachineInfoNative {
  MachineInfoNative._(DynamicLibrary library)
      : _collect = library.lookupFunction<_CollectNative, _CollectNative>('mi_collect_json'),
        _free = library.lookupFunction<_FreeNative, _FreeDart>('mi_free_string'),
        _version = library.lookupFunction<_VersionNative, _VersionNative>('mi_version'),
        _icon = library.lookupFunction<_IconNative, _IconDart>('mi_app_icon_png_base64'),
        _uninstall = library.lookupFunction<_UninstallNative, _UninstallDart>('mi_launch_uninstaller');

  static MachineInfoNative? _instance;

  static MachineInfoNative get instance => _instance ??= MachineInfoNative._(_openLibrary());

  final _CollectNative _collect;
  final _FreeDart _free;
  final _VersionNative _version;
  final _IconDart _icon;
  final _UninstallDart _uninstall;

  String get version => _version().toDartString();

  String collectJson(String section) {
    final sectionPtr = section.toNativeUtf8();
    try {
      final result = _collect(sectionPtr);
      if (result == nullptr) {
        throw StateError('machineinfo returned no data for "$section"');
      }
      try {
        return result.toDartString();
      } finally {
        _free(result);
      }
    } finally {
      malloc.free(sectionPtr);
    }
  }

  String? appIconPngBase64(String iconPath, {int size = 64}) {
    final pathPtr = iconPath.toNativeUtf8();
    try {
      final result = _icon(pathPtr, size);
      if (result == nullptr) return null;
      try {
        return result.toDartString();
      } finally {
        _free(result);
      }
    } finally {
      malloc.free(pathPtr);
    }
  }

  int launchUninstaller(String command) {
    final commandPtr = command.toNativeUtf8();
    try {
      return _uninstall(commandPtr);
    } finally {
      malloc.free(commandPtr);
    }
  }

  static DynamicLibrary _openLibrary() {
    final override = Platform.environment['MACHINEINFO_LIB'];
    if (override != null && override.isNotEmpty) return DynamicLibrary.open(override);
    if (Platform.isMacOS) return DynamicLibrary.open('machine_info_native.framework/machine_info_native');
    if (Platform.isLinux) return DynamicLibrary.open('libmachineinfo.so');
    if (Platform.isWindows) return DynamicLibrary.open('machineinfo.dll');
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
