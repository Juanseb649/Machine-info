import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/src/infrastructure/icns_reader.dart';
import 'package:machine_info/src/infrastructure/technology_detector.dart';

Uint8List _bytes(List<int> prefix, String body) => Uint8List.fromList([...prefix, ...latin1.encode(body)]);

void main() {
  const detector = TechnologyDetector();

  test('detects frameworks from installed files', () {
    expect(detector.fromPaths([r'resources\app.asar', 'Code.exe']).framework, 'Electron');
    expect(detector.fromPaths(['flutter_windows.dll', 'app.exe']).language, 'Dart');
    expect(detector.fromPaths(['lib/app.jar']).framework, 'JVM');
    expect(detector.fromPaths(['App.runtimeconfig.json']).framework, '.NET');
    expect(detector.fromPaths(['python311.dll']).language, 'Python');
    expect(detector.fromPaths(['Qt6Core.dll']).framework, 'Qt');
    expect(detector.fromPaths(['UnityPlayer.dll']).framework, 'Unity');
    expect(detector.fromPaths(['readme.txt']).isKnown, isFalse);
  });

  test('prefers specific frameworks over the C++ runtime', () {
    final tech = detector.fromPaths(['msvcp140.dll', 'resources/app.asar']);
    expect(tech.framework, 'Electron');
    expect(tech.evidence.single, 'resources/app.asar');
  });

  test('detects languages from executables', () {
    expect(detector.fromExecutable(_bytes([], '#!/usr/bin/env python3\nprint(1)')).language, 'Python');
    expect(detector.fromExecutable(_bytes([], '#!/bin/bash\necho')).language, 'Shell');
    expect(detector.fromExecutable(_bytes([0x7F, 0x45, 0x4C, 0x46], '...Go buildinf:...')).language, 'Go');
    expect(detector.fromExecutable(_bytes([0x4D, 0x5A], '.../rustc/abc/library...')).language, 'Rust');
    expect(detector.fromExecutable(_bytes([0x4D, 0x5A], '...mscoree.dll...')).framework, '.NET Framework');
    expect(detector.fromExecutable(_bytes([0x4D, 0x5A], 'plain')).language, 'C / C++');
    expect(detector.fromExecutable(_bytes([], 'not a binary')).isKnown, isFalse);
  });

  test('extracts the preferred PNG from an icns container', () {
    final png128 = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];
    final png512 = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 9, 9];
    List<int> entry(String type, List<int> data) {
      final header = ByteData(8)..setUint32(4, data.length + 8);
      final bytes = header.buffer.asUint8List();
      bytes.setRange(0, 4, ascii.encode(type));
      return [...bytes, ...data];
    }

    final body = [...entry('ic09', png512), ...entry('ic07', png128), ...entry('is32', [0, 0, 0])];
    final header = ByteData(8)..setUint32(4, body.length + 8);
    final file = header.buffer.asUint8List()..setRange(0, 4, ascii.encode('icns'));
    final png = const IcnsReader().extractPng(Uint8List.fromList([...file, ...body]));
    expect(png, Uint8List.fromList(png128));
    expect(const IcnsReader().extractPng(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
