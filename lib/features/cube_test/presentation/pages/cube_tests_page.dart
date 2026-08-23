import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/cube_test_model.dart';
import '../../providers/cube_test_providers.dart';

/// Cube testing reports logged against one order.
class CubeTestsPage extends ConsumerWidget {
  const CubeTestsPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(cubeTestsProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Cube Test Reports'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/orders/$orderId/cube-tests/add');
          ref.invalidate(cubeTestsProvider(orderId));
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add test', style: TextStyle(color: Colors.white)),
      ),
      body: testsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(cubeTestsProvider(orderId)),
        ),
        data: (tests) {
          if (tests.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cubeTestsProvider(orderId)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              itemCount: tests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _CubeTestCard(
                test: tests[i],
                orderId: orderId,
              ),
            ),
          );
        },
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.test;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.period.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _DueChip(test: t),
              const SizedBox(width: 4),
              _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: _delete,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
            ],
          ),
          const SizedBox(height: 10),
          _Row(Icons.event_outlined, 'Casting date', t.castingDateLabel),
          _Row(Icons.science_outlined, 'Testing date', t.testDateLabel),
          _Row(Icons.scale_outlined, 'Quantity', t.quantity, isLast: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                t.hasFile
                    ? Icons.description_outlined
                    : Icons.file_upload_outlined,
                size: 16,
                color: t.hasFile ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.hasFile ? 'Report attached' : 'No report attached yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.hasFile ? AppColors.primary : AppColors.textMuted,
                    fontWeight:
                        t.hasFile ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
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
    late final String text;
    late final Color bg;
    late final Color fg;

    if (days > 0) {
      text = 'in $days day${days == 1 ? '' : 's'}';
      bg = const Color(0xFFEFF3FF);
      fg = AppColors.primary;
    } else if (days == 0) {
      text = 'Due today';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFB26A00);
    } else {
      text = 'Tested';
      bg = const Color(0xFFE6F4EA);
      fg = const Color(0xFF1B7F3B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.isLast = false});
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No cube tests yet',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Log a cube test when a sample is cast, then attach the result sheet once it has been tested.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Failed to load cube tests',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
