import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_mark.dart';

/// Brand screen shown while the stored 30-day session is restored.
///
/// It deliberately does NOT navigate. The router's redirect holds every route
/// here while `AuthState.isRestoring` is true and moves on the moment restore
/// finishes — the old fixed 3-second Timer to `/login` raced that check and
/// could throw an already-signed-in technician back to the login screen.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// Slow continuous drift for the background glow — gives the screen life
  /// during an otherwise dead wait on the session check.
  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(begin: 0.86, end: 1)
      .animate(
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
      );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );

  late final Animation<double> _textFade = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.blue950,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: Stack(
            children: [
              // Two soft drifting glows behind the mark.
              AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(
                    _ambientController.value,
                  );
                  return Stack(
                    children: [
                      Positioned(
                        top: -120 + (18 * t),
                        right: -90,
                        child: _Glow(
                          size: 320,
                          color: AppColors.blue400.withValues(alpha: 0.30),
                        ),
                      ),
                      Positioned(
                        bottom: -140 - (18 * t),
                        left: -110,
                        child: _Glow(
                          size: 360,
                          color: AppColors.blue500.withValues(alpha: 0.22),
                        ),
                      ),
                    ],
                  );
                },
              ),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: AnimatedBuilder(
                          animation: _ambientController,
                          builder: (context, child) {
                            final t = Curves.easeInOut.transform(
                              _ambientController.value,
                            );
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Halo that breathes behind the plate, so the
                                // white mark reads as lit rather than pasted on.
                                Container(
                                  width: 210 + (14 * t),
                                  height: 210 + (14 * t),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(
                                      alpha: 0.06 + (0.04 * t),
                                    ),
                                  ),
                                ),
                                child!,
                              ],
                            );
                          },
                          child: const BrandLogoPlate(logoSize: 104),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          Text(
                            'SHIVESH',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 7,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const BrandSubtitlePill(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Restore indicator, pinned low so it never crowds the mark.
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Restoring your session…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
