import 'bounding_box.dart';

class Detection {
  const Detection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.bbox,
    this.nameVi,
  });

  final int classId;
  final String className;
  final String? nameVi;
  final double confidence;
  final BoundingBox bbox;

  static const Map<String, String> plantDescriptions = {
    'Acacia': 'Lá hình lưỡi liềm hoặc lá kép lông chim nhỏ, hoa bông vàng tươi đặc trưng.',
    'Bamboo-shoots': 'Thân đốt tròn rỗng màu xanh hoặc vàng, thường mọc thành bụi dày.',
    'Banana-plant': 'Thân giả mọng nước, phiến lá to dài hình bầu dục, có buồng hoa hoặc quả chuối.',
    'Banyan-Tree': 'Tán lá xòe rộng sum suê, rễ phụ buông rủ từ các cành lớn xuống đất.',
    'Coconut-tree': 'Thân đơn độc thẳng tắp không cành, lá xẻ dài tập trung ở ngọn, có buồng dừa.',
    'Mango-Tree': 'Tán tròn sum suê, lá non màu tía đỏ sau chuyển xanh đậm dai bóng, mép lá gợn sóng.',
    'Neem-Tree': 'Lá kép lông chim lẻ, mép lá có răng cưa nhọn rõ, thân gỗ tỏa cành đều.',
    'Palm-tree': 'Thân tròn đơn độc xù xì, lá xòe tròn hình quạt hoặc lông chim xẻ tán.',
    'Papaya-Tree': 'Thân mềm có sẹo cuống lá, lá xẻ thùy chân vịt sâu 7-9 thùy, quả bám quanh thân.',
    'Pine': 'Lá hình kim xanh quanh năm mọc thành chùm 2-3 lá, quả nón hóa gỗ đặc trưng.',
    'lemon tree': 'Cây bụi nhỏ thân gỗ, cành có gai nhọn, lá tỏa mùi thơm tinh dầu, quả tròn mọng.',
    'peepal tree': 'Lá hình trái tim bóng mịn với chóp lá kéo dài thành đuôi nhọn đặc trưng.',
  };

  String get description =>
      plantDescriptions[className] ??
      plantDescriptions[className.toLowerCase()] ??
      'Thực vật được nhận diện bởi mô hình AI.';

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  String get displayName =>
      (nameVi != null && nameVi!.trim().isNotEmpty) ? nameVi! : className;

  String get fullTitle =>
      (nameVi != null && nameVi!.trim().isNotEmpty)
          ? '$nameVi ($className)'
          : className;

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      classId: json['class_id'] as int,
      className: json['class_name'] as String,
      nameVi: json['name_vi'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      bbox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'class_name': className,
      if (nameVi != null) 'name_vi': nameVi,
      'confidence': confidence,
      'bbox': bbox.toJson(),
    };
  }
}
