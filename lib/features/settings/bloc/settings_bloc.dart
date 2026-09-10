import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/repositories/auth_repository.dart';
import 'package:virtual_desktop/core/repositories/wallpaper_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  /// Every collaborator arrives through the constructor — including the
  /// wallpaper-scoped [WallpaperRepository]/[StorageService], which this
  /// bloc used to resolve from `get_it` itself with a hardcoded
  /// `wallpaperInstanceName`. Choosing an implementation is the
  /// composition root's job (convention #3): reaching into the container
  /// from an event handler meant a third wallpaper backend could no
  /// longer be swapped by re-registering, and made this the one bloc no
  /// test could construct without a fully populated global container.
  SettingsBloc({
    required SettingsRepository settingsRepository,
    required WallpaperRepository wallpaperRepository,
    required StorageService wallpaperStorageService,
    required AuthRepository authRepository,
  }) : _settingsRepository = settingsRepository,
       _wallpaperRepository = wallpaperRepository,
       _wallpaperStorageService = wallpaperStorageService,
       _authRepository = authRepository,
       super(const SettingsLoading()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsThemeModeChanged>(_onThemeModeChanged);
    on<SettingsWallpaperColorChanged>(_onWallpaperColorChanged);
    on<SettingsWallpaperImageChanged>(_onWallpaperImageChanged);
    on<SettingsWallpaperResetToColor>(_onWallpaperResetToColor);
  }

  final SettingsRepository _settingsRepository;
  final WallpaperRepository _wallpaperRepository;
  final StorageService _wallpaperStorageService;
  final AuthRepository _authRepository;

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    // Checked before load(): settings keys are scoped per user, so
    // SettingsRepository itself can't answer with no signed-in user.
    final user = _authRepository.currentUser;
    if (user == null) {
      // Signed out mid-load — emit defaults rather than throwing out of the
      // event handler, which would leave Settings stuck on its spinner.
      emit(const SettingsLoaded(AppSettings()));
      return;
    }
    var settings = await _settingsRepository.load();
    final wallpapers = await _wallpaperRepository
        .watchWallpapers(user.uid)
        .first;
    final matching = wallpapers.where((w) => w.isSet);

    if (matching.isNotEmpty) {
      final storageKey = matching.first.storageKey!;
      final urlResult = await _wallpaperStorageService.getDownloadUrl(
        storageKey,
      );

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
