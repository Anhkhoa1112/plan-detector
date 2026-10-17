# Flutter Architecture

## Status

Not implemented in this phase.

Flutter SDK availability could not be confirmed in the current terminal session because `flutter --version` did not return promptly and was stopped.

## Target Structure

```text
flutter_app/
└── lib/
    ├── core/
    ├── models/
    ├── services/
    ├── screens/
    ├── widgets/
    ├── providers/
    └── main.dart
```

## Integration Contract

The Flutter app should call FastAPI `POST /predict`, parse the JSON response, and scale `x1, y1, x2, y2` from original image pixels to the rendered image size before drawing bounding boxes.
