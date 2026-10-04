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
  }

  T _enum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
