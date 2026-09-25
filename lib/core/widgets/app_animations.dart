import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Motion primitives shared by every screen.
///
/// IMPORTANT — all of these honour `MediaQuery.disableAnimations` (the OS
/// "remove animations" accessibility setting). They degrade to a static child
/// rather than an instant jump, so users with reduced-motion enabled still see
/// correct layout. Never bypass these with a raw AnimationController unless you
/// replicate that check.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.slow,
    this.offset = 0.10,
    this.curve = AppMotion.ease,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Vertical travel as a fraction of the child's own height.
  final double offset;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.offset),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Staggers [FadeSlideIn] across a list so items cascade instead of snapping in
/// together. [index] drives the delay; cap it so long lists don't wait seconds.
class StaggeredItem extends StatelessWidget {
  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.stagger = const Duration(milliseconds: 60),
    this.maxIndex = 8,
  });

  final int index;
  final Widget child;
  final Duration stagger;
  final int maxIndex;

  @override
  Widget build(BuildContext context) {
    final effective = index > maxIndex ? maxIndex : index;
    return FadeSlideIn(delay: stagger * effective, child: child);
  }
}

/// Wraps any tappable surface with a subtle press-in scale.
///
/// Uses 0.97 deliberately: enough to feel responsive under a thumb, small
/// enough to avoid the "everything bounces" look.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: (_pressed && !reduced) ? widget.scale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        child: widget.child,
      ),
    );
  }
}

/// A shimmering placeholder block used while content loads.
///
/// Prefer this over a spinner for list/card content: it preserves layout, so
/// the screen does not jump when real data arrives.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.sm,
    this.onDark = false,
  });

  final double width;
  final double height;
  final double radius;

  /// Use translucent-white bands instead of blue-grey ones. Required on the
  /// gradient hero, where the default light shimmer is invisible.
  final bool onDark;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final base = widget.onDark
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.surfaceMuted;
    final highlight = widget.onDark
        ? Colors.white.withValues(alpha: 0.30)
        : AppColors.blue100;

    if (reduced) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t), 0),
              colors: [base, highlight, base],
              stops: const [0.30, 0.5, 0.70],
            ),
          ),
        );
      },
    );
  }
}

/// Counts a number up when it first appears. Used for dashboard stats so the
/// header feels responsive rather than static.
class AnimatedCountUp extends StatelessWidget {
  const AnimatedCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) return Text('$value', style: style);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppMotion.ease,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// A soft pulsing dot — signals "live"/in-progress without a spinner.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, this.color = AppColors.success, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (reduced) return dot;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size * 2.2,
          height: widget.size * 2.2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.10 + 0.16 * (1 - t)),
          ),
          child: child,
        );
      },
      child: dot,
    );
  }
}
