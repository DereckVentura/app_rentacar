import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

abstract final class AppTheme {
  static final _controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  static final _surfaceShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(23),
    side: const BorderSide(color: AppColors.border),
  );

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.onGold,
      secondary: AppColors.goldLight,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.error,
    ),
    textTheme: AppTypography.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: AppColors.border,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: _surfaceShape,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: _surfaceShape,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.secondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.elevated,
      border: _inputBorder(AppColors.border),
      enabledBorder: _inputBorder(AppColors.goldDark.withValues(alpha: .58)),
      focusedBorder: _inputBorder(AppColors.gold),
      errorBorder: _inputBorder(AppColors.error),
      focusedErrorBorder: _inputBorder(AppColors.error),
      contentPadding: const EdgeInsets.all(Space.lg),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 52),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        shape: _controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        overlayColor: AppColors.onGold,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 52),
        foregroundColor: AppColors.goldLight,
        side: const BorderSide(color: AppColors.goldDark),
        shape: _controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        overlayColor: AppColors.goldLight,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.goldLight,
        shape: _controlShape,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: Color(0xFF473822),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.fromMap({
        WidgetState.selected: IconThemeData(color: AppColors.goldLight),
        WidgetState.any: IconThemeData(color: AppColors.secondary),
      }),
      labelTextStyle: WidgetStateProperty.fromMap({
        WidgetState.selected: TextStyle(color: AppColors.goldLight),
        WidgetState.any: TextStyle(color: AppColors.secondary),
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.elevated,
      contentTextStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 15,
        height: 1.4,
      ),
      shape: _surfaceShape,
    ),
  );
}
