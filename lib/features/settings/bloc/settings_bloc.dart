import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/models/wallpaper_item.dart';
import 'package:virtual_desktop/shared/utils/mime_utils.dart';
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
    on<SettingsWallpaperUploadRequested>(_onWallpaperUploadRequested);
    on<SettingsWallpaperSelected>(_onWallpaperSelected);
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

  /// The wallpaper upload workflow, start to finish: reuse an identical
  /// image if one is already stored, otherwise upload it, record it, mark
  /// it active, and resolve a URL to display. This whole sequence used to
  /// live in _SettingsWindowContentState.
  Future<void> _onWallpaperUploadRequested(
    SettingsWallpaperUploadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final current = state;
    if (current is! SettingsLoaded) return;

    final user = _authRepository.currentUser;
    if (user == null) {
      emit(current.copyWith(notice: 'Not signed in.'));
      return;
    }

    emit(current.copyWith(isUploadingWallpaper: true));

    // Dedupe first — re-picking the same file in the picker should reuse
    // the stored copy rather than upload it again.
    final existingResult = await _wallpaperRepository.findExisting(
      ownerId: user.uid,
      name: event.fileName,
      size: event.bytes.length,
    );
    final existing = existingResult.getOrElse((_) => null);
    if (existing != null) {
      await _applyWallpaper(
        existing,
        user.uid,
        emit,
        notice: 'Reused previously uploaded wallpaper',
      );
      return;
    }

    final uploadResult = await _wallpaperStorageService.uploadFile(
      bytes: event.bytes,
      fileName: event.fileName,
      mimeType: mimeTypeForFileName(event.fileName),
      ownerId: user.uid,
    );

    final String? storageKey = uploadResult.match(
      (failure) {
        emit(
          _loaded().copyWith(
            isUploadingWallpaper: false,
            notice: 'Wallpaper upload failed: ${failure.message}',
          ),
        );
        return null;
      },
      (key) => key,
    );
    if (storageKey == null) return;

    final saveResult = await _wallpaperRepository.saveWallpaper(
      name: event.fileName,
      ownerId: user.uid,
      storageKey: storageKey,
      size: event.bytes.length,
    );

    await saveResult.match(
      (failure) async => emit(
        _loaded().copyWith(
          isUploadingWallpaper: false,
          notice: 'Could not save wallpaper record: ${failure.message}',
        ),
      ),
      (item) async => _applyWallpaper(item, user.uid, emit),
    );
  }

  Future<void> _onWallpaperSelected(
    SettingsWallpaperSelected event,
    Emitter<SettingsState> emit,
  ) async {
    final user = _authRepository.currentUser;
    if (user == null) return;
    await _applyWallpaper(event.item, user.uid, emit);
  }

  /// Marks [item] the active wallpaper and applies its URL to settings.
  /// Shared by the upload path and the gallery-tap path so the two can't
  /// drift — the widget used to run slightly different sequences for each.
  Future<void> _applyWallpaper(
    WallpaperItem item,
    String ownerId,
    Emitter<SettingsState> emit, {
    String? notice,
  }) async {
    await _wallpaperRepository.updateWallpaper(
      itemId: item.id,
      ownerId: ownerId,
    );

    final urlResult = await _wallpaperStorageService.getDownloadUrl(
      item.storageKey!,
    );

    await urlResult.match(
      (failure) async => emit(
        _loaded().copyWith(
          isUploadingWallpaper: false,
          notice: 'Could not load wallpaper: ${failure.message}',
        ),
      ),
      (url) async {
        final updated = _loaded().settings.copyWith(
          wallpaperType: WallpaperType.image,
          wallpaperImageUrl: url,
        );
        emit(
          _loaded().copyWith(
            settings: updated,
            isUploadingWallpaper: false,
            notice: notice,
          ),
        );
        await _settingsRepository.save(updated);
      },
    );
  }

  /// The current SettingsLoaded, or a defaults-bearing one if a sign-out
  /// raced the workflow. Every emit above goes through this rather than
  /// capturing `state` once, because awaits sit between them.
  SettingsLoaded _loaded() {
    final current = state;
    return current is SettingsLoaded
        ? current
        : const SettingsLoaded(AppSettings());
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
