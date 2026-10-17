import 'detection.dart';

class PredictionResponse {
  const PredictionResponse({
    required this.success,
    this.status = 'recognized',
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    this.isPlant = true,
    this.message,
  });

  final bool success;
  final String status;
  final int imageWidth;
  final int imageHeight;
  final List<Detection> detections;
  final bool isPlant;
  final String? message;

  bool get isRecognized => status == 'recognized';
  bool get isUncertain => status == 'uncertain';
  bool get isUnknown => status == 'unknown';
  bool get hasDetections => detections.isNotEmpty;
  int get count => detections.length;

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    final rawDetections = (json['detections'] as List<dynamic>?) ?? [];
    final detectionsList = rawDetections
        .map((item) => Detection.fromJson(item as Map<String, dynamic>))
        .toList();

    return PredictionResponse(
      success: json['success'] as bool? ?? true,
      status: json['status'] as String? ?? 'recognized',
      imageWidth: json['image_width'] as int? ?? 0,
      imageHeight: json['image_height'] as int? ?? 0,
      detections: detectionsList,
      isPlant: json['is_plant'] as bool? ?? (detectionsList.isNotEmpty),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'status': status,
      'image_width': imageWidth,
      'image_height': imageHeight,
      'detections': detections.map((item) => item.toJson()).toList(),
      'is_plant': isPlant,
      if (message != null) 'message': message,
    };
  }
}
