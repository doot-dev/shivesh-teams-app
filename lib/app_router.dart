import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/otp_page.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/common/presentation/pages/splash_page.dart';
import 'features/common/presentation/widgets/main_scaffold.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/orders/presentation/pages/order_details_page.dart';
import 'features/orders/presentation/pages/orders_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/tm/presentation/pages/add_tm_page.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final isLoggedIn = _ref.read(authProvider).isLoggedIn;
    final loc = state.matchedLocation;
    final isAuthRoute =
        loc == '/login' || loc == '/otp' || loc == '/splash';
    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && (loc == '/login' || loc == '/otp')) return '/home';
    return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
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
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailsPage(orderId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'add-tm',
            builder: (context, state) =>
                AddTmPage(orderId: state.pathParameters['id']!),
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
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      ),
    ],
  );
});
