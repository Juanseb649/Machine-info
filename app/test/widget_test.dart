import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/main.dart';
import 'package:machine_info/src/application/inventory_controller.dart';
import 'package:machine_info/src/domain/entities.dart';
import 'package:machine_info/src/domain/machine_info_repository.dart';

class FakeRepository implements MachineInfoRepository {
  @override
  Future<HardwareSnapshot> loadHardware() async => HardwareSnapshot(
        platform: 'fake',
        collectedAt: DateTime(2026),
        os: const SectionResult(
          SectionStatus.ok,
          OsInfo(
            name: 'FakeOS',
            version: '1.0',
            kernel: 'k',
            hostname: 'host',
            architecture: 'x86_64',
            uptime: Duration(minutes: 5),
          ),
        ),
        cpu: const SectionResult(SectionStatus.unsupported, null),
        memory: const SectionResult(SectionStatus.unsupported, null),
        disks: const SectionResult(SectionStatus.ok, []),
        temperatures: const SectionResult(SectionStatus.permissionDenied, []),
      );

  @override
  Future<SectionResult<List<InstalledPackage>>> loadSoftware() async => const SectionResult(
        SectionStatus.ok,
        [InstalledPackage(name: 'git', version: '2.45', publisher: 'Git', source: 'fake')],
      );
}

void main() {
  testWidgets('renders tabs with data from the repository port', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = InventoryController(FakeRepository());
    await tester.pumpWidget(MachineInfoApp(controller: controller));
    await controller.loadAll();
    await tester.pumpAndSettle();

    expect(find.text('FakeOS'), findsOneWidget);

    await tester.tap(find.text('Software'));
    await tester.pumpAndSettle();
    expect(find.text('git'), findsOneWidget);
  });
}
