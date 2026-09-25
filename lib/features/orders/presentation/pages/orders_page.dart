import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/month_bar.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';
import '../widgets/order_card.dart';
import '../widgets/order_search_bar.dart';

/// Full order queue, split into Active and Past, with server-side search.
///
/// NOTE: this is a bottom-nav destination, so it deliberately has NO back
/// button — an earlier version showed one that popped to a blank route.
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    // Keep the search text when switching tabs — a technician looking for one
    // client usually wants to check both queues.
    ref
        .read(orderFilterProvider.notifier)
        .setType(_tabController.index == 1 ? 'past' : 'active');
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(orderFilterProvider);
    final notifier = ref.read(orderFilterProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ---------- Gradient header: title, search, tabs ----------
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xxl),
                bottomRight: Radius.circular(AppRadius.xxl),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideIn(
                      child: Text(
                        'Orders',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 50),
                      child: OrderSearchBar(onQueryChanged: notifier.setQuery),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    MonthBar(month: filter.month, onChanged: notifier.setMonth),
                    const SizedBox(height: AppSpacing.md),
                    // Pill-style segmented control rather than an underline —
                    // reads better on the gradient.
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 70),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primaryDark,
                          unselectedLabelColor: Colors.white.withValues(
                            alpha: 0.85,
                          ),
                          labelStyle: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: theme.textTheme.labelLarge,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          splashBorderRadius: BorderRadius.circular(
                            AppRadius.pill,
                          ),
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          tabs: const [
                            Tab(height: 38, text: 'Active'),
                            Tab(height: 38, text: 'Past'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------- Active-filter summary ----------
          if (filter.isActive)
            _FilterSummary(filter: filter, onClear: notifier.clear),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OrderListView(
                  filter: filter.copyWith(type: 'active'),
                  emptyIcon: Icons.assignment_outlined,
                  emptyTitle: 'No active orders',
                ),
                _OrderListView(
                  filter: filter.copyWith(type: 'past'),
                  emptyIcon: Icons.history_rounded,
                  emptyTitle: 'No past orders',
                  showTracker: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin bar under the header showing what's filtered and a one-tap reset.
class _FilterSummary extends ConsumerWidget {
  const _FilterSummary({required this.filter, required this.onClear});

  final OrderFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final results = ref.watch(searchedOrdersProvider(filter));
    final count = results.asData?.value.length;

    final parts = ['"${filter.query.trim()}"', monthLabel(filter.month)];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null
                  ? 'Searching ${parts.join(' · ')}'
                  : '$count result${count == 1 ? '' : 's'} for ${parts.join(' · ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Clear',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab body. Kept generic so Active and Past cannot drift apart.
class _OrderListView extends ConsumerWidget {
  const _OrderListView({
    required this.filter,
    required this.emptyIcon,
    required this.emptyTitle,
    this.showTracker = true,
  });

  final OrderFilter filter;
  final IconData emptyIcon;
  final String emptyTitle;
  final bool showTracker;

  void _refresh(WidgetRef ref) {
    ref.invalidate(searchedOrdersProvider(filter));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchedOrdersProvider(filter));

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        _refresh(ref);
        await ref
            .read(searchedOrdersProvider(filter).future)
            .catchError((_) => <FieldOrder>[]);
      },
      child: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: const [
            OrderCardSkeleton(),
            SizedBox(height: AppSpacing.md),
            OrderCardSkeleton(),
            SizedBox(height: AppSpacing.md),
            OrderCardSkeleton(),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ErrorStateView(
              message: 'We could not load these orders. Pull down to retry.',
              onRetry: () => _refresh(ref),
            ),
          ],
        ),
        data: (orders) {
          if (orders.isEmpty) {
            // A search that found nothing is a different situation from an
            // empty queue, and saying "No active orders" there reads as a bug.
            final searching = filter.isActive;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                EmptyState(
                  icon: searching ? Icons.search_off_rounded : emptyIcon,
                  title: searching ? 'No matching orders' : emptyTitle,
                  message: searching
                      ? 'Nothing in ${monthLabel(filter.month)}. Try a '
                            'different name, order number or month.'
                      : 'Nothing for ${monthLabel(filter.month)}. '
                            'Use ‹ › above to see another month.',
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter,
              110,
            ),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => StaggeredItem(
              index: i,
              child: OrderCard(order: orders[i], showTracker: showTracker),
            ),
          );
        },
      ),
    );
  }
}
