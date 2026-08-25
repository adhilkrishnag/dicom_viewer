import 'package:flutter/material.dart';
import 'image_coordinate_transform.dart';
import 'rectangle_roi_measurement.dart';

/// Custom painter for rendering a rectangular ROI overlay in viewport coordinates.
///
/// Follows the visual conventions established by [DistanceMeasurementPainter]:
/// - Yellow accent for valid state, red accent for invalid state
/// - Shadow + foreground stroke for high contrast
/// - Corner markers at each normalized rectangle corner
/// - Measurement badge with W/H/A dimensions
class RectangleRoiPainter extends CustomPainter {
  /// Creates a [RectangleRoiPainter].
  const RectangleRoiPainter({
    required this.measurement,
    required this.transform,
  });

  /// The active ROI measurement to draw, or null if no ROI exists.
  final DicomRectangleRoiMeasurement? measurement;

  /// The coordinate transform pipeline for mapping image points to viewport space.
  final ImageCoordinateTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    final m = measurement;
    if (m == null) return;

    // Convert normalized rectangle corners from pixel space to viewport space
    final topLeftVp = transform.pixelToViewport(
      Offset(m.normalizedRect.left, m.normalizedRect.top),
    );
    final topRightVp = transform.pixelToViewport(
      Offset(m.normalizedRect.right, m.normalizedRect.top),
    );
    final bottomLeftVp = transform.pixelToViewport(
      Offset(m.normalizedRect.left, m.normalizedRect.bottom),
    );
    final bottomRightVp = transform.pixelToViewport(
      Offset(m.normalizedRect.right, m.normalizedRect.bottom),
    );

    final vpRect = Rect.fromLTRB(
      topLeftVp.dx,
      topLeftVp.dy,
      bottomRightVp.dx,
      bottomRightVp.dy,
    );

    if (!m.isValid) {
      _paintInvalidRoi(
        canvas,
        vpRect,
        topLeftVp,
        topRightVp,
        bottomLeftVp,
        bottomRightVp,
        m,
      );
    } else {
      _paintValidRoi(
        canvas,
        vpRect,
        topLeftVp,
        topRightVp,
        bottomLeftVp,
        bottomRightVp,
        m,
      );
    }
  }

  void _paintValidRoi(
    Canvas canvas,
    Rect vpRect,
    Offset topLeft,
    Offset topRight,
    Offset bottomLeft,
    Offset bottomRight,
    DicomRectangleRoiMeasurement m,
  ) {
    const mainColor = Colors.yellowAccent;
    const shadowColor = Colors.black87;

    // Rectangle shadow outline
    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.miter;
    canvas.drawRect(vpRect, shadowPaint);

    // Main rectangle outline
    final linePaint =
        Paint()
          ..color = mainColor
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.miter;
    canvas.drawRect(vpRect, linePaint);

    // Semi-transparent fill
    final fillPaint =
        Paint()
          ..color = mainColor.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
    canvas.drawRect(vpRect, fillPaint);

    // Corner markers
    _drawCornerMarker(canvas, topLeft, mainColor, shadowColor);
    _drawCornerMarker(canvas, topRight, mainColor, shadowColor);
    _drawCornerMarker(canvas, bottomLeft, mainColor, shadowColor);
    _drawCornerMarker(canvas, bottomRight, mainColor, shadowColor);

    // Measurement badge
    _drawMeasurementBadge(canvas, vpRect, m.formattedDimensions, mainColor);
  }

  void _paintInvalidRoi(
    Canvas canvas,
    Rect vpRect,
    Offset topLeft,
    Offset topRight,
    Offset bottomLeft,
    Offset bottomRight,
    DicomRectangleRoiMeasurement m,
  ) {
    const errorColor = Colors.redAccent;
    const shadowColor = Colors.black87;

    // Rectangle shadow outline
    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
    canvas.drawRect(vpRect, shadowPaint);

    // Main rectangle outline
    final linePaint =
        Paint()
          ..color = errorColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
    canvas.drawRect(vpRect, linePaint);

    // Semi-transparent error fill
    final fillPaint =
        Paint()
          ..color = errorColor.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
    canvas.drawRect(vpRect, fillPaint);

    // Corner markers
    _drawCornerMarker(canvas, topLeft, errorColor, shadowColor);
    _drawCornerMarker(canvas, topRight, errorColor, shadowColor);
    _drawCornerMarker(canvas, bottomLeft, errorColor, shadowColor);
    _drawCornerMarker(canvas, bottomRight, errorColor, shadowColor);

    // Error badge
    _drawMeasurementBadge(canvas, vpRect, 'Out of bounds', errorColor);
  }

  void _drawCornerMarker(
    Canvas canvas,
    Offset center,
    Color color,
    Color shadowColor,
  ) {
    // Outer shadow dot
    final shadowCircle =
        Paint()
          ..color = shadowColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, shadowCircle);

    // Inner marker dot
    final dotPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, dotPaint);
  }

  void _drawMeasurementBadge(
    Canvas canvas,
    Rect vpRect,
    String text,
    Color accentColor,
  ) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 6.0;
    const padV = 3.0;
    final badgeWidth = textPainter.width + padH * 2;
    final badgeHeight = textPainter.height + padV * 2;

    // Position badge below the rectangle, centered horizontally
    final badgeCenterX = vpRect.center.dx;
    final badgeCenterY = vpRect.bottom + 12.0 + badgeHeight / 2.0;
    final badgeCenter = Offset(badgeCenterX, badgeCenterY);

    final badgeRect = Rect.fromCenter(
      center: badgeCenter,
      width: badgeWidth,
      height: badgeHeight,
    );
    final badgeRRect = RRect.fromRectAndRadius(
      badgeRect,
      const Radius.circular(4.0),
    );

    // Badge background
    final bgPaint =
        Paint()
          ..color = const Color(0xE6101010)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(badgeRRect, bgPaint);

    // Badge border
    final borderPaint =
        Paint()
          ..color = accentColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
    canvas.drawRRect(badgeRRect, borderPaint);

    // Draw text
    textPainter.paint(
      canvas,
      Offset(badgeRect.left + padH, badgeRect.top + padV),
    );
  }

  @override
  bool shouldRepaint(RectangleRoiPainter oldDelegate) {
    return oldDelegate.measurement != measurement ||
        oldDelegate.transform != transform;
  }
}
