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

const Map<int, double> kCalibratedClassThresholds = {
  0: 0.45,  // Acacia
  1: 0.50,  // Bamboo-shoots
  2: 0.40,  // Banana-plant
  3: 0.40,  // Banyan-Tree
  4: 0.40,  // Coconut-tree
  5: 0.50,  // Mango-Tree
  6: 0.40,  // Neem-Tree
  7: 0.40,  // Palm-tree
  8: 0.45,  // Papaya-Tree
  9: 0.45,  // Pine
  10: 0.55, // lemon tree
  11: 0.50, // peepal tree
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

    final overallPlantRatio = _calculatePlantFeatures(decodedImage);
    final letterbox = _preprocessLetterbox(decodedImage);

    final inputOrtValue = OrtValueTensor.createTensorWithDataList(
      letterbox.tensorData,
      [1, 3, 640, 640],
    );

    final runOptions = OrtRunOptions();
    final outputs = _session!.run(runOptions, {'images': inputOrtValue});
    inputOrtValue.release();
    runOptions.release();

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

    final List<Detection> rawCandidates = [];
    const int numAnchors = 8400;

    for (int i = 0; i < numAnchors; i++) {
      int bestClassId = 0;
      double maxScore = -1.0;

      for (int c = 0; c < 12; c++) {
        final score = (classScoreLists[c][i] as num).toDouble();
        if (score > maxScore) {
          maxScore = score;
          bestClassId = c;
        }
      }

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

      final boxPlantRatio = _calculatePlantFeatures(decodedImage, [x1, y1, x2, y2]);

      final isLemonTree = (bestClassId == 10);
      if (isLemonTree && boxPlantRatio < 0.035 && overallPlantRatio < 0.035) {
        continue;
      }
      if (overallPlantRatio < 0.02 && maxScore < 0.60) {
        continue;
      }

      final className = kClassNames[bestClassId] ?? 'Class $bestClassId';
      final nameVi = kPlantViNames[bestClassId];

      rawCandidates.add(
        Detection(
          classId: bestClassId,
          className: className,
          nameVi: nameVi,
          confidence: double.parse(maxScore.toStringAsFixed(6)),
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

    final nmsCandidates = _applyNMS(rawCandidates, iou);

    final List<Detection> confirmedDetections = [];
    final List<Detection> uncertainDetections = [];

    for (final det in nmsCandidates) {
      final classTh = kCalibratedClassThresholds[det.classId] ?? 0.45;
      final effectiveTh = math.max(classTh, confidence);

      if (det.confidence >= effectiveTh) {
        confirmedDetections.add(det);
      } else if (det.confidence >= 0.25) {
        uncertainDetections.add(det);
      }
    }

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
    } else if (uncertainDetections.isNotEmpty) {
      final bestCand = uncertainDetections.reduce((a, b) => a.confidence > b.confidence ? a : b);
      final viName = bestCand.nameVi ?? bestCand.className;
      final pct = (bestCand.confidence * 100).toStringAsFixed(1);

      return PredictionResponse(
        success: true,
        status: 'uncertain',
        imageWidth: letterbox.origWidth,
        imageHeight: letterbox.origHeight,
        detections: uncertainDetections,
        isPlant: true,
        message: "AI phát hiện dấu hiệu tương tự '$viName' ($pct%) nhưng độ tự tin chưa đủ cao. Hãy thử chụp ảnh rõ hơn hoặc đưa camera gần cây hơn.",
      );
    } else {
      final isPlant = overallPlantRatio >= 0.03;
      final String msg = !isPlant
          ? 'Ảnh không phải là thực vật hoặc không tìm thấy đặc điểm thực vật. Vui lòng chụp rõ cây xanh, hoa lá hoặc thân cây.'
          : 'Loại cây này chưa nằm trong danh sách 12 loài cây mà AI được huấn luyện. Vui lòng thử lại với các loài được hỗ trợ.';

      return PredictionResponse(
        success: true,
        status: 'unknown',
        imageWidth: letterbox.origWidth,
        imageHeight: letterbox.origHeight,
        detections: const [],
        isPlant: isPlant,
        message: msg,
      );
    }
  }

  double _calculatePlantFeatures(img.Image image, [List<double>? boxCoords]) {
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
        if (endX <= startX || endY <= startY) return 0.0;
      }

      int plantCount = 0;
      int totalSampled = 0;
      final step = math.max(1, math.min((endX - startX) ~/ 60, (endY - startY) ~/ 60));

      for (int y = startY; y < endY; y += step) {
        for (int x = startX; x < endX; x += step) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          final bool isGreen = (g > r * 0.90) && (g > b * 1.05) && (g > 35);
          final bool isBark = (r > g) && (g > b) && (r > 40) && (r < 180) && ((r - b) > 18) && ((g - b) > 8);

          if (isGreen || isBark) {
            plantCount++;
          }
          totalSampled++;
        }
      }

      if (totalSampled == 0) return 0.0;
      return plantCount / totalSampled;
    } catch (_) {
      return 0.5;
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

  List<Detection> _applyNMS(List<Detection> detections, double iouThreshold) {
    if (detections.length <= 1) return detections;
    final sorted = List<Detection>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final result = <Detection>[];

    while (sorted.isNotEmpty) {
      final best = sorted.removeAt(0);
      result.add(best);
      sorted.removeWhere((item) =>
          item.classId == best.classId &&
          _calculateIoU(item.bbox, best.bbox) > iouThreshold);
    }
    return result;
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
  }
}
