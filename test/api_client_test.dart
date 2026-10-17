import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plant_detector_app/models/prediction_response.dart';
import 'package:plant_detector_app/services/plant_api_client.dart';

void main() {
  test('parses prediction response with detections', () {
    final response = PredictionResponse.fromJson({
      'success': true,
      'image_width': 1200,
      'image_height': 896,
      'detections': [
        {
          'class_id': 10,
          'class_name': 'lemon tree',
          'name_vi': 'Cây Chanh',
          'confidence': 0.326685,
          'bbox': {'x1': 532.01, 'y1': 22.69, 'x2': 1200.0, 'y2': 849.46},
        },
      ],
    });

    expect(response.success, isTrue);
    expect(response.detections, hasLength(1));
    expect(response.detections.first.className, 'lemon tree');
    expect(response.detections.first.nameVi, 'Cây Chanh');
    expect(response.detections.first.bbox.x2, 1200.0);
  });

  test('health request parses backend status', () async {
    final client = PlantApiClient(
      baseUrl: 'http://192.168.100.245:8000',
      httpClient: _FakeClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/health');
        return _jsonResponse({
          'status': 'ok',
          'model_loaded': true,
          'model_path': 'models/production/best.pt',
          'load_error': null,
        });
      }),
    );

    final health = await client.getHealth();

    expect(health.isReady, isTrue);
    expect(health.modelLoaded, isTrue);
  });

  test('image upload uses multipart image field and parses response', () async {
    final imageFile = await _createTempImage();
    final client = PlantApiClient(
      baseUrl: 'http://192.168.100.245:8000',
      httpClient: _FakeClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/predict');
        expect(request.url.queryParameters['confidence'], '0.25');
        expect(request.url.queryParameters['iou'], '0.45');
        expect(request, isA<http.MultipartRequest>());
        final multipart = request as http.MultipartRequest;
        expect(multipart.files.single.field, 'image');
        expect(multipart.files.single.contentType.mimeType, 'image/jpeg');
        return _jsonResponse({
          'success': true,
          'image_width': 10,
          'image_height': 10,
          'detections': <Object?>[],
        });
      }),
    );

    final prediction = await client.predictImage(imageFile);

    expect(prediction.success, isTrue);
    expect(prediction.detections, isEmpty);
  });

  test('throws useful API exception on HTTP errors', () async {
    final client = PlantApiClient(
      baseUrl: 'http://192.168.100.245:8000',
      httpClient: _FakeClient((request) async {
        return _jsonResponse({
          'detail': 'Image file is invalid',
        }, statusCode: 400);
      }),
    );

    expect(
      client.getHealth,
      throwsA(
        isA<PlantApiException>().having(
          (error) => error.message,
          'message',
          contains('Image file is invalid'),
        ),
      ),
    );
  });

  test('throws PlantApiException with 404 message', () async {
    final client = PlantApiClient(
      baseUrl: 'http://192.168.100.245:8000',
      httpClient: _FakeClient((request) async {
        return _jsonResponse({
          'detail': 'Not Found',
        }, statusCode: 404);
      }),
    );

    expect(
      client.getHealth,
      throwsA(
        isA<PlantApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          equals(404),
        ),
      ),
    );
  });

  test('throws PlantApiException with 500 server error', () async {
    final client = PlantApiClient(
      baseUrl: 'http://192.168.100.245:8000',
      httpClient: _FakeClient((request) async {
        return _jsonResponse({
          'detail': 'Internal Server Error',
        }, statusCode: 500);
      }),
    );

    expect(
      client.getHealth,
      throwsA(
        isA<PlantApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          equals(500),
        ),
      ),
    );
  });

  test('validates non-existent image file before sending', () async {
    final client = PlantApiClient(baseUrl: 'http://192.168.100.245:8000');
    final missingFile = File('D:/non_existent_image_12345.jpg');

    expect(
      () => client.predictImage(missingFile),
      throwsA(
        isA<PlantApiException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals(PlantApiErrorCode.fileNotFound),
        ),
      ),
    );
  });
}

Future<File> _createTempImage({int byteCount = 4}) async {
  final dir = await Directory.systemTemp.createTemp('plant_api_client_test_');
  final file = File('${dir.path}/image.jpg');
  final bytes = List<int>.filled(byteCount, 0xFF);
  return file.writeAsBytes(bytes);
}

http.StreamedResponse _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(Stream.value(bytes), statusCode);
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}
