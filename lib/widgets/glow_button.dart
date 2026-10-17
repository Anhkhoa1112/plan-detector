import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isPrimary = true,
    this.isLoading = false,
    this.isDarkMode = true,
    this.height = 54.0,
    this.borderRadius = 27.0,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final bool isLoading;
  final bool isDarkMode;
  final double height;
  final double borderRadius;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final baseDecoration = widget.isPrimary
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryEmerald,
                AppColors.emeraldDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.38),
                      blurRadius: _isPressed ? 8 : 18,
                      spreadRadius: _isPressed ? -2 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          )
        : BoxDecoration(
            color: widget.isDarkMode
                ? AppColors.glassDarkElevated
                : AppColors.glassLightElevated,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.isDarkMode
                  ? AppColors.glassDarkBorder
                  : AppColors.glassLightBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isDarkMode
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          );

    final textColor = widget.isPrimary
        ? const Color(0xFF04180E)
        : (widget.isDarkMode ? AppColors.textMainDark : AppColors.textMainLight);

    return AnimatedScale(
      scale: _isPressed && isEnabled ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          opacity: isEnabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: widget.height,
            decoration: baseDecoration,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isPrimary
                            ? const Color(0xFF04180E)
                            : AppColors.primaryEmerald,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 20,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
