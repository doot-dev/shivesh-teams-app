import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/delivery_tracker.dart';
import '../../data/models/order_models.dart';

/// The canonical order card, shared by Home and the Orders list.
///
/// Deliberately ONE widget rather than a copy per screen — the two lists drifted
/// apart visually before this existed. [highlight] renders the blue "today"
/// treatment; [showTracker] swaps the slim bar for the full 4-step tracker.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.highlight = false,
    this.showTracker = true,
  });

  final FieldOrder order;
  final bool highlight;
  final bool showTracker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => context.push('/orders/${order.id}'),
      padding: EdgeInsets.zero,
      border: highlight
          ? Border.all(color: AppColors.blue200, width: 1.4)
          : null,
      shadow: highlight ? AppColors.shadowMd : AppColors.shadowSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product avatar — gradient only on the highlighted card so it
                // does not compete with every row in a long list.
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: highlight ? AppColors.softGradient : null,
                    color: highlight ? null : AppColors.blue50,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    size: 22,
                    color: highlight ? Colors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.projectName.isEmpty
                            ? 'Untitled project'
                            : order.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.clientName.isEmpty
                            ? order.product
                            : order.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge.of(order.status),
              ],
            ),
          ),

          // ---------- Spec strip ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  _Spec(label: 'Grade', value: order.grade),
                  _Divider(),
                  _Spec(label: 'Quantity', value: order.quantity),
                  _Divider(),
                  _Spec(label: 'Time', value: order.time),
                ],
              ),
            ),
          ),

          if (order.location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      order.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: showTracker
                ? DeliveryTracker(status: order.step, compact: true)
                : DeliveryProgressBar(status: order.step),
          ),
        ],
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 9.5,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: AppColors.border,
    );
  }
}
