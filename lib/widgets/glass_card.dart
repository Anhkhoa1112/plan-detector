import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.isDarkMode = true,
    this.isElevated = false,
    this.backgroundColor,
    this.borderColor,
    this.blurSigma = 14.0,
    this.borderWidth = 1.0,
    this.glowColor,
    this.onTap,
    this.height,
    this.width,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool isDarkMode;
  final bool isElevated;
  final Color? backgroundColor;
  final Color? borderColor;
  final double blurSigma;
  final double borderWidth;
  final Color? glowColor;
  final VoidCallback? onTap;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ??
        (isDarkMode
            ? (isElevated ? AppColors.glassDarkElevated : AppColors.glassDark)
            : (isElevated ? AppColors.glassLightElevated : AppColors.glassLight));

    final effectiveBorder = borderColor ??
        (isDarkMode ? AppColors.glassDarkBorder : AppColors.glassLightBorder);

    Widget cardBody = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: effectiveBorder,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0xFF15945A).withValues(alpha: 0.08),
                blurRadius: isDarkMode ? 18 : 22,
                offset: const Offset(0, 8),
              ),
              if (glowColor != null)
                BoxShadow(
                  color: glowColor!,
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      cardBody = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.primaryEmerald.withValues(alpha: 0.16),
          highlightColor: isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          child: cardBody,
        ),
      );
    }

    if (margin != null) {
      cardBody = Padding(
        padding: margin!,
        child: cardBody,
      );
    }

    return cardBody;
  }
}
