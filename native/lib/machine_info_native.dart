import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _CollectNative = Pointer<Utf8> Function(Pointer<Utf8> section);
typedef _FreeNative = Void Function(Pointer<Utf8> value);
typedef _FreeDart = void Function(Pointer<Utf8> value);
typedef _VersionNative = Pointer<Utf8> Function();

class MachineInfoNative {
  MachineInfoNative._(DynamicLibrary library)
      : _collect = library.lookupFunction<_CollectNative, _CollectNative>('mi_collect_json'),
        _free = library.lookupFunction<_FreeNative, _FreeDart>('mi_free_string'),
        _version = library.lookupFunction<_VersionNative, _VersionNative>('mi_version');

  static MachineInfoNative? _instance;

  static MachineInfoNative get instance => _instance ??= MachineInfoNative._(_openLibrary());

  final _CollectNative _collect;
  final _FreeDart _free;
  final _VersionNative _version;

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

  static DynamicLibrary _openLibrary() {
    final override = Platform.environment['MACHINEINFO_LIB'];
    if (override != null && override.isNotEmpty) return DynamicLibrary.open(override);
    if (Platform.isMacOS) return DynamicLibrary.open('machine_info_native.framework/machine_info_native');
    if (Platform.isLinux) return DynamicLibrary.open('libmachineinfo.so');
    if (Platform.isWindows) return DynamicLibrary.open('machineinfo.dll');
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
