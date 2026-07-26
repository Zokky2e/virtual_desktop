import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum WallpaperType { color, image }

class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.wallpaperType = WallpaperType.color,
    this.wallpaperColorValue = 0xFF1E2A38,
    this.wallpaperImageUrl,
  });

  final ThemeMode themeMode;
  final WallpaperType wallpaperType;

  /// Stored as an int (Color.value) rather than a Color directly, since
  /// Color isn't trivially JSON/SharedPreferences-serializable on its own.
  final int wallpaperColorValue;
  final String? wallpaperImageUrl;

  Color get wallpaperColor => Color(wallpaperColorValue);

  AppSettings copyWith({
    ThemeMode? themeMode,
    WallpaperType? wallpaperType,
    int? wallpaperColorValue,
    String? wallpaperImageUrl,
    bool clearWallpaperImageUrl = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      wallpaperType: wallpaperType ?? this.wallpaperType,
      wallpaperColorValue: wallpaperColorValue ?? this.wallpaperColorValue,
      wallpaperImageUrl: clearWallpaperImageUrl
          ? null
          : (wallpaperImageUrl ?? this.wallpaperImageUrl),
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    wallpaperType,
    wallpaperColorValue,
    wallpaperImageUrl,
  ];
}
