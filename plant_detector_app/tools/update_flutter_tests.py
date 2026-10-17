def update_test():
    path = "D:/plant_detector_app/test/models_test.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if "parses uncertain status" in content:
        print("models_test.dart already has status tests.")
        return

    additional_tests = """
    test('parses uncertain status and getters correctly', () {
      final response = PredictionResponse.fromJson({
        'success': true,
        'status': 'uncertain',
        'image_width': 800,
        'image_height': 600,
        'message': 'Độ tự tin chưa đủ cao',
        'is_plant': true,
        'detections': [
          {
            'class_id': 4,
            'class_name': 'Coconut-tree',
            'name_vi': 'Cây dừa',
            'confidence': 0.32,
            'bbox': {'x1': 5, 'y1': 10, 'x2': 50, 'y2': 100},
          }
        ],
      });
      expect(response.status, equals('uncertain'));
      expect(response.isUncertain, isTrue);
      expect(response.isRecognized, isFalse);
      expect(response.isUnknown, isFalse);
      expect(response.message, contains('Độ tự tin'));
      expect(response.hasDetections, isTrue);
    });

    test('parses unknown status for non-plant rejection', () {
      final response = PredictionResponse.fromJson({
        'success': true,
        'status': 'unknown',
        'image_width': 800,
        'image_height': 600,
        'message': 'Ảnh không phải là cây',
        'is_plant': false,
        'detections': <Object?>[],
      });
      expect(response.status, equals('unknown'));
      expect(response.isUnknown, isTrue);
      expect(response.isPlant, isFalse);
      expect(response.hasDetections, isFalse);
    });
"""
    # Insert right before the last closing brace
    last_brace_idx = content.rfind("}")
    if last_brace_idx != -1:
        new_content = content[:last_brace_idx] + additional_tests + content[last_brace_idx:]
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("Updated models_test.dart successfully.")
    else:
        print("Could not find closing brace.")

if __name__ == "__main__":
    update_test()
