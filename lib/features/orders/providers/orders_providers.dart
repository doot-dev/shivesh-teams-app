import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tech_api_provider.dart';
import '../../../core/widgets/month_bar.dart';
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

/// One order-list query: the Active/Past tab, optional search text and the
/// delivery month (defaults to this month).
///
/// This is a Riverpod family key, so it MUST be value-equal — two identical
/// filters have to hash the same or every rebuild would refetch and the list
/// would flicker on each keystroke.
class OrderFilter {
  OrderFilter({this.type = 'active', this.query = '', DateTime? month})
    : month = monthOf(month ?? DateTime.now());

  /// `active` or `past`.
  final String type;

  /// Free text: order code, project, client, product or grade.
  final String query;

  /// First day of the delivery month shown.
  final DateTime month;

  bool get hasQuery => query.trim().isNotEmpty;

  /// The month always applies, so "filtered" means the search box.
  bool get isActive => hasQuery;

  OrderFilter copyWith({String? type, String? query, DateTime? month}) =>
      OrderFilter(
        type: type ?? this.type,
        query: query ?? this.query,
        month: month ?? this.month,
      );

  /// Drop the text but keep the tab and the month.
  OrderFilter cleared() => OrderFilter(type: type, month: month);

  String get fromIso => monthFromIso(month);
  String get toIso => monthToIso(month);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderFilter &&
          other.type == type &&
          other.query.trim() == query.trim() &&
          other.month == month;

  @override
  int get hashCode => Object.hash(type, query.trim(), month);
}

/// The live filter for the Orders screen, shared so the header, the result
/// count and the list all read the same state.
///
/// A `Notifier` rather than the legacy `StateProvider`: on Riverpod 3.x
/// `StateProvider` is only reachable via `flutter_riverpod/legacy.dart`, and
/// the rest of both apps is already on the modern API.
class OrderFilterNotifier extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => OrderFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setType(String type) => state = state.copyWith(type: type);

  void setMonth(DateTime month) => state = state.copyWith(month: month);

  /// Drop the text, keeping the current tab and month.
  void clear() => state = state.cleared();
}

final orderFilterProvider = NotifierProvider<OrderFilterNotifier, OrderFilter>(
  OrderFilterNotifier.new,
);

/// Server-side filtered orders for one [OrderFilter]: always the month
/// window. Home keeps the unfiltered [activeOrdersProvider].
final searchedOrdersProvider =
    FutureProvider.family<List<FieldOrder>, OrderFilter>((ref, filter) {
      return ref
          .read(techApiProvider)
          .getOrders(
            type: filter.type,
            query: filter.query,
            dateFrom: filter.fromIso,
            dateTo: filter.toIso,
          );
    });

final orderByIdProvider = FutureProvider.family<FieldOrder?, String>((
  ref,
  orderId,
) async {
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
