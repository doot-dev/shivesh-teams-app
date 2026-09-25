import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/file_viewer.dart';
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
      ref.invalidate(allCubeTestsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  /// The edit page adds files and changes the sample; lists refresh on save.
  void _edit() => context.push(
    '/orders/${widget.orderId}/cube-tests/add',
    extra: widget.test,
  );

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
                    CubeDueBadge(test: t),
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
          CubeAttachments(test: t, onAdd: _edit),
          // Below the files, not in the header: at 300dp a second header icon
          // squeezes the due badge.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit or add files'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A test's files, shared by both cube test lists: none (tap [onAdd] to add
/// some), one (opens straight away), or several (a sheet listing them all).
class CubeAttachments extends StatelessWidget {
  const CubeAttachments({super.key, required this.test, this.onAdd});
  final CubeTest test;
  final VoidCallback? onAdd;

  void _showAll(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        children: [
          Text(
            'Test reports (${test.attachments.length})',
            style: Theme.of(ctx).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final a in test.attachments) CubeFileRow.file(a),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final files = test.attachments;
    if (files.isEmpty) {
      return CubeFileRow(
        icon: Icons.file_upload_outlined,
        title: 'No report attached yet',
        subtitle: onAdd == null ? '' : 'Tap to add files',
        muted: true,
        onTap: onAdd,
      );
    }
    if (files.length == 1) return CubeFileRow.file(files.first);
    return CubeFileRow(
      icon: Icons.folder_copy_outlined,
      title: '${files.length} report files',
      subtitle: files.map((a) => a.displayName).join(', '),
      onTap: () => _showAll(context),
    );
  }
}

/// One file line: icon, name and "who · when", ellipsised so a long file name
/// never overflows a 300dp screen. [trailing] defaults to a chevron when
/// tappable.
class CubeFileRow extends StatelessWidget {
  const CubeFileRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.onTap,
    this.trailing,
    this.muted = false,
  }) : file = null;

  /// A server file; tapping opens it in the in-app viewer.
  CubeFileRow.file(CubeTestAttachment this.file, {super.key, this.trailing})
    : icon = file.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
      title = file.displayName,
      subtitle = file.subtitle,
      onTap = null,
      muted = false;

  final CubeTestAttachment? file;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted ? AppColors.textMuted : AppColors.primary;
    final f = file;
    final tap = f == null
        ? onTap
        : () => openServerFile(context, f.fileUrl, title: f.displayName);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: tap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: muted ? AppColors.background : AppColors.blue50,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  (tap == null
                      ? const SizedBox.shrink()
                      : Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: color,
                        )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the scheduled test date has arrived. Shared by both cube test lists.
class CubeDueBadge extends StatelessWidget {
  const CubeDueBadge({super.key, required this.test});
  final CubeTest test;

  @override
  Widget build(BuildContext context) {
    final days = test.daysUntilDue;
    if (days > 0) return StatusBadge('in $days day${days == 1 ? '' : 's'}');
    if (days == 0) return const StatusBadge('Due today', tone: Tone.warn);
    return const StatusBadge('Tested', tone: Tone.ok);
  }
}
