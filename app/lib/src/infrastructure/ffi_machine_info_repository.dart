import 'dart:convert';
import 'dart:isolate';

import 'package:machine_info_native/machine_info_native.dart';

import '../domain/entities.dart';
import '../domain/machine_info_repository.dart';
import 'report_mapper.dart';

class FfiMachineInfoRepository implements MachineInfoRepository {
  const FfiMachineInfoRepository({ReportMapper mapper = const ReportMapper()}) : _mapper = mapper;

  final ReportMapper _mapper;

  @override
  Future<HardwareSnapshot> loadHardware() async => _mapper.hardware(await _collect('hardware'));

  @override
  Future<SectionResult<List<InstalledPackage>>> loadSoftware() async => _mapper.software(await _collect('software'));

  Future<Map<String, dynamic>> _collect(String section) async {
    final raw = await Isolate.run(() => MachineInfoNative.instance.collectJson(section));
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
