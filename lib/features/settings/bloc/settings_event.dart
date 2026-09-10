import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/models/wallpaper_item.dart';

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

/// Upload a newly picked image and apply it as the wallpaper.
///
/// The whole dedupe → upload → save → select → resolve-URL sequence lives
/// in SettingsBloc. It used to sit in a State method, which meant a third
/// wallpaper backend had to satisfy a call order defined in a widget, and
/// none of it was reachable from a test. The widget's job now ends at the
/// file picker.
class SettingsWallpaperUploadRequested extends SettingsEvent {
  const SettingsWallpaperUploadRequested({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  // bytes is compared by length rather than content: two different picks
  // of the same file should still be distinct events, and hashing a
  // multi-megabyte image on every comparison is not worth it.
  @override
  List<Object?> get props => [fileName, bytes.length];
}

/// Apply a wallpaper the user already uploaded, picked from the gallery.
class SettingsWallpaperSelected extends SettingsEvent {
  const SettingsWallpaperSelected(this.item);
  final WallpaperItem item;
  @override
  List<Object?> get props => [item];
}
