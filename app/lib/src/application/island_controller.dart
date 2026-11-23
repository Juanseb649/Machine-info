import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/island_host.dart';
import 'settings_controller.dart';

/// Decides when the Dynamic Island is on screen: only while the main window
/// is minimized, the feature is enabled and the platform can draw it.
class IslandController extends ChangeNotifier {
  IslandController({required IslandHost host, required SettingsController settings})
      : _host = host,
        _settings = settings;

  final IslandHost _host;
  final SettingsController _settings;

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

  void _onSettingsChanged() => _sync();

  Future<void> _sync() async {
    final show = _shouldShow;
    if (show == _visible) return;
    _visible = show;
    notifyListeners();
    try {
      if (show) {
        await _host.show();
      } else {
        await _host.hide();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _events?.cancel();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
