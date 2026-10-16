import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('sharedPrefsProvider doit être surchargé'));

final class Settings {
  /// Délai minimal entre deux interrogations de GitHub ; 0 = manuel uniquement.
  final int refreshHours;
  final ThemeMode themeMode;
  const Settings({this.refreshHours = 6, this.themeMode = ThemeMode.dark});

  Settings copyWith({int? refreshHours, ThemeMode? themeMode}) => Settings(
        refreshHours: refreshHours ?? this.refreshHours,
        themeMode: themeMode ?? this.themeMode,
      );

  Duration? get refreshInterval =>
      refreshHours <= 0 ? null : Duration(hours: refreshHours);
}

const refreshChoices = <int>[1, 6, 12, 24, 0];

final class SettingsNotifier extends Notifier<Settings> {
  static const _hoursKey = 'settings.refreshHours';
  static const _themeKey = 'settings.theme';

  @override
  Settings build() {
    final p = ref.read(sharedPrefsProvider);
    final hours = p.getInt(_hoursKey);
    final theme = ThemeMode.values.firstWhere(
      (m) => m.name == p.getString(_themeKey),
      orElse: () => ThemeMode.dark,
    );
    return Settings(
      refreshHours: hours != null && refreshChoices.contains(hours) ? hours : 6,
      themeMode: theme,
    );
  }

  Future<void> setRefreshHours(int hours) async {
    state = state.copyWith(refreshHours: hours);
    await ref.read(sharedPrefsProvider).setInt(_hoursKey, hours);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPrefsProvider).setString(_themeKey, mode.name);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
