import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/entities.dart';
import '../domain/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SettingsRepository _repository;
  final DateTime Function() _clock;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  Timer? _scheduleTimer;
  bool? _lastScheduleIsNight;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      _settings = await _repository.load();
    } catch (_) {
      _settings = const AppSettings();
    }
    _loaded = true;
    _syncScheduleTimer();
    notifyListeners();
  }

  ThemeMode get themeMode => switch (_settings.themePreference) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.automatic => _settings.autoThemeSource == AutoThemeSource.system
            ? ThemeMode.system
            : (isNightBySchedule ? ThemeMode.dark : ThemeMode.light),
      };

  bool get isNightBySchedule {
    final hour = _clock().hour;
    final day = _settings.dayStartHour;
    final night = _settings.nightStartHour;
    if (day == night) return false;
    if (day < night) return hour < day || hour >= night;
    return hour >= night && hour < day;
  }

  Future<void> setThemePreference(ThemePreference value) => _update(_settings.copyWith(themePreference: value));

  Future<void> setAutomatic(bool enabled, {required Brightness current}) => _update(_settings.copyWith(
        themePreference: enabled
            ? ThemePreference.automatic
            : (current == Brightness.dark ? ThemePreference.dark : ThemePreference.light),
      ));

  Future<void> setAutoThemeSource(AutoThemeSource value) => _update(_settings.copyWith(autoThemeSource: value));

  Future<void> setSchedule({int? dayStartHour, int? nightStartHour}) =>
      _update(_settings.copyWith(dayStartHour: dayStartHour, nightStartHour: nightStartHour));

  Future<void> setTemperatureUnit(TemperatureUnit value) => _update(_settings.copyWith(temperatureUnit: value));

  Future<void> completeOnboarding() => _update(_settings.copyWith(onboardingCompleted: true));

  Future<void> restartOnboarding() => _update(_settings.copyWith(onboardingCompleted: false));

  Future<void> _update(AppSettings next) async {
    _settings = next;
    _syncScheduleTimer();
    notifyListeners();
    try {
      await _repository.save(next);
    } catch (_) {}
  }

  void _syncScheduleTimer() {
    final needsTimer = _settings.themePreference == ThemePreference.automatic &&
        _settings.autoThemeSource == AutoThemeSource.schedule;
    if (!needsTimer) {
      _scheduleTimer?.cancel();
      _scheduleTimer = null;
      _lastScheduleIsNight = null;
      return;
    }
    _lastScheduleIsNight = isNightBySchedule;
    _scheduleTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      final night = isNightBySchedule;
      if (night != _lastScheduleIsNight) {
        _lastScheduleIsNight = night;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    super.dispose();
  }
}
