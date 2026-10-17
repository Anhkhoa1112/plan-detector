import re

def update_home_screen():
    path = "D:/plant_detector_app/lib/screens/home_screen.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check if already updated
    if "prediction.isUncertain" in content:
        print("home_screen.dart already contains isUncertain handling.")
        return

    # In _buildResultSection, inject Uncertain notice before detections list
    target = "        const SizedBox(height: 12),\n\n        ...List.generate(prediction.detections.length, (index) {"
    replacement = """        const SizedBox(height: 12),

        if (prediction.isUncertain) ...[
          GlassCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 16,
            isDarkMode: _isDarkMode,
            borderColor: AppColors.warning.withValues(alpha: 0.50),
            glowColor: AppColors.warning.withValues(alpha: 0.15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.help_outline_rounded, color: AppColors.warning, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chưa thể xác nhận chắc chắn (Uncertain)',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prediction.message ??
                            'Mô hình phát hiện đặc điểm tương đồng nhưng độ tin cậy chưa vượt ngưỡng an toàn. Bạn nên chụp cận cảnh hoặc rõ nét hơn để xác nhận chính xác.',
                        style: TextStyle(
                          color: _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        ...List.generate(prediction.detections.length, (index) {"""

    if target in content:
        content = content.replace(target, replacement, 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print("Updated home_screen.dart with Uncertain banner successfully.")
    else:
        print("Could not find exact target block in home_screen.dart.")

if __name__ == "__main__":
    update_home_screen()
