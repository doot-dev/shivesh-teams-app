import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tech_api_provider.dart';
import '../data/models/order_models.dart';

/// The unfiltered active queue. Home and [todayOrderProvider] depend on this,
/// so it deliberately stays search-free — filtering happens in
/// [searchedOrdersProvider] instead of mutating this one.
final activeOrdersProvider = FutureProvider<List<FieldOrder>>((ref) {
  return ref.read(techApiProvider).getOrders(type: 'active');
});

final pastOrdersProvider = FutureProvider<List<FieldOrder>>((ref) {
  return ref.read(techApiProvider).getOrders(type: 'past');
});

/// One order-list query: the Active/Past tab plus the optional search text and
/// delivery-date window.
///
/// This is a Riverpod family key, so it MUST be value-equal — two identical
/// filters have to hash the same or every rebuild would refetch and the list
/// would flicker on each keystroke.
class OrderFilter {
  const OrderFilter({
    this.type = 'active',
    this.query = '',
    this.from,
    this.to,
  });

  /// `active` or `past`.
  final String type;

  /// Free text: order code, project, client, product or grade.
  final String query;

  /// Inclusive delivery-date window. Null means unbounded on that side.
  final DateTime? from;
  final DateTime? to;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasDate => from != null || to != null;
  bool get isActive => hasQuery || hasDate;

  /// How many filters are applied — drives the "clear" affordance and the
  /// badge on the filter button.
  int get activeCount => (hasQuery ? 1 : 0) + (hasDate ? 1 : 0);

  OrderFilter copyWith({
    String? type,
    String? query,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return OrderFilter(
      type: type ?? this.type,
      query: query ?? this.query,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  /// Drop the text and dates but keep the tab.
  OrderFilter cleared() => OrderFilter(type: type);

  /// The backend only understands ISO `yyyy-MM-dd`; anything else is ignored
  /// server-side, so format here rather than at the call site.
  static String? _iso(DateTime? d) {
    if (d == null) return null;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String? get fromIso => _iso(from);
  String? get toIso => _iso(to);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderFilter &&
          other.type == type &&
          other.query.trim() == query.trim() &&
          other.fromIso == fromIso &&
          other.toIso == toIso;

  @override
  int get hashCode => Object.hash(type, query.trim(), fromIso, toIso);
}

/// The live filter for the Orders screen, shared so the header, the result
/// count and the list all read the same state.
///
/// A `Notifier` rather than the legacy `StateProvider`: on Riverpod 3.x
/// `StateProvider` is only reachable via `flutter_riverpod/legacy.dart`, and
/// the rest of both apps is already on the modern API.
class OrderFilterNotifier extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => const OrderFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setType(String type) => state = state.copyWith(type: type);

  void setRange(DateTime? from, DateTime? to) => state = state.copyWith(
        from: from,
        to: to,
        clearFrom: from == null,
        clearTo: to == null,
      );

  void clearDates() =>
      state = state.copyWith(clearFrom: true, clearTo: true);

  /// Drop the text and dates, keeping the current tab.
  void clear() => state = state.cleared();
}

final orderFilterProvider =
    NotifierProvider<OrderFilterNotifier, OrderFilter>(OrderFilterNotifier.new);

/// Server-side filtered orders for one [OrderFilter].
///
/// When no filter is applied this reuses the plain active/past providers so a
/// cleared search box hits the same cache the rest of the app already warmed,
/// instead of firing a redundant request.
final searchedOrdersProvider =
    FutureProvider.family<List<FieldOrder>, OrderFilter>((ref, filter) async {
  if (!filter.isActive) {
    return ref.watch(
      filter.type == 'past'
          ? pastOrdersProvider.future
          : activeOrdersProvider.future,
    );
  }

  return ref.read(techApiProvider).getOrders(
        type: filter.type,
        query: filter.query,
        dateFrom: filter.fromIso,
        dateTo: filter.toIso,
      );
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
