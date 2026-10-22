import 'package:flutter/material.dart';

/// Danh mục các loài trái cây thông dụng được hỗ trợ
enum FruitCategory {
  auto,
  banana,
  mango,
  papaya,
  orange,
  lemon,
  apple,
  tomato,
  avocado,
  watermelon,
  dragonFruit,
}

extension FruitCategoryExtension on FruitCategory {
  String get nameVi {
    switch (this) {
      case FruitCategory.auto:
        return 'Tự động nhận diện';
      case FruitCategory.banana:
        return 'Chuối';
      case FruitCategory.mango:
        return 'Xoài';
      case FruitCategory.papaya:
        return 'Đu đủ';
      case FruitCategory.orange:
        return 'Cam / Quýt';
      case FruitCategory.lemon:
        return 'Chanh';
      case FruitCategory.apple:
        return 'Táo';
      case FruitCategory.tomato:
        return 'Cà chua';
      case FruitCategory.avocado:
        return 'Quả Bơ';
      case FruitCategory.watermelon:
        return 'Dưa hấu';
      case FruitCategory.dragonFruit:
        return 'Thanh Long';
    }
  }

  String get nameEn {
    switch (this) {
      case FruitCategory.auto:
        return 'Auto Detect';
      case FruitCategory.banana:
        return 'Banana';
      case FruitCategory.mango:
        return 'Mango';
      case FruitCategory.papaya:
        return 'Papaya';
      case FruitCategory.orange:
        return 'Orange';
      case FruitCategory.lemon:
        return 'Lemon / Lime';
      case FruitCategory.apple:
        return 'Apple';
      case FruitCategory.tomato:
        return 'Tomato';
      case FruitCategory.avocado:
        return 'Avocado';
      case FruitCategory.watermelon:
        return 'Watermelon';
      case FruitCategory.dragonFruit:
        return 'Dragon Fruit';
    }
  }

  String get iconEmoji {
    switch (this) {
      case FruitCategory.auto:
        return '✨';
      case FruitCategory.banana:
        return '🍌';
      case FruitCategory.mango:
        return '🥭';
      case FruitCategory.papaya:
        return '🍈';
      case FruitCategory.orange:
        return '🍊';
      case FruitCategory.lemon:
        return '🍋';
      case FruitCategory.apple:
        return '🍎';
      case FruitCategory.tomato:
        return '🍅';
      case FruitCategory.avocado:
        return '🥑';
      case FruitCategory.watermelon:
        return '🍉';
      case FruitCategory.dragonFruit:
        return '🐉';
    }
  }
}

/// Trạng thái độ chín / chất lượng của trái cây
enum RipenessStatus {
  ripe,       // Chín thơm ngon / Hoàn hảo để ăn
  turning,    // Vừa chín tới / Ương giòn
  unripe,     // Còn sống / Non xanh
  rotten,     // Bị hư hỏng / Dập thối / Nấm mốc
  notFruit,   // Không nhận diện thấy quả trái cây
}

extension RipenessStatusExtension on RipenessStatus {
  String get labelVi {
    switch (this) {
      case RipenessStatus.ripe:
        return 'Chín Thơm Ngon';
      case RipenessStatus.turning:
        return 'Vừa Chín Tới (Ương)';
      case RipenessStatus.unripe:
        return 'Còn Sống (Non Xanh)';
      case RipenessStatus.rotten:
        return 'Hư Hỏng / Dập Thối';
      case RipenessStatus.notFruit:
        return 'Không Xác Định Trái Cây';
    }
  }

  String get badgeText {
    switch (this) {
      case RipenessStatus.ripe:
        return 'ĐẠT ĐỘ CHÍN TỐT';
      case RipenessStatus.turning:
        return 'SẮP CHÍN / ĂN GIÒN';
      case RipenessStatus.unripe:
        return 'CÒN NON / CHƯA CHÍN';
      case RipenessStatus.rotten:
        return 'CẢNH BÁO HƯ HỎNG';
      case RipenessStatus.notFruit:
        return 'KHÔNG PHẢI QUẢ';
    }
  }

  Color get color {
    switch (this) {
      case RipenessStatus.ripe:
        return const Color(0xFF10B981); // Emerald Green / Ripe
      case RipenessStatus.turning:
        return const Color(0xFFF59E0B); // Amber Yellow
      case RipenessStatus.unripe:
        return const Color(0xFF0EA5E9); // Sky Cyan / Unripe
      case RipenessStatus.rotten:
        return const Color(0xFFEF4444); // Red Warning
      case RipenessStatus.notFruit:
        return const Color(0xFF94A3B8); // Slate Gray
    }
  }

  IconData get icon {
    switch (this) {
      case RipenessStatus.ripe:
        return Icons.check_circle_rounded;
      case RipenessStatus.turning:
        return Icons.timelapse_rounded;
      case RipenessStatus.unripe:
        return Icons.eco_rounded;
      case RipenessStatus.rotten:
        return Icons.report_problem_rounded;
      case RipenessStatus.notFruit:
        return Icons.help_outline_rounded;
    }
  }
}

/// Các chỉ số quang phổ màu sắc đo lường được
class FruitColorMetrics {
  const FruitColorMetrics({
    required this.yellowRatio,
    required this.greenRatio,
    required this.redRatio,
    required this.orangeRatio,
    required this.brownRotRatio,
    required this.avgBrightness,
    required this.avgSaturation,
  });

  final double yellowRatio;     // Tỷ lệ sắc vàng
  final double greenRatio;      // Tỷ lệ sắc xanh lục diệp lục
  final double redRatio;        // Tỷ lệ sắc đỏ anthocyanin
  final double orangeRatio;     // Tỷ lệ sắc cam carotenoid
  final double brownRotRatio;   // Tỷ lệ đốm thâm/nâu/dập thối
  final double avgBrightness;   // Độ sáng vỏ quả (0 - 1)
  final double avgSaturation;   // Độ rực màu (0 - 1)
}

/// Kết quả phân tích độ chín và chất lượng của Trái cây
class FruitAnalysisResult {
  const FruitAnalysisResult({
    required this.category,
    required this.nameVi,
    required this.nameEn,
    required this.iconEmoji,
    required this.status,
    required this.ripenessPercent,
    required this.freshnessPercent,
    required this.confidence,
    required this.headline,
    required this.summary,
    required this.evidence,
    required this.storageTip,
    required this.nutritionNote,
    required this.edibilityVerdict,
    required this.metrics,
    this.estimatedDaysToRipe,
  });

  final FruitCategory category;
  final String nameVi;
  final String nameEn;
  final String iconEmoji;
  final RipenessStatus status;
  final double ripenessPercent;   // 0.0 -> 100.0%
  final double freshnessPercent;  // 0.0 -> 100.0%
  final double confidence;        // 0.0 -> 1.0
  final String headline;
  final String summary;
  final String evidence;
  final String storageTip;
  final String nutritionNote;
  final String edibilityVerdict;
  final FruitColorMetrics metrics;
  final int? estimatedDaysToRipe;

  bool get isEdible => status == RipenessStatus.ripe || status == RipenessStatus.turning;
  bool get isRotten => status == RipenessStatus.rotten;
  bool get isUnripe => status == RipenessStatus.unripe;
}
