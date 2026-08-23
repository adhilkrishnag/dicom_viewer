import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'distance_measurement.dart';
import 'image_coordinate_transform.dart';

/// Custom painter for rendering 2D distance measurement caliper lines,
/// endpoint markers, and measurement distance badges in viewport coordinates.
class DistanceMeasurementPainter extends CustomPainter {
  /// Creates a [DistanceMeasurementPainter].
  const DistanceMeasurementPainter({
    required this.measurement,
    required this.transform,
  });

  /// The active measurement to draw, or null if no measurement exists.
  final DicomDistanceMeasurement? measurement;

  /// The coordinate transform pipeline for mapping image points to viewport space.
  final ImageCoordinateTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    final m = measurement;
    if (m == null) return;

    final startVp = transform.pixelToViewport(
      Offset(m.start.pixelX, m.start.pixelY),
    );
    final endVp = transform.pixelToViewport(Offset(m.end.pixelX, m.end.pixelY));

    if (!m.isValid) {
      _paintInvalidMeasurement(canvas, startVp, endVp, m);
    } else {
      _paintValidMeasurement(canvas, startVp, endVp, m);
    }
  }

  void _paintValidMeasurement(
    Canvas canvas,
    Offset p1,
    Offset p2,
    DicomDistanceMeasurement m,
  ) {
    const mainColor = Colors.yellowAccent;
    const shadowColor = Colors.black87;

    // Line background shadow for high contrast
    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, shadowPaint);

    // Main caliper line
    final linePaint =
        Paint()
          ..color = mainColor
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, linePaint);

    // Endpoint calipers / markers
    _drawEndpointMarker(canvas, p1, mainColor, shadowColor);
    _drawEndpointMarker(canvas, p2, mainColor, shadowColor);

    // Measurement badge
    _drawMeasurementBadge(canvas, p1, p2, m.formattedDistance, mainColor);
  }

  void _paintInvalidMeasurement(
    Canvas canvas,
    Offset p1,
    Offset p2,
    DicomDistanceMeasurement m,
  ) {
    const errorColor = Colors.redAccent;
    const shadowColor = Colors.black87;

    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
    canvas.drawLine(p1, p2, shadowPaint);

    final linePaint =
        Paint()
          ..color = errorColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
    canvas.drawLine(p1, p2, linePaint);

    _drawEndpointMarker(canvas, p1, errorColor, shadowColor);
    _drawEndpointMarker(canvas, p2, errorColor, shadowColor);

    _drawMeasurementBadge(canvas, p1, p2, 'Out of bounds', errorColor);
  }

  void _drawEndpointMarker(
    Canvas canvas,
    Offset center,
    Color color,
    Color shadowColor,
  ) {
    // Outer shadow ring
    final shadowCircle =
        Paint()
          ..color = shadowColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5.0, shadowCircle);

    // Inner marker dot
    final dotPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, dotPaint);

    // Crosshair tick marks
    final tickPaint =
        Paint()
          ..color = shadowColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx - 6, center.dy),
      Offset(center.dx + 6, center.dy),
      tickPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 6),
      Offset(center.dx, center.dy + 6),
      tickPaint,
    );

    final tickForeground =
        Paint()
          ..color = color
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx - 5, center.dy),
      Offset(center.dx + 5, center.dy),
      tickForeground,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 5),
      Offset(center.dx, center.dy + 5),
      tickForeground,
    );
  }

  void _drawMeasurementBadge(
    Canvas canvas,
    Offset p1,
    Offset p2,
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

    final midX = (p1.dx + p2.dx) / 2.0;
    final midY = (p1.dy + p2.dy) / 2.0;

    // Normal vector perpendicular to measurement line
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);

    double offsetX = 0.0;
    double offsetY = -16.0;

    if (len > 1e-4) {
      // Perpendicular unit vector (-dy/len, dx/len) scaled by 16px
      final nx = -dy / len;
      final ny = dx / len;
      offsetX = nx * 16.0;
      offsetY = ny * 16.0;
    }

    final badgeCenter = Offset(midX + offsetX, midY + offsetY);

    const padH = 6.0;
    const padV = 3.0;
    final badgeWidth = textPainter.width + padH * 2;
    final badgeHeight = textPainter.height + padV * 2;

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
  bool shouldRepaint(DistanceMeasurementPainter oldDelegate) {
    return oldDelegate.measurement != measurement ||
        oldDelegate.transform != transform;
  }
}
