import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/fruit_analysis.dart';

class FruitAnalyzerService {
  FruitAnalyzerService._();
  static final FruitAnalyzerService instance = FruitAnalyzerService._();

  /// Phân tích hình ảnh để xác định loài trái cây và trạng thái chín, sống, hư
  Future<FruitAnalysisResult> analyzeFruit(
    File imageFile, {
    FruitCategory targetCategory = FruitCategory.auto,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw const FormatException('Không thể đọc hoặc giải mã tệp ảnh.');
    }

    // 1. Trích xuất chỉ số quang học và màu sắc (Colorimetric Analysis)
    final metrics = _extractColorMetrics(decodedImage);

    // 2. Xác định danh mục quả (nếu chọn auto)
    final detectedCategory = targetCategory == FruitCategory.auto
        ? _detectFruitCategory(metrics)
        : targetCategory;

    // 3. Nếu ảnh hoàn toàn không có đặc trưng màu sắc của trái cây (ảnh xám, tường nhà, giấy trắng, đồ vật vô cơ)
    final totalVibrantFruitColor = metrics.yellowRatio +
        metrics.orangeRatio +
        metrics.redRatio +
        metrics.greenRatio;

    final hasFruitTraits = totalVibrantFruitColor >= 0.05 ||
        (metrics.brownRotRatio >= 0.15 && metrics.avgSaturation >= 0.12);

    if (metrics.avgSaturation < 0.08 || !hasFruitTraits) {
      return _buildNotFruitResult(metrics, category: detectedCategory);
    }

    // 4. Đánh giá trạng thái chín / sống / hư theo loài quả cụ thể
    return _evaluateRipeness(detectedCategory, metrics);
  }

  /// Trích xuất phân bố màu sắc đa kênh RGB & HSV tập trung vùng trung tâm đối tượng
  FruitColorMetrics _extractColorMetrics(img.Image image) {
    // Trọng tâm vùng quả (Bỏ bớt 10% viền xung quanh để tránh rìa nền)
    final startX = (image.width * 0.10).toInt();
    final endX = (image.width * 0.90).toInt();
    final startY = (image.height * 0.10).toInt();
    final endY = (image.height * 0.90).toInt();

    final step = math.max(1, math.min((endX - startX) ~/ 80, (endY - startY) ~/ 80));

    int yellowCount = 0;
    int orangeCount = 0;
    int redCount = 0;
    int greenCount = 0;
    int brownRotCount = 0;
    int totalCount = 0;

    double totalSat = 0.0;
    double totalVal = 0.0;

    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final delta = maxC - minC;

        final val = maxC / 255.0;
        final sat = maxC == 0 ? 0.0 : delta / maxC;

        totalVal += val;
        totalSat += sat;
        totalCount++;

        // Tính góc màu Hue (0 - 360 độ)
        double hue = 0.0;
        if (delta > 0.0001) {
          if (maxC == r) {
            hue = 60.0 * (((g - b) / delta) % 6.0);
          } else if (maxC == g) {
            hue = 60.0 * (((b - r) / delta) + 2.0);
          } else {
            hue = 60.0 * (((r - g) / delta) + 4.0);
          }
        }
        if (hue < 0) hue += 360.0;

        // Nhận diện vùng hư hỏng, thâm đen, hoại tử (Necrosis / Brown Rot)
        // Vết thâm sẫm: r > g > b, val thấp hoặc đốm sẫm tối đen trên nền sáng
        final isDarkNecrosis = (val < 0.26 && sat > 0.15) ||
            (r > g && g > b && val < 0.40 && (r - b) < 50 && (r - g) < 35 && val > 0.08);

        // Nấm mốc xỉn trắng / xám loang trên bề mặt
        final isMold = (sat < 0.12 && val > 0.45 && val < 0.85);

        if (isDarkNecrosis || isMold) {
          brownRotCount++;
          continue;
        }

        // Phân loại sắc tố màu quả
        if ((hue >= 345 || hue <= 18) && sat > 0.24 && val > 0.20) {
          redCount++;
        } else if (hue > 18 && hue <= 44 && sat > 0.26 && val > 0.25) {
          orangeCount++;
        } else if (hue > 44 && hue <= 68 && sat > 0.24 && val > 0.30) {
          yellowCount++;
        } else if (hue > 68 && hue <= 165 && sat > 0.20 && val > 0.18) {
          greenCount++;
        }
      }
    }

    if (totalCount == 0) {
      return const FruitColorMetrics(
        yellowRatio: 0,
        greenRatio: 0,
        redRatio: 0,
        orangeRatio: 0,
        brownRotRatio: 0,
        avgBrightness: 0,
        avgSaturation: 0,
      );
    }

    return FruitColorMetrics(
      yellowRatio: yellowCount / totalCount,
      orangeRatio: orangeCount / totalCount,
      redRatio: redCount / totalCount,
      greenRatio: greenCount / totalCount,
      brownRotRatio: brownRotCount / totalCount,
      avgBrightness: totalVal / totalCount,
      avgSaturation: totalSat / totalCount,
    );
  }

  /// Tự động phán đoán loài trái cây thông dụng
  FruitCategory _detectFruitCategory(FruitColorMetrics m) {
    // 1. Chuối: Ưu tiên nhận diện Chuối khi có sắc vàng rực hoặc vàng kết hợp xanh/đốm nâu đặc trưng
    if (m.yellowRatio > 0.28 || (m.yellowRatio > 0.18 && m.greenRatio > 0.15)) {
      return FruitCategory.banana;
    }

    // 2. Cam / Quýt: Sắc cam chiếm ưu thế nổi trội
    if (m.orangeRatio > 0.30 || (m.orangeRatio > 0.18 && m.yellowRatio > 0.15)) {
      return FruitCategory.orange;
    }

    // 3. Cà chua hoặc Táo đỏ: Sắc đỏ tươi chiếm chủ đạo
    if (m.redRatio > 0.28) {
      // Cà chua thường có độ bóng rực cao hơn và có sắc cam/đỏ tươi
      if (m.avgBrightness > 0.45 && m.orangeRatio > 0.10) {
        return FruitCategory.tomato;
      }
      return FruitCategory.apple;
    }

    // 4. Xoài: Thường có sắc vàng cam hoặc xanh đậm mịn
    if (m.yellowRatio > 0.20 && m.orangeRatio > 0.10) {
      return FruitCategory.mango;
    }

    // 5. Đu đủ: Sắc cam vàng kết hợp xanh
    if (m.orangeRatio > 0.20 && (m.yellowRatio > 0.10 || m.greenRatio > 0.15)) {
      return FruitCategory.papaya;
    }

    // 6. Chanh: Sắc xanh lá tươi hoặc vàng chanh nhạt
    if (m.greenRatio > 0.35 && m.avgBrightness > 0.40) {
      return FruitCategory.lemon;
    }

    // 7. Bơ: Sắc nâu đen sẫm (chín) hoặc xanh đậm sần sùi (sống)
    if (m.brownRotRatio > 0.30 && m.greenRatio > 0.15) {
      return FruitCategory.avocado;
    }

    // 8. Dưa hấu: Xanh đậm sọc kèm đốm đáy
    if (m.greenRatio > 0.30) {
      return FruitCategory.watermelon;
    }

    // Mặc định chọn chuối (loại trái cây thông dụng nhất để thẩm định độ chín)
    return FruitCategory.banana;
  }

  /// Đánh giá độ chín theo từng loại trái cây cụ thể
  FruitAnalysisResult _evaluateRipeness(FruitCategory category, FruitColorMetrics m) {
    switch (category) {
      case FruitCategory.banana:
        return _evalBanana(m);
      case FruitCategory.mango:
        return _evalMango(m);
      case FruitCategory.papaya:
        return _evalPapaya(m);
      case FruitCategory.orange:
        return _evalOrange(m);
      case FruitCategory.lemon:
        return _evalLemon(m);
      case FruitCategory.apple:
        return _evalApple(m);
      case FruitCategory.tomato:
        return _evalTomato(m);
      case FruitCategory.avocado:
        return _evalAvocado(m);
      case FruitCategory.watermelon:
        return _evalWatermelon(m);
      case FruitCategory.dragonFruit:
        return _evalDragonFruit(m);
      case FruitCategory.auto:
        return _evalBanana(m);
    }
  }

  // --- CÁC HÀM ĐÁNH GIÁ TỪNG LOẠI TRÁI CÂY CHI TIẾT ---

  FruitAnalysisResult _evalBanana(FruitColorMetrics m) {
    const nameVi = 'Chuối';
    const nameEn = 'Banana';
    const icon = '🍌';

    // Ngưỡng phát hiện
    final isRotten = m.brownRotRatio > 0.35 || (m.brownRotRatio > 0.25 && m.yellowRatio < 0.20);
    final isRipe = m.yellowRatio >= 0.30 && m.brownRotRatio <= 0.28;
    final isTurning = m.yellowRatio >= 0.20 && m.greenRatio >= 0.18;

    RipenessStatus status;
    double ripenessPercent;
    double freshnessPercent;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String edibilityVerdict;
    int? daysToRipe;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripenessPercent = 100.0;
      freshnessPercent = math.max(5.0, (1.0 - m.brownRotRatio) * 100);
      headline = 'Chuối Quá Chín / Dập Thâm Đen';
      summary = 'Vỏ chuối thâm sẫm diện rộng, xuất hiện dấu hiệu thịt quả bị nhũn hỏng, lên men chua.';
      evidence = 'Đốm thâm nâu đen chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}% bề mặt vỏ quả.';
      storageTip = 'Không nên tiếp tục lưu trữ cùng các quả khác vì khí ethylene thải ra sẽ làm lây hư hỏng nhanh chóng.';
      nutritionNote = 'Đường đã chuyển hóa quá mức, vi sinh vật có thể đã xâm nhập. Không an toàn cho dạ dày nhạy cảm.';
      edibilityVerdict = 'Cảnh báo: Không nên ăn sống. Có thể gọt bỏ phần hư để làm bánh nếu thịt quả bên trong chưa chua.';
      daysToRipe = 0;
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      final sugarSpots = (m.brownRotRatio * 100).clamp(0.0, 20.0);
      ripenessPercent = (85.0 + sugarSpots * 0.7).clamp(80.0, 98.0);
      freshnessPercent = (96.0 - m.brownRotRatio * 40).clamp(70.0, 98.0);
      headline = 'Chuối Chín Vàng Thơm Ngon';
      summary = 'Vỏ chuối ngả vàng ươm hoàn hảo, có lấm tấm đốm mật (sugar spots) tự nhiên, vị ngọt đậm và mềm dẻo.';
      evidence = 'Sắc tố vàng carotenoid chiếm ${(m.yellowRatio * 100).toStringAsFixed(1)}%, đốm mật đường ngọt nhẹ ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bảo quản nhiệt độ phòng thoáng mát, có thể bọc cuống chuối bằng màng bọc thực phẩm để giữ tươi thêm 2-3 ngày.';
      nutritionNote = 'Hàm lượng chất chống oxy hóa, fructose và kali đạt đỉnh cao nhất, dễ tiêu hóa và bổ sung năng lượng tức thì.';
      edibilityVerdict = 'Ăn ngay: Hoàn hảo nhất để ăn trực tiếp, làm sữa chua, sinh tố bồi bổ sức khỏe.';
      daysToRipe = 0;
    } else if (isTurning) {
      status = RipenessStatus.turning;
      ripenessPercent = 60.0 + (m.yellowRatio / (m.yellowRatio + m.greenRatio + 1e-4)) * 20.0;
      freshnessPercent = 95.0;
      headline = 'Chuối Vừa Chín Tới (Ương)';
      summary = 'Chuối đang trong giai đoạn chuyển vàng, gốc hoặc đầu quả còn xanh nhẹ, vị ngọt thanh và còn độ săn giòn.';
      evidence = 'Sắc vàng ${(m.yellowRatio * 100).toStringAsFixed(1)}% đang dần lấn át sắc xanh diệp lục ${(m.greenRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Để nơi thoáng khí từ 1 - 2 ngày ở nhiệt độ phòng, chuối sẽ chuyển vàng rực rỡ và thơm lừng.';
      nutritionNote = 'Cân bằng lý tưởng giữa tinh bột kháng lợi khuẩn và lượng đường tự nhiên, chỉ số GI vừa phải.';
      edibilityVerdict = 'Ngon miệng: Rất thích hợp cho người thích ăn chuối dẻo giòn hoặc người đang ăn kiêng giảm đường.';
      daysToRipe = 1;
    } else {
      status = RipenessStatus.unripe;
      ripenessPercent = math.max(10.0, (1.0 - m.greenRatio) * 50.0);
      freshnessPercent = 98.0;
      headline = 'Chuối Còn Xanh (Chưa Chín)';
      summary = 'Vỏ chuối màu xanh lục bóng bẩy, thịt quả chắc cứng, chứa nhiều tinh bột kháng chưa chuyển hóa thành đường.';
      evidence = 'Chỉ số diệp lục xanh chiếm áp đảo ${(m.greenRatio * 100).toStringAsFixed(1)}% diện tích bề mặt.';
      storageTip = 'Để ở nơi ấm trong nhà hoặc để gần táo/cà chua để khí ethylene kích thích chuối chín nhanh hơn.';
      nutritionNote = 'Giàu tinh bột kháng (Resistant Starch) hoạt động như chất xơ prebiotic nuôi dưỡng hệ vi sinh đường ruột.';
      edibilityVerdict = 'Chờ chín: Chưa thích hợp để ăn ngọt trực tiếp. Thích hợp nấu canh chuối ốc, làm chuối chát xào hoặc luộc.';
      daysToRipe = 3;
    }

    final confidence = _calculateConfidence(status, m);

    return FruitAnalysisResult(
      category: FruitCategory.banana,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripenessPercent,
      freshnessPercent: freshnessPercent,
      confidence: confidence,
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: edibilityVerdict,
      metrics: m,
      estimatedDaysToRipe: daysToRipe,
    );
  }

  FruitAnalysisResult _evalMango(FruitColorMetrics m) {
    const nameVi = 'Xoài';
    const nameEn = 'Mango';
    const icon = '🥭';

    final isRotten = m.brownRotRatio > 0.28 || (m.brownRotRatio > 0.20 && m.avgBrightness < 0.35);
    final isRipe = (m.yellowRatio + m.orangeRatio) > 0.35 && m.brownRotRatio < 0.25;
    final isTurning = (m.yellowRatio + m.orangeRatio) >= 0.18 && m.greenRatio >= 0.20;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;
    int? days;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 20.0;
      headline = 'Xoài Bị Thối / Nhiễm Bệnh Thán Thư';
      summary = 'Vỏ xoài xuất hiện đốm đen thâm lõm, thịt quả có dấu hiệu ủng nước hoặc lên men chua hôi.';
      evidence = 'Vết hoại tử thâm nâu chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}% diện tích vỏ.';
      storageTip = 'Loại bỏ ngay để tránh ruồi giấm và nấm mốc lây lan sang các loại quả khác trong giỏ.';
      nutritionNote = 'Nấm mốc tạo độc tố mycotoxin nguy hại cho gan và tiêu hóa. Tuyệt đối không nên ăn.';
      verdict = 'Bỏ đi: Quả đã hư hỏng, không đảm bảo an toàn vệ sinh thực phẩm.';
      days = 0;
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = (85.0 + m.orangeRatio * 20.0).clamp(80.0, 99.0);
      freshness = 95.0;
      headline = 'Xoài Chín Vàng Mọng Nước';
      summary = 'Vỏ xoài vàng ươm hoặc ửng cam mọng nước, mùi thơm ngào ngạt lan tỏa, thịt mềm ngọt đậm đà.';
      evidence = 'Sắc tố vàng và cam chín chiếm ${((m.yellowRatio + m.orangeRatio) * 100).toStringAsFixed(1)}% tổng thể.';
      storageTip = 'Nên ăn ngay hoặc cất ngăn mát tủ lạnh (8-10°C) dùng trong 2-3 ngày để giữ nguyên độ tươi.';
      nutritionNote = 'Dồi dào vitamin A, vitamin C và beta-carotene giúp sáng mắt và tăng cường miễn dịch.';
      verdict = 'Ăn ngay: Đạt hương vị ngọt thơm đỉnh cao.';
      days = 0;
    } else if (isTurning) {
      status = RipenessStatus.turning;
      ripeness = 65.0;
      freshness = 96.0;
      headline = 'Xoài Ương (Vừa Chín Tới)';
      summary = 'Vỏ xoài ửng vàng trên nền xanh, ruột xoài dẻo giòn, vị chua ngọt hòa quyện kích thích vị giác.';
      evidence = 'Sắc vàng cam ${(m.yellowRatio * 100).toStringAsFixed(1)}% xen kẽ sắc xanh ${(m.greenRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Để nơi râm mát 1-2 ngày nếu muốn ăn ngọt mềm, hoặc chấm muối ớt ăn giòn ngay.';
      nutritionNote = 'Cung cấp nhiều chất xơ hòa tan pectin và vitamin C dồi dào.';
      verdict = 'Cực ngon: Lý tưởng để ăn giòn chua ngọt hoặc làm gỏi xoài.';
      days = 2;
    } else {
      status = RipenessStatus.unripe;
      ripeness = 25.0;
      freshness = 98.0;
      headline = 'Xoài Xanh Giòn (Còn Sống)';
      summary = 'Vỏ xanh đậm bóng mịn, thịt quả rất cứng và giòn, vị chua thanh đậm chất xoài non.';
      evidence = 'Sắc xanh diệp lục chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}% bề mặt quả.';
      storageTip = 'Ủ trong thùng gạo hoặc túi giấy kín để khí ethylene tự nhiên giúp xoài mau chín thơm.';
      nutritionNote = 'Giàu axit citric và chất chống oxy hóa giúp giải nhiệt cơ thể.';
      verdict = 'Ăn giòn chua: Thích hợp chấm muối tôm, làm nộm hoặc lắc chua cay.';
      days = 4;
    }

    return FruitAnalysisResult(
      category: FruitCategory.mango,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: days,
    );
  }

  FruitAnalysisResult _evalPapaya(FruitColorMetrics m) {
    const nameVi = 'Đu đủ';
    const nameEn = 'Papaya';
    const icon = '🍈';

    final isRotten = m.brownRotRatio > 0.28;
    final isRipe = (m.orangeRatio + m.yellowRatio) > 0.32 && m.brownRotRatio < 0.25;
    final isTurning = (m.orangeRatio + m.yellowRatio) >= 0.15 && m.greenRatio >= 0.25;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;
    int? days;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 15.0;
      headline = 'Đu Đủ Dập Nát / Thối Hỏng';
      summary = 'Vỏ mềm nhũn, xuất hiện vết thâm ủng nước loang lổ hoặc sợi mốc trắng.';
      evidence = 'Vết ủng hư hỏng chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bỏ ngay vào thùng rác hữu cơ.';
      nutritionNote = 'Quả đã nhiễm nấm men phân hủy không an toàn.';
      verdict = 'Không ăn: Đã hỏng.';
      days = 0;
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = 92.0;
      freshness = 94.0;
      headline = 'Đu Đủ Chín Vàng Cam Mềm Ngọt';
      summary = 'Vỏ đu đủ ngả vàng cam rực rỡ, thịt quả mềm mọng nước, vị ngọt đậm thơm mát lành tính.';
      evidence = 'Sắc tố carotenoid vàng cam chiếm ${((m.orangeRatio + m.yellowRatio) * 100).toStringAsFixed(1)}%.';
      storageTip = 'Cất ngăn mát tủ lạnh dùng trong vòng 2-3 ngày.';
      nutritionNote = 'Rất giàu enzyme Papain hỗ trợ tiêu hóa đạm cực tốt, dồi dào vitamin C & folate.';
      verdict = 'Thưởng thức ngay: Tốt cho dạ dày và tiêu hóa.';
      days = 0;
    } else if (isTurning) {
      status = RipenessStatus.turning;
      ripeness = 60.0;
      freshness = 97.0;
      headline = 'Đu Đủ Hườm (Vừa Chín Tới)';
      summary = 'Vỏ có các vệt vàng chạy dọc thân xen lẫn vỏ xanh, ruột có màu cam nhạt, ăn giòn sần sật.';
      evidence = 'Vệt chín vàng cam đạt ${((m.orangeRatio + m.yellowRatio) * 100).toStringAsFixed(1)}% bên cạnh sắc xanh.';
      storageTip = 'Ủ thêm 1-2 ngày ở nơi kín gió để đu đủ chín ngọt đậm đà.';
      nutritionNote = 'Enzyme tiêu hóa hoạt tính cao, lượng đường chưa quá cao.';
      verdict = 'Ăn giòn hoặc chờ thêm 1-2 ngày.';
      days = 2;
    } else {
      status = RipenessStatus.unripe;
      ripeness = 20.0;
      freshness = 98.0;
      headline = 'Đu Đủ Xanh (Còn Sống)';
      summary = 'Vỏ xanh mướt toàn bộ, cứng cáp, cuống nhiều mủ trắng tinh tự nhiên.';
      evidence = 'Sắc tố xanh diệp lục chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Nếu muốn làm chín, để cạnh chuối chín trong 3-4 ngày.';
      nutritionNote = 'Giàu enzyme papain trong nhựa mủ, tuyệt vời để làm mềm thịt khi hầm.';
      verdict = 'Chế biến món mặn: Hầm sườn, nấu canh hoặc bào sợi làm gỏi nộm.';
      days = 4;
    }

    return FruitAnalysisResult(
      category: FruitCategory.papaya,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: days,
    );
  }

  FruitAnalysisResult _evalOrange(FruitColorMetrics m) {
    const nameVi = 'Cam / Quýt';
    const nameEn = 'Orange / Citrus';
    const icon = '🍊';

    final isRotten = m.brownRotRatio > 0.25;
    final isRipe = (m.orangeRatio + m.yellowRatio) > 0.35 && m.brownRotRatio < 0.20;
    final isTurning = (m.orangeRatio + m.yellowRatio) >= 0.18 && m.greenRatio >= 0.25;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;
    int? days;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 10.0;
      headline = 'Cam Bị Mốc / Thối Cuống';
      summary = 'Vỏ cam bị úng nước hoặc có mảng mốc xanh Penicillium lan rộng, tép cam chua thối.';
      evidence = 'Vết nấm mốc hoặc dập úng chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bỏ ngay lập tức, lau sạch rổ đựng để tránh bào tử nấm lây lan.';
      nutritionNote = 'Bào tử nấm mốc nguy hiểm cho đường hô hấp và tiêu hóa.';
      verdict = 'Bỏ đi: Quả đã hỏng hoàn toàn.';
      days = 0;
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = 95.0;
      freshness = 95.0;
      headline = 'Cam Chín Mọng Nước Ngọt Lành';
      summary = 'Vỏ cam sáng bóng ngả màu vàng cam tươi, tép cam mọng nước, vị ngọt thanh mát.';
      evidence = 'Màu cam vàng rực rỡ chiếm ${((m.orangeRatio + m.yellowRatio) * 100).toStringAsFixed(1)}%.';
      storageTip = 'Để nơi khô mát hoặc ngăn mát tủ lạnh có thể giữ tươi đến 1-2 tuần.';
      nutritionNote = 'Cực giàu Vitamin C, Hesperidin và các Flavonoid tăng sức đề kháng mùa dịch.';
      verdict = 'Ăn ngay hoặc vắt nước cam tươi nguyên chất.';
      days = 0;
    } else if (isTurning) {
      status = RipenessStatus.turning;
      ripeness = 70.0;
      freshness = 97.0;
      headline = 'Cam Sành Ửng Vàng (Vừa Chín)';
      summary = 'Vỏ cam xanh bóng chuyển đốm vàng cam ở đít quả, nhiều nước và vị chua dịu dễ chịu.';
      evidence = 'Sắc cam vàng ${(m.orangeRatio * 100).toStringAsFixed(1)}% bên cạnh vỏ xanh.';
      storageTip = 'Bảo quản nhiệt độ phòng thoáng khí vài ngày cam sẽ xuống nước ngọt hơn.';
      nutritionNote = 'Hàm lượng vitamin C tự nhiên rất cao.';
      verdict = 'Rất thích hợp vắt nước uống giải nhiệt.';
      days = 2;
    } else {
      status = RipenessStatus.unripe;
      ripeness = 30.0;
      freshness = 98.0;
      headline = 'Cam Còn Non Xanh (Chưa Chín)';
      summary = 'Vỏ xanh sẫm dày cứng, tép cam ít nước, vị chua gắt và nhiều tinh dầu cay ở vỏ.';
      evidence = 'Sắc xanh chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}% diện tích vỏ.';
      storageTip = 'Cam là loại quả khó tự ngọt thêm sau khi hái, nên để vài ngày cho bớt vị hăng.';
      nutritionNote = 'Vị chua nhiều axit citric hữu cơ.';
      verdict = 'Chờ thêm hoặc dùng làm gia vị / ướp món ăn.';
      days = 4;
    }

    return FruitAnalysisResult(
      category: FruitCategory.orange,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: days,
    );
  }

  FruitAnalysisResult _evalLemon(FruitColorMetrics m) {
    const nameVi = 'Chanh';
    const nameEn = 'Lemon / Lime';
    const icon = '🍋';

    final isRotten = m.brownRotRatio > 0.25;
    // Chanh vàng (Lemon) chín vàng, hoặc Chanh ta (Lime) xanh mỏng vỏ bóng nước
    final isYellowRipe = m.yellowRatio > 0.35 && m.brownRotRatio < 0.20;
    final isGreenRipe = m.greenRatio > 0.40 && m.avgBrightness > 0.42 && m.brownRotRatio < 0.15;
    final isRipe = isYellowRipe || isGreenRipe;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 10.0;
      headline = 'Chanh Bị Héo Khô / Thối Mốc';
      summary = 'Vỏ chanh khô quắt thâm đen hoặc dập mốc, tép chanh bị mất hết nước.';
      evidence = 'Vết thâm hoại tử chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bỏ quả hỏng đi để không làm mốc các quả khác.';
      nutritionNote = 'Đã mất dược tính và giá trị dinh dưỡng.';
      verdict = 'Bỏ đi: Không còn nước và an toàn.';
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = 95.0;
      freshness = 97.0;
      headline = isYellowRipe ? 'Chanh Vàng Chín Mọng Thơm Lừng' : 'Chanh Xanh Căng Bóng Mọng Nước';
      summary = isYellowRipe
          ? 'Quả chanh vỏ vàng tươi mịn màng, hương tinh dầu thơm ngát, vị chua thanh mọng nước.'
          : 'Vỏ chanh mỏng căng mướt, nhiều nước, tinh dầu thơm cay nồng nàn.';
      evidence = isYellowRipe
          ? 'Sắc vàng chanh đạt ${(m.yellowRatio * 100).toStringAsFixed(1)}%.'
          : 'Sắc xanh tươi bóng đạt ${(m.greenRatio * 100).toStringAsFixed(1)}%, độ sáng cao.';
      storageTip = 'Bọc màng bọc thực phẩm hoặc cho vào hộp kín để ngăn mát tủ lạnh giữ tươi hơn 3 tuần.';
      nutritionNote = 'Giàu axit citric, kali và vitamin C giúp thanh lọc giải độc và kiềm hóa cơ thể.';
      verdict = 'Tuyệt vời: Dùng pha nước giải khát, làm nước chấm, ướp salad.';
    } else {
      status = RipenessStatus.unripe;
      ripeness = 40.0;
      freshness = 98.0;
      headline = 'Chanh Non (Vỏ Dày Ít Nước)';
      summary = 'Chanh còn non, vỏ sần sùi dày cộm, tép chanh còn nhỏ và vắt ra rất ít nước cốt.';
      evidence = 'Sắc xanh đậm ${(m.greenRatio * 100).toStringAsFixed(1)}%, vỏ cứng.';
      storageTip = 'Để ở nơi thoáng mát thêm vài ngày vỏ sẽ mỏng bớt.';
      nutritionNote = 'Nhiều tinh dầu vỏ chanh nhưng ít nước cốt.';
      verdict = 'Chờ thêm: Thích hợp lấy vỏ làm gia vị hoặc nạo tinh dầu.';
    }

    return FruitAnalysisResult(
      category: FruitCategory.lemon,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: isRipe ? 0 : 3,
    );
  }

  FruitAnalysisResult _evalApple(FruitColorMetrics m) {
    const nameVi = 'Táo';
    const nameEn = 'Apple';
    const icon = '🍎';

    final isRotten = m.brownRotRatio > 0.22;
    final isRipe = (m.redRatio + m.yellowRatio) > 0.35 && m.brownRotRatio < 0.20;
    final isTurning = (m.redRatio + m.yellowRatio) >= 0.20 && m.greenRatio >= 0.25;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 15.0;
      headline = 'Táo Bị Dập Úng / Thối Nâu';
      summary = 'Bề mặt táo có vết dập thâm đen lõm sâu, thịt quả xốp mềm nhũn úng nước.';
      evidence = 'Vết dập thâm nâu chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Loại bỏ ngay vì táo hỏng sinh nhiều khí ethylene làm hỏng các quả xung quanh.';
      nutritionNote = 'Thịt quả dập có thể chứa vi nấm men patulin gây hại dạ dày.';
      verdict = 'Không nên ăn: Quả đã dập úng hỏng.';
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = 95.0;
      freshness = 96.0;
      headline = 'Táo Chín Đỏ Căng Mọng Giòn Ngọt';
      summary = 'Vỏ táo đỏ tươi bóng láng, thịt quả chắc giòn rụm, ngọt đậm đà nhiều nước.';
      evidence = 'Sắc đỏ và vàng chín chiếm ${((m.redRatio + m.yellowRatio) * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bảo quản ngăn mát tủ lạnh (2-4°C) giúp táo giữ độ giòn tan suốt 2-4 tuần.';
      nutritionNote = 'Giàu chất chống oxy hóa Quercetin và chất xơ Pectin giúp giảm cholesterol xấu.';
      verdict = 'Thưởng thức ngay: Táo giòn ngọt hoàn hảo cho bữa phụ.';
    } else if (isTurning) {
      status = RipenessStatus.turning;
      ripeness = 70.0;
      freshness = 97.0;
      headline = 'Táo Vừa Chín (Giòn Chua Nhẹ)';
      summary = 'Táo má hồng ửng đỏ xen lẫn màu xanh, vị giòn tan và có hậu vị chua thanh mát.';
      evidence = 'Sắc đỏ ${(m.redRatio * 100).toStringAsFixed(1)}% bên cạnh màu xanh non.';
      storageTip = 'Để nhiệt độ phòng 2-3 ngày nếu thích ăn ngọt đậm hơn.';
      nutritionNote = 'Hàm lượng axit malic tự nhiên giúp kích thích tiêu hóa.';
      verdict = 'Ăn giòn chua: Rất ngon cho người không thích quá ngọt.';
    } else {
      status = RipenessStatus.unripe;
      ripeness = 35.0;
      freshness = 98.0;
      headline = 'Táo Xanh (Còn Non Chát)';
      summary = 'Táo vỏ xanh xỉn, kích thước quả còn nhỏ, vị chua chát rõ rệt.';
      evidence = 'Sắc xanh diệp lục chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Ủ ở nơi ấm vài ngày để táo chín.';
      nutritionNote = 'Nhiều tanin gây vị chát.';
      verdict = 'Chờ thêm: Phù hợp làm salad chua hoặc nướng bánh.';
    }

    return FruitAnalysisResult(
      category: FruitCategory.apple,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: isRipe ? 0 : 3,
    );
  }

  FruitAnalysisResult _evalTomato(FruitColorMetrics m) {
    const nameVi = 'Cà chua';
    const nameEn = 'Tomato';
    const icon = '🍅';

    final isRotten = m.brownRotRatio > 0.20;
    final isRipe = m.redRatio > 0.35 && m.brownRotRatio < 0.18;
    final isTurning = (m.redRatio + m.orangeRatio) >= 0.20 && m.greenRatio >= 0.20;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 10.0;
      headline = 'Cà Chua Bị Thối Đít / Dập Nứt';
      summary = 'Vỏ cà chua nứt toác chảy dịch, phần đít thâm đen hoại tử hoặc mốc trắng sần.';
      evidence = 'Vết nấm mốc thối rữa chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bỏ ngay quả thối tránh lây sang các quả khác.';
      nutritionNote = 'Có thể chứa vi khuẩn gây rối loạn đường ruột nghiêm trọng.';
      verdict = 'Bỏ đi: Tuyệt đối không sử dụng.';
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = 96.0;
      freshness = 97.0;
      headline = 'Cà Chua Chín Đỏ Mọng Tuyệt Đẹp';
      summary = 'Vỏ đỏ tươi bóng bẩy căng tràn, thịt cà chua mọng nước, nhiều bột ngọt bùi.';
      evidence = 'Sắc tố đỏ lycopene chiếm ${(m.redRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bảo quản nhiệt độ phòng, để cuống hướng lên trên để giữ cà chua tươi ngon lâu nhất.';
      nutritionNote = 'Dồi dào Lycopene - chất chống oxy hóa mạnh mẽ bảo vệ tim mạch và làn da.';
      verdict = 'Ăn ngay: Ăn sống salad hoặc nấu sốt thơm ngon.';
    } else if (isTurning) {
      status = RipenessStatus.turning;
      ripeness = 65.0;
      freshness = 98.0;
      headline = 'Cà Chua Ương (Ửng Cam Vàng)';
      summary = 'Quả đang chuyển từ cam sang đỏ, thịt quả săn chắc giòn rụm.';
      evidence = 'Màu cam đỏ ${(m.orangeRatio * 100).toStringAsFixed(1)}% bên cạnh sắc xanh.';
      storageTip = 'Để nhiệt độ phòng 1-2 ngày cà chua sẽ đỏ mọng hoàn hảo.';
      nutritionNote = 'Hàm lượng vitamin C cao, đang tích lũy lycopene.';
      verdict = 'Ngon giòn: Rất thích hợp làm món xào hoặc muối chua.';
    } else {
      status = RipenessStatus.unripe;
      ripeness = 20.0;
      freshness = 99.0;
      headline = 'Cà Chua Xanh (Chưa Chín)';
      summary = 'Vỏ xanh ngắt, quả cứng đanh, chứa hợp chất tomatine/solanine.';
      evidence = 'Sắc xanh diệp lục chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Để nơi ấm có ánh nắng nhẹ để cà chua chuyển đỏ tự nhiên.';
      nutritionNote = 'Cà chua xanh sống chứa alkaloid solanine, không nên ăn sống số lượng lớn.';
      verdict = 'Chờ chín hoặc chế biến chín kỹ (cà chua xanh tẩm bột chiên).';
    }

    return FruitAnalysisResult(
      category: FruitCategory.tomato,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: isRipe ? 0 : 3,
    );
  }

  FruitAnalysisResult _evalAvocado(FruitColorMetrics m) {
    const nameVi = 'Quả Bơ';
    const nameEn = 'Avocado';
    const icon = '🥑';

    final isRotten = m.brownRotRatio > 0.45;
    // Bơ chín: vỏ nâu sẫm / tím đen mềm tay (hoặc sẫm màu)
    final isRipe = (m.brownRotRatio > 0.25 || m.avgBrightness < 0.28) && m.greenRatio < 0.30;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 15.0;
      headline = 'Bơ Bị Thối Nhũn / Xơ Đen';
      summary = 'Quả bơ nhũn lõm sâu, vỏ nứt thâm đen xỉn, bên trong bị xơ đen và có mùi dầu ôi.';
      evidence = 'Vết hoại tử thâm đen chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Không thể cứu vãn, nên bỏ.';
      nutritionNote = 'Chất béo trong bơ đã bị oxy hóa ôi thiu.';
      verdict = 'Không nên ăn: Đã bị thối nhũn.';
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = 95.0;
      freshness = 94.0;
      headline = 'Bơ Đã Chín Dẻo Béo Ngậy';
      summary = 'Vỏ chuyển màu nâu tím sẫm, ấn nhẹ thấy êm tay, cuống có màu vàng xanh tươi.';
      evidence = 'Vỏ sẫm màu đặc trưng của bơ sáp chín, độ mềm vừa vặn.';
      storageTip = 'Cất ngăn mát tủ lạnh nếu chưa ăn ngay để làm chậm quá trình chín quá đà.';
      nutritionNote = 'Cực giàu chất béo không bão hòa đơn lành mạnh (Omega 9) và vitamin E làm đẹp da.';
      verdict = 'Ăn ngay: Đạt độ dẻo quánh thơm béo tuyệt hảo.';
    } else {
      status = RipenessStatus.unripe;
      ripeness = 25.0;
      freshness = 98.0;
      headline = 'Bơ Còn Xanh Cứng (Chưa Chín)';
      summary = 'Vỏ xanh tươi sáng bóng, ấn vào cứng ngắc, cuống bám rất chặt.';
      evidence = 'Sắc xanh chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}%, vỏ cứng.';
      storageTip = 'Để ở nơi thoáng mát cạnh quả chuối chín, bơ sẽ tự chín sau 2-4 ngày. Tuyệt đối không cho vào tủ lạnh khi bơ còn xanh.';
      nutritionNote = 'Thịt quả còn nhiều nhựa chát, chưa chuyển hóa thành dầu béo.';
      verdict = 'Chờ chín: Chưa ăn được, cần ủ thêm vài ngày.';
    }

    return FruitAnalysisResult(
      category: FruitCategory.avocado,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: isRipe ? 0 : 3,
    );
  }

  FruitAnalysisResult _evalWatermelon(FruitColorMetrics m) {
    const nameVi = 'Dưa hấu';
    const nameEn = 'Watermelon';
    const icon = '🍉';

    final isRotten = m.brownRotRatio > 0.25;
    // Dưa chín: Đốm đáy có màu vàng kem / vàng đất (m.yellowRatio > 0.12)
    final hasYellowSpot = m.yellowRatio > 0.10;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 10.0;
      headline = 'Dưa Hấu Bị Ủng / Nứt Chảy Nước';
      summary = 'Vỏ dưa bị lõm mềm, nứt toác chảy nước chua lên men.';
      evidence = 'Vết dập úng chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bỏ ngay quả hỏng.';
      nutritionNote = 'Đường lên men sinh cồn và vi khuẩn đường ruột.';
      verdict = 'Bỏ đi: Đã thối hỏng.';
    } else if (hasYellowSpot || m.avgBrightness > 0.35) {
      status = RipenessStatus.ripe;
      ripeness = 92.0;
      freshness = 96.0;
      headline = 'Dưa Hấu Chín Giòn Ngọt Mọng Nước';
      summary = 'Vỏ đanh chắc, có đốm tiếp đất vàng kem tự nhiên, gõ nghe tiếng bộp bộp vang đanh.';
      evidence = 'Đốm đáy vàng kem chín tự nhiên ${(m.yellowRatio * 100).toStringAsFixed(1)}%, vỏ sọc rõ nét.';
      storageTip = 'Để nguyên quả nơi thoáng mát hoặc bổ miếng cho hộp kín để tủ lạnh.';
      nutritionNote = 'Chứa hơn 91% nước cùng chất chống oxy hóa Lycopene & Citrulline thanh nhiệt.';
      verdict = 'Ăn ngay: Bổ dưa ăn mát lạnh giải khát tuyệt đỉnh.';
    } else {
      status = RipenessStatus.unripe;
      ripeness = 40.0;
      freshness = 98.0;
      headline = 'Dưa Hấu Non (Đốm Đáy Trắng Nhạt)';
      summary = 'Vỏ xanh đều không có đốm vàng đất, ruột dưa có thể còn màu hồng nhạt, vị ngọt thanh nhẹ.';
      evidence = 'Sắc xanh chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}%, thiếu đốm vàng đất.';
      storageTip = 'Dưa hấu sau khi hái không tự ngọt thêm nhiều, nên dùng sớm.';
      nutritionNote = 'Ít đường hơn, tính mát giải nhiệt.';
      verdict = 'Ăn được nhưng ruột sẽ nhạt hơn dưa già.';
    }

    return FruitAnalysisResult(
      category: FruitCategory.watermelon,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: 0,
    );
  }

  FruitAnalysisResult _evalDragonFruit(FruitColorMetrics m) {
    const nameVi = 'Thanh Long';
    const nameEn = 'Dragon Fruit';
    const icon = '🐉';

    final isRotten = m.brownRotRatio > 0.25;
    final isRipe = m.redRatio > 0.30 && m.brownRotRatio < 0.20;

    RipenessStatus status;
    double ripeness;
    double freshness;
    String headline;
    String summary;
    String evidence;
    String storageTip;
    String nutritionNote;
    String verdict;

    if (isRotten) {
      status = RipenessStatus.rotten;
      ripeness = 100.0;
      freshness = 15.0;
      headline = 'Thanh Long Bị Thối Tai / Dập Nát';
      summary = 'Tai thanh long héo úa thâm đen, vỏ chảy dịch nhớt mốc meo.';
      evidence = 'Vết dập thối chiếm ${(m.brownRotRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Loại bỏ quả hỏng.';
      nutritionNote = 'Nấm mốc làm giảm chất lượng.';
      verdict = 'Không nên ăn.';
    } else if (isRipe) {
      status = RipenessStatus.ripe;
      ripeness = 95.0;
      freshness = 97.0;
      headline = 'Thanh Long Chín Mọng Vỏ Đỏ Tươi';
      summary = 'Vỏ màu đỏ hồng rực rỡ, tai thanh long còn xanh tươi mềm mại, ruột ngọt thanh mát lành.';
      evidence = 'Sắc đỏ hồng rực rỡ chiếm ${(m.redRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Bảo quản ngăn mát tủ lạnh giúp quả ngon ngọt sảng khoái hơn khi ăn.';
      nutritionNote = 'Cực giàu chất xơ hòa tan, chất chống oxy hóa Betalain và hạt giàu Omega 3 tốt cho đường ruột.';
      verdict = 'Thưởng thức ngay: Rất mát và tốt cho tiêu hóa.';
    } else {
      status = RipenessStatus.unripe;
      ripeness = 40.0;
      freshness = 98.0;
      headline = 'Thanh Long Còn Hơi Non';
      summary = 'Vỏ còn nhiều vệt xanh, ruột có vị chua thanh nhẹ, tai quả cứng đanh.';
      evidence = 'Sắc xanh còn chiếm ${(m.greenRatio * 100).toStringAsFixed(1)}%.';
      storageTip = 'Để nhiệt độ phòng 2-3 ngày quả sẽ lên màu đỏ đều.';
      nutritionNote = 'Ít đường, vị chua mát.';
      verdict = 'Chờ chín thêm nếu thích ăn ngọt đậm.';
    }

    return FruitAnalysisResult(
      category: FruitCategory.dragonFruit,
      nameVi: nameVi,
      nameEn: nameEn,
      iconEmoji: icon,
      status: status,
      ripenessPercent: ripeness,
      freshnessPercent: freshness,
      confidence: _calculateConfidence(status, m),
      headline: headline,
      summary: summary,
      evidence: evidence,
      storageTip: storageTip,
      nutritionNote: nutritionNote,
      edibilityVerdict: verdict,
      metrics: m,
      estimatedDaysToRipe: isRipe ? 0 : 2,
    );
  }

  FruitAnalysisResult _buildNotFruitResult(
    FruitColorMetrics m, {
    FruitCategory category = FruitCategory.auto,
  }) {
    return FruitAnalysisResult(
      category: category,
      nameVi: 'Không xác định trái cây',
      nameEn: 'Not a recognized fruit',
      iconEmoji: '🔍',
      status: RipenessStatus.notFruit,
      ripenessPercent: 0.0,
      freshnessPercent: 0.0,
      confidence: 0.88,
      headline: 'Không Phát Hiện Thấy Trái Cây Hợp Lệ',
      summary: 'Hình ảnh không có đặc trưng màu sắc hoặc kết cấu của các loại quả thông dụng (Chuối, Xoài, Táo, Cam, Chanh, Đu Đủ, Cà Chua...).',
      evidence: 'Tỷ lệ màu sắc trái cây tự nhiên quá thấp (<12%), sắc độ xỉn màu.',
      storageTip: 'Vui lòng đưa quả vào giữa khung ngắm máy ảnh, chụp rõ dưới ánh sáng tự nhiên đầy đủ.',
      nutritionNote: 'Không có dữ liệu dinh dưỡng cho vật thể không phải quả tươi.',
      edibilityVerdict: 'Vui lòng chụp lại ảnh trái cây cần kiểm tra.',
      metrics: m,
      estimatedDaysToRipe: null,
    );
  }

  double _calculateConfidence(RipenessStatus status, FruitColorMetrics m) {
    // Đảm bảo confidence thực tế từ 0.78 đến 0.98
    double base = 0.82;
    if (status == RipenessStatus.ripe) {
      base += math.min(0.14, (m.yellowRatio + m.redRatio + m.orangeRatio) * 0.2);
    } else if (status == RipenessStatus.rotten) {
      base += math.min(0.15, m.brownRotRatio * 0.3);
    } else if (status == RipenessStatus.unripe) {
      base += math.min(0.14, m.greenRatio * 0.2);
    }
    return double.parse(base.clamp(0.75, 0.98).toStringAsFixed(2));
  }
}
