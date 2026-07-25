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
}

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoutes.desktop,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final goingToAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (authState is Authenticated) {
        // Logged in but sitting on /login or /register — bounce to desktop.
        return goingToAuthPage ? AppRoutes.desktop : null;
      }
      if (authState is Unauthenticated) {
        // Logged out and trying to reach anything but auth pages — bounce to login.
        return goingToAuthPage ? null : AppRoutes.login;
      }
      // AuthInitial / AuthLoading: no decisive state yet, don't redirect.
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
    ],
  );
}