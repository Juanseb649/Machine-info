import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/entities.dart';
import '../domain/island.dart';
import '../domain/island_host.dart';
import '../domain/machine_info_repository.dart';
import 'island_payload.dart';
import 'settings_controller.dart';

/// Decides when the Dynamic Island is on screen: only while the main window
/// is minimized, the feature is enabled and the platform can draw it.
class IslandController extends ChangeNotifier {
  IslandController({
    required IslandHost host,
    required SettingsController settings,
    required MachineInfoRepository repository,
    IslandPayloadBuilder builder = const IslandPayloadBuilder(),
  })  : _host = host,
        _settings = settings,
        _repository = repository,
        _builder = builder;

  final IslandHost _host;
  final SettingsController _settings;
  final MachineInfoRepository _repository;
  final IslandPayloadBuilder _builder;

  Timer? _timer;
  bool _sampling = false;
  IslandMetrics? _latest;

  /// Last readings sent to the island, also used by the in-app preview.
  IslandMetrics? get latest => _latest;

  StreamSubscription<IslandEvent>? _events;

  bool _supported = false;
  bool _minimized = false;
  bool _dismissed = false;
  bool _visible = false;

  bool get supported => _supported;
  bool get minimized => _minimized;
  bool get visible => _visible;

  bool get _shouldShow => _supported && _settings.settings.islandEnabled && _minimized && !_dismissed;

  Future<void> start() async {
    try {
      _supported = await _host.isSupported();
    } catch (_) {
      _supported = false;
    }
    _events = _host.events.listen(_onEvent);
    _settings.addListener(_onSettingsChanged);
    notifyListeners();
  }

  void _onEvent(IslandEvent event) {
    switch (event) {
      case IslandEvent.windowMinimized:
        _minimized = true;
        _dismissed = false;
      case IslandEvent.windowRestored:
      case IslandEvent.islandTapped:
        _minimized = false;
      case IslandEvent.islandDismissed:
        _dismissed = true;
    }
    _sync();
  }

  Duration? _activeInterval;

  void _onSettingsChanged() {
    if (_visible) {
      if (_activeInterval != _interval) _startSampling();
      _push();
    }
    _sync();
  }

  Future<void> _sync() async {
    final show = _shouldShow;
    if (show == _visible) return;
    _visible = show;
    notifyListeners();
    if (show) {
      _push();
      await _call(_host.show);
      _startSampling();
      unawaited(sample());
    } else {
      _stopSampling();
      await _call(_host.hide);
    }
  }

  Duration get _interval => Duration(seconds: _settings.settings.islandRefreshSeconds);

  void _startSampling() {
    _timer?.cancel();
    _activeInterval = _interval;
    _timer = Timer.periodic(_interval, (_) => sample());
  }

  void _stopSampling() {
    _timer?.cancel();
    _timer = null;
    _activeInterval = null;
  }

  /// Uses a snapshot the app already has, so the island opens with numbers
  /// instead of waiting for the first sample. Ignored while the island is
  /// visible, because it then samples on its own.
  void seed(HardwareSnapshot? snapshot) {
    if (snapshot == null || _visible) return;
    _latest = IslandMetrics.fromSnapshot(snapshot);
  }

  /// Reads the hardware once and sends it to the island. Overlapping calls
  /// are skipped so a slow sensor read never piles up work.
  Future<void> sample() async {
    if (_sampling) return;
    _sampling = true;
    try {
      final snapshot = await _repository.loadHardware();
      _latest = IslandMetrics.fromSnapshot(snapshot);
      notifyListeners();
      if (_visible) _push();
    } catch (_) {
      // Keep showing the previous readings; the next tick tries again.
    } finally {
      _sampling = false;
    }
  }

  void _push() {
    final metrics = _latest;
    if (metrics == null) return;
    final s = _settings.settings;
    unawaited(_call(() => _host.update(
        _builder.build(metrics, unit: s.temperatureUnit, preferred: s.islandPrimaryMetric))));
  }

  Future<void> _call(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopSampling();
    _events?.cancel();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
