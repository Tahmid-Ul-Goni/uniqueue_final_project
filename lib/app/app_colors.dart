import 'package:flutter/material.dart';

/// Single source of truth for the UniQueue flat visual system.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0A2A66);
  static const primaryDark = Color(0xFF071D49);
  static const primarySoft = Color(0xFFE6ECF7);
  static const accent = Color(0xFFD32F2F);
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFD9DEE7);
  static const textPrimary = Color(0xFF12202F);
  static const textSecondary = Color(0xFF5B6776);
  static const disabled = Color(0xFFB8C0CC);
  static const skeleton = Color(0xFFE9ECEF);

  static const waitingFill = Color(0xFFE6ECF7);
  static const waitingText = Color(0xFF0A2A66);
  static const approachingFill = Color(0xFFFFF3CD);
  static const approachingText = Color(0xFF7A5600);
  static const servingFill = Color(0xFFDDF3E4);
  static const servingText = Color(0xFF14683A);
  static const onHoldFill = Color(0xFFFFE6D0);
  static const onHoldText = Color(0xFF9A4A00);
  static const completedFill = Color(0xFFE9ECEF);
  static const completedText = Color(0xFF3F4A56);
  static const cancelledFill = Color(0xFFFBE0E0);
  static const cancelledText = Color(0xFF9B1C1C);
  static const expiredFill = Color(0xFFEDE7F6);
  static const expiredText = Color(0xFF4A2C82);

  static const success = Color(0xFF14683A);
  static const successSoft = Color(0xFFDDF3E4);
  static const warning = Color(0xFF9A4A00);
  static const warningSoft = Color(0xFFFFE6D0);
  static const error = Color(0xFFB3261E);
  static const info = primary;

  // Compatibility aliases used by existing screen widgets.
  static const red = accent;
  static const redDark = primaryDark;
  static const redSoft = primarySoft;
}
