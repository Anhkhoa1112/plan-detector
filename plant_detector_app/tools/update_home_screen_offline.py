import re

path = "D:/plant_detector_app/lib/screens/home_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add import for LocalPlantDetectorService if not present
if "local_plant_detector_service.dart" not in content:
    target_import = "import '../services/plant_api_client.dart';"
    replacement_import = "import '../services/plant_api_client.dart';\nimport '../services/local_plant_detector_service.dart';"
    content = content.replace(target_import, replacement_import, 1)

# 2. Add _isOfflineMode state variable
if "bool _isOfflineMode =" not in content:
    target_state = "bool _isDarkMode = true;"
    replacement_state = "bool _isDarkMode = true;\n  bool _isOfflineMode = true; // Default: Standalone on-device AI"
    content = content.replace(target_state, replacement_state, 1)

# 3. In initState, initialize LocalPlantDetectorService
if "LocalPlantDetectorService.instance.initialize()" not in content:
    target_init = "_checkHealth();\n  }"
    replacement_init = """_checkHealth();
    LocalPlantDetectorService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }"""
    content = content.replace(target_init, replacement_init, 1)

# 4. In _detectImage, branch based on _isOfflineMode
old_detect_call = "final prediction = await _apiClient.predictImage(image);"
new_detect_call = """final PredictionResponse prediction;
      if (_isOfflineMode) {
        prediction = await LocalPlantDetectorService.instance.predict(image);
      } else {
        prediction = await _apiClient.predictImage(image);
      }"""
if old_detect_call in content:
    content = content.replace(old_detect_call, new_detect_call, 1)

# 5. In _buildAiStatusCard, update to show offline mode status and toggle switch
old_status_card_target = """Widget _buildAiStatusCard() {
    final isOnline = _health?.isReady ?? false;"""

new_status_card_body = """Widget _buildAiStatusCard() {
    final isLocalReady = LocalPlantDetectorService.instance.isReady;
    final isOnline = _isOfflineMode ? isLocalReady : (_health?.isReady ?? false);
    final statusColor = _isOfflineMode
        ? (isLocalReady ? AppColors.primaryEmerald : AppColors.warning)
        : (_checkingHealth
            ? AppColors.warning
            : (isOnline ? AppColors.primaryEmerald : AppColors.error));

    final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = _isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 18,
      isDarkMode: _isDarkMode,
      borderColor: statusColor.withValues(alpha: 0.35),
      glowColor: isOnline ? AppColors.primaryEmerald.withValues(alpha: 0.14) : null,
      child: Row(
        children: [
          // Glowing status indicator dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.65),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isOfflineMode
                          ? (isLocalReady ? '✦ AI Offline Sẵn Sàng' : 'Đang nạp AI Offline...')
                          : (_checkingHealth
                              ? 'Đang kiểm tra kết nối AI...'
                              : (isOnline ? '✦ AI Engine Server' : 'Mất kết nối máy chủ AI')),
                      style: TextStyle(
                        color: textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isOfflineMode
                            ? AppColors.primaryEmerald.withValues(alpha: 0.20)
                            : AppColors.aiBlue.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isOfflineMode ? 'ON-DEVICE' : 'SERVER',
                        style: TextStyle(
                          color: _isOfflineMode ? AppColors.primaryEmerald : AppColors.aiBlue,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isOfflineMode
                    ? 'YOLOv8n Onnx • 12 loài • Offline 100% không cần PC'
                    : (isOnline
                        ? 'YOLOv8n • 12 loài cây • $_activeBaseUrl'
                        : 'Không kết nối được $_activeBaseUrl'),
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Toggle button between Offline On-Device and Remote Server
          InkWell(
            onTap: () {
              setState(() {
                _isOfflineMode = !_isOfflineMode;
                _prediction = null;
                _errorMessage = null;
              });
              if (!_isOfflineMode) {
                _checkHealth();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDarkMode ? AppColors.glassDarkBorder : AppColors.glassLightBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOfflineMode ? Icons.phone_android_rounded : Icons.cloud_outlined,
                    size: 14,
                    color: _isOfflineMode ? AppColors.primaryEmerald : AppColors.aiBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOfflineMode ? 'Đổi Server' : 'Đổi Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textMain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }"""

# Find where _buildAiStatusCard starts and where the old function ends
start_idx = content.find("Widget _buildAiStatusCard() {")
if start_idx != -1:
    end_marker = "  Widget _buildWorkspaceArea() {"
    end_idx = content.find(end_marker, start_idx)
    if end_idx != -1:
        content = content[:start_idx] + new_status_card_body + "\n\n" + content[end_idx:]
        print("Updated _buildAiStatusCard successfully.")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated home_screen.dart successfully.")
