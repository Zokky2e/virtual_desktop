import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:virtual_desktop/core/repositories/settings_repository.dart';
import 'package:virtual_desktop/features/authentication/bloc/auth_state.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_cubit.dart';
import 'package:virtual_desktop/features/settings/bloc/settings_bloc.dart';
import 'package:virtual_desktop/features/settings/bloc/settings_event.dart';
import 'package:virtual_desktop/features/settings/bloc/settings_state.dart';
import '../core/di/injector.dart';
import '../core/repositories/auth_repository.dart';
import '../features/authentication/bloc/auth_bloc.dart';
import '../features/authentication/bloc/auth_event.dart';
import 'router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _authBloc;
  late final SettingsBloc _settingsBloc;
  late final FileClipboardCubit _clipboardCubit;
  late final GoRouter _router;
  StreamSubscription? _authSubscriptionForSettings;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(authRepository: getIt<AuthRepository>())
      ..add(const AuthSubscriptionRequested());
    _settingsBloc = SettingsBloc(
      settingsRepository: getIt<SettingsRepository>(),
    )..add(const SettingsLoadRequested());

    _clipboardCubit = FileClipboardCubit();

    _authSubscriptionForSettings = _authBloc.stream.listen((authState) {
      if (authState is Authenticated) {
        _settingsBloc.add(const SettingsLoadRequested());
      } else if (authState is Unauthenticated) {
        _clipboardCubit.clear();
      }
    });

    _router = buildRouter(_authBloc);
  }

  @override
  void dispose() {
    _authSubscriptionForSettings?.cancel();
    _authBloc.close();
    _settingsBloc.close();
    _clipboardCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _settingsBloc),
        BlocProvider.value(value: _clipboardCubit),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          final themeMode = settingsState is SettingsLoaded
              ? settingsState.settings.themeMode
              : ThemeMode.dark;
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Virtual Desktop',
            themeMode: themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                primary: Colors.white,
                onPrimary: const Color(0xFF25344A),
                onSecondary: Colors.blueAccent,
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                primary: const Color(0xFF25344A),
                onPrimary: Colors.white,
                seedColor: Colors.deepPurple,
                onSecondary: Colors.blueAccent,
                brightness: Brightness.dark,
              ),
            ),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
