import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities.dart';
import '../domain/settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  const SharedPrefsSettingsRepository();

  static const _theme = 'theme_preference';
  static const _autoSource = 'auto_theme_source';
  static const _dayStart = 'day_start_hour';
  static const _nightStart = 'night_start_hour';
  static const _unit = 'temperature_unit';
  static const _onboarding = 'onboarding_completed';
  static const _islandEnabled = 'island_enabled';
  static const _islandMetric = 'island_primary_metric';
  static const _islandRefresh = 'island_refresh_seconds';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = AppSettings();
    return AppSettings(
      themePreference: _enum(ThemePreference.values, prefs.getString(_theme), defaults.themePreference),
      autoThemeSource: _enum(AutoThemeSource.values, prefs.getString(_autoSource), defaults.autoThemeSource),
      dayStartHour: prefs.getInt(_dayStart) ?? defaults.dayStartHour,
      nightStartHour: prefs.getInt(_nightStart) ?? defaults.nightStartHour,
      temperatureUnit: _enum(TemperatureUnit.values, prefs.getString(_unit), defaults.temperatureUnit),
      onboardingCompleted: prefs.getBool(_onboarding) ?? defaults.onboardingCompleted,
      islandEnabled: prefs.getBool(_islandEnabled) ?? defaults.islandEnabled,
      islandPrimaryMetric:
          _enum(IslandPrimaryMetric.values, prefs.getString(_islandMetric), defaults.islandPrimaryMetric),
      islandRefreshSeconds: (prefs.getInt(_islandRefresh) ?? defaults.islandRefreshSeconds).clamp(1, 10),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_theme, settings.themePreference.name);
    await prefs.setString(_autoSource, settings.autoThemeSource.name);
    await prefs.setInt(_dayStart, settings.dayStartHour);
    await prefs.setInt(_nightStart, settings.nightStartHour);
    await prefs.setString(_unit, settings.temperatureUnit.name);
    await prefs.setBool(_onboarding, settings.onboardingCompleted);
    await prefs.setBool(_islandEnabled, settings.islandEnabled);
    await prefs.setString(_islandMetric, settings.islandPrimaryMetric.name);
    await prefs.setInt(_islandRefresh, settings.islandRefreshSeconds);
  }

  T _enum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
