import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/health_status.dart';
import '../models/prediction_response.dart';
import '../services/plant_api_client.dart';
import '../services/local_plant_detector_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bounding_box_overlay.dart';
import '../widgets/detection_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/glow_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late PlantApiClient _apiClient;
  String _activeBaseUrl = AppConfig.backendBaseUrl;
  final ImagePicker _imagePicker = ImagePicker();

  // Theme Mode State: Dark / Light Mode Toggle
  bool _isDarkMode = true;
  bool _isOfflineMode = true; // Default: Standalone on-device AI

  HealthStatus? _health;
  PredictionResponse? _prediction;
  File? _selectedImage;
  int? _imageNativeWidth;
  int? _imageNativeHeight;

  String? _errorMessage;
  bool _checkingHealth = false;
  bool _pickingImage = false;
  bool _detecting = false;
  bool _showOverlay = true;
  int? _selectedDetectionIndex;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _initApiClient(_activeBaseUrl);
    _checkHealth();
    LocalPlantDetectorService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _apiClient.close();
    super.dispose();
  }

  void _initApiClient(String baseUrl) {
    _apiClient = PlantApiClient(baseUrl: baseUrl);
  }

  Future<void> _checkHealth() async {
    setState(() {
      _checkingHealth = true;
      _errorMessage = null;
    });

    try {
      final health = await _apiClient.getHealth();
      if (!mounted) return;
      setState(() {
        _health = health;
      });
    } on PlantApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _health = null;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _health = null;
        _errorMessage = 'Không thể kết nối máy chủ backend: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingHealth = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _pickingImage = true;
      _errorMessage = null;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (picked != null) {
        final file = File(picked.path);
        final size = await file.length();
        if (size > PlantApiClient.maxFileBytes) {
          final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
          if (!mounted) return;
          _showErrorSnackbar('Ảnh quá lớn ($sizeMb MB). Vui lòng chọn ảnh dưới 10 MB.');
          return;
        }

        final dimensions = await _decodeImageDimensions(file);

        if (!mounted) return;
        setState(() {
          _selectedImage = file;
          _imageNativeWidth = dimensions.width.toInt();
          _imageNativeHeight = dimensions.height.toInt();
          _prediction = null;
          _selectedDetectionIndex = null;
          _showOverlay = true;
        });
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      if (error.code == 'camera_access_denied') {
        _showPermissionDialog('Quyền Camera', 'Vui lòng cấp quyền Camera trong cài đặt điện thoại để chụp ảnh cây.');
      } else if (error.code == 'photo_access_denied') {
        _showPermissionDialog('Quyền Thư viện ảnh', 'Vui lòng cấp quyền truy cập ảnh trong cài đặt điện thoại.');
      } else {
        _showErrorSnackbar('Lỗi quyền thiết bị: ${error.message}');
      }
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackbar('Không thể chọn ảnh: $error');
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
        });
      }
    }
  }

  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: _isDarkMode ? AppColors.glassDarkBorder : AppColors.glassLightBorder,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu', style: TextStyle(color: AppColors.primaryEmerald)),
          ),
        ],
      ),
    );
  }

  Future<Size> _decodeImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) => completer.complete(img));
      final img = await completer.future;
      return Size(img.width.toDouble(), img.height.toDouble());
    } catch (_) {
      return const Size(1000, 1000);
    }
  }

  Future<void> _detectImage() async {
    final image = _selectedImage;
    if (image == null) {
      _showErrorSnackbar('Vui lòng chọn hoặc chụp ảnh trước khi nhận dạng.');
      return;
    }

    setState(() {
      _detecting = true;
      _errorMessage = null;
      _prediction = null;
      _selectedDetectionIndex = null;
    });

    try {
      final PredictionResponse prediction;
      if (_isOfflineMode) {
        prediction = await LocalPlantDetectorService.instance.predict(image);
      } else {
        prediction = await _apiClient.predictImage(image);
      }
      if (!mounted) return;
      setState(() {
        _prediction = prediction;
        if (prediction.imageWidth > 0 && prediction.imageHeight > 0) {
          _imageNativeWidth = prediction.imageWidth;
          _imageNativeHeight = prediction.imageHeight;
        }
      });
      if (!prediction.isPlant) {
        _showInfoSnackbar('⚠️ Ảnh không phải là cây! Vui lòng chụp rõ cây cỏ, hoa lá hoặc thân cây.');
      } else if (prediction.detections.isEmpty) {
        _showInfoSnackbar('Không phát hiện thấy loài cây nào đạt ngưỡng tin cậy (>25%).');
      }
    } on PlantApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
      _showErrorSnackbar(error.message);
    } catch (error) {
      if (!mounted) return;
      final msg = 'Lỗi không xác định: $error';
      setState(() {
        _errorMessage = msg;
      });
      _showErrorSnackbar(msg);
    } finally {
      if (mounted) {
        setState(() {
          _detecting = false;
        });
      }
    }
  }

  void _resetImage() {
    setState(() {
      _selectedImage = null;
      _prediction = null;
      _selectedDetectionIndex = null;
      _errorMessage = null;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Color(0xFF050706))),
        backgroundColor: AppColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: _activeBaseUrl);
    showDialog(
      context: context,
      builder: (context) {
        final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
        final textSub = _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

        return AlertDialog(
          backgroundColor: _isDarkMode ? AppColors.bgDarkSecondary : AppColors.bgLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: _isDarkMode ? AppColors.glassDarkBorder : AppColors.glassLightBorder,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lan_rounded, color: AppColors.primaryEmerald, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Cài đặt Máy chủ AI',
                style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhập địa chỉ URL backend FastAPI trong mạng LAN của bạn:',
                style: TextStyle(color: textSub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: TextStyle(color: textMain, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  labelStyle: TextStyle(color: textSub),
                  hintText: 'http://192.168.100.245:8000',
                  hintStyle: TextStyle(
                    color: _isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                  filled: true,
                  fillColor: _isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _isDarkMode ? AppColors.glassDarkBorder : AppColors.glassLightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.link_rounded, color: AppColors.primaryEmerald),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy', style: TextStyle(color: textSub)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: const Color(0xFF04180E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final newUrl = controller.text.trim();
                if (newUrl.isNotEmpty) {
                  setState(() {
                    _activeBaseUrl = newUrl;
                    _initApiClient(newUrl);
                  });
                  Navigator.pop(context);
                  _checkHealth();
                }
              },
              child: const Text('Lưu & Kết nối', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? AppColors.bgDark : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Fluid Ambient Background Lights (iPhone Liquid Glass Effect)
          if (_isDarkMode) ...[
            // Deep emerald ambient light at top-center
            Positioned(
              top: -120,
              left: -40,
              right: -40,
              height: 420,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 0.85,
                    colors: [
                      AppColors.primaryEmerald.withValues(alpha: 0.16),
                      AppColors.emeraldDark.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // AI Blue fluid backlight at bottom-right
            Positioned(
              bottom: -100,
              right: -80,
              width: 360,
              height: 360,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.80,
                    colors: [
                      AppColors.aiBlue.withValues(alpha: 0.14),
                      AppColors.aiPurple.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Light mode soft pastel mesh gradient
            Positioned(
              top: -140,
              left: -50,
              right: -50,
              height: 450,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 0.90,
                    colors: [
                      const Color(0xFFB4F2D0).withValues(alpha: 0.55),
                      const Color(0xFFC7E2FF).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              width: 340,
              height: 340,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.75,
                    colors: [
                      const Color(0xFFD6C8FF).withValues(alpha: 0.40),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // 2. Main Scrollable Content inside SafeArea
          SafeArea(
            child: Column(
              children: [
                _buildHeaderBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAiStatusCard(),
                        const SizedBox(height: 14),
                        _buildWorkspaceArea(),
                        const SizedBox(height: 16),
                        if (_prediction != null) _buildResultSection(),
                        if (_errorMessage != null && _selectedImage == null)
                          _buildErrorCard(_errorMessage!),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Brand Logo Badge with Emerald Glow
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryEmerald, AppColors.emeraldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.energy_savings_leaf_rounded,
              color: Color(0xFF04180E),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // App Title & Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Scan',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'AI Plant Recognition',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '✦ V1',
                      style: TextStyle(
                        color: AppColors.primaryEmerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Theme Toggle Button (Light/Dark Mode)
          GlassCard(
            padding: const EdgeInsets.all(8),
            borderRadius: 14,
            isDarkMode: _isDarkMode,
            blurSigma: 8,
            onTap: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
            child: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkMode ? const Color(0xFFFFCA5C) : const Color(0xFF15945A),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // Settings Button (Liquid Glass)
          GlassCard(
            padding: const EdgeInsets.all(8),
            borderRadius: 14,
            isDarkMode: _isDarkMode,
            blurSigma: 8,
            onTap: _showServerSettingsDialog,
            child: Icon(
              Icons.tune_rounded,
              color: textMain,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiStatusCard() {
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
  }

  Widget _buildWorkspaceArea() {
    if (_selectedImage == null) {
      return _buildIdleViewfinder();
    }
    return _buildImageWorkspace();
  }

  Widget _buildIdleViewfinder() {
    final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;
    final textMuted = _isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      borderRadius: 26,
      isDarkMode: _isDarkMode,
      child: Column(
        children: [
          // Viewfinder Frame with Liquid Glass backdrop
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ..._buildCornerBrackets(),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppColors.primaryEmerald.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryEmerald.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.primaryEmerald,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '✦ Sẵn sàng nhận diện',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chụp hoặc chọn ảnh cây để quét',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buttons: Camera & Gallery
          Row(
            children: [
              Expanded(
                flex: 5,
                child: GlowButton(
                  onPressed: _pickingImage ? null : () => _pickImage(ImageSource.camera),
                  label: 'Camera',
                  icon: Icons.photo_camera_rounded,
                  isPrimary: true,
                  isDarkMode: _isDarkMode,
                  height: 54,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: GlowButton(
                  onPressed: _pickingImage ? null : () => _pickImage(ImageSource.gallery),
                  label: 'Thư viện',
                  icon: Icons.photo_library_rounded,
                  isPrimary: false,
                  isDarkMode: _isDarkMode,
                  height: 54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Badges
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('✓ 12 loài cây', style: TextStyle(color: textMuted, fontSize: 11)),
              Text('•', style: TextStyle(color: textMuted, fontSize: 11)),
              Text('✓ Bounding Box', style: TextStyle(color: textMuted, fontSize: 11)),
              Text('•', style: TextStyle(color: textMuted, fontSize: 11)),
              Text('✓ YOLOv8 AI', style: TextStyle(color: textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBrackets() {
    const cSize = 20.0;
    const cWidth = 2.5;
    const cColor = AppColors.primaryEmerald;

    return [
      Positioned(
        top: 14,
        left: 14,
        child: Container(
          width: cSize,
          height: cSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cColor, width: cWidth),
              left: BorderSide(color: cColor, width: cWidth),
            ),
          ),
        ),
      ),
      Positioned(
        top: 14,
        right: 14,
        child: Container(
          width: cSize,
          height: cSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cColor, width: cWidth),
              right: BorderSide(color: cColor, width: cWidth),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 14,
        left: 14,
        child: Container(
          width: cSize,
          height: cSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cColor, width: cWidth),
              left: BorderSide(color: cColor, width: cWidth),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 14,
        right: 14,
        child: Container(
          width: cSize,
          height: cSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cColor, width: cWidth),
              right: BorderSide(color: cColor, width: cWidth),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildImageWorkspace() {
    final image = _selectedImage!;
    final width = _imageNativeWidth ?? 1000;
    final height = _imageNativeHeight ?? 1000;
    final textMuted = _isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (_prediction != null && _prediction!.detections.isNotEmpty && _showOverlay)
              BoundingBoxOverlay(
                imageFile: image,
                imageWidth: width,
                imageHeight: height,
                detections: _prediction!.detections,
                selectedIndex: _selectedDetectionIndex,
                maxHeight: 340,
                onSelectDetection: (index) {
                  setState(() {
                    _selectedDetectionIndex = index;
                  });
                },
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 340),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isDarkMode
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.10),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isDarkMode
                          ? Colors.black.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.file(
                    image,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            // Scanning Laser Line Overlay
            if (_detecting)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ScanLinePainter(
                          progress: _scanAnimation.value,
                          color: AppColors.primaryEmerald,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Controls
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 22,
          isDarkMode: _isDarkMode,
          child: Column(
            children: [
              if (_detecting) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Đang phân tích mô hình YOLO...',
                      style: TextStyle(
                        color: AppColors.primaryEmerald,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Đang xử lý hình ảnh và tìm kiếm đối tượng thực vật',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ] else if (_prediction == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: GlowButton(
                    onPressed: _detectImage,
                    label: 'Nhận diện loài cây',
                    icon: Icons.auto_awesome_rounded,
                    isPrimary: true,
                    isDarkMode: _isDarkMode,
                    height: 52,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlowButton(
                        onPressed: () => _pickImage(ImageSource.camera),
                        label: 'Chụp lại',
                        icon: Icons.refresh_rounded,
                        isPrimary: false,
                        isDarkMode: _isDarkMode,
                        height: 44,
                        borderRadius: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlowButton(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        label: 'Chọn khác',
                        icon: Icons.photo_library_outlined,
                        isPrimary: false,
                        isDarkMode: _isDarkMode,
                        height: 44,
                        borderRadius: 14,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: GlowButton(
                        onPressed: () => _pickImage(ImageSource.camera),
                        label: 'Chụp mới',
                        icon: Icons.photo_camera_rounded,
                        isPrimary: true,
                        isDarkMode: _isDarkMode,
                        height: 46,
                        borderRadius: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlowButton(
                        onPressed: _resetImage,
                        label: 'Đóng ảnh',
                        icon: Icons.close_rounded,
                        isPrimary: false,
                        isDarkMode: _isDarkMode,
                        height: 46,
                        borderRadius: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    final prediction = _prediction!;

    // Non-Plant or Empty Detection Check
    if (!prediction.isPlant || prediction.detections.isEmpty) {
      return _buildNonPlantOrEmptyCard(prediction);
    }

    final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_rounded, color: AppColors.primaryEmerald, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Kết quả nhận diện',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                '${prediction.detections.length} loài cây',
                style: const TextStyle(
                  color: AppColors.primaryEmerald,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

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

        ...List.generate(prediction.detections.length, (index) {
          final det = prediction.detections[index];
          final color = BoundingBoxOverlay.getColorForIndex(index);
          return DetectionCard(
            index: index + 1,
            detection: det,
            color: color,
            isDarkMode: _isDarkMode,
            isSelected: _selectedDetectionIndex == index,
            onTap: () {
              setState(() {
                if (_selectedDetectionIndex == index) {
                  _selectedDetectionIndex = null;
                } else {
                  _selectedDetectionIndex = index;
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildNonPlantOrEmptyCard(PredictionResponse prediction) {
    final isNonPlant = !prediction.isPlant;
    final alertColor = isNonPlant ? AppColors.warning : AppColors.error;
    final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 22,
      isDarkMode: _isDarkMode,
      borderColor: alertColor.withValues(alpha: 0.40),
      glowColor: alertColor.withValues(alpha: 0.15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNonPlant ? Icons.warning_amber_rounded : Icons.search_off_rounded,
              color: alertColor,
              size: 38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isNonPlant ? 'Ảnh không phải là cây!' : 'Không phát hiện thấy cây nào',
            style: TextStyle(
              color: textMain,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prediction.message ??
                (isNonPlant
                    ? 'Hệ thống AI không nhận diện được đặc điểm thực vật trong bức ảnh này.'
                    : 'Không tìm thấy loài cây phù hợp vượt qua ngưỡng tin cậy (>25%).'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSub,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Hướng dẫn chụp ảnh nhận diện chính xác:',
                  style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('• Hướng camera trực tiếp vào thân cây, cành lá hoặc hoa', style: TextStyle(color: textSub, fontSize: 12)),
                Text('• Đảm bảo đủ ánh sáng tự nhiên, không bị quá tối hoặc chói lóa', style: TextStyle(color: textSub, fontSize: 12)),
                Text('• Tránh chụp đồ vật trong phòng, màn hình điện tử hoặc con người', style: TextStyle(color: textSub, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlowButton(
            onPressed: () => _pickImage(ImageSource.camera),
            label: 'Chụp lại ảnh cây khác',
            icon: Icons.photo_camera_rounded,
            isPrimary: true,
            isDarkMode: _isDarkMode,
            height: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;
    final textMuted = _isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      isDarkMode: _isDarkMode,
      borderColor: AppColors.error.withValues(alpha: 0.40),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sự cố kết nối máy chủ',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Không thể gửi ảnh tới FastAPI AI engine',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: textSub,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlowButton(
                  onPressed: _checkHealth,
                  label: 'Thử lại',
                  icon: Icons.refresh_rounded,
                  isPrimary: true,
                  isDarkMode: _isDarkMode,
                  height: 44,
                  borderRadius: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlowButton(
                  onPressed: _showServerSettingsDialog,
                  label: 'Đổi IP',
                  icon: Icons.settings_rounded,
                  isPrimary: false,
                  isDarkMode: _isDarkMode,
                  height: 44,
                  borderRadius: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), glowPaint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final beamHeight = 40.0;
    final beamRect = Rect.fromLTRB(0, y - beamHeight, size.width, y);
    final beamPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - beamHeight),
        Offset(0, y),
        [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.20),
        ],
      );
    canvas.drawRect(beamRect, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
