import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cube_test/providers/cube_test_providers.dart';
import '../../features/notifications/providers/notifications_providers.dart';
import '../../features/orders/providers/orders_providers.dart';
import '../../features/profile/providers/profile_providers.dart';

/// Drop every scrap of the signed-in technician's data from memory.
///
/// WHY THIS EXISTS: none of the data providers below are `.autoDispose`, so in
/// non-codegen Riverpod they live in the root `ProviderScope` for the whole app
/// run. Clearing the token on logout does NOT clear them — which is why signing
/// out and signing in as a different technician used to show the previous
/// technician's orders, cube tests and profile until the app was force-killed.
///
/// Call this on logout AND immediately after a successful login. The login-side
/// call is the safety net: it covers a session that ended without a clean
/// logout (crash, token revoked server-side, app killed mid-session).
///
/// Invalidating a `family` provider clears every instance of it, so the
/// per-order cube-test caches go too.
///
/// SAFE TO CALL WITH SCREENS MOUNTED: invalidation rebuilds a provider only if
/// something is still listening. On logout the router has already redirected to
/// /login, so these simply drop their state instead of refetching with a dead
/// token.
void resetSessionData(Ref ref) {
  // Orders
  ref.invalidate(activeOrdersProvider);
  ref.invalidate(pastOrdersProvider);
  ref.invalidate(searchedOrdersProvider);
  ref.invalidate(orderByIdProvider);
  ref.invalidate(todayOrderProvider);
  // The search box and date range are part of the previous user's session too.
  ref.invalidate(orderFilterProvider);

  // Cube tests: the per-order lists (keyed by order code), the cross-order
  // feed, and the filter driving it.
  ref.invalidate(cubeTestsProvider);
  ref.invalidate(allCubeTestsProvider);
  ref.invalidate(cubeTestFilterProvider);

  // Profile + notifications
  ref.invalidate(technicianProfileProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(remindersProvider);
}
