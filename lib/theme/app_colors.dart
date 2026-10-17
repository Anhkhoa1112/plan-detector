import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds (Dark Mode)
  static const Color bgDark = Color(0xFF050706); // Nền chính
  static const Color bgDarkSecondary = Color(0xFF0A0F0C); // Gradient / vùng chuyển

  // Backgrounds (Light Mode)
  static const Color bgLight = Color(0xFFEFF5F1); // Nền chính sáng
  static const Color bgLightSecondary = Color(0xFFDFECE4); // Gradient sáng

  // Glass tokens (Dark Mode)
  // Glass: #FFFFFF 6–9% (Mặt kính)
  static final Color glassDark = Colors.white.withValues(alpha: 0.08);
  // Glass sáng: #FFFFFF 10–14% (Card nổi)
  static final Color glassDarkElevated = Colors.white.withValues(alpha: 0.12);
  // Glass border: #FFFFFF 12–18% (Viền kính)
  static final Color glassDarkBorder = Colors.white.withValues(alpha: 0.15);

  // Glass tokens (Light Mode)
  static final Color glassLight = Colors.white.withValues(alpha: 0.72);
  static final Color glassLightElevated = Colors.white.withValues(alpha: 0.88);
  static final Color glassLightBorder = Colors.white.withValues(alpha: 0.60);

  // Primary Emerald
  static const Color primaryEmerald = Color(0xFF35E88A); // AI, Scan, Detection
  static const Color emeraldDark = Color(0xFF15945A); // Gradient phụ
  static final Color emeraldGlow = const Color(0xFF35E88A).withValues(alpha: 0.25); // Glow 20-30%

  // AI Accents
  static const Color aiBlue = Color(0xFF6C8CFF); // Processing / AI
  static const Color aiPurple = Color(0xFF9B7CFF); // Accent phụ

  // Text tokens (Dark Mode)
  static const Color textMainDark = Color(0xFFF5F7F6); // Heading
  static const Color textSubDark = Color(0xFFA8B0AC); // Description
  static const Color textMutedDark = Color(0xFF68736D); // Caption

  // Text tokens (Light Mode)
  static const Color textMainLight = Color(0xFF0C1610); // Heading
  static const Color textSubLight = Color(0xFF3E4E45); // Description
  static const Color textMutedLight = Color(0xFF6E8075); // Caption

  // Status
  static const Color error = Color(0xFFFF647C); // Error
  static const Color warning = Color(0xFFFFCA5C); // Warning / Confidence thấp

  // Dynamic confidence color grading
  static Color forConfidence(double confidence) {
    if (confidence >= 0.70) return primaryEmerald;
    if (confidence >= 0.40) return warning;
    return error;
  }
}
