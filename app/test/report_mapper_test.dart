import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/src/domain/entities.dart';
import 'package:machine_info/src/infrastructure/report_mapper.dart';

const _hardwareJson = '''
{"schemaVersion":1,"platform":"linux","generatedAt":1700000000,
 "os":{"status":"ok","data":{"name":"Ubuntu","version":"24.04","kernel":"6.8","hostname":"pc","architecture":"x86_64","uptimeSeconds":7200}},
 "cpu":{"status":"ok","data":{"model":"Ryzen","vendor":"AMD","architecture":"x86_64","physicalCores":8,"logicalCores":16,"baseFrequencyMhz":3800.00,"usagePercent":12.50}},
 "memory":{"status":"ok","data":{"totalBytes":1000,"availableBytes":250,"usedBytes":750,"swapTotalBytes":0,"swapUsedBytes":0}},
 "disks":{"status":"ok","data":[{"name":"/dev/sda1","mountPoint":"/","filesystem":"ext4","kind":"fixed","totalBytes":100,"freeBytes":40,"usedBytes":60}]},
 "temperatures":{"status":"unsupported","data":[]}}
''';

void main() {
  const mapper = ReportMapper();

  test('maps hardware sections', () {
    final snapshot = mapper.hardware(jsonDecode(_hardwareJson) as Map<String, dynamic>);
    expect(snapshot.platform, 'linux');
    expect(snapshot.os.data!.uptime, const Duration(hours: 2));
    expect(snapshot.cpu.data!.logicalCores, 16);
    expect(snapshot.memory.data!.usedRatio, 0.75);
    expect(snapshot.disks.data!.single.kind, DiskKind.fixed);
    expect(snapshot.temperatures.status, SectionStatus.unsupported);
  });

  test('maps software and permission status', () {
    final ok = mapper.software(jsonDecode(
            '{"software":{"status":"ok","data":[{"name":"git","version":"2.45","publisher":"","source":"dpkg"}]}}')
        as Map<String, dynamic>);
    expect(ok.data!.single.name, 'git');
    expect(ok.data!.single.installLocation, '');
    expect(ok.data!.single.canUninstall, isFalse);

    final detailed = mapper.software(jsonDecode(
            r'{"software":{"status":"ok","data":[{"name":"Code","version":"1.9","publisher":"Microsoft","source":"user",'
            r'"installLocation":"C:\\Apps\\Code","iconPath":"C:\\Apps\\Code\\Code.exe,0",'
            r'"uninstallCommand":"\"C:\\Apps\\Code\\unins000.exe\"","installDate":"2026-09-30","sizeBytes":4096}]}}')
        as Map<String, dynamic>);
    final code = detailed.data!.single;
    expect(code.installLocation, r'C:\Apps\Code');
    expect(code.iconPath, r'C:\Apps\Code\Code.exe,0');
    expect(code.uninstallCommand, r'"C:\Apps\Code\unins000.exe"');
    expect(code.installDate, '2026-09-30');
    expect(code.sizeBytes, 4096);
    expect(code.canUninstall, isTrue);

    final denied = mapper.software(
        jsonDecode('{"software":{"status":"permission_denied","data":[]}}') as Map<String, dynamic>);
    expect(denied.status, SectionStatus.permissionDenied);
  });

  test('throws on native error payload', () {
    expect(() => mapper.software({'error': 'unknown section'}), throwsStateError);
  });
}
