class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.modelLoaded,
    required this.modelPath,
    this.loadError,
  });

  final String status;
  final bool modelLoaded;
  final String modelPath;
  final String? loadError;

  bool get isReady => status == 'ok' && modelLoaded;

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String,
      modelLoaded: json['model_loaded'] as bool,
      modelPath: json['model_path'] as String,
      loadError: json['load_error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'model_loaded': modelLoaded,
      'model_path': modelPath,
      if (loadError != null) 'load_error': loadError,
    };
  }
}
