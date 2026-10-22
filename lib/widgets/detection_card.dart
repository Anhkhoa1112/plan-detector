import 'package:flutter/material.dart';
import '../models/detection.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class DetectionCard extends StatelessWidget {
  const DetectionCard({
    super.key,
    required this.detection,
    this.color = AppColors.primaryEmerald,
    this.isSelected = false,
    this.isDarkMode = true,
    this.onTap,
  });

  final Detection detection;
  final Color color;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasViName = detection.nameVi != null && detection.nameVi!.trim().isNotEmpty;
    final plantName = hasViName ? detection.nameVi! : detection.className;

    final textMain = isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

    return GlassCard(
      onTap: onTap,
      borderRadius: 20.0,
      isDarkMode: isDarkMode,
      isElevated: isSelected,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      borderColor: isSelected ? color : null,
      borderWidth: isSelected ? 2.0 : 1.0,
      glowColor: isSelected ? color.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Plant Icon & Plant Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tên cây: $plantName',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (hasViName)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          detection.className,
                          style: TextStyle(
                            color: textSub,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Đặc điểm nhận dạng / mô tả
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Đặc điểm:',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detection.description,
                  style: TextStyle(
                    color: textSub,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
