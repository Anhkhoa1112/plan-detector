import 'package:flutter/material.dart';

import '../models/fruit_analysis.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class FruitResultCard extends StatelessWidget {
  const FruitResultCard({
    super.key,
    required this.result,
    required this.isDarkMode,
  });

  final FruitAnalysisResult result;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    if (result.status == RipenessStatus.notFruit) {
      return _buildNotFruitCard(context);
    }

    final textMain = isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;
    final textMuted = isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight;

    final statusColor = result.status.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Thẻ Tiêu Đề Chính & Tình Trạng Quả
        GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 24,
          isDarkMode: isDarkMode,
          borderColor: statusColor.withValues(alpha: 0.40),
          glowColor: statusColor.withValues(alpha: 0.16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng thông tin tên quả & Huy hiệu tình trạng
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon quả lớn
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        result.iconEmoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Tên quả & Tiêu đề
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              result.nameVi,
                              style: TextStyle(
                                color: textMain,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${result.nameEn})',
                              style: TextStyle(
                                color: textSub,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(result.status.icon, color: statusColor, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                result.status.badgeText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Headline & Tóm tắt đánh giá
              Text(
                result.headline,
                style: TextStyle(
                  color: textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.summary,
                style: TextStyle(
                  color: textSub,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),

              // Bằng chứng thị giác phát hiện
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.remove_red_eye_outlined, color: AppColors.aiBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.evidence,
                        style: TextStyle(
                          color: textSub,
                          fontSize: 12.5,
                          height: 1.38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Thước Đo Tiến Trình Độ Chín (Ripeness Progress Meter) & Độ Tươi Ngon
        GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 22,
          isDarkMode: isDarkMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, color: AppColors.primaryEmerald, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Chỉ số độ chín & độ tươi',
                        style: TextStyle(
                          color: textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Độ tin cậy ${(result.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thanh đo Độ Chín (%)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mức độ chín quả:', style: TextStyle(color: textSub, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    '${result.ripenessPercent.toStringAsFixed(0)}%',
                    style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (result.ripenessPercent / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 14),

              // Thanh đo Độ Tươi Ngon (%)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Độ tươi ngon an toàn:', style: TextStyle(color: textSub, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    '${result.freshnessPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: result.freshnessPercent >= 70 ? AppColors.primaryEmerald : AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (result.freshnessPercent / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    result.freshnessPercent >= 70 ? AppColors.primaryEmerald : AppColors.error,
                  ),
                ),
              ),

              if (result.estimatedDaysToRipe != null && result.estimatedDaysToRipe! > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.aiBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.aiBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.aiBlue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dự kiến chín hoàn hảo sau khoảng ${result.estimatedDaysToRipe} ngày nữa (ở nhiệt độ phòng).',
                          style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF1E3A8A), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Khuyến Nghị Sử Dụng & Ăn Uống (Edibility Verdict)
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          isDarkMode: isDarkMode,
          borderColor: result.isRotten
              ? AppColors.error.withValues(alpha: 0.40)
              : AppColors.primaryEmerald.withValues(alpha: 0.35),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: result.isRotten
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.primaryEmerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  result.isRotten ? Icons.warning_rounded : Icons.restaurant_menu_rounded,
                  color: result.isRotten ? AppColors.error : AppColors.primaryEmerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khuyến nghị tiêu dùng',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.edibilityVerdict,
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
        ),
        const SizedBox(height: 14),

        // 4. Mẹo Bảo Quản & Dinh Dưỡng
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                context,
                title: 'Mẹo bảo quản',
                icon: Icons.kitchen_rounded,
                iconColor: const Color(0xFF06B6D4),
                content: result.storageTip,
                textMain: textMain,
                textSub: textSub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                context,
                title: 'Dinh dưỡng & Sức khỏe',
                icon: Icons.health_and_safety_rounded,
                iconColor: const Color(0xFFA855F7),
                content: result.nutritionNote,
                textMain: textMain,
                textSub: textSub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 5. Phân Tích Quang Phổ Màu Sắc (Color Spectrum Breakdown)
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          isDarkMode: isDarkMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phân tích quang phổ màu sắc',
                style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildMetricRow('Sắc vàng (Chín đường)', result.metrics.yellowRatio, const Color(0xFFFBBF24)),
              const SizedBox(height: 8),
              _buildMetricRow('Sắc cam (Carotenoid)', result.metrics.orangeRatio, const Color(0xFFFB923C)),
              const SizedBox(height: 8),
              _buildMetricRow('Sắc đỏ (Anthocyanin/Lycopene)', result.metrics.redRatio, const Color(0xFFF87171)),
              const SizedBox(height: 8),
              _buildMetricRow('Sắc xanh lục (Diệp lục non)', result.metrics.greenRatio, const Color(0xFF34D399)),
              const SizedBox(height: 8),
              _buildMetricRow('Đốm thâm nâu (Dập / Hoại tử)', result.metrics.brownRotRatio, const Color(0xFF78716C)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
    required Color textMain,
    required Color textSub,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: textSub,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, double ratio, Color barColor) {
    final textSub = isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;
    final percent = (ratio * 100).toStringAsFixed(1);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: textSub, fontSize: 12)),
            Text('$percent%', style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildNotFruitCard(BuildContext context) {
    final textMain = isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      borderRadius: 22,
      isDarkMode: isDarkMode,
      borderColor: AppColors.warning.withValues(alpha: 0.45),
      glowColor: AppColors.warning.withValues(alpha: 0.15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.warning,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Không nhận diện thấy quả trái cây',
            style: TextStyle(
              color: textMain,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.summary,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSub,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Mẹo chụp ảnh trái cây chuẩn AI Mobile:',
                  style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('• Đặt quả ở vị trí trung tâm khung ngắm máy ảnh', style: TextStyle(color: textSub, fontSize: 12)),
                Text('• Giữ khoảng cách 20 - 40 cm, đủ sáng, tránh bóng râm tối sầm', style: TextStyle(color: textSub, fontSize: 12)),
                Text('• Bạn có thể chọn cụ thể loại quả (Chuối, Xoài, Cam...) trên thanh công cụ', style: TextStyle(color: textSub, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
