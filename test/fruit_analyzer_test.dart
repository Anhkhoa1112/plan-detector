import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plant_detector_app/models/fruit_analysis.dart';
import 'package:plant_detector_app/services/fruit_analyzer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FruitAnalyzerService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fruit_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Phân tích quả chuối chín vàng (Ripe Banana)', () async {
      // Tạo ảnh mẫu mô phỏng quả chuối chín vàng: R=250, G=220, B=30
      final image = img.Image(width: 200, height: 200);
      for (var p in image) {
        p.r = 245;
        p.g = 215;
        p.b = 35;
      }

      final testFile = File('${tempDir.path}/ripe_banana.png');
      await testFile.writeAsBytes(img.encodePng(image));

      final result = await FruitAnalyzerService.instance.analyzeFruit(
        testFile,
        targetCategory: FruitCategory.banana,
      );

      expect(result.category, equals(FruitCategory.banana));
      expect(result.status, equals(RipenessStatus.ripe));
      expect(result.ripenessPercent, greaterThanOrEqualTo(80.0));
      expect(result.isEdible, isTrue);
      expect(result.headline, contains('Chuối Chín Vàng'));
    });

    test('Phân tích quả chuối xanh non (Unripe Banana)', () async {
      // Tạo ảnh mẫu chuối xanh: R=40, G=175, B=45
      final image = img.Image(width: 200, height: 200);
      for (var p in image) {
        p.r = 40;
        p.g = 175;
        p.b = 45;
      }

      final testFile = File('${tempDir.path}/unripe_banana.png');
      await testFile.writeAsBytes(img.encodePng(image));

      final result = await FruitAnalyzerService.instance.analyzeFruit(
        testFile,
        targetCategory: FruitCategory.banana,
      );

      expect(result.category, equals(FruitCategory.banana));
      expect(result.status, equals(RipenessStatus.unripe));
      expect(result.isUnripe, isTrue);
      expect(result.headline, contains('Chuối Còn Xanh'));
      expect(result.estimatedDaysToRipe, greaterThan(0));
    });

    test('Phân tích quả chuối hư thối dập nát (Rotten Banana)', () async {
      // Tạo ảnh mẫu chuối thối: 60% thâm đen (R=45, G=30, B=25) và 40% vàng xỉn (R=170, G=140, B=40)
      final image = img.Image(width: 200, height: 200);
      for (int y = 0; y < 200; y++) {
        for (int x = 0; x < 200; x++) {
          final p = image.getPixel(x, y);
          if (y < 120) {
            p.r = 45;
            p.g = 30;
            p.b = 25;
          } else {
            p.r = 170;
            p.g = 140;
            p.b = 40;
          }
        }
      }

      final testFile = File('${tempDir.path}/rotten_banana.png');
      await testFile.writeAsBytes(img.encodePng(image));

      final result = await FruitAnalyzerService.instance.analyzeFruit(
        testFile,
        targetCategory: FruitCategory.banana,
      );

      expect(result.category, equals(FruitCategory.banana));
      expect(result.status, equals(RipenessStatus.rotten));
      expect(result.isRotten, isTrue);
      expect(result.isEdible, isFalse);
      expect(result.headline, contains('Dập Thâm Đen'));
    });

    test('Phân tích quả cà chua chín đỏ mọng (Ripe Tomato)', () async {
      // Tạo ảnh mẫu cà chua đỏ tươi: R=235, G=35, B=30
      final image = img.Image(width: 200, height: 200);
      for (var p in image) {
        p.r = 235;
        p.g = 35;
        p.b = 30;
      }

      final testFile = File('${tempDir.path}/ripe_tomato.png');
      await testFile.writeAsBytes(img.encodePng(image));

      final result = await FruitAnalyzerService.instance.analyzeFruit(
        testFile,
        targetCategory: FruitCategory.tomato,
      );

      expect(result.category, equals(FruitCategory.tomato));
      expect(result.status, equals(RipenessStatus.ripe));
      expect(result.isEdible, isTrue);
      expect(result.headline, contains('Cà Chua Chín Đỏ'));
    });

    test('Ảnh phi hoa quả (Màn hình tối hoặc nền xám không có quả)', () async {
      // Tạo ảnh màu xám trung tính bợt bạt R=128, G=128, B=128
      final image = img.Image(width: 200, height: 200);
      for (var p in image) {
        p.r = 128;
        p.g = 128;
        p.b = 128;
      }

      final testFile = File('${tempDir.path}/grey_room.png');
      await testFile.writeAsBytes(img.encodePng(image));

      final result = await FruitAnalyzerService.instance.analyzeFruit(
        testFile,
        targetCategory: FruitCategory.auto,
      );

      expect(result.status, equals(RipenessStatus.notFruit));
      expect(result.headline, contains('Không Phát Hiện Thấy Trái Cây'));
    });
  });
}
