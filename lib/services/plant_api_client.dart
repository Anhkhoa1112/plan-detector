import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/health_status.dart';
import '../models/prediction_response.dart';

enum PlantApiErrorCode {
  timeout,
  noConnection,
  fileNotFound,
  fileTooLarge,
  unsupportedFormat,
  badRequest,
  notFound,
  serverError,
  invalidResponse,
  unknown,
}

class PlantApiException implements Exception {
  const PlantApiException(
    this.message, {
    this.statusCode,
    this.errorCode = PlantApiErrorCode.unknown,
  });

  final String message;
  final int? statusCode;
  final PlantApiErrorCode errorCode;

  @override
  String toString() => message;
}

class PlantApiClient {
  PlantApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 45),
  }) : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
       _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  static const int maxFileBytes = 10 * 1024 * 1024; // 10MB limit

  Uri get baseUri => Uri.parse(_baseUrl);
  String get baseUrl => _baseUrl;

  Future<HealthStatus> getHealth() async {
    final uri = baseUri.resolve('/health');
    final response = await _sendWithTimeout(() => _httpClient.get(uri));
    _ensureSuccess(response);
    return HealthStatus.fromJson(_decodeJsonObject(response.body));
  }

  Future<PredictionResponse> predictImage(
    File imageFile, {
    double confidence = 0.25,
    double iou = 0.45,
  }) async {
    if (!await imageFile.exists()) {
      throw const PlantApiException(
        'Tệp ảnh không tồn tại trên thiết bị.',
        errorCode: PlantApiErrorCode.fileNotFound,
      );
    }

    final fileSize = await imageFile.length();
    if (fileSize == 0) {
      throw const PlantApiException(
        'Tệp ảnh rỗng (0 bytes). Vui lòng chọn ảnh khác.',
        statusCode: 400,
        errorCode: PlantApiErrorCode.badRequest,
      );
    }
    if (fileSize > maxFileBytes) {
      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      throw PlantApiException(
        'Dung lượng ảnh quá lớn ($sizeMb MB). Giới hạn tối đa là 10 MB.',
        statusCode: 400,
        errorCode: PlantApiErrorCode.fileTooLarge,
      );
    }

    final contentType = _imageContentType(imageFile.path);
    final uri = baseUri.replace(
      path: '/predict',
      queryParameters: {
        'confidence': confidence.toString(),
        'iou': iou.toString(),
      },
    );

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: contentType,
        ),
      );

    final response = await _sendWithTimeout(() {
      return _httpClient.send(request).then(http.Response.fromStream);
    });

    _ensureSuccess(response);
    return PredictionResponse.fromJson(_decodeJsonObject(response.body));
  }

  Future<http.Response> _sendWithTimeout(
    Future<http.Response> Function() send,
  ) async {
    try {
      return await send().timeout(timeout);
    } on TimeoutException {
      throw const PlantApiException(
        'Quá thời gian chờ phản hồi từ máy chủ (Timeout). Vui lòng kiểm tra lại kết nối mạng LAN.',
        errorCode: PlantApiErrorCode.timeout,
      );
    } on SocketException {
      throw PlantApiException(
        'Không thể kết nối đến máy chủ backend ($_baseUrl). Vui lòng kiểm tra địa chỉ IP và đảm bảo backend đang chạy.',
        errorCode: PlantApiErrorCode.noConnection,
      );
    } on FormatException catch (error) {
      throw PlantApiException(
        'Dữ liệu phản hồi từ máy chủ không hợp lệ: ${error.message}',
        errorCode: PlantApiErrorCode.invalidResponse,
      );
    } on http.ClientException catch (error) {
      throw PlantApiException(
        'Lỗi kết nối HTTP: ${error.message}',
        errorCode: PlantApiErrorCode.noConnection,
      );
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String detail = '';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] != null) {
        detail = body['detail'].toString();
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        detail = response.body;
      }
    }

    PlantApiErrorCode code = PlantApiErrorCode.unknown;
    String userMessage = '';

    if (response.statusCode == 400) {
      code = PlantApiErrorCode.badRequest;
      userMessage = detail.isNotEmpty
          ? 'Ảnh không hợp lệ: $detail'
          : 'Dữ liệu gửi lên không hợp lệ (HTTP 400).';
    } else if (response.statusCode == 404) {
      code = PlantApiErrorCode.notFound;
      userMessage = 'Không tìm thấy API endpoint trên máy chủ (HTTP 404).';
    } else if (response.statusCode == 503) {
      code = PlantApiErrorCode.serverError;
      userMessage = detail.isNotEmpty
          ? 'Dịch vụ AI chưa sẵn sàng: $detail'
          : 'Mô hình AI chưa sẵn sàng (HTTP 503).';
    } else if (response.statusCode >= 500) {
      code = PlantApiErrorCode.serverError;
      userMessage = detail.isNotEmpty
          ? 'Lỗi máy chủ: $detail'
          : 'Lỗi máy chủ backend (HTTP ${response.statusCode}).';
    } else {
      userMessage = detail.isNotEmpty
          ? 'Lỗi HTTP ${response.statusCode}: $detail'
          : 'Lỗi HTTP ${response.statusCode}';
    }

    throw PlantApiException(
      userMessage,
      statusCode: response.statusCode,
      errorCode: code,
    );
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  void close() {
    _httpClient.close();
  }

  MediaType _imageContentType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    return MediaType('image', 'jpeg');
  }
}
