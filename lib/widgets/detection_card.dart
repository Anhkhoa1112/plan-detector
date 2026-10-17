import 'package:flutter/material.dart';
import '../models/detection.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class DetectionCard extends StatelessWidget {
  const DetectionCard({
    super.key,
    required this.index,
    required this.detection,
    this.color = AppColors.primaryEmerald,
    this.isSelected = false,
    this.isDarkMode = true,
    this.onTap,
  });

  final int index;
  final Detection detection;
  final Color color;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final confPct = (detection.confidence * 100).toStringAsFixed(1);
    final confColor = AppColors.forConfidence(detection.confidence);
    final hasViName = detection.nameVi != null && detection.nameVi!.trim().isNotEmpty;

    final textMain = isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;
    final textMuted = isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight;

    return GlassCard(
      onTap: onTap,
      borderRadius: 20.0,
      isDarkMode: isDarkMode,
      isElevated: isSelected,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: isSelected ? color : null,
      borderWidth: isSelected ? 2.0 : 1.0,
      glowColor: isSelected ? color.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Index Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '#$index',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Plant Titles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasViName ? detection.nameVi! : detection.className,
                      style: TextStyle(
                        color: textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
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
              // Confidence Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: confColor.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: confColor.withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: confColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$confPct%',
                      style: TextStyle(
                        color: confColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Confidence Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Độ tin cậy AI',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _confidenceLabel(detection.confidence),
                    style: TextStyle(
                      color: confColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(
                      height: 7,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    FractionallySizedBox(
                      widthFactor: detection.confidence.clamp(0.0, 1.0),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              confColor.withValues(alpha: 0.8),
                              confColor,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: confColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Metadata footer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.crop_free_rounded,
                      size: 13,
                      color: textSub,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${detection.bbox.width.toInt()} × ${detection.bbox.height.toInt()} px',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Class ID: ${detection.classId}',
                  style: TextStyle(
                    color: textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _confidenceLabel(double conf) {
    if (conf >= 0.85) return 'Rất cao';
    if (conf >= 0.70) return 'Độ tin cậy tốt';
    if (conf >= 0.40) return 'Trung bình';
    return 'Cần xác minh thêm';
  }
}
