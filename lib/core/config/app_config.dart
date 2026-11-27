import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF172554);
  static const secondary = Color(0xFF334E68);
  static const accent = Color(0xFF2563EB);
  static const appBackground = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const primaryText = Color(0xFF0F172A);
  static const secondaryText = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);
}

abstract final class AppConfig {
  static const appName = 'CopMap';
  static const brandColor = AppColors.primary;
}
