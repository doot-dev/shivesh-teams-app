import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_animations.dart';

/// The standard content surface: white, hairline border, soft blue shadow.
///
/// Use this instead of a bare Container for anything card-like — it keeps
/// radius, border and elevation consistent, which is most of what makes the
/// app read as one product rather than ten screens.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.border,
    this.radius = AppRadius.xl,
    this.shadow,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BoxBorder? border;
  final double radius;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: AppColors.border),
        boxShadow: shadow ?? AppColors.shadowSm,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return PressableScale(onTap: onTap, child: card);
  }
}

/// Colour group for a status. Pick it with [toneFor] so one status word always
/// gets one colour, on every screen.
enum Tone { ok, warn, err, primary, muted }

/// COMPLETED, PAID → ok; DELAYED, PARTIALLY_PAID → warn; CANCELLED, OVERDUE →
/// err; NEW, DISPATCHED, SENT → primary; ASSIGNED and anything unknown → muted.
Tone toneFor(String status) =>
    switch (status.toUpperCase().replaceAll(' ', '_')) {
      'COMPLETED' ||
      'REACHED' ||
      'PAID' ||
      'ACCEPTED' ||
      'DELIVERED' ||
      'TESTED' => Tone.ok,
      'DELAYED' ||
      'PENDING' ||
      'PARTIALLY_PAID' ||
      'DUE' ||
      'DUE_TODAY' => Tone.warn,
      'CANCELLED' || 'REJECTED' || 'OVERDUE' => Tone.err,
      'NEW' ||
      'CONFIRMED' ||
      'DISPATCHED' ||
      'SENT' ||
      'IN_PROGRESS' ||
      'IN_TRANSIT' => Tone.primary,
      _ => Tone.muted,
    };

/// "DISPATCHED" → "Dispatched", "PARTIALLY_PAID" → "Part paid". Never raw CAPS.
String statusText(String status) => switch (status) {
  '' => '—',
  'PARTIALLY_PAID' => 'Part paid',
  'IN_TRANSIT' => 'On the way',
  'IN_PROGRESS' => 'Dispatched',
  _ =>
    status[0].toUpperCase() +
        status.substring(1).toLowerCase().replaceAll('_', ' '),
};

/// (soft background, soft text, solid background, solid text) for a tone.
/// Text colours are darkened where the raw semantic colour is too light to
/// read at 11px. Warn keeps dark text even when solid: white or amber on amber
/// fails contrast.
(Color, Color, Color, Color) _toneColors(Tone tone) => switch (tone) {
  Tone.ok => (
    AppColors.successSoft,
    AppColors.deliveredText,
    AppColors.deliveredText,
    Colors.white,
  ),
  Tone.warn => (
    AppColors.warningSoft,
    Color.lerp(AppColors.warning, AppColors.textPrimary, 0.45)!,
    AppColors.warning,
    AppColors.textPrimary,
  ),
  Tone.err => (
    AppColors.dangerSoft,
    Color.lerp(AppColors.danger, AppColors.textPrimary, 0.2)!,
    AppColors.danger,
    Colors.white,
  ),
  Tone.primary => (
    AppColors.blue50,
    AppColors.blue700,
    AppColors.primary,
    Colors.white,
  ),
  Tone.muted => (
    AppColors.surfaceMuted,
    AppColors.textSecondary,
    AppColors.textSecondary,
    Colors.white,
  ),
};

/// The one status pill: soft tint with a 6px dot and the label in the tone
/// colour, or [solid] (filled, white text and dot).
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = Tone.muted,
    this.solid = false,
  });

  /// From a server status word: tone and readable label in one go.
  StatusBadge.of(String status, {super.key, String? label, this.solid = false})
    : label = label ?? statusText(status),
      tone = toneFor(status);

  final String label;
  final Tone tone;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, solidBg, solidFg) = _toneColors(tone);
    final color = solid ? solidFg : fg;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? solidBg : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, size: 6),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small round pill holding a number, e.g. a section's item count.
class CountBubble extends StatelessWidget {
  const CountBubble(
    this.count, {
    super.key,
    this.tone = Tone.primary,
    this.solid = false,
  });

  final int count;
  final Tone tone;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, solidBg, solidFg) = _toneColors(tone);
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solid ? solidBg : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: solid ? solidFg : fg,
        ),
      ),
    );
  }
}

/// The status colour alone, for tight spots (a list row, a legend).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.tone, this.size = 8});

  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Dot(color: _toneColors(tone).$2, size: size);
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Section header with an optional trailing action ("View all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Designed empty state — never leave a blank screen when there is no data.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeSlideIn(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
              decoration: const BoxDecoration(
                color: AppColors.blue50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 36,
                color: AppColors.blue400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Designed error state with a retry affordance.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: compact ? AppSpacing.xl : AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.dangerSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 28,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Something went wrong',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled key/value row used inside detail cards.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  /// e.g. a call button next to a phone number.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A compact stat tile (label above, big number below).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: AppSpacing.sm),
          AnimatedCountUp(
            value: value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Field label used above inputs across all forms.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
      child: Row(
        children: [
          Text(text, style: AppTypography.overline),
          if (required)
            Text(
              ' *',
              style: AppTypography.overline.copyWith(color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder shaped like an order card, shown while lists load.
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerBox(width: 44, height: 44, radius: AppRadius.md),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 150, height: 13),
                    SizedBox(height: AppSpacing.sm),
                    ShimmerBox(width: 90, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(width: double.infinity, height: 8, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(width: 200, height: 10),
        ],
      ),
    );
  }
}
