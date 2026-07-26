import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';
import '../../repositories/settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _themeModeKey = 'settings.themeMode';
  static const _wallpaperTypeKey = 'settings.wallpaperType';
  static const _wallpaperColorKey = 'settings.wallpaperColorValue';
  static const _wallpaperImageUrlKey = 'settings.wallpaperImageUrl';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey);
    final wallpaperTypeIndex = prefs.getInt(_wallpaperTypeKey);
    final wallpaperColorValue = prefs.getInt(_wallpaperColorKey);
    final wallpaperImageUrl = prefs.getString(_wallpaperImageUrlKey);
    return AppSettings(
      themeMode: themeModeIndex != null
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.dark,
      wallpaperType: wallpaperTypeIndex != null
          ? WallpaperType.values[wallpaperTypeIndex]
          : WallpaperType.color,
      wallpaperColorValue: wallpaperColorValue ?? 0xFF1E2A38,
      wallpaperImageUrl: wallpaperImageUrl,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, settings.themeMode.index);
    await prefs.setInt(_wallpaperTypeKey, settings.wallpaperType.index);
    await prefs.setInt(_wallpaperColorKey, settings.wallpaperColorValue);
    if (settings.wallpaperImageUrl != null) {
      await prefs.setString(_wallpaperImageUrlKey, settings.wallpaperImageUrl!);
    } else {
      await prefs.remove(_wallpaperImageUrlKey);
    }
  }
}
