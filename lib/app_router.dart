import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/tech_api_provider.dart';

import 'features/auth/presentation/pages/change_password_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/otp_page.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/common/presentation/pages/splash_page.dart';
import 'features/common/presentation/widgets/main_scaffold.dart';
import 'features/cube_test/presentation/pages/add_cube_test_page.dart';
import 'features/cube_test/presentation/pages/all_cube_tests_page.dart';
import 'features/cube_test/presentation/pages/cube_tests_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/orders/presentation/pages/order_details_page.dart';
import 'features/orders/presentation/pages/orders_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/tm/presentation/pages/add_tm_page.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      // Only re-evaluate routing when something route-relevant moved.
      // Rebuilding on every keystroke-driven isLoading flip would rerun the
      // redirect mid-login for no reason.
      if (prev?.isLoggedIn != next.isLoggedIn || prev?.status != next.status) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    final loc = state.matchedLocation;

    // Session restore is still in flight — hold on the splash rather than
    // bouncing a signed-in technician to /login for a frame.
    if (auth.isRestoring) return loc == '/splash' ? null : '/splash';

    final isAuthRoute = loc == '/login' || loc == '/otp';

    if (!auth.isLoggedIn) {
      return isAuthRoute ? null : '/login';
    }

    // Signed in: never sit on splash or an auth screen.
    if (isAuthRoute || loc == '/splash') return '/home';
    return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashPage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      GoRoute(
        path: '/otp',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OtpPage()),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailsPage(orderId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'add-tm',
            builder: (context, state) =>
                AddTmPage(orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'cube-tests',
            builder: (context, state) =>
                CubeTestsPage(orderId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) =>
                    AddCubeTestPage(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(
          location: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrdersPage()),
          ),
          GoRoute(
            path: '/cube-tests',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AllCubeTestsPage()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      ),
    ],
  );

  // Tapping an "Order Assigned" / status notification opens that order.
  //
  // Routed here rather than from the service because only the router can
  // navigate, and the guard below matters: pushing /orders/<id> while signed
  // out would land a logged-out technician on a screen that 401s. The redirect
  // sends them to /login, and the order is simply not auto-opened.
  final sub = ref.read(notificationServiceProvider).onOrderTapped.listen((
    orderId,
  ) {
    if (!ref.read(authProvider).isLoggedIn) return;
    router.push('/orders/$orderId');
  });
  ref.onDispose(sub.cancel);

  return router;
});
