import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/utils/mime_utils.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class SettingsWindowContent extends StatefulWidget {
  const SettingsWindowContent({super.key});

  @override
  State<SettingsWindowContent> createState() => _SettingsWindowContentState();
}

class _SettingsWindowContentState extends State<SettingsWindowContent> {
  static const _wallpaperPresets = [
    0xFF1E2A38, // default navy
    0xFF2D2D2D, // charcoal
    0xFF3E2723, // dark brown
    0xFF1B3A2F, // dark green
    0xFF2A1E38, // dark purple
  ];

  bool _isUploadingWallpaper = false;

  Future<void> _openCustomColorPicker(
    BuildContext context,
    Color current,
  ) async {
    Color picked = current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pick a background color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (color) => picked = color,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Use this color'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<SettingsBloc>().add(
        SettingsWallpaperColorChanged(picked.value),
      );
    }
  }

  Future<void> _uploadCustomWallpaper(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;

    final uid = getIt<AuthRepository>().currentUser?.uid;
    if (uid == null || !context.mounted) return;

    setState(() => _isUploadingWallpaper = true);

    final storageKey =
        'users/$uid/wallpaper/${DateTime.now().millisecondsSinceEpoch}_${file!.name}';

    final storageService = getIt<StorageService>();
    final uploadResult = await storageService.uploadFile(
      bytes: file.bytes!,
      path: storageKey,
      mimeType: mimeTypeForFileName(file.name),
    );

    if (!context.mounted) return;

    await uploadResult.match(
      (failure) async {
        setState(() => _isUploadingWallpaper = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallpaper upload failed: ${failure.message}'),
          ),
        );
      },
      (path) async {
        final urlResult = await storageService.getDownloadUrl(path);
        if (!context.mounted) return;
        setState(() => _isUploadingWallpaper = false);
        urlResult.match(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not load uploaded wallpaper: ${failure.message}',
              ),
            ),
          ),
          (url) => context.read<SettingsBloc>().add(
            SettingsWallpaperImageChanged(url),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is! SettingsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final settings = state.settings;
        return Container(
          color: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              Text(
                'Theme',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) => context
                    .read<SettingsBloc>()
                    .add(SettingsThemeModeChanged(selection.first)),
              ),
              const SizedBox(height: 24),
              Text(
                'Desktop Background',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final colorValue in _wallpaperPresets)
                    GestureDetector(
                      onTap: () => context.read<SettingsBloc>().add(
                        SettingsWallpaperColorChanged(colorValue),
                      ),
                      child: _WallpaperSwatch(
                        color: Color(colorValue),
                        isSelected:
                            settings.wallpaperType == WallpaperType.color &&
                            settings.wallpaperColorValue == colorValue,
                      ),
                    ),
                  // Custom color swatch — shows the currently picked custom
                  // color if one is active and isn't one of the presets,
                  // otherwise shows a "+"/palette icon inviting a pick.
                  GestureDetector(
                    onTap: () => _openCustomColorPicker(
                      context,
                      settings.wallpaperColor,
                    ),
                    child: _WallpaperSwatch(
                      color:
                          settings.wallpaperType == WallpaperType.color &&
                              !_wallpaperPresets.contains(
                                settings.wallpaperColorValue,
                              )
                          ? settings.wallpaperColor
                          : Theme.of(
                              context,
                            ).colorScheme.onPrimary.withValues(alpha: 0.36),
                      isSelected:
                          settings.wallpaperType == WallpaperType.color &&
                          !_wallpaperPresets.contains(
                            settings.wallpaperColorValue,
                          ),
                      child:
                          settings.wallpaperType == WallpaperType.color &&
                              !_wallpaperPresets.contains(
                                settings.wallpaperColorValue,
                              )
                          ? null
                          : Icon(
                              Icons.palette,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Custom Image',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (settings.wallpaperType == WallpaperType.image &&
                  settings.wallpaperImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    settings.wallpaperImageUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          Icons.image,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        label: Text(
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          _isUploadingWallpaper
                              ? 'Uploading...'
                              : 'Replace Image',
                        ),
                        onPressed: _isUploadingWallpaper
                            ? null
                            : () => _uploadCustomWallpaper(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => context.read<SettingsBloc>().add(
                        const SettingsWallpaperResetToColor(),
                      ),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.image,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  label: Text(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    _isUploadingWallpaper
                        ? 'Uploading...'
                        : 'Upload Custom Image',
                  ),
                  onPressed: _isUploadingWallpaper
                      ? null
                      : () => _uploadCustomWallpaper(context),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WallpaperSwatch extends StatelessWidget {
  const _WallpaperSwatch({
    required this.color,
    required this.isSelected,
    this.child,
  });

  final Color color;
  final bool isSelected;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white24,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: child,
    );
  }
}
