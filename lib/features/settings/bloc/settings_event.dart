import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

class SettingsThemeModeChanged extends SettingsEvent {
  const SettingsThemeModeChanged(this.themeMode);
  final ThemeMode themeMode;
  @override
  List<Object?> get props => [themeMode];
}

class SettingsWallpaperColorChanged extends SettingsEvent {
  const SettingsWallpaperColorChanged(this.colorValue);
  final int colorValue;
  @override
  List<Object?> get props => [colorValue];
}

class SettingsWallpaperImageChanged extends SettingsEvent {
  const SettingsWallpaperImageChanged(this.imageUrl);
  final String imageUrl;
  @override
  List<Object?> get props => [imageUrl];
}

class SettingsWallpaperResetToColor extends SettingsEvent {
  const SettingsWallpaperResetToColor();
}
