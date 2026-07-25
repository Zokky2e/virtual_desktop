import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/di/injector.dart';
import '../core/repositories/auth_repository.dart';
import '../features/authentication/bloc/auth_bloc.dart';
import '../features/authentication/bloc/auth_event.dart';
import '../features/authentication/presentation/login_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AuthBloc(authRepository: getIt<AuthRepository>())
            ..add(const AuthSubscriptionRequested()),
      child: MaterialApp(
        title: 'Virtual Desktop',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        // Temporary until Phase 5 replaces this with go_router + redirect logic.
        home: const LoginPage(),
      ),
    );
  }
}
