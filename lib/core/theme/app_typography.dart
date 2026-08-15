import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme get textTheme {
    final base = ThemeData.light().textTheme;
    return GoogleFonts.poppinsTextTheme(base).apply(
      displayColor: AppColors.textPrimary,
      bodyColor: AppColors.textPrimary,
    );
  }

  static TextStyle get button => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
