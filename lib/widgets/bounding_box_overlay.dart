import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/detection.dart';

class BoundingBoxOverlay extends StatelessWidget {
  const BoundingBoxOverlay({
    super.key,
    required this.imageFile,
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    this.selectedIndex,
    this.onSelectDetection,
    this.maxHeight = 360,
  });

  final File imageFile;
  final int imageWidth;
  final int imageHeight;
  final List<Detection> detections;
  final int? selectedIndex;
  final ValueChanged<int>? onSelectDetection;
  final double maxHeight;

  static const List<Color> detectionColors = [
    Color(0xFF35E88A), // Emerald
    Color(0xFFFFCA5C), // Warning Gold
    Color(0xFF6C8CFF), // AI Blue
    Color(0xFFFF647C), // Coral Pink
    Color(0xFF9B7CFF), // AI Purple
    Color(0xFF00E5FF), // Cyan
    Color(0xFFFF9100), // Amber
    Color(0xFFAEEA00), // Lime
  ];

  static Color getColorForIndex(int index) {
    return detectionColors[index % detectionColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final aspect = (imageWidth > 0 && imageHeight > 0)
            ? (imageWidth / imageHeight)
            : 1.0;

        double renderWidth = availableWidth;
        double renderHeight = renderWidth / aspect;

        if (renderHeight > maxHeight) {
          renderHeight = maxHeight;
          renderWidth = renderHeight * aspect;
        }

        final renderedSize = Size(renderWidth, renderHeight);

        return Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: SizedBox(
                width: renderedSize.width,
                height: renderedSize.height,
                child: GestureDetector(
                  onTapUp: (details) {
                    if (onSelectDetection == null || detections.isEmpty) return;
                    _handleTap(details.localPosition, renderedSize);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        imageFile,
                        width: renderedSize.width,
                        height: renderedSize.height,
                        fit: BoxFit.fill,
                      ),
                      CustomPaint(
                        size: renderedSize,
                        painter: _BoundingBoxPainter(
                          imageWidth: imageWidth.toDouble(),
                          imageHeight: imageHeight.toDouble(),
                          detections: detections,
                          selectedIndex: selectedIndex,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset tapPosition, Size renderedSize) {
    if (imageWidth <= 0 || imageHeight <= 0) return;
    final scaleX = renderedSize.width / imageWidth;
    final scaleY = renderedSize.height / imageHeight;

    for (int i = detections.length - 1; i >= 0; i--) {
      final det = detections[i];
      final rect = Rect.fromLTRB(
        det.bbox.x1 * scaleX,
        det.bbox.y1 * scaleY,
        det.bbox.x2 * scaleX,
        det.bbox.y2 * scaleY,
      );
      if (rect.inflate(8).contains(tapPosition)) {
        onSelectDetection?.call(i);
        return;
      }
    }
  }
}

class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    this.selectedIndex,
  });

  final double imageWidth;
  final double imageHeight;
  final List<Detection> detections;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      final isSelected = selectedIndex == i;
      final color = BoundingBoxOverlay.getColorForIndex(i);

      final left = (det.bbox.x1 * scaleX).clamp(0.0, size.width);
      final top = (det.bbox.y1 * scaleY).clamp(0.0, size.height);
      final right = (det.bbox.x2 * scaleX).clamp(0.0, size.width);
      final bottom = (det.bbox.y2 * scaleY).clamp(0.0, size.height);

      final rect = Rect.fromLTRB(left, top, right, bottom);

      final fillPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.30 : 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      if (isSelected) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 5.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
          ..style = PaintingStyle.stroke;
        canvas.drawRect(rect, glowPaint);
      }

      final strokePaint = Paint()
        ..color = color
        ..strokeWidth = isSelected ? 2.8 : 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawRect(rect, strokePaint);

      _drawCornerAccents(canvas, rect, color, isSelected ? 3.6 : 2.6);
      _drawLabelBadge(canvas, rect, size, i + 1, det, color, isSelected);
    }
  }

  void _drawCornerAccents(
    Canvas canvas,
    Rect rect,
    Color color,
    double strokeWidth,
  ) {
    final cornerLength = math.min(18.0, math.min(rect.width, rect.height) / 3);
    if (cornerLength <= 0) return;

    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, cornerLength), cornerPaint);

    canvas.drawLine(rect.topRight, rect.topRight - Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, cornerLength), cornerPaint);

    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, cornerLength), cornerPaint);

    canvas.drawLine(rect.bottomRight, rect.bottomRight - Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - Offset(0, cornerLength), cornerPaint);
  }

  void _drawLabelBadge(
    Canvas canvas,
    Rect rect,
    Size size,
    int index,
    Detection det,
    Color color,
    bool isSelected,
  ) {
    final labelText = det.displayName;
    final textSpan = TextSpan(
      text: labelText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const hPadding = 8.0;
    const vPadding = 4.0;
    final badgeWidth = textPainter.width + (hPadding * 2);
    final badgeHeight = textPainter.height + (vPadding * 2);

    double badgeLeft = rect.left;
    if (badgeLeft + badgeWidth > size.width) {
      badgeLeft = math.max(0.0, size.width - badgeWidth);
    }

    double badgeTop = rect.top - badgeHeight - 4;
    if (badgeTop < 0) {
      badgeTop = rect.top + 4;
    }

    final badgeRect = Rect.fromLTWH(badgeLeft, badgeTop, badgeWidth, badgeHeight);
    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(6));

    final bgPaint = Paint()
      ..color = const Color(0xFF050706).withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = isSelected ? 1.6 : 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(badgeLeft + hPadding, badgeTop + vPadding),
    );
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.detections != detections ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
