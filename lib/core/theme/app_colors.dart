import 'package:flutter/material.dart';

/// The app's single source of colour truth — a disciplined blue system.
///
/// Structure follows the "near-monochrome + one accent" rule: a 50→900 blue
/// ramp carries every surface, border and emphasis, while semantic colours
/// (success / warning / danger / info) are reserved for MEANING only, never
/// decoration. Never hardcode a hex in a widget; add it here instead, or the
/// palette silently drifts screen by screen.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------
  // Blue ramp — the spine of the design system.
  // ---------------------------------------------------------------------
  static const Color blue50 = Color(0xFFEFF4FF);
  static const Color blue100 = Color(0xFFDCE7FF);
  static const Color blue200 = Color(0xFFC0D4FF);
  static const Color blue300 = Color(0xFF95B8FF);
  static const Color blue400 = Color(0xFF6491FB);
  static const Color blue500 = Color(0xFF3F6BF6);
  static const Color blue600 = Color(0xFF2A4CEB);
  static const Color blue700 = Color(0xFF2139D8);
  static const Color blue800 = Color(0xFF2131AF);
  static const Color blue900 = Color(0xFF1F3E96);
  static const Color blue950 = Color(0xFF13205C);

  /// Primary action colour. Every filled CTA in the app uses this.
  static const Color primary = blue600;
  static const Color primaryDark = blue800;
  static const Color primarySoft = blue100;
  static const Color primaryTint = blue50;

  /// Legacy alias retained so older call sites keep compiling.
  static const Color accent = success;

  // ---------------------------------------------------------------------
  // Surfaces — cool-tinted neutrals, never pure grey.
  // ---------------------------------------------------------------------
  static const Color background = Color(0xFFF5F8FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF3FE);
  static const Color card = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------
  // Text — a 3-step hierarchy. If you need a fourth, the layout is wrong.
  // ---------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF0E1A38);
  static const Color textSecondary = Color(0xFF4A5980);
  static const Color textMuted = Color(0xFF8A97B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------
  // Borders — hairlines that define regions, not a design element.
  // ---------------------------------------------------------------------
  static const Color border = Color(0xFFE2EAFB);
  static const Color borderStrong = Color(0xFFC9D8F5);

  // ---------------------------------------------------------------------
  // Semantic — meaning only.
  // ---------------------------------------------------------------------
  static const Color success = Color(0xFF12A150);
  static const Color successSoft = Color(0xFFE4F7EC);
  static const Color warning = Color(0xFFE08600);
  static const Color warningSoft = Color(0xFFFFF3E0);
  static const Color danger = Color(0xFFDC2B2B);
  static const Color dangerSoft = Color(0xFFFDECEC);
  static const Color info = blue600;
  static const Color infoSoft = blue50;

  // ---------------------------------------------------------------------
  // Legacy aliases — kept so pre-redesign widgets still compile.
  // ---------------------------------------------------------------------
  static const Color gradientStart = blue50;
  static const Color gradientEnd = Color(0xFFFFFFFF);
  static const Color progressGreen = success;
  static const Color progressTrack = Color(0xFFE2EAFB);
  static const Color delivered = successSoft;
  static const Color deliveredText = Color(0xFF0A6B36);

  /// The hero gradient used on the login header and home banner.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue700, blue900],
  );

  /// A softer gradient for cards that must not compete with a CTA.
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue500, blue700],
  );

  /// Standard elevation. Blue-tinted so shadows read as depth, not dirt.
  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: blue950.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: blue950.withValues(alpha: 0.07),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: blue950.withValues(alpha: 0.12),
      blurRadius: 32,
      offset: const Offset(0, 14),
    ),
  ];
}

/// Spacing, radius and motion tokens on a 4px grid.
///
/// Durations and curves live here too so every animation in the app shares one
/// personality — mismatched easing is the fastest way to make a UI feel cheap.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal page gutter. Every screen uses this — do not improvise.
  static const double gutter = 20;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration mid = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 450);

  /// Standard easing for almost everything.
  static const Curve ease = Curves.easeOutCubic;

  /// For elements entering the screen — slight overshoot reads as "alive".
  static const Curve entrance = Curves.easeOutBack;

  /// For continuous/looping motion (shimmer, pulse).
  static const Curve smooth = Curves.easeInOut;
}
