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
  const SettingsLoaded(this.settings);
  final AppSettings settings;
  @override
  List<Object?> get props => [settings];
}
