import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF10100F);
  static const surface = Color(0xFF1C1B19);
  static const elevated = Color(0xFF25231F);
  static const border = Color(0xFF3B362E);
  static const gold = Color(0xFFE5C278);
  static const goldLight = Color(0xFFF0D595);
  static const goldDark = Color(0xFFB3935A);
  static const text = Color(0xFFF8F4ED);
  static const secondary = Color(0xFFBCB4A6);
  static const disabled = Color(0xFF858076);
  static const onGold = Color(0xFF241A09);
  static const success = Color(0xFF30D158);
  static const error = Color(0xFFFF453A);
  static const warning = Color(0xFFFFD60A);
}

abstract final class Space {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20;
  static const double xxl = 24, section = 32, hero = 40;
}
