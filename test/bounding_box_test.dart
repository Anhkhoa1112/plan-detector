import 'package:flutter_test/flutter_test.dart';
import 'package:plant_detector_app/models/bounding_box.dart';
import 'package:plant_detector_app/widgets/bounding_box_overlay.dart';

void main() {
  group('Bounding Box Coordinate Scaling', () {
    test('exact scaling calculation matches aspect ratio without distortion', () {
      const origW = 1200.0;
      const origH = 800.0;
      const renderW = 300.0;
      const renderH = 200.0;

      const scaleX = renderW / origW; // 0.25
      const scaleY = renderH / origH; // 0.25

      expect(scaleX, equals(scaleY)); // Preserves aspect ratio

      const box = BoundingBox(x1: 200, y1: 100, x2: 600, y2: 500);

      final scaledLeft = box.x1 * scaleX;
      final scaledTop = box.y1 * scaleY;
      final scaledRight = box.x2 * scaleX;
      final scaledBottom = box.y2 * scaleY;

      expect(scaledLeft, equals(50.0));
      expect(scaledTop, equals(25.0));
      expect(scaledRight, equals(150.0));
      expect(scaledBottom, equals(125.0));
    });

    test('palette provides cycling distinct colors', () {
      final color0 = BoundingBoxOverlay.getColorForIndex(0);
      final color1 = BoundingBoxOverlay.getColorForIndex(1);
      final color8 = BoundingBoxOverlay.getColorForIndex(8);

      expect(color0, isNot(equals(color1)));
      expect(color0, equals(color8)); // cycles back after length
    });
  });
}
