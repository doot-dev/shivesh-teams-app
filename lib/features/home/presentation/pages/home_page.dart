import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../orders/data/models/order_models.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../../orders/providers/orders_providers.dart';
import '../../../profile/providers/profile_providers.dart';

/// The technician's landing screen: a blue gradient hero with live counts,
/// today's assignment, then the rest of the active queue.
///
/// The hero deliberately extends BEHIND the status bar (no top SafeArea) so the
/// gradient bleeds to the top edge; the inner padding restores the safe inset.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayOrderAsync = ref.watch(todayOrderProvider);
    final activeOrdersAsync = ref.watch(activeOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(activeOrdersProvider);
          ref.invalidate(technicianProfileProvider);
          await ref.read(activeOrdersProvider.future).catchError(
                (_) => <FieldOrder>[],
              );
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(child: _HomeHero()),

            // ---------- Today's order ----------
            ...todayOrderAsync.when(
              data: (order) => order == null
                  ? const <Widget>[]
                  : <Widget>[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.gutter,
                            AppSpacing.xxl,
                            AppSpacing.gutter,
                            AppSpacing.md,
                          ),
                          child: FadeSlideIn(
                            delay: const Duration(milliseconds: 90),
                            child: Row(
                              children: [
                                const PulsingDot(color: AppColors.success),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: SectionHeader(
                                    title: "Today's order",
                                    subtitle: 'Your next delivery',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.gutter,
                          ),
                          child: FadeSlideIn(
                            delay: const Duration(milliseconds: 140),
                            child: OrderCard(order: order, highlight: true),
                          ),
                        ),
                      ),
                    ],
              loading: () => const <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.xxl,
                      AppSpacing.gutter,
                      0,
                    ),
                    child: OrderCardSkeleton(),
                  ),
                ),
              ],
              error: (_, _) => const <Widget>[],
            ),

            // ---------- Active queue ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 190),
                  child: SectionHeader(
                    title: 'Active orders',
                    actionLabel: 'View all',
                    onAction: () => context.go('/orders'),
                  ),
                ),
              ),
            ),

            activeOrdersAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: Column(
                    children: [
                      OrderCardSkeleton(),
                      SizedBox(height: AppSpacing.md),
                      OrderCardSkeleton(),
                    ],
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorStateView(
                  message: 'We could not load your orders. Pull to refresh or '
                      'try again.',
                  compact: true,
                  onRetry: () => ref.invalidate(activeOrdersProvider),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'No active orders',
                      message:
                          'New assignments will appear here as soon as they '
                          'are dispatched to you.',
                      compact: true,
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        0,
                        AppSpacing.gutter,
                        AppSpacing.md,
                      ),
                      child: StaggeredItem(
                        index: i,
                        child: OrderCard(order: orders[i], showTracker: false),
                      ),
                    ),
                    childCount: orders.length,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

/// Gradient header: greeting, notification bell, and three live counters.
class _HomeHero extends ConsumerWidget {
  const _HomeHero();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(technicianProfileProvider);
    final activeOrdersAsync = ref.watch(activeOrdersProvider);
    // Riverpod 3.x: `valueOrNull` no longer exists — `.value` is the nullable one.
    final orders = activeOrdersAsync.value ?? const <FieldOrder>[];

    final inTransit = orders
        .where((o) =>
            o.deliveryStatus == DeliveryStatus.onTheWay ||
            o.deliveryStatus == DeliveryStatus.dispatched)
        .length;
    final reached = orders
        .where((o) => o.deliveryStatus == DeliveryStatus.reached)
        .length;

    return Container(
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
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 2),
                          profileAsync.when(
                            data: (p) => Text(
                              p.name.isEmpty ? 'Technician' : p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            loading: () => const ShimmerBox(
                              width: 160,
                              height: 26,
                              onDark: true,
                            ),
                            error: (_, _) => Text(
                              'Technician',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: PressableScale(
                      onTap: () => context.push('/notifications'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 21,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 110),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Active',
                        value: orders.length,
                        icon: Icons.assignment_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'In transit',
                        value: inTransit,
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Reached',
                        value: reached,
                        icon: Icons.task_alt_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
