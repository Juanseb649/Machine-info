import 'entities.dart';

abstract interface class MachineInfoRepository {
  Future<HardwareSnapshot> loadHardware();
  Future<SectionResult<List<InstalledPackage>>> loadSoftware();
}
