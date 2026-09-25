import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/file_viewer.dart';
import '../../../../core/widgets/delivery_tracker.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';

/// Everything the technician needs for one order: spec, delivery status,
/// vendor, cube tests, TMs, and the comment thread.
class OrderDetailsPage extends ConsumerStatefulWidget {
  const OrderDetailsPage({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await ref.read(techApiProvider).addComment(widget.orderId, msg);
      _messageController.clear();
      ref.invalidate(orderByIdProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderByIdProvider(widget.orderId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                'Order details',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              orderAsync.when(
                                data: (o) => Text(
                                  o?.clientName.isNotEmpty == true
                                      ? o!.clientName
                                      : 'Assignment',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                                loading: () => const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: ShimmerBox(
                                    width: 110,
                                    height: 12,
                                    onDark: true,
                                  ),
                                ),
                                error: (_, _) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
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
                          Tab(height: 38, text: 'Details'),
                          Tab(height: 38, text: 'Comments'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: orderAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: const [
                  OrderCardSkeleton(),
                  SizedBox(height: AppSpacing.md),
                  OrderCardSkeleton(),
                ],
              ),
              error: (e, _) => ErrorStateView(
                message: 'We could not load this order.',
                onRetry: () =>
                    ref.invalidate(orderByIdProvider(widget.orderId)),
              ),
              data: (order) {
                if (order == null) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Order not found',
                    message:
                        'It may have been reassigned or removed from your queue.',
                  );
                }
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _DetailsTab(order: order, orderId: widget.orderId),
                    _CommentsTab(
                      order: order,
                      messageController: _messageController,
                      isSending: _isSending,
                      onSend: _sendComment,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Details Tab ─────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.order, required this.orderId});
  final FieldOrder order;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var step = 0;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.gutter,
        AppSpacing.gutter,
        AppSpacing.xxxl,
      ),
      children: [
        StaggeredItem(
          index: step++,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.projectName.isEmpty
                            ? 'Untitled project'
                            : order.projectName,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    StatusBadge.of(order.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xs),
                DetailRow(
                  icon: Icons.person_outline,
                  label: 'Client',
                  value: order.clientName,
                ),
                if (order.placedBy != null)
                  DetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Placed by',
                    value: order.placedBy!,
                    trailing: order.placedByPhone == null
                        ? null
                        : IconButton(
                            tooltip: 'Call ${order.placedByPhone}',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.call_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            onPressed: () => launchUrl(
                              Uri.parse('tel:${order.placedByPhone}'),
                            ),
                          ),
                  ),
                DetailRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Product',
                  value: order.product,
                ),
                DetailRow(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Grade',
                  value: order.grade,
                ),
                DetailRow(
                  icon: Icons.scale_outlined,
                  label: 'Quantity',
                  value: order.quantity,
                ),
                DetailRow(
                  icon: Icons.event_outlined,
                  label: 'Schedule',
                  value: '${order.date}  ·  ${order.time}',
                ),
                DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Site',
                  value: order.location,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (order.isActive) ...[
          StaggeredItem(
            index: step++,
            child: _DeliveryStatusCard(order: order, orderId: orderId),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        StaggeredItem(
          index: step++,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendor details', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                DetailRow(
                  icon: Icons.factory_outlined,
                  label: 'Vendor',
                  value: order.vendor.isNotEmpty
                      ? order.vendor
                      : 'Not assigned',
                ),
                DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Handler name',
                  value: order.vendorDetail.handlerName,
                ),
                DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact no.',
                  value: order.vendorDetail.contactNo,
                ),
                DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Plant location',
                  value: order.vendorDetail.plantLocation,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        StaggeredItem(
          index: step++,
          child: _CubeTestEntry(orderId: orderId),
        ),
        const SizedBox(height: AppSpacing.xl),

        // TMs can be added at ANY time, including after the order is closed —
        // challans and paperwork routinely land late. The entry is stamped with
        // its own createdAt so a late addition is visible as such.
        StaggeredItem(
          index: step++,
          child: SectionHeader(
            title: 'TM details',
            subtitle: '${order.tmDetails.length} transit mixer(s)',
            actionLabel: 'Add TM',
            onAction: () => context.push('/orders/$orderId/add-tm'),
          ),
        ),
        if (!order.isActive) ...[
          const SizedBox(height: AppSpacing.sm),
          const _ClosedOrderNote(
            message:
                'This order is closed. Anything you add now is recorded with '
                'today\'s date and time.',
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        if (order.tmDetails.isEmpty)
          const EmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'No TM details yet',
            message: 'Add a transit mixer to start tracking this delivery.',
            compact: true,
          )
        else
          ...order.tmDetails.map(
            (tm) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _TmCard(tm: tm, orderId: orderId),
            ),
          ),
      ],
    );
  }
}

/// Lets the technician move the order: Dispatched, Delayed, Reached, Completed
/// (one status per order). The server refuses a step that is not allowed
/// from the current one, and that message is shown as is.
class _DeliveryStatusCard extends ConsumerStatefulWidget {
  const _DeliveryStatusCard({required this.order, required this.orderId});
  final FieldOrder order;
  final String orderId;

  @override
  ConsumerState<_DeliveryStatusCard> createState() =>
      _DeliveryStatusCardState();
}

class _DeliveryStatusCardState extends ConsumerState<_DeliveryStatusCard> {
  bool _saving = false;

  Future<void> _update(String next) async {
    if (next == widget.order.status) return;
    setState(() => _saving = true);
    try {
      await ref.read(techApiProvider).updateStatus(widget.orderId, next);
      ref.invalidate(orderByIdProvider(widget.orderId));
      ref.invalidate(activeOrdersProvider);
      ref.invalidate(pastOrdersProvider);
      ref.invalidate(searchedOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${statusLabel(next)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_serverMessage(e, 'Could not update status'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.order.status;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Order status', style: theme.textTheme.titleSmall),
              ),
              if (_saving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          DeliveryTracker(status: widget.order.step),
          if (widget.order.isDelayed) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const StatusBadge('Delayed', tone: Tone.warn),
                Text(
                  'The next step clears it',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tap to update',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: fieldStatuses.map((s) {
              final selected = s == current;
              return PressableScale(
                onTap: _saving ? null : () => _update(s),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    boxShadow: selected ? AppColors.shadowSm : null,
                  ),
                  child: Text(
                    statusLabel(s),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Entry point to this order's cube testing reports.
class _CubeTestEntry extends StatelessWidget {
  const _CubeTestEntry({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/orders/$orderId/cube-tests'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.softGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.science_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cube test reports', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Log casting details and attach results',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Inline notice explaining that a closed order still accepts new entries.
///
/// Deliberately informational rather than a blocker: the office needs late
/// challans and cube results recorded, so the app says WHEN the entry will be
/// stamped instead of refusing it.
class _ClosedOrderNote extends StatelessWidget {
  const _ClosedOrderNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TmCard extends ConsumerStatefulWidget {
  const _TmCard({required this.tm, required this.orderId});
  final TmDetail tm;
  final String orderId;

  @override
  ConsumerState<_TmCard> createState() => _TmCardState();
}

class _TmCardState extends ConsumerState<_TmCard> {
  late DeliveryStatus _selectedStatus;
  bool _deleting = false;
  bool _savingStatus = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.tm.status;
  }

  /// Persist the TM's status. The dropdown used to only call setState, so the
  /// technician's choice was lost as soon as the page was rebuilt or reopened.
  Future<void> _updateStatus(DeliveryStatus next) async {
    final previous = _selectedStatus;
    setState(() {
      _selectedStatus = next;
      _savingStatus = true;
    });
    try {
      // W32: "Reached" goes through its own endpoint, which stamps the arrival
      // time and tells the client they may now check (or reject) the truck.
      if (next == DeliveryStatus.reached) {
        await ref
            .read(techApiProvider)
            .markTmReached(widget.orderId, widget.tm.id);
      } else {
        await ref
            .read(techApiProvider)
            .updateTm(widget.orderId, widget.tm.id, status: next.apiValue);
      }
      ref.invalidate(orderByIdProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        setState(() => _selectedStatus = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_serverMessage(e, 'Could not update TM status')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete TM?'),
        content: Text('${widget.tm.tmNumber} will be removed from this order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteTm();
  }

  Future<void> _deleteTm() async {
    setState(() => _deleting = true);
    try {
      await ref.read(techApiProvider).deleteTm(widget.orderId, widget.tm.id);
      ref.invalidate(orderByIdProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_serverMessage(e, 'Failed to delete'))),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tm = widget.tm;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tm.tmNumber, style: theme.textTheme.titleSmall),
                    Text(
                      'Truck ${tm.truckNo}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (tm.isReviewed)
                const SizedBox.shrink()
              else
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
                        onPressed: _confirmDelete,
                        tooltip: 'Delete TM',
                        visualDensity: VisualDensity.compact,
                      ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          DetailRow(label: 'Quantity', value: tm.qty),
          DetailRow(label: 'Batch start', value: tm.batchStartTime),
          DetailRow(label: 'Batch end', value: tm.batchEndTime),
          DetailRow(label: 'Challan no.', value: tm.challanNo),
          if (tm.addedAtLabel.isNotEmpty)
            DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Added on',
              value: tm.addedAtLabel,
            ),
          if (tm.hasChallanFile)
            DetailRow(
              icon: Icons.attach_file_rounded,
              label: 'Challan photo',
              value: 'Attached',
              trailing: TextButton(
                onPressed: () => openServerFile(
                  context,
                  tm.challanUrl!,
                  title: 'Challan ${tm.challanNo}',
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('View'),
              ),
            )
          else if (!tm.isRejected)
            // D13: the bill waits for this photo.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const StatusBadge('Photo missing', tone: Tone.err),
                  Text(
                    'The bill waits for it',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          if (tm.isReviewed)
            DetailRow(
              icon: tm.isRejected
                  ? Icons.block_rounded
                  : Icons.verified_rounded,
              label: 'Office review',
              value: tm.isRejected
                  ? 'Rejected${tm.rejectionReason != null ? ' — ${tm.rejectionReason}' : ''}'
                  : 'Accepted (locked)',
            ),
          const SizedBox(height: AppSpacing.md),
          const FieldLabel('Status'),
          const SizedBox(height: AppSpacing.xs + 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButton<DeliveryStatus>(
              value: _selectedStatus,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(AppRadius.md),
              icon: _savingStatus
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                    ),
              items: DeliveryStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label, style: theme.textTheme.bodyMedium),
                    ),
                  )
                  .toList(),
              onChanged: _savingStatus
                  ? null
                  : (v) {
                      if (v != null) _updateStatus(v);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comments Tab ─────────────────────────────────────────────────────────────

class _CommentsTab extends StatelessWidget {
  const _CommentsTab({
    required this.order,
    required this.messageController,
    required this.isSending,
    required this.onSend,
  });
  final FieldOrder order;
  final TextEditingController messageController;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: order.comments.isEmpty
              ? const EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No comments yet',
                  message:
                      'Post an update so the office knows how the delivery '
                      'is going.',
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  itemCount: order.comments.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.lg),
                  itemBuilder: (context, i) => StaggeredItem(
                    index: i,
                    child: _CommentBubble(comment: order.comments[i]),
                  ),
                ),
        ),
        _MessageInput(
          controller: messageController,
          isSending: isSending,
          onSend: onSend,
        ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});
  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = comment.isMe;

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              isMe ? 'You' : comment.author,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              comment.timeAgo,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: isMe ? AppColors.softGradient : null,
            color: isMe ? null : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(isMe ? AppRadius.lg : 4),
              bottomRight: Radius.circular(isMe ? 4 : AppRadius.lg),
            ),
            border: isMe ? null : Border.all(color: AppColors.border),
            boxShadow: AppColors.shadowSm,
          ),
          child: Text(
            comment.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isMe ? Colors.white : AppColors.textPrimary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppColors.shadowMd,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Post a message…',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            PressableScale(
              onTap: isSending ? null : onSend,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: isSending ? null : AppColors.softGradient,
                  color: isSending ? AppColors.blue300 : null,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.shadowSm,
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The server's own message (e.g. "Order … is locked since …", "already
/// accepted") instead of a raw exception dump.
String _serverMessage(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
  }
  return fallback;
}
