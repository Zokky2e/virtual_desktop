import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/authentication/bloc/auth_bloc.dart';
import '../features/authentication/bloc/auth_state.dart';
import '../features/authentication/presentation/login_page.dart';
import '../features/authentication/presentation/register_page.dart';
import '../features/desktop/presentation/desktop_page.dart';
import 'go_router_refresh_stream.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const desktop = '/desktop';
  static const loading = '/loading';
}

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      print(
        'ROUTER REDIRECT: ${state.matchedLocation} | ${authBloc.state.runtimeType}',
      );
      final authState = authBloc.state;
      final goingToAuthPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      final goingToLoading = state.matchedLocation == AppRoutes.loading;
      if (authState is AuthInitial) {
        return goingToLoading ? null : AppRoutes.loading;
      }
      if (authState is Authenticated) {
        // Logged in but sitting on /login or /register — bounce to desktop.
        final shouldGoToDesktop = goingToAuthPage || goingToLoading;
        return shouldGoToDesktop ? AppRoutes.desktop : null;
      }
      if (authState is Unauthenticated || authState is AuthError) {
        // Logged out and trying to reach anything but auth pages — bounce to login.
        return goingToAuthPage ? null : AppRoutes.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.desktop,
        builder: (context, state) => const DesktopPage(),
      ),
      GoRoute(
        path: AppRoutes.loading,
        builder: (_, __) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ],
  );
}
