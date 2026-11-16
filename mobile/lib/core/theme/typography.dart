import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodyLarge: TextStyle(fontSize: 17, color: AppColors.text),
      bodyMedium: TextStyle(fontSize: 15, color: AppColors.secondary),
      bodySmall: TextStyle(fontSize: 13, color: AppColors.secondary),
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
