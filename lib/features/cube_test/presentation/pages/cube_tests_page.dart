import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/cube_test_model.dart';
import '../../providers/cube_test_providers.dart';

/// Cube testing reports logged against one order.
class CubeTestsPage extends ConsumerWidget {
  const CubeTestsPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(cubeTestsProvider(orderId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/orders/$orderId/cube-tests/add');
          ref.invalidate(cubeTestsProvider(orderId));
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add test'),
      ),
      body: Column(
        children: [
          // ---------- Gradient header ----------
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
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cube test reports',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            testsAsync.when(
                              data: (t) => t.isEmpty
                                  ? 'No samples logged'
                                  : '${t.length} sample(s) logged',
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
              ),
            ),
          ),

          Expanded(
            child: testsAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: const [
                  OrderCardSkeleton(),
                  SizedBox(height: AppSpacing.md),
                  OrderCardSkeleton(),
                ],
              ),
              error: (e, _) => ErrorStateView(
                message: 'We could not load the cube tests for this order.',
                onRetry: () => ref.invalidate(cubeTestsProvider(orderId)),
              ),
              data: (tests) {
                if (tests.isEmpty) {
                  return const EmptyState(
                    icon: Icons.science_outlined,
                    title: 'No cube tests yet',
                    message:
                        'Log a cube test when a sample is cast, then attach '
                        'the result sheet once it has been tested.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(cubeTestsProvider(orderId));
                    await ref
                        .read(cubeTestsProvider(orderId).future)
                        .catchError((_) => <CubeTest>[]);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                      96,
                    ),
                    itemCount: tests.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => StaggeredItem(
                      index: i,
                      child: _CubeTestCard(test: tests[i], orderId: orderId),
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

class _CubeTestCard extends ConsumerStatefulWidget {
  const _CubeTestCard({required this.test, required this.orderId});
  final CubeTest test;
  final String orderId;

  @override
  ConsumerState<_CubeTestCard> createState() => _CubeTestCardState();
}

class _CubeTestCardState extends ConsumerState<_CubeTestCard> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete cube test'),
        content: const Text('This cube test report will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref
          .read(techApiProvider)
          .deleteCubeTest(widget.orderId, widget.test.id);
      ref.invalidate(cubeTestsProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.test;

    return AppCard(
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
                    Text(t.period.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    _DueChip(test: t),
                  ],
                ),
              ),
              _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.danger,
                      ),
                      onPressed: _delete,
                      tooltip: 'Delete report',
                      visualDensity: VisualDensity.compact,
                    ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
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
          if (t.addedAtLabel.isNotEmpty)
            DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Added on',
              value: t.addedAtLabel,
            ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: t.hasFile ? AppColors.blue50 : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  t.hasFile
                      ? Icons.description_rounded
                      : Icons.file_upload_outlined,
                  size: 17,
                  color: t.hasFile ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    t.hasFile ? 'Report attached' : 'No report attached yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: t.hasFile
                          ? AppColors.primary
                          : AppColors.textMuted,
                      fontWeight: t.hasFile ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows whether the scheduled test date has arrived.
class _DueChip extends StatelessWidget {
  const _DueChip({required this.test});
  final CubeTest test;

  @override
  Widget build(BuildContext context) {
    final days = test.daysUntilDue;

    if (days > 0) {
      return StatusBadge(
        label: 'in $days day${days == 1 ? '' : 's'}',
        tone: BadgeTone.info,
        dense: true,
      );
    }
    if (days == 0) {
      return const StatusBadge(
        label: 'Due today',
        tone: BadgeTone.warning,
        dense: true,
      );
    }
    return const StatusBadge(
      label: 'Tested',
      tone: BadgeTone.success,
      dense: true,
    );
  }
}
