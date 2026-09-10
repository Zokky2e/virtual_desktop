import 'package:equatable/equatable.dart';
import '../../../core/models/app_settings.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  const SettingsLoaded(
    this.settings, {
    this.isUploadingWallpaper = false,
    this.notice,
    this.noticeId = 0,
  });

  final AppSettings settings;

  /// True while a wallpaper upload is in flight. Lived in the Settings
  /// widget as a local bool until the workflow moved into this bloc.
  final bool isUploadingWallpaper;

  /// Transient message for a SnackBar — an upload failure, or the notice
  /// that an existing wallpaper was reused instead of re-uploaded.
  final String? notice;

  /// Increments with every new [notice]. Without it, Equatable would treat
  /// two identical consecutive messages as the same state and BlocListener
  /// would show the SnackBar only once.
  final int noticeId;

  SettingsLoaded copyWith({
    AppSettings? settings,
    bool? isUploadingWallpaper,

    /// Pass a message to raise a new notice (which bumps [noticeId]).
    /// Omit it to clear — a notice is one-shot, so carrying the previous
    /// one forward would re-fire it on the next unrelated change.
    String? notice,
  }) {
    return SettingsLoaded(
      settings ?? this.settings,
      isUploadingWallpaper: isUploadingWallpaper ?? this.isUploadingWallpaper,
      notice: notice,
      noticeId: notice == null ? noticeId : noticeId + 1,
    );
  }

  @override
  List<Object?> get props => [settings, isUploadingWallpaper, notice, noticeId];
}
