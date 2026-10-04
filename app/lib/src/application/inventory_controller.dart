import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/entities.dart';
import '../domain/machine_info_repository.dart';

class AsyncState<T> {
  const AsyncState({this.value, this.error, this.loading = false});

  final T? value;
  final Object? error;
  final bool loading;

  AsyncState<T> startLoading() => AsyncState(value: value, loading: true);
}

class InventoryController extends ChangeNotifier {
  InventoryController(this._repository, {this.refreshInterval = const Duration(seconds: 5)});

  final MachineInfoRepository _repository;
  final Duration refreshInterval;

  AsyncState<HardwareSnapshot> hardware = const AsyncState();
  AsyncState<SectionResult<List<InstalledPackage>>> software = const AsyncState();

  Timer? _timer;
  bool get autoRefresh => _timer != null;

  Future<void> loadAll() => Future.wait([refreshHardware(), refreshSoftware()]);

  Future<void> refreshHardware() async {
    if (hardware.loading) return;
    hardware = hardware.startLoading();
    notifyListeners();
    try {
      hardware = AsyncState(value: await _repository.loadHardware());
    } catch (e) {
      hardware = AsyncState(value: hardware.value, error: e);
    }
    notifyListeners();
  }

  Future<void> refreshSoftware() async {
    if (software.loading) return;
    software = software.startLoading();
    notifyListeners();
    try {
      software = AsyncState(value: await _repository.loadSoftware());
    } catch (e) {
      software = AsyncState(value: software.value, error: e);
    }
    notifyListeners();
  }

  void setAutoRefresh(bool enabled) {
    _timer?.cancel();
    _timer = enabled ? Timer.periodic(refreshInterval, (_) => refreshHardware()) : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
