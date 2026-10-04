import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/src/application/settings_controller.dart';
import 'package:machine_info/src/domain/entities.dart';
import 'package:machine_info/src/domain/settings_repository.dart';

class _Repo implements SettingsRepository {
  _Repo(this.value);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

void main() {
  test('automatic by system follows the OS', () async {
    final controller = SettingsController(_Repo(const AppSettings()));
    await controller.load();
    expect(controller.themeMode, ThemeMode.system);
    controller.dispose();
  });

  test('automatic by schedule switches between day and night', () async {
    var now = DateTime(2026, 10, 4, 12);
    final repo = _Repo(const AppSettings(autoThemeSource: AutoThemeSource.schedule));
    final controller = SettingsController(repo, clock: () => now);
    await controller.load();
    expect(controller.themeMode, ThemeMode.light);
    now = DateTime(2026, 10, 4, 21);
    expect(controller.themeMode, ThemeMode.dark);
    now = DateTime(2026, 10, 4, 5);
    expect(controller.themeMode, ThemeMode.dark);
    controller.dispose();
  });

  test('turning automatic off keeps the current look and persists it', () async {
    final repo = _Repo(const AppSettings());
    final controller = SettingsController(repo);
    await controller.load();
    await controller.setAutomatic(false, current: Brightness.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(repo.value.themePreference, ThemePreference.dark);
    await controller.completeOnboarding();
    expect(repo.value.onboardingCompleted, isTrue);
    controller.dispose();
  });
}
