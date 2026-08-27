import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Shivesh logo on a solid white plate, plus the "SHIVESH / TEAM" wordmark.
///
/// The plate is NOT decoration. `assets/logo/logo.png` is a multi-colour mark
/// whose dominant tone is a dark navy-teal (#004860, luminance ~58) and it is
/// 84% transparent, so painting it straight onto the blue brand gradient made
/// it read as a dark smudge — that was the "logo not visible" bug. It needs a
/// light backdrop to survive, so every dark-background surface (splash, login,
/// OTP) must render it through this widget rather than a bare Image.asset.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.logoSize = 76,
    this.showWordmark = true,
    this.titleStyle,
    this.compact = false,
  });

  /// Height of the logo artwork itself; the white plate sizes around it.
  final double logoSize;

  /// Whether to draw the "SHIVESH" + "TEAM" lockup under the plate.
  final bool showWordmark;

  /// Overrides the "SHIVESH" text style (splash uses a larger cut than login).
  final TextStyle? titleStyle;

  /// Tightens the vertical rhythm for space-constrained layouts (login with
  /// the keyboard open).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogoPlate(logoSize: logoSize),
        if (showWordmark) ...[
          SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
          Text(
            'SHIVESH',
            style:
                titleStyle ??
                theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 5,
                ),
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          const BrandSubtitlePill(),
        ],
      ],
    );
  }
}

/// White rounded plate that carries the logo artwork.
///
/// Kept public and separate so a screen can use just the plate without the
/// wordmark. See [BrandMark] for why the white backdrop is required.
class BrandLogoPlate extends StatelessWidget {
  const BrandLogoPlate({super.key, this.logoSize = 76});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    // Generous padding: the artwork's own content only fills the middle ~65%
    // of the PNG canvas, so a tight plate looks unbalanced.
    final padding = logoSize * 0.30;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(logoSize * 0.42),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue950.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Image.asset(
        'assets/logo/logo.png',
        height: logoSize,
        width: logoSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // The source PNG is only 252x252, so it is upscaled on xxhdpi screens;
        // an explicit error builder keeps a missing/!corrupt asset from taking
        // out the splash, which is the one screen that must always render.
        errorBuilder: (_, _, _) => Icon(
          Icons.apartment_rounded,
          size: logoSize,
          color: AppColors.blue800,
        ),
      ),
    );
  }
}

/// The translucent "TEAM" pill that sits under the wordmark.
class BrandSubtitlePill extends StatelessWidget {
  const BrandSubtitlePill({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        'TEAM',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
        ),
      ),
    );
  }
}
