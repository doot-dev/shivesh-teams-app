import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/month_bar.dart';
import '../../../orders/presentation/widgets/order_search_bar.dart';
import '../../data/models/cube_test_model.dart';
import '../../providers/cube_test_providers.dart';
import 'cube_tests_page.dart' show CubeAttachments, CubeDueBadge;

/// Every cube test report across all orders this technician is assigned to.
///
/// This is the bottom-nav "Cube Tests" destination — the per-order list is
/// [CubeTestsPage], reached from an order. Deliberately has NO back button:
/// it is a tab root, not a pushed page.
///
/// All filtering is server-side (see `allCubeTestsProvider`); the search box,
/// casting month and status chips write into one shared [CubeTestFilter] which
/// keys the request.
class AllCubeTestsPage extends ConsumerStatefulWidget {
  const AllCubeTestsPage({super.key});

  @override
  ConsumerState<AllCubeTestsPage> createState() => _AllCubeTestsPageState();
}

class _AllCubeTestsPageState extends ConsumerState<AllCubeTestsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(cubeTestFilterProvider);
    final notifier = ref.read(cubeTestFilterProvider.notifier);
    final testsAsync = ref.watch(allCubeTestsProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ---------- Gradient header: title, search, status chips ----------
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
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cube tests',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                testsAsync.when(
                                  data: (t) => t.isEmpty
                                      ? 'No reports found'
                                      : '${t.length} report${t.length == 1 ? '' : 's'}',
                                  loading: () => 'Loading…',
                                  error: (_, _) => 'Could not load',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.science_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OrderSearchBar(
                      hintText: 'Search order, project or client',
                      onQueryChanged: notifier.setQuery,
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    MonthBar(month: filter.month, onChanged: notifier.setMonth),
                    const SizedBox(height: AppSpacing.md),
                    _StatusChips(
                      selected: filter.status,
                      onSelect: notifier.setStatus,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (filter.isActive)
            _FilterSummary(
              count: testsAsync.maybeWhen(
                data: (t) => t.length,
                orElse: () => null,
              ),
              onClear: notifier.clear,
            ),

          Expanded(
            child: testsAsync.when(
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
              error: (e, _) => ErrorStateView(
                message: 'We could not load your cube test reports.',
                onRetry: () => ref.invalidate(allCubeTestsProvider(filter)),
              ),
              data: (tests) {
                if (tests.isEmpty) {
                  return EmptyState(
                    icon: Icons.science_outlined,
                    title: filter.isActive
                        ? 'No matching reports'
                        : 'No cube tests in ${monthLabel(filter.month)}',
                    message: filter.isActive
                        ? 'Try a different search, status or month.'
                        : 'Tests show here by casting date. '
                              'Use ‹ › above to see another month.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(allCubeTestsProvider(filter));
                    await ref
                        .read(allCubeTestsProvider(filter).future)
                        .catchError((_) => <CubeTestEntry>[]);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                      // Clears the floating bottom nav bar.
                      110,
                    ),
                    itemCount: tests.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => StaggeredItem(
                      index: i,
                      child: _CubeTestEntryCard(entry: tests[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tested / Scheduled / All selector.
class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.selected, required this.onSelect});

  final CubeTestStatusFilter selected;
  final ValueChanged<CubeTestStatusFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Wrap: at 300dp with large text the third chip drops to a new line.
    return Wrap(
      runSpacing: AppSpacing.sm,
      children: CubeTestStatusFilter.values.map((status) {
        final active = status == selected;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => onSelect(status),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.ease,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: Colors.white.withValues(alpha: active ? 1 : 0.42),
                  width: 1.2,
                ),
              ),
              child: Text(
                status.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.primary : Colors.white,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// "N results · Clear filters" strip, shown only while a filter is applied.
class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.count, required this.onClear});

  final int? count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
                  ? 'Filtering…'
                  : '$count result${count == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear filters'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// One report in the cross-order list. Tapping opens that order's cube tests,
/// where the report can be edited or deleted.
class _CubeTestEntryCard extends StatelessWidget {
  const _CubeTestEntryCard({required this.entry});

  final CubeTestEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = entry.test;

    return AppCard(
      onTap: entry.orderId.isEmpty
          ? null
          : () => context.push('/orders/${entry.orderId}/cube-tests'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.science_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.orderId.isEmpty ? 'Cube test' : entry.orderId,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (entry.projectLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.projectLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CubeDueBadge(test: t),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          DetailRow(
            icon: Icons.timelapse_rounded,
            label: 'Period',
            value: t.period.label,
          ),
          DetailRow(
            icon: Icons.event_outlined,
            label: 'Casting date',
            value: t.castingDateLabel,
          ),
          DetailRow(
            icon: Icons.science_outlined,
            label: 'Testing date',
            value: t.testDateLabel,
          ),
          DetailRow(
            icon: Icons.scale_outlined,
            label: 'Quantity',
            value: t.quantity,
          ),
          if (entry.productLabel.isNotEmpty)
            DetailRow(
              icon: Icons.inventory_2_outlined,
              label: 'Product',
              value: entry.productLabel,
            ),
          if (t.loggedBy != null)
            DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Logged by',
              value: t.loggedBy!,
            ),
          if (t.addedAtLabel.isNotEmpty)
            DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Added on',
              value: t.addedAtLabel,
            ),
          const SizedBox(height: AppSpacing.md),
          CubeAttachments(test: t),
        ],
      ),
    );
  }
}
