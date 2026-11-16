import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const elevated = Color(0xFF1C1C1E);
  static const border = Color(0xFF2C2C2E);
  static const gold = Color(0xFFC9A24B);
  static const goldLight = Color(0xFFE6C97A);
  static const goldDark = Color(0xFFA8832F);
  static const text = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFA1A1A6);
  static const disabled = Color(0xFF636366);
  static const onGold = Color(0xFF000000);
  static const success = Color(0xFF30D158);
  static const error = Color(0xFFFF453A);
  static const warning = Color(0xFFFFD60A);
}

abstract final class Space {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20;
  static const double xxl = 24, section = 32, hero = 40;
}
