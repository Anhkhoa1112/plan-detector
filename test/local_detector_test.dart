import 'package:flutter_test/flutter_test.dart';
import 'package:plant_detector_app/services/local_plant_detector_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalPlantDetectorService Constants & Metadata', () {
    test('contains exact 12 classes with Vietnamese mappings', () {
      expect(kClassNames.length, equals(12));
      expect(kPlantViNames.length, equals(12));
      expect(kCalibratedClassThresholds.length, equals(12));

      for (int i = 0; i < 12; i++) {
        expect(kClassNames.containsKey(i), isTrue);
        expect(kPlantViNames.containsKey(i), isTrue);
        expect(kCalibratedClassThresholds.containsKey(i), isTrue);
        expect(kCalibratedClassThresholds[i]!, greaterThanOrEqualTo(0.35));
        expect(kCalibratedClassThresholds[i]!, lessThanOrEqualTo(0.60));
      }

      expect(kClassNames[10], equals('lemon tree'));
      expect(kPlantViNames[10], equals('Cây Chanh'));
      expect(kCalibratedClassThresholds[10], equals(0.55));
    });

    test('singleton instance is accessible', () {
      final service = LocalPlantDetectorService.instance;
      expect(service, isNotNull);
      expect(service.isReady, isFalse);
    });
  });
}
