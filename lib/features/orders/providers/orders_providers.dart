import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tech_api_provider.dart';
import '../data/models/order_models.dart';

final activeOrdersProvider = FutureProvider<List<FieldOrder>>((ref) {
  return ref.read(techApiProvider).getOrders(type: 'active');
});

final pastOrdersProvider = FutureProvider<List<FieldOrder>>((ref) {
  return ref.read(techApiProvider).getOrders(type: 'past');
});

final orderByIdProvider =
    FutureProvider.family<FieldOrder?, String>((ref, orderId) async {
  try {
    return await ref.read(techApiProvider).getOrder(orderId);
  } catch (_) {
    return null;
  }
});

final todayOrderProvider = FutureProvider<FieldOrder?>((ref) async {
  final orders = await ref.watch(activeOrdersProvider.future);
  return orders.firstOrNull;
});
