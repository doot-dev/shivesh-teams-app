import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tech_api_provider.dart';
import '../data/models/cube_test_model.dart';

/// Cube testing reports for one order, newest first.
///
/// Keyed by the ORDER CODE (ORD-2025-0001) — the same value the routes use.
/// Invalidate this family entry after any create/delete so the list reflects
/// the server rather than a stale snapshot.
final cubeTestsProvider =
    FutureProvider.family<List<CubeTest>, String>((ref, orderId) {
  return ref.read(techApiProvider).getCubeTests(orderId);
});
