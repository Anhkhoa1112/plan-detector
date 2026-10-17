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
