import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../features/orders/data/models/order_models.dart';

/// Horizontal 4-step delivery tracker (Confirmed → Dispatched → On the way →
/// Reached).
///
/// The connector line animates its fill, so a status change reads as forward
/// motion rather than a redraw. Steps at or before [status] are "done"; the
/// current step is emphasised with a ring.
class DeliveryTracker extends StatelessWidget {
  const DeliveryTracker({
    super.key,
    required this.status,
    this.compact = false,
  });

  final DeliveryStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = DeliveryStatus.values;
    final currentIndex = steps.indexOf(status);

    return Column(
      children: [
        SizedBox(
          height: compact ? 22 : 26,
          child: Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              // Even slots are dots, odd slots are the connectors between them.
              if (i.isEven) {
                final index = i ~/ 2;
                return _Dot(
                  done: index <= currentIndex,
                  current: index == currentIndex,
                  compact: compact,
                );
              }
              final leftIndex = (i - 1) ~/ 2;
              return Expanded(
                child: _Connector(filled: leftIndex < currentIndex),
              );
            }),
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Row(
          children: List.generate(steps.length, (index) {
            final isDone = index <= currentIndex;
            return Expanded(
              child: Text(
                steps[index].label,
                textAlign: index == 0
                    ? TextAlign.left
                    : index == steps.length - 1
                        ? TextAlign.right
                        : TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: compact ? 9 : 10,
                  color: isDone ? AppColors.textSecondary : AppColors.textMuted,
                  fontWeight: index == currentIndex
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.done,
    required this.current,
    required this.compact,
  });

  final bool done;
  final bool current;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 16.0 : 20.0;
    return AnimatedContainer(
      duration: AppMotion.mid,
      curve: AppMotion.ease,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: done ? AppColors.primary : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: done ? AppColors.primary : AppColors.borderStrong,
          width: 2,
        ),
        boxShadow: current
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: done
          ? Icon(Icons.check_rounded, size: compact ? 10 : 12, color: Colors.white)
          : null,
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.progressTrack,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: filled ? 1 : 0),
        duration: AppMotion.slow,
        curve: AppMotion.ease,
        builder: (context, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slim progress bar used on compact list cards where the full tracker would
/// dominate the layout.
class DeliveryProgressBar extends StatelessWidget {
  const DeliveryProgressBar({super.key, required this.status});

  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == DeliveryStatus.reached;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: status.progress.clamp(0.06, 1.0)),
        duration: AppMotion.slow,
        curve: AppMotion.ease,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          backgroundColor: AppColors.progressTrack,
          color: done ? AppColors.success : AppColors.primary,
          minHeight: 6,
        ),
      ),
    );
  }
}
