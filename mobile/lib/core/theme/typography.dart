import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -1.65,
        color: AppColors.text,
      ),
      headlineSmall: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w600,
        height: 1.13,
        letterSpacing: -.75,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -.5,
        color: AppColors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AppColors.text,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5, color: AppColors.text),
      bodyMedium: TextStyle(
        fontSize: 16,
        height: 1.45,
        color: AppColors.secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: AppColors.secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  static TextStyle price(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(
        color: AppColors.goldLight,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
