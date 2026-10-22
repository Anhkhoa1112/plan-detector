import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/fruit_analysis.dart';
import '../models/prediction_response.dart';
import '../services/fruit_analyzer_service.dart';
import '../services/local_plant_detector_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bounding_box_overlay.dart';
import '../widgets/detection_card.dart';
import '../widgets/fruit_result_card.dart';
import '../widgets/fruit_selector_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/glow_button.dart';

enum AppScanMode {
  plant, // Nhận diện 12 loài cây trồng (ONNX AI)
  fruit, // Soi trái cây (Độ chín, Sống, Hư hỏng)
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  // Mode & Theme State - Mặc định là Nhận diện Cây trồng (Plant Mode)
  AppScanMode _scanMode = AppScanMode.plant;
  FruitCategory _selectedFruitCategory = FruitCategory.auto;
  bool _isDarkMode = true;

  // Selected Image & Dimensions
  File? _selectedImage;
  int? _imageNativeWidth;
  int? _imageNativeHeight;
  static const int maxFileBytes = 10 * 1024 * 1024; // 10 MB

  // Detection Results
  PredictionResponse? _plantPrediction;
  FruitAnalysisResult? _fruitResult;

  // UI Flow State
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

    LocalPlantDetectorService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.lightImpact();
    setState(() {
      _pickingImage = true;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (picked != null) {
        final file = File(picked.path);
        final size = await file.length();
        if (size > maxFileBytes) {
          final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
          if (!mounted) return;
          _showErrorSnackbar('Ảnh quá lớn ($sizeMb MB). Vui lòng chọn ảnh dưới 10 MB.');
          return;
        }

        if (!mounted) return;
        setState(() {
          _selectedImage = file;
          _plantPrediction = null;
          _fruitResult = null;
          _selectedDetectionIndex = null;
          _showOverlay = true;
        });

        _decodeImageDimensions(file).then((dimensions) {
          if (mounted && _selectedImage?.path == file.path) {
            setState(() {
              _imageNativeWidth = dimensions.width.toInt();
              _imageNativeHeight = dimensions.height.toInt();
            });
          }
        });

        // Tự động phân tích ảnh
        _runAnalysis();
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      if (error.code == 'camera_access_denied') {
        _showPermissionDialog('Quyền Máy Ảnh', 'Vui lòng cấp quyền Máy Ảnh trong cài đặt điện thoại để chụp ảnh nhận diện.');
      } else if (error.code == 'photo_access_denied') {
        _showPermissionDialog('Quyền Thư Viện', 'Vui lòng cấp quyền truy cập ảnh trong cài đặt điện thoại.');
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

  Future<void> _runAnalysis() async {
    final image = _selectedImage;
    if (image == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _detecting = true;
      _plantPrediction = null;
      _fruitResult = null;
      _selectedDetectionIndex = null;
    });

    try {
      if (_scanMode == AppScanMode.plant) {
        // Chế độ Cây trồng (Mô hình ONNX 12 loài)
        final prediction = await LocalPlantDetectorService.instance
            .predict(image)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Quá trình nhận diện mất quá nhiều thời gian. Vui lòng thử lại.');
        });

        if (!mounted) return;
        setState(() {
          _plantPrediction = prediction;
          if (prediction.imageWidth > 0 && prediction.imageHeight > 0) {
            _imageNativeWidth = prediction.imageWidth;
            _imageNativeHeight = prediction.imageHeight;
          }
        });

        if (!prediction.isPlant) {
          _showWarningSnackbar('⚠️ Không tìm thấy đặc tính cây rõ rệt. Hãy chụp lại gần tán lá hoặc thân cây.');
        }
      } else {
        // Chế độ Trái cây (Độ chín, Sống, Hư)
        final result = await FruitAnalyzerService.instance
            .analyzeFruit(image, targetCategory: _selectedFruitCategory)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Quá trình phân tích quả mất quá nhiều thời gian. Vui lòng thử lại.');
        });

        if (!mounted) return;
        setState(() {
          _fruitResult = result;
        });
      }

      // Tự động cuộn mượt mà xuống kết quả sau khi phân tích xong
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackbar('Lỗi phân tích: $error');
    } finally {
      if (mounted) {
        setState(() {
          _detecting = false;
        });
      }
    }
  }

  void _resetImage() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedImage = null;
      _plantPrediction = null;
      _fruitResult = null;
      _selectedDetectionIndex = null;
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

  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? AppColors.bgDark : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildAmbientGlows(),

          SafeArea(
            child: Column(
              children: [
                _buildHeaderBar(),
                _buildScanModeSwitcher(),
                if (_scanMode == AppScanMode.fruit) ...[
                  const SizedBox(height: 6),
                  FruitSelectorBar(
                    selectedCategory: _selectedFruitCategory,
                    onCategoryChanged: (cat) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedFruitCategory = cat;
                      });
                      if (_selectedImage != null) {
                        _runAnalysis();
                      }
                    },
                    isDarkMode: _isDarkMode,
                  ),
                ],
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildWorkspaceArea(),
                        if (_selectedImage != null && (_plantPrediction != null || _fruitResult != null)) ...[
                          const SizedBox(height: 16),
                          _buildResultArea(),
                        ],
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

  Widget _buildAmbientGlows() {
    final isFruit = _scanMode == AppScanMode.fruit;
    final accentColor = isFruit ? const Color(0xFFF59E0B) : AppColors.primaryEmerald;

    if (_isDarkMode) {
      return Stack(
        children: [
          Positioned(
            top: -120,
            left: -40,
            right: -40,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 0.85,
                  colors: [
                    accentColor.withValues(alpha: 0.16),
                    accentColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            width: 320,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.80,
                  colors: [
                    AppColors.aiBlue.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Positioned(
            top: -140,
            left: -50,
            right: -50,
            height: 420,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 0.90,
                  colors: [
                    const Color(0xFFB4F2D0).withValues(alpha: 0.50),
                    const Color(0xFFFED7AA).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildHeaderBar() {
    final textMain = _isDarkMode ? AppColors.textMainDark : AppColors.textMainLight;
    final textSub = _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _scanMode == AppScanMode.plant
                    ? [AppColors.primaryEmerald, AppColors.emeraldDark]
                    : [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (_scanMode == AppScanMode.plant ? AppColors.primaryEmerald : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _scanMode == AppScanMode.plant ? Icons.energy_savings_leaf_rounded : Icons.apple_rounded,
              color: const Color(0xFF04180E),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scanMode == AppScanMode.plant ? 'Plant AI Detector' : 'Fruit AI Inspector',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _scanMode == AppScanMode.plant ? '12 loài cây chuẩn xác' : 'Độ chín & chất lượng quả',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI PRO',
                        style: TextStyle(
                          color: AppColors.primaryEmerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          GlassCard(
            padding: const EdgeInsets.all(8),
            borderRadius: 12,
            isDarkMode: _isDarkMode,
            blurSigma: 8,
            onTap: () {
              HapticFeedback.lightImpact();
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
        ],
      ),
    );
  }

  Widget _buildScanModeSwitcher() {
    final activeBg = _isDarkMode ? Colors.white.withValues(alpha: 0.16) : Colors.white;
    final inactiveText = _isDarkMode ? AppColors.textSubDark : AppColors.textSubLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Tab 1: Nhận diện Cây cối (Mặc định)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_scanMode != AppScanMode.plant) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _scanMode = AppScanMode.plant;
                    });
                    if (_selectedImage != null) _runAnalysis();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _scanMode == AppScanMode.plant ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _scanMode == AppScanMode.plant
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🌿', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          'Quét Cây Cối',
                          style: TextStyle(
                            color: _scanMode == AppScanMode.plant
                                ? (_isDarkMode ? Colors.white : const Color(0xFF0F172A))
                                : inactiveText,
                            fontSize: 13,
                            fontWeight: _scanMode == AppScanMode.plant ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tab 2: Soi Trái cây (Chín/Sống/Hư)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_scanMode != AppScanMode.fruit) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _scanMode = AppScanMode.fruit;
                    });
                    if (_selectedImage != null) _runAnalysis();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _scanMode == AppScanMode.fruit ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _scanMode == AppScanMode.fruit
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🍎', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          'Soi Trái Cây',
                          style: TextStyle(
                            color: _scanMode == AppScanMode.fruit
                                ? (_isDarkMode ? Colors.white : const Color(0xFF0F172A))
                                : inactiveText,
                            fontSize: 13,
                            fontWeight: _scanMode == AppScanMode.fruit ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    final isFruit = _scanMode == AppScanMode.fruit;
    final accentColor = isFruit ? const Color(0xFFF59E0B) : AppColors.primaryEmerald;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      isDarkMode: _isDarkMode,
      child: Column(
        children: [
          Builder(
            builder: (context) {
              final screenH = MediaQuery.of(context).size.height;
              final viewfinderH = (screenH * 0.33).clamp(240.0, 330.0);

              return Container(
                height: viewfinderH,
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
                    ..._buildCornerBrackets(accentColor),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.14),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.25),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isFruit ? Icons.document_scanner_rounded : Icons.energy_savings_leaf_rounded,
                              color: accentColor,
                              size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isFruit ? '✦ Soi Trái Cây (Chín / Sống / Hư)' : '✦ Quét Nhận Diện 12 Loài Cây',
                          style: TextStyle(
                            color: textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFruit
                              ? 'Chụp quả trái cây để phân tích độ chín & chất lượng'
                              : 'Chụp rõ cành lá, thân hoặc tán cây (Xoài, Cọ, Dừa...)',
                          style: TextStyle(
                            color: textSub,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 6,
                child: GlowButton(
                  onPressed: _pickingImage ? null : () => _pickImage(ImageSource.camera),
                  label: 'Chụp Ảnh',
                  icon: Icons.photo_camera_rounded,
                  isPrimary: true,
                  isDarkMode: _isDarkMode,
                  height: 52,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: GlowButton(
                  onPressed: _pickingImage ? null : () => _pickImage(ImageSource.gallery),
                  label: 'Thư Viện',
                  icon: Icons.photo_library_rounded,
                  isPrimary: false,
                  isDarkMode: _isDarkMode,
                  height: 52,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBrackets(Color cColor) {
    const cSize = 20.0;
    const cWidth = 2.5;

    return [
      Positioned(
        top: 14,
        left: 14,
        child: Container(
          width: cSize,
          height: cSize,
          decoration: BoxDecoration(
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
          decoration: BoxDecoration(
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
          decoration: BoxDecoration(
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
          decoration: BoxDecoration(
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
    final isFruit = _scanMode == AppScanMode.fruit;
    final laserColor = isFruit ? const Color(0xFFF59E0B) : AppColors.primaryEmerald;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenH = MediaQuery.of(context).size.height;
        final previewMaxH = (screenH * 0.38).clamp(240.0, 360.0);

        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (!isFruit &&
                    _plantPrediction != null &&
                    _plantPrediction!.detections.isNotEmpty &&
                    _showOverlay)
                  BoundingBoxOverlay(
                    imageFile: image,
                    imageWidth: width,
                    imageHeight: height,
                    detections: _plantPrediction!.detections,
                    selectedIndex: _selectedDetectionIndex,
                    maxHeight: previewMaxH,
                    onSelectDetection: (index) {
                      setState(() {
                        _selectedDetectionIndex = index;
                      });
                    },
                  )
                else
                  Container(
                    constraints: BoxConstraints(maxHeight: previewMaxH),
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
                          blurRadius: 18,
                          offset: const Offset(0, 6),
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
                              color: laserColor,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Controls Bar
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 20,
              isDarkMode: _isDarkMode,
              child: Column(
                children: [
                  if (_detecting) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(laserColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isFruit
                              ? 'Đang kiểm tra độ chín & chất lượng quả...'
                              : 'Đang nhận diện mô hình AI cây trồng...',
                          style: TextStyle(
                            color: laserColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFruit
                          ? 'Trích xuất sắc tố carotenoid, diệp lục & đốm thâm nấm mốc'
                          : 'Phân tích đa lớp ONNX & lọc nhận diện 12 loài cây',
                      style: TextStyle(
                        color: _isDarkMode ? AppColors.textMutedDark : AppColors.textMutedLight,
                        fontSize: 11.5,
                      ),
                    ),
                  ] else ...[
                    // Nút hành động chính
                    SizedBox(
                      width: double.infinity,
                      child: GlowButton(
                        onPressed: _runAnalysis,
                        label: isFruit ? '🔍 Phân Tích Độ Chín Quả' : '🔍 Nhận Diện Cây Ngay',
                        icon: Icons.auto_awesome_rounded,
                        isPrimary: true,
                        isDarkMode: _isDarkMode,
                        height: 48,
                        borderRadius: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GlowButton(
                            onPressed: () => _pickImage(ImageSource.camera),
                            label: 'Chụp khác',
                            icon: Icons.photo_camera_rounded,
                            isPrimary: false,
                            isDarkMode: _isDarkMode,
                            height: 42,
                            borderRadius: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlowButton(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            label: 'Thư viện',
                            icon: Icons.photo_library_outlined,
                            isPrimary: false,
                            isDarkMode: _isDarkMode,
                            height: 42,
                            borderRadius: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _resetImage,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Đóng ảnh',
                          color: _isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultArea() {
    if (_scanMode == AppScanMode.plant && _plantPrediction != null) {
      return _buildPlantResultSection(_plantPrediction!);
    }

    if (_scanMode == AppScanMode.fruit && _fruitResult != null) {
      return FruitResultCard(
        result: _fruitResult!,
        isDarkMode: _isDarkMode,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlantResultSection(PredictionResponse prediction) {
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
                const Icon(Icons.psychology_rounded, color: AppColors.primaryEmerald, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Kết quả nhận diện cây',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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
                '${prediction.detections.length} phát hiện',
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

        ...List.generate(prediction.detections.length, (index) {
          final det = prediction.detections[index];
          final color = BoundingBoxOverlay.getColorForIndex(index);
          return DetectionCard(
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
            isNonPlant ? 'Không tìm thấy đặc tính cây rõ rệt' : 'Chưa nhận diện rõ loài cây',
            style: TextStyle(
              color: textMain,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prediction.message ??
                'Hãy chụp lại cành lá, thân hoặc tán cây với đủ ánh sáng để mô hình AI nhận diện chính xác nhất.',
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
              color: _isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Hướng dẫn chụp ảnh cây đạt độ chính xác cao:',
                  style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('• Với Cây Cọ / Cây Dừa: Chụp rõ phần tán lá quạt và thân cây', style: TextStyle(color: textSub, fontSize: 12)),
                Text('• Với Cây Xoài: Hướng camera vào tán lá hoặc cành quả xoài', style: TextStyle(color: textSub, fontSize: 12)),
                Text('• Giữ khoảng cách 1 - 3 mét để bắt trọn hình thái cây', style: TextStyle(color: textSub, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlowButton(
            onPressed: () => _pickImage(ImageSource.camera),
            label: 'Chụp Lại Ảnh Cây',
            icon: Icons.photo_camera_rounded,
            isPrimary: true,
            isDarkMode: _isDarkMode,
            height: 48,
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
