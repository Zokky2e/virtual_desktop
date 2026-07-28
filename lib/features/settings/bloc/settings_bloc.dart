import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/di/injector.dart';
import 'package:virtual_desktop/core/models/wallpaper_item.dart';
import 'package:virtual_desktop/core/repositories/auth_repository.dart';
import 'package:virtual_desktop/core/repositories/wallpaper_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository,
      super(const SettingsLoading()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsThemeModeChanged>(_onThemeModeChanged);
    on<SettingsWallpaperColorChanged>(_onWallpaperColorChanged);
    on<SettingsWallpaperImageChanged>(_onWallpaperImageChanged);
    on<SettingsWallpaperResetToColor>(_onWallpaperResetToColor);
  }

  final SettingsRepository _settingsRepository;

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    var settings = await _settingsRepository.load();
    final wallpaperRepository = getIt<WallpaperRepository>();
    final authRepository = getIt<AuthRepository>();
    final storageService = getIt<StorageService>();
    final wallpapers = await wallpaperRepository
        .watchWallpapers(authRepository.currentUser!.uid)
        .first;
    final matching = wallpapers.where((w) => w.isSet);

    if (matching.isNotEmpty) {
      final storageKey = matching.first.storageKey!;
      final urlResult = await storageService.getDownloadUrl(storageKey);

      urlResult.match(
        (_) {},
        (url) => {
          settings = settings.copyWith(
            wallpaperType: WallpaperType.image,
            wallpaperImageUrl: url,
          ),
        },
      );
    }
    emit(SettingsLoaded(settings));
  }

  Future<void> _onThemeModeChanged(
    SettingsThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final current = state;
    if (current is! SettingsLoaded) return;
    final updated = current.settings.copyWith(themeMode: event.themeMode);
    emit(SettingsLoaded(updated));
    await _settingsRepository.save(updated);
  }

  Future<void> _onWallpaperColorChanged(
    SettingsWallpaperColorChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final current = state;
    if (current is! SettingsLoaded) return;
    final updated = current.settings.copyWith(
      wallpaperType: WallpaperType.color,
      wallpaperColorValue: event.colorValue,
    );
    emit(SettingsLoaded(updated));
    await _settingsRepository.save(updated);
  }

  Future<void> _onWallpaperImageChanged(
    SettingsWallpaperImageChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final current = state;
    if (current is! SettingsLoaded) return;
    final updated = current.settings.copyWith(
      wallpaperType: WallpaperType.image,
      wallpaperImageUrl: event.imageUrl,
    );
    emit(SettingsLoaded(updated));
    await _settingsRepository.save(updated);
  }

  Future<void> _onWallpaperResetToColor(
    SettingsWallpaperResetToColor event,
    Emitter<SettingsState> emit,
  ) async {
    final current = state;
    if (current is! SettingsLoaded) return;
    final updated = current.settings.copyWith(
      wallpaperType: WallpaperType.color,
      clearWallpaperImageUrl: true,
    );
    emit(SettingsLoaded(updated));
    await _settingsRepository.save(updated);
  }
}
