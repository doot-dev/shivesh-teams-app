import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';

class OrderDetailsPage extends ConsumerStatefulWidget {
  const OrderDetailsPage({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderByIdProvider(widget.orderId));

    return orderAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: const BackButton(color: AppColors.textPrimary),
          title: const Text('Order Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: const BackButton(color: AppColors.textPrimary),
          title: const Text('Order Details'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load order',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(orderByIdProvider(widget.orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: const Center(child: Text('Order not found')),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            leading: const BackButton(color: AppColors.textPrimary),
            title: const Text('Order Details'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: AppColors.border,
                tabs: const [Tab(text: 'Details'), Tab(text: 'Comments')],
              ),
            ),
          ),
          body: TabBarView(
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
          ),
        );
      },
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: 'Project Summary',
          children: [
            _DetailRow(Icons.business_outlined, 'Project', order.projectName),
            _DetailRow(Icons.person_outline, 'Client', order.clientName),
            _DetailRow(Icons.inventory_2_outlined, 'Product', order.product),
            _DetailRow(Icons.workspace_premium_outlined, 'Grade', order.grade),
            _DetailRow(Icons.scale_outlined, 'Quantity', order.quantity),
            _DetailRow(Icons.location_on_outlined, 'Site', order.location,
                isLast: true),
          ],
        ),
        const SizedBox(height: 16),
        if (order.isActive) ...[
          _DeliveryStatusCard(order: order, orderId: orderId),
          const SizedBox(height: 16),
        ],
        _SectionCard(
          title: 'Vendor Details',
          children: [
            _DetailRow(Icons.factory_outlined, 'Vendor',
                order.vendor.isNotEmpty ? order.vendor : 'Not assigned'),
            _DetailRow(Icons.person_outline_rounded, 'Handler name',
                order.vendorDetail.handlerName),
            _DetailRow(Icons.phone_outlined, 'Contact no.',
                order.vendorDetail.contactNo),
            _DetailRow(Icons.place_outlined, 'Plant location',
                order.vendorDetail.plantLocation,
                isLast: true),
          ],
        ),
        const SizedBox(height: 16),
        _CubeTestEntry(orderId: orderId),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'TM details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            if (order.isActive)
              GestureDetector(
                onTap: () => context.push('/orders/$orderId/add-tm'),
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 16, color: AppColors.primary),
                    Text(
                      ' TM details',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...order.tmDetails.map(
          (tm) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TmCard(tm: tm, orderId: orderId, isActive: order.isActive),
          ),
        ),
        if (order.tmDetails.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No TM details yet',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted)),
            ),
          ),
      ],
    );
  }
}

/// Lets the technician advance the order's delivery status.
///
/// Sends `DeliveryStatus.apiValue` (ASSIGNED / IN_TRANSIT / DELIVERED), never
/// the Dart enum name — the backend validates against its own enum and rejects
/// anything else with a 400.
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

  Future<void> _update(DeliveryStatus next) async {
    if (next == widget.order.deliveryStatus) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(techApiProvider)
          .updateStatus(widget.orderId, next.apiValue);
      ref.invalidate(orderByIdProvider(widget.orderId));
      ref.invalidate(activeOrdersProvider);
      ref.invalidate(pastOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${next.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.order.deliveryStatus;

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
                child: Text('Delivery Status',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (_saving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current.progress,
              backgroundColor: AppColors.progressTrack,
              color: AppColors.progressGreen,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DeliveryStatus.values.map((s) {
              final selected = s == current;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _saving ? null : () => _update(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    s.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/orders/$orderId/cube-tests'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.science_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cube Test Reports',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'Log casting details and attach results',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value, {this.isLast = false});
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
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

class _TmCard extends ConsumerStatefulWidget {
  const _TmCard(
      {required this.tm, required this.orderId, required this.isActive});
  final TmDetail tm;
  final String orderId;
  final bool isActive;

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
      await ref.read(techApiProvider).updateTm(
            widget.orderId,
            widget.tm.id,
            status: next.apiValue,
          );
      ref.invalidate(orderByIdProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        setState(() => _selectedStatus = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update TM status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _deleteTm() async {
    setState(() => _deleting = true);
    try {
      await ref.read(techApiProvider).deleteTm(widget.orderId, widget.tm.id);
      ref.invalidate(orderByIdProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tm = widget.tm;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tm.tmNumber,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (widget.isActive)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.textMuted),
                      onPressed: () {},
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            onPressed: _deleteTm,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          _TmInfo('Truck No: ${tm.truckNo}'),
          _TmInfo('Qty: ${tm.qty}'),
          _TmInfo('Batch Start Time: ${tm.batchStartTime}'),
          _TmInfo('Batch End Time: ${tm.batchEndTime}'),
          _TmInfo('Challan No: ${tm.challanNo}'),
          if (widget.isActive) ...[
            const SizedBox(height: 10),
            Text('Status',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButton<DeliveryStatus>(
                value: _selectedStatus,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                icon: _savingStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted),
                items: DeliveryStatus.values
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label,
                            style: theme.textTheme.bodySmall)))
                    .toList(),
                onChanged: _savingStatus
                    ? null
                    : (v) {
                        if (v != null) _updateStatus(v);
                      },
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('View Challan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TmInfo extends StatelessWidget {
  const _TmInfo(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMuted)),
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
              ? Center(
                  child: Text('No comments yet',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: order.comments.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 16),
                  itemBuilder: (context, i) =>
                      _CommentBubble(comment: order.comments[i]),
                ),
        ),
        _MessageInput(
            controller: messageController,
            isSending: isSending,
            onSend: onSend),
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
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: isMe
              ? [
                  Text(comment.timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(width: 6),
                  Text(comment.author,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                ]
              : [
                  Text(comment.author,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(comment.timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: isMe ? null : Border.all(color: AppColors.border),
          ),
          child: Text(
            comment.message,
            style: theme.textTheme.bodySmall?.copyWith(
                color: isMe ? Colors.white : AppColors.textPrimary,
                height: 1.4),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Post a message...',
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.2)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSending
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
