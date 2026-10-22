import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../models/bounding_box.dart';
import '../models/detection.dart';
import '../models/prediction_response.dart';

/// Ngưỡng tin cậy đã hiệu chỉnh cho từng loài cây
/// - Ngưỡng thấp hơn = nhạy hơn nhưng vẫn đảm bảo chính xác
/// - Ngưỡng cao hơn cho các loài hay bị nhầm (Chanh vs Xoài)
const Map<int, double> kCalibratedClassThresholds = {
  0: 0.38,  // Acacia (Cây Keo)
  1: 0.35,  // Bamboo-shoots (Măng Tre)
  2: 0.35,  // Banana-plant (Cây Chuối)
  3: 0.38,  // Banyan-Tree (Cây Đa)
  4: 0.35,  // Coconut-tree (Cây Dừa)
  5: 0.35,  // Mango-Tree (Cây Xoài)
  6: 0.38,  // Neem-Tree (Cây Sầu Đâu)
  7: 0.30,  // Palm-tree (Cây Cọ) - Ngưỡng thấp vì hay bị bỏ sót
  8: 0.40,  // Papaya-Tree (Cây Đu Đủ)
  9: 0.38,  // Pine (Cây Thông)
  10: 0.55, // lemon tree (Cây Chanh) - Ngưỡng CAO vì hay nhận nhầm từ Xoài
  11: 0.38, // peepal tree (Cây Bồ Đề)
};

/// Các cặp loài thường bị model nhầm lẫn
/// Key = loài bị nhầm (class ID), Value = loài thực tế (class ID)
const Map<int, int> kConfusionPairs = {
  10: 5,   // Chanh (10) thường bị nhầm từ Xoài (5)
};

const Map<int, String> kClassNames = {
  0: 'Acacia',
  1: 'Bamboo-shoots',
  2: 'Banana-plant',
  3: 'Banyan-Tree',
  4: 'Coconut-tree',
  5: 'Mango-Tree',
  6: 'Neem-Tree',
  7: 'Palm-tree',
  8: 'Papaya-Tree',
  9: 'Pine',
  10: 'lemon tree',
  11: 'peepal tree',
};

const Map<int, String> kPlantViNames = {
  0: 'Cây Keo',
  1: 'Măng Tre / Tre',
  2: 'Cây Chuối',
  3: 'Cây Đa',
  4: 'Cây Dừa',
  5: 'Cây Xoài',
  6: 'Cây Sầu Đâu / Neem',
  7: 'Cây Cọ',
  8: 'Cây Đu Đủ',
  9: 'Cây Thông',
  10: 'Cây Chanh',
  11: 'Cây Bồ Đề',
};

class PlantFeatureResult {
  const PlantFeatureResult({
    required this.greenRatio,
    required this.plantRatio,
  });

  final double greenRatio;
  final double plantRatio;
}

class _LetterboxResult {
  const _LetterboxResult({
    required this.tensorData,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.origWidth,
    required this.origHeight,
  });

  final Float32List tensorData;
  final double scale;
  final int padX;
  final int padY;
  final int origWidth;
  final int origHeight;
}

class LocalPlantDetectorService {
  LocalPlantDetectorService._();
  static final LocalPlantDetectorService instance = LocalPlantDetectorService._();

  OrtSession? _session;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initError;

  bool get isReady => _isInitialized && _session != null;
  String? get initError => _initError;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) return;
    _isInitializing = true;
    _initError = null;

    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();

      final rawAsset = await rootBundle.load('assets/models/best.onnx');
      final bytes = rawAsset.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      _isInitialized = true;
      debugPrint('[LocalPlantDetector] ONNX session initialized successfully.');
    } catch (e, stack) {
      _initError = e.toString();
      debugPrint('[LocalPlantDetector] Failed to initialize: $e\n$stack');
    } finally {
      _isInitializing = false;
    }
  }

  Future<PredictionResponse> predict(
    File imageFile, {
    double confidence = 0.25,
    double iou = 0.45,
  }) async {
    if (!_isInitialized || _session == null) {
      await initialize();
      if (!_isInitialized || _session == null) {
        throw StateError('Mô hình AI Offline chưa sẵn sàng: ${_initError ?? "Không thể nạp model"}');
      }
    }

    final bytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw const FormatException('Không thể giải mã tệp hình ảnh.');
    }

    // 1. Phân tích đặc trưng thực vật toàn ảnh
    final overallFeatures = calculatePlantFeatures(decodedImage);
    final overallGreenRatio = overallFeatures.greenRatio;
    final overallPlantRatio = overallFeatures.plantRatio;

    // 2. Tiền xử lý Letterbox và chạy ONNX
    final letterbox = _preprocessLetterbox(decodedImage);

    final inputOrtValue = OrtValueTensor.createTensorWithDataList(
      letterbox.tensorData,
      [1, 3, 640, 640],
    );

    final runOptions = OrtRunOptions();
    List<OrtValue?> outputs;
    try {
      outputs = _session!.run(runOptions, {'images': inputOrtValue});
    } finally {
      inputOrtValue.release();
      runOptions.release();
    }

    if (outputs.isEmpty || outputs[0] == null) {
      throw const FormatException('Không nhận được dữ liệu tensor từ mô hình ONNX.');
    }

    final rawOutputs = outputs[0]!.value as List;
    final batch0 = rawOutputs[0] as List; // Shape: [16, 8400]

    final cxList = batch0[0] as List;
    final cyList = batch0[1] as List;
    final wList = batch0[2] as List;
    final hList = batch0[3] as List;

    final List<List<dynamic>> classScoreLists = [];
    for (int c = 0; c < 12; c++) {
      classScoreLists.add(batch0[4 + c] as List);
    }

    // ================================================================
    // 3. GLOBAL CLASS VOTING - Phân tích tổng thể toàn bộ 8400 anchor
    //    Mỗi anchor bỏ phiếu cho class có điểm cao nhất.
    //    Số lượng phiếu và tổng điểm giúp xác định loài cây THỰC SỰ
    //    chiếm ưu thế trong ảnh, giải quyết nhầm lẫn Xoài↔Chanh, Cọ↔Dừa
    // ================================================================
    final List<double> classTotalScore = List.filled(12, 0.0);
    final List<int> classVoteCount = List.filled(12, 0);
    const int numAnchors = 8400;

    for (int i = 0; i < numAnchors; i++) {
      int winnerClass = -1;
      double winnerScore = 0.15; // Ngưỡng tối thiểu để bỏ phiếu
      for (int c = 0; c < 12; c++) {
        final score = (classScoreLists[c][i] as num).toDouble();
        if (score > winnerScore) {
          winnerScore = score;
          winnerClass = c;
        }
      }
      if (winnerClass >= 0) {
        classTotalScore[winnerClass] += winnerScore;
        classVoteCount[winnerClass]++;
      }
    }

    // Tìm loài chiếm ưu thế (dominant class)
    int dominantClass = -1;
    double dominantScore = 0.0;
    int dominantVotes = 0;
    for (int c = 0; c < 12; c++) {
      if (classTotalScore[c] > dominantScore) {
        dominantScore = classTotalScore[c];
        dominantVotes = classVoteCount[c];
        dominantClass = c;
      }
    }

    debugPrint('[PlantDetector] Global Voting: dominant=$dominantClass '
        'score=${dominantScore.toStringAsFixed(2)} votes=$dominantVotes');
    for (int c = 0; c < 12; c++) {
      if (classVoteCount[c] > 0) {
        debugPrint('  Class $c (${kClassNames[c]}): votes=${classVoteCount[c]} '
            'totalScore=${classTotalScore[c].toStringAsFixed(2)}');
      }
    }

    // ================================================================
    // 4. Thu thập ứng viên Bounding Box
    // ================================================================
    final List<Detection> rawCandidates = [];

    for (int i = 0; i < numAnchors; i++) {
      int bestClassId = 0;
      double maxScore = -1.0;
      double secondBestScore = -1.0;
      int secondBestClassId = -1;

      for (int c = 0; c < 12; c++) {
        final score = (classScoreLists[c][i] as num).toDouble();
        if (score > maxScore) {
          secondBestScore = maxScore;
          secondBestClassId = bestClassId;
          maxScore = score;
          bestClassId = c;
        } else if (score > secondBestScore) {
          secondBestScore = score;
          secondBestClassId = c;
        }
      }

      if (maxScore < 0.20) continue;

      // ============================================================
      // CHỐNG NHẦM LẪN TẠI TỪNG ANCHOR:
      // Nếu model cho Chanh (10) điểm cao nhất, nhưng:
      //   - Global Voting nói Xoài (5) chiếm ưu thế
      //   - Và Xoài là second-best class tại anchor này
      //   - Và chênh lệch điểm nhỏ (< 0.15)
      // → Chuyển anchor này từ Chanh sang Xoài
      // ============================================================
      if (bestClassId == 10 && dominantClass == 5 &&
          secondBestClassId == 5 && (maxScore - secondBestScore) < 0.15) {
        bestClassId = 5;
        maxScore = secondBestScore; // Dùng điểm Xoài gốc
      }

      // Tương tự: Nếu Dừa (4) chiếm ưu thế nhưng anchor nói Cọ (7) hoặc ngược lại
      // → KHÔNG chuyển, vì Dừa và Cọ khác nhau rõ ràng

      if (maxScore < 0.20) continue;

      final cx = (cxList[i] as num).toDouble();
      final cy = (cyList[i] as num).toDouble();
      final w = (wList[i] as num).toDouble();
      final h = (hList[i] as num).toDouble();

      final x1 = math.max(0.0, (cx - w / 2 - letterbox.padX) / letterbox.scale);
      final y1 = math.max(0.0, (cy - h / 2 - letterbox.padY) / letterbox.scale);
      final x2 = math.min(letterbox.origWidth.toDouble(), (cx + w / 2 - letterbox.padX) / letterbox.scale);
      final y2 = math.min(letterbox.origHeight.toDouble(), (cy + h / 2 - letterbox.padY) / letterbox.scale);

      if (x2 <= x1 || y2 <= y1) continue;

      final className = kClassNames[bestClassId] ?? 'Class $bestClassId';
      final nameVi = kPlantViNames[bestClassId];

      rawCandidates.add(
        Detection(
          classId: bestClassId,
          className: className,
          nameVi: nameVi,
          confidence: double.parse(maxScore.toStringAsFixed(4)),
          bbox: BoundingBox(
            x1: double.parse(x1.toStringAsFixed(2)),
            y1: double.parse(y1.toStringAsFixed(2)),
            x2: double.parse(x2.toStringAsFixed(2)),
            y2: double.parse(y2.toStringAsFixed(2)),
          ),
        ),
      );
    }

    outputs[0]!.release();

    // ================================================================
    // 5. Cross-Class NMS: Loại bỏ box trùng lặp giữa các loài
    // ================================================================
    final nmsCandidates = _applyCrossClassNMS(rawCandidates, iou);

    // ================================================================
    // 6. Xác nhận các phát hiện đạt ngưỡng tin cậy hiệu chỉnh
    // ================================================================
    final List<Detection> confirmedDetections = [];

    for (final det in nmsCandidates) {
      final classTh = kCalibratedClassThresholds[det.classId] ?? 0.38;
      // effectiveTh = ngưỡng class-specific, không thấp hơn confidence param
      final effectiveTh = math.max(classTh, confidence);

      if (det.confidence >= effectiveTh) {
        confirmedDetections.add(det);
      }
    }

    // ================================================================
    // 7. FALLBACK RESCUE: Nếu không có box nào đạt ngưỡng nhưng
    //    Global Voting cho thấy có loài cây rõ ràng chiếm ưu thế
    //    (ít nhất 5 anchor bỏ phiếu, tổng điểm >= 1.5)
    //    → Tạo detection toàn ảnh cho loài đó
    // ================================================================
    if (confirmedDetections.isEmpty && dominantClass >= 0 &&
        dominantVotes >= 5 && dominantScore >= 1.5) {
      final rescuedConfidence = math.min(0.85, dominantScore / (dominantVotes * 0.5));

      if (rescuedConfidence >= 0.30) {
        final rescuedDet = Detection(
          classId: dominantClass,
          className: kClassNames[dominantClass]!,
          nameVi: kPlantViNames[dominantClass],
          confidence: double.parse(rescuedConfidence.toStringAsFixed(4)),
          bbox: BoundingBox(
            x1: (letterbox.origWidth * 0.05).roundToDouble(),
            y1: (letterbox.origHeight * 0.05).roundToDouble(),
            x2: (letterbox.origWidth * 0.95).roundToDouble(),
            y2: (letterbox.origHeight * 0.95).roundToDouble(),
          ),
        );
        confirmedDetections.add(rescuedDet);

        debugPrint('[PlantDetector] Rescued via Global Voting: '
            '${kClassNames[dominantClass]} conf=${rescuedConfidence.toStringAsFixed(3)}');
      }
    }

    // ================================================================
    // 8. Phân loại kết quả cuối cùng
    // ================================================================
    if (confirmedDetections.isNotEmpty) {
      return PredictionResponse(
        success: true,
        status: 'recognized',
        imageWidth: letterbox.origWidth,
        imageHeight: letterbox.origHeight,
        detections: confirmedDetections,
        isPlant: true,
        message: null,
      );
    } else {
      final isRealPlant = overallGreenRatio >= 0.030 || overallPlantRatio >= 0.060;
      final String msg = !isRealPlant
          ? 'Ảnh không tìm thấy đặc tính thực vật rõ nét. Vui lòng hướng camera gần vào thân, cành lá hoặc tán cây.'
          : 'Chưa nhận diện rõ loài trong 12 loài cây. Vui lòng chụp rõ tán lá hoặc chụp từ khoảng cách 1-3 mét.';

      return PredictionResponse(
        success: true,
        status: 'unknown',
        imageWidth: letterbox.origWidth,
        imageHeight: letterbox.origHeight,
        detections: const [],
        isPlant: isRealPlant,
        message: msg,
      );
    }
  }

  /// Tính toán đặc tính thực vật (xanh lá, thân cây, xơ vỏ cọ/dừa, hoa quả)
  PlantFeatureResult calculatePlantFeatures(img.Image image, [List<double>? boxCoords]) {
    try {
      int startX = 0;
      int startY = 0;
      int endX = image.width;
      int endY = image.height;

      if (boxCoords != null && boxCoords.length >= 4) {
        startX = math.max(0, boxCoords[0].toInt());
        startY = math.max(0, boxCoords[1].toInt());
        endX = math.min(image.width, boxCoords[2].toInt());
        endY = math.min(image.height, boxCoords[3].toInt());
        if (endX <= startX || endY <= startY) {
          return const PlantFeatureResult(greenRatio: 0.0, plantRatio: 0.0);
        }
      }

      int greenCount = 0;
      int plantCount = 0;
      int totalSampled = 0;

      final step = math.max(1, math.min((endX - startX) ~/ 60, (endY - startY) ~/ 60));

      for (int y = startY; y < endY; y += step) {
        for (int x = startX; x < endX; x += step) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          // 1. Sắc xanh thực vật (lá xanh tươi, lá non, lá đậm, lá cọ, lá dừa)
          final bool isFoliageGreen = (g > 30) && (g > r * 0.98) && (g > b * 1.05);
          final bool isLimeGreen = (g > 35) && (r > 30) && (g >= r * 0.88) && (g > b * 1.15);
          final bool isGreen = isFoliageGreen || isLimeGreen;

          // 2. Thân cây, vỏ cây xù xì, vỏ thân cây cọ xám/nâu, xơ dừa
          //    Điều kiện (r-g) <= 45 loại bỏ da người, gỗ bàn mịn
          final bool isBark = (r > g) && (g > b) &&
              (r >= 35) && (r <= 165) &&
              ((r - b) >= 15) && ((g - b) >= 5) &&
              ((r - g) <= 45);

          // 3. Trái cây chín / hoa quả
          final bool isFruit = (r > 110) && (g > 85) && (b < 110) && (r > b * 1.25);

          if (isGreen) {
            greenCount++;
            plantCount++;
          } else if (isBark || isFruit) {
            plantCount++;
          }
          totalSampled++;
        }
      }

      if (totalSampled == 0) {
        return const PlantFeatureResult(greenRatio: 0.0, plantRatio: 0.0);
      }

      return PlantFeatureResult(
        greenRatio: greenCount / totalSampled,
        plantRatio: plantCount / totalSampled,
      );
    } catch (_) {
      return const PlantFeatureResult(greenRatio: 0.0, plantRatio: 0.0);
    }
  }

  _LetterboxResult _preprocessLetterbox(img.Image orig) {
    const targetSize = 640;
    final scale = math.min(targetSize / orig.width, targetSize / orig.height);
    final newW = (orig.width * scale).round();
    final newH = (orig.height * scale).round();
    final padX = (targetSize - newW) ~/ 2;
    final padY = (targetSize - newH) ~/ 2;

    final resized = img.copyResize(orig, width: newW, height: newH, interpolation: img.Interpolation.linear);

    final tensor = Float32List(1 * 3 * targetSize * targetSize);
    const planeSize = targetSize * targetSize;
    const padVal = 114.0 / 255.0;

    tensor.fillRange(0, tensor.length, padVal);

    for (int y = 0; y < newH; y++) {
      final ty = padY + y;
      for (int x = 0; x < newW; x++) {
        final tx = padX + x;
        final p = resized.getPixel(x, y);
        final idx = ty * targetSize + tx;
        tensor[0 * planeSize + idx] = p.r / 255.0;
        tensor[1 * planeSize + idx] = p.g / 255.0;
        tensor[2 * planeSize + idx] = p.b / 255.0;
      }
    }

    return _LetterboxResult(
      tensorData: tensor,
      scale: scale,
      padX: padX,
      padY: padY,
      origWidth: orig.width,
      origHeight: orig.height,
    );
  }

  double _calculateIoU(BoundingBox a, BoundingBox b) {
    final interX1 = math.max(a.x1, b.x1);
    final interY1 = math.max(a.y1, b.y1);
    final interX2 = math.min(a.x2, b.x2);
    final interY2 = math.min(a.y2, b.y2);

    final interW = math.max(0.0, interX2 - interX1);
    final interH = math.max(0.0, interY2 - interY1);
    final interArea = interW * interH;

    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    final unionArea = areaA + areaB - interArea;

    if (unionArea <= 0.0) return 0.0;
    return interArea / unionArea;
  }

  /// Cross-Class NMS: Loại bỏ box đè lên nhau giữa các loài khác nhau
  List<Detection> _applyCrossClassNMS(List<Detection> detections, double iouThreshold) {
    if (detections.length <= 1) return detections;
    final sorted = List<Detection>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final result = <Detection>[];

    while (sorted.isNotEmpty) {
      final best = sorted.removeAt(0);
      result.add(best);

      sorted.removeWhere((item) {
        final iouVal = _calculateIoU(item.bbox, best.bbox);
        if (iouVal <= iouThreshold) return false;

        // Cùng class → loại bỏ trùng lặp
        if (item.classId == best.classId) return true;

        // Khác class nhưng IoU > 0.55 → giữ loài có điểm cao hơn (đã sort)
        return iouVal > 0.55;
      });
    }
    return result;
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
  }
}
