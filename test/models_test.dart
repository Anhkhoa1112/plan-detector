import 'package:flutter_test/flutter_test.dart';
import 'package:plant_detector_app/models/bounding_box.dart';
import 'package:plant_detector_app/models/detection.dart';
import 'package:plant_detector_app/models/health_status.dart';
import 'package:plant_detector_app/models/prediction_response.dart';

void main() {
  group('BoundingBox', () {
    test('calculates width, height, and area correctly', () {
      const box = BoundingBox(x1: 100, y1: 50, x2: 300, y2: 250);
      expect(box.width, equals(200.0));
      expect(box.height, equals(200.0));
      expect(box.area, equals(40000.0));
      final rect = box.toRect();
      expect(rect.left, equals(100.0));
      expect(rect.top, equals(50.0));
      expect(rect.right, equals(300.0));
      expect(rect.bottom, equals(250.0));
    });

    test('toJson produces expected structure', () {
      const box = BoundingBox(x1: 10, y1: 20, x2: 30, y2: 40);
      final json = box.toJson();
      expect(json['x1'], equals(10.0));
      expect(json['y1'], equals(20.0));
      expect(json['x2'], equals(30.0));
      expect(json['y2'], equals(40.0));
    });
  });

  group('Detection', () {
    test('formats confidencePercent and fullTitle with Vietnamese name', () {
      const det = Detection(
        classId: 3,
        className: 'aloe vera',
        nameVi: 'Cây Nha Đam',
        confidence: 0.9425,
        bbox: BoundingBox(x1: 0, y1: 0, x2: 10, y2: 10),
      );
      expect(det.confidencePercent, equals('94.3%'));
      expect(det.displayName, equals('Cây Nha Đam'));
      expect(det.fullTitle, equals('Cây Nha Đam (aloe vera)'));
    });

    test('fallback when nameVi is null', () {
      const det = Detection(
        classId: 1,
        className: 'cactus',
        nameVi: null,
        confidence: 0.88,
        bbox: BoundingBox(x1: 0, y1: 0, x2: 10, y2: 10),
      );
      expect(det.displayName, equals('cactus'));
      expect(det.fullTitle, equals('cactus'));
    });
  });

  group('HealthStatus', () {
    test('isReady is true only when status=ok and modelLoaded=true', () {
      final ready = HealthStatus.fromJson({
        'status': 'ok',
        'model_loaded': true,
        'model_path': 'best.pt',
      });
      expect(ready.isReady, isTrue);

      final notReady = HealthStatus.fromJson({
        'status': 'ok',
        'model_loaded': false,
        'model_path': 'best.pt',
        'load_error': 'Failed to load weights',
      });
      expect(notReady.isReady, isFalse);
      expect(notReady.loadError, equals('Failed to load weights'));
    });
  });

  group('PredictionResponse', () {
    test('handles multiple detections correctly', () {
      final response = PredictionResponse.fromJson({
        'success': true,
        'image_width': 1920,
        'image_height': 1080,
        'detections': [
          {
            'class_id': 1,
            'class_name': 'rose',
            'name_vi': 'Hoa Hồng',
            'confidence': 0.95,
            'bbox': {'x1': 10, 'y1': 20, 'x2': 100, 'y2': 200},
          },
          {
            'class_id': 2,
            'class_name': 'daisy',
            'name_vi': 'Hoa Cúc',
            'confidence': 0.80,
            'bbox': {'x1': 200, 'y1': 300, 'x2': 400, 'y2': 500},
          },
        ],
      });
      expect(response.success, isTrue);
      expect(response.hasDetections, isTrue);
      expect(response.count, equals(2));
      expect(response.detections[0].className, equals('rose'));
      expect(response.detections[1].className, equals('daisy'));
    });

    test('handles empty detections list gracefully', () {
      final response = PredictionResponse.fromJson({
        'success': true,
        'image_width': 800,
        'image_height': 600,
        'detections': <Object?>[],
      });
      expect(response.success, isTrue);
      expect(response.hasDetections, isFalse);
      expect(response.count, equals(0));
    });
  });

    test('parses uncertain status and getters correctly', () {
      final response = PredictionResponse.fromJson({
        'success': true,
        'status': 'uncertain',
        'image_width': 800,
        'image_height': 600,
        'message': 'Độ tự tin chưa đủ cao',
        'is_plant': true,
        'detections': [
          {
            'class_id': 4,
            'class_name': 'Coconut-tree',
            'name_vi': 'Cây dừa',
            'confidence': 0.32,
            'bbox': {'x1': 5, 'y1': 10, 'x2': 50, 'y2': 100},
          }
        ],
      });
      expect(response.status, equals('uncertain'));
      expect(response.isUncertain, isTrue);
      expect(response.isRecognized, isFalse);
      expect(response.isUnknown, isFalse);
      expect(response.message, contains('Độ tự tin'));
      expect(response.hasDetections, isTrue);
    });

    test('parses unknown status for non-plant rejection', () {
      final response = PredictionResponse.fromJson({
        'success': true,
        'status': 'unknown',
        'image_width': 800,
        'image_height': 600,
        'message': 'Ảnh không phải là cây',
        'is_plant': false,
        'detections': <Object?>[],
      });
      expect(response.status, equals('unknown'));
      expect(response.isUnknown, isTrue);
      expect(response.isPlant, isFalse);
      expect(response.hasDetections, isFalse);
    });
}
