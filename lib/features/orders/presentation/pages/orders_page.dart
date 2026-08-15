import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOrdersAsync = ref.watch(activeOrdersProvider);
    final pastOrdersAsync = ref.watch(pastOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.border,
            tabs: const [Tab(text: 'Active'), Tab(text: 'Past')],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          activeOrdersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (orders) => _ActiveOrderList(orders: orders),
          ),
          pastOrdersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (orders) => _PastOrderList(orders: orders),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderList extends StatelessWidget {
  const _ActiveOrderList({required this.orders});
  final List<FieldOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text('No active orders',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ActiveOrderCard(order: orders[i]),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final FieldOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = order.deliveryStatus.progress;

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
          Text(order.projectName,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(order.product,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(children: [
            _SmallInfo('Grade', order.grade),
            const SizedBox(width: 24),
            _SmallInfo('Quantity', order.quantity),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(order.time,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(width: 16),
            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(order.location,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.progressTrack,
              color: AppColors.progressGreen,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepLabel('Confirmed'),
              _StepLabel('Dispatched'),
              _StepLabel('On the way'),
              _StepLabel('Reached'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/orders/${order.id}'),
              child: const Text('View details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastOrderList extends StatelessWidget {
  const _PastOrderList({required this.orders});
  final List<FieldOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text('No past orders',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _PastOrderCard(order: orders[i]),
    );
  }
}

class _PastOrderCard extends StatelessWidget {
  const _PastOrderCard({required this.order});
  final FieldOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Text(order.projectName,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.delivered,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Delivered',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.deliveredText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.product}- ${order.grade}(${order.quantity})',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(order.date,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.access_time_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(order.time,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(order.location,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/orders/${order.id}'),
              child: const Text('View details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11)),
        Text(value,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(fontSize: 9, color: AppColors.textMuted),
    );
  }
}
