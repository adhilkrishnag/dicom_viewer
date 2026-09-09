import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../parsing/dicom_dataset.dart';
import '../parsing/tag.dart';
import '../windowing/palette_color_lut.dart';
import '../windowing/photometric.dart';
import 'image_coordinate_transform.dart';

/// Immutable result of a pixel probe at a discrete pixel coordinate.
///
/// Internal to `dicom_viewer`.
class DicomProbeResult {
  /// Creates a [DicomProbeResult] instance.
  const DicomProbeResult({
    required this.pixelColumn,
    required this.pixelRow,
    required this.isInside,
    this.storedValue,
    this.rescaledValue,
    this.unit = '',
    this.isHounsfield = false,
    this.rgb,
    this.paletteIndex,
    this.isPadding = false,
  });

  /// Evaluates probe results for discrete coordinate ([pixelColumn], [pixelRow])
  /// on [dataset] using decoded [rawPixels].
  factory DicomProbeResult.evaluate({
    required DicomDataset dataset,
    required int pixelColumn,
    required int pixelRow,
    required List<int> rawPixels,
  }) {
    final columns = dataset.columns;
    final rows = dataset.rows;

    if (pixelColumn < 0 ||
        pixelColumn >= columns ||
        pixelRow < 0 ||
        pixelRow >= rows ||
        columns <= 0 ||
        rows <= 0) {
      return DicomProbeResult(
        pixelColumn: pixelColumn,
        pixelRow: pixelRow,
        isInside: false,
      );
    }

    final photo = PhotometricInterpretationX.parse(
      dataset.photometricInterpretation,
    );

    // RGB 3-sample handling
    if (dataset.samplesPerPixel == 3 &&
        photo == PhotometricInterpretation.rgb) {
      final p = pixelRow * columns + pixelColumn;
      final rIdx = p * 3;
      if (rIdx + 2 < rawPixels.length) {
        final r = rawPixels[rIdx];
        final g = rawPixels[rIdx + 1];
        final b = rawPixels[rIdx + 2];
        return DicomProbeResult(
          pixelColumn: pixelColumn,
          pixelRow: pixelRow,
          isInside: true,
          rgb: [r, g, b],
        );
      }
    }

    // YBR 3-sample handling (YBR_FULL, YBR_FULL_422)
    // Stored samples are [Y, Cb, Cr]; converts to display [R, G, B] per DICOM PS3.3 C.7.6.3.1.2
    if (dataset.samplesPerPixel == 3 &&
        photo == PhotometricInterpretation.ybrFull) {
      final p = pixelRow * columns + pixelColumn;
      final yIdx = p * 3;
      if (yIdx + 2 < rawPixels.length) {
        final double y = rawPixels[yIdx].toDouble();
        final double cb = rawPixels[yIdx + 1].toDouble() - 128.0;
        final double cr = rawPixels[yIdx + 2].toDouble() - 128.0;

        final int r = (y + 1.402 * cr).round().clamp(0, 255);
        final int g = (y - 0.344136 * cb - 0.714136 * cr).round().clamp(0, 255);
        final int b = (y + 1.772 * cb).round().clamp(0, 255);

        return DicomProbeResult(
          pixelColumn: pixelColumn,
          pixelRow: pixelRow,
          isInside: true,
          rgb: [r, g, b],
        );
      }
    }

    // YBR_PARTIAL_422: CCIR 601-2 (BT.601) limited-range probe.
    // Stored samples are [Y, Cb, Cr] (interleaved, post-decode).
    if (dataset.samplesPerPixel == 3 &&
        photo == PhotometricInterpretation.ybrPartial422) {
      final p = pixelRow * columns + pixelColumn;
      final yIdx = p * 3;
      if (yIdx + 2 < rawPixels.length) {
        final double yShifted = rawPixels[yIdx].toDouble() - 16.0;
        final double cb = rawPixels[yIdx + 1].toDouble() - 128.0;
        final double cr = rawPixels[yIdx + 2].toDouble() - 128.0;

        final int r = (1.1644 * yShifted + 1.5960 * cr).round().clamp(0, 255);
        final int g = (1.1644 * yShifted - 0.3918 * cb - 0.8130 * cr)
            .round()
            .clamp(0, 255);
        final int b = (1.1644 * yShifted + 2.0172 * cb).round().clamp(0, 255);

        return DicomProbeResult(
          pixelColumn: pixelColumn,
          pixelRow: pixelRow,
          isInside: true,
          rgb: [r, g, b],
        );
      }
    }

    final idx = pixelRow * columns + pixelColumn;
    if (idx >= rawPixels.length) {
      return DicomProbeResult(
        pixelColumn: pixelColumn,
        pixelRow: pixelRow,
        isInside: false,
      );
    }

    final stored = rawPixels[idx];

    // Palette Color LUT handling
    if (photo == PhotometricInterpretation.paletteColor) {
      try {
        final lut = PaletteColorLut.fromDataset(dataset);
        var lutIdx = stored - lut.firstMappedValue;
        if (lutIdx < 0) {
          lutIdx = 0;
        } else if (lutIdx >= lut.numberOfEntries) {
          lutIdx = lut.numberOfEntries - 1;
        }
        final r = lut.redLut[lutIdx];
        final g = lut.greenLut[lutIdx];
        final b = lut.blueLut[lutIdx];
        return DicomProbeResult(
          pixelColumn: pixelColumn,
          pixelRow: pixelRow,
          isInside: true,
          storedValue: stored,
          paletteIndex: stored,
          rgb: [r, g, b],
        );
      } catch (_) {
        // Fallback to scalar stored value if LUT is segmented/unsupported
      }
    }

    // Exact Task 8 Rescale & HU Eligibility Evaluation
    final slopeElem = dataset.getElement(DicomTag.rescaleSlope);
    final interceptElem = dataset.getElement(DicomTag.rescaleIntercept);
    final explicitSlope = slopeElem?.asDouble;
    final explicitIntercept = interceptElem?.asDouble;

    final hasExplicitSlope =
        explicitSlope != null && explicitSlope.isFinite && explicitSlope > 0.0;
    final hasExplicitIntercept =
        explicitIntercept != null && explicitIntercept.isFinite;
    final isExplicitRescaleValid = hasExplicitSlope && hasExplicitIntercept;

    final isMonochrome = photo.isMonochrome;
    final isCT = dataset.modality.toUpperCase() == 'CT';
    final isHounsfield =
        isCT &&
        isMonochrome &&
        isExplicitRescaleValid &&
        dataset.samplesPerPixel == 1;

    final unit = isHounsfield ? 'HU' : '';
    final double slope = hasExplicitSlope ? explicitSlope : 1.0;
    final double intercept = hasExplicitIntercept ? explicitIntercept : 0.0;

    final rescaled = stored * slope + intercept;

    // Pixel Padding Evaluation in stored space
    final padVal = dataset.pixelPaddingValue;
    final padLimit = dataset.pixelPaddingRangeLimit;
    final hasPadding = padVal != null;
    final padMin =
        hasPadding
            ? (padLimit != null ? math.min(padVal, padLimit) : padVal)
            : null;
    final padMax =
        hasPadding
            ? (padLimit != null ? math.max(padVal, padLimit) : padVal)
            : null;
    final isPadding = hasPadding && stored >= padMin! && stored <= padMax!;

    return DicomProbeResult(
      pixelColumn: pixelColumn,
      pixelRow: pixelRow,
      isInside: true,
      storedValue: stored,
      rescaledValue: hasExplicitSlope || hasExplicitIntercept ? rescaled : null,
      unit: unit,
      isHounsfield: isHounsfield,
      isPadding: isPadding,
    );
  }

  /// Discrete pixel column index ($0 \le c < \text{columns}$).
  final int pixelColumn;

  /// Discrete pixel row index ($0 \le r < \text{rows}$).
  final int pixelRow;

  /// Whether the probe point is within the valid image matrix bounds.
  final bool isInside;

  /// Raw stored pixel value from DICOM pixel data.
  final int? storedValue;

  /// Modality-rescaled real-world value ($stored \times slope + intercept$), or null if no rescale.
  final double? rescaledValue;

  /// Unit string (`'HU'` for verified CT, empty for others).
  final String unit;

  /// Whether the value represents a verified Hounsfield Unit.
  final bool isHounsfield;

  /// RGB channel values `[R, G, B]` (0..255) for RGB or Palette Color datasets.
  final List<int>? rgb;

  /// Palette LUT scalar index for PALETTE COLOR datasets.
  final int? paletteIndex;

  /// Whether the stored pixel falls within the DICOM Pixel Padding range.
  final bool isPadding;

  /// Formatted lines to display in the probe HUD badge.
  List<String> get formattedLines {
    if (!isInside) return const [];

    final lines = <String>['Pixel: ($pixelColumn, $pixelRow)'];

    if (rgb != null) {
      if (paletteIndex != null) {
        lines.add('Index: $paletteIndex');
      }
      lines.add('RGB: (${rgb![0]}, ${rgb![1]}, ${rgb![2]})');
      return lines;
    }

    final padSuffix = isPadding ? ' (Padding)' : '';

    if (isHounsfield) {
      lines.add('Stored: $storedValue$padSuffix');
      final huStr = rescaledValue!.toStringAsFixed(1);
      lines.add('HU: $huStr HU');
    } else if (rescaledValue != null) {
      lines.add('Stored: $storedValue$padSuffix');
      lines.add('Value: ${rescaledValue!.toStringAsFixed(1)}');
    } else if (storedValue != null) {
      lines.add('Value: $storedValue$padSuffix');
    }

    return lines;
  }

  /// Accessibility-friendly label for screen readers.
  String get semanticsLabel {
    if (!isInside) return 'Pointer outside image';

    final buffer = StringBuffer('Pixel column $pixelColumn, row $pixelRow. ');
    if (rgb != null) {
      if (paletteIndex != null) {
        buffer.write('Palette index $paletteIndex. ');
      }
      buffer.write('Red ${rgb![0]}, Green ${rgb![1]}, Blue ${rgb![2]}.');
      return buffer.toString();
    }

    final padNotice = isPadding ? ', pixel is padding' : '';

    if (isHounsfield) {
      buffer.write(
        'Stored value $storedValue$padNotice. ${rescaledValue!.toStringAsFixed(1)} Hounsfield Units.',
      );
    } else if (rescaledValue != null) {
      buffer.write(
        'Stored value $storedValue$padNotice. Rescaled value ${rescaledValue!.toStringAsFixed(1)}.',
      );
    } else if (storedValue != null) {
      buffer.write('Value $storedValue$padNotice.');
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomProbeResult &&
          runtimeType == other.runtimeType &&
          pixelColumn == other.pixelColumn &&
          pixelRow == other.pixelRow &&
          isInside == other.isInside &&
          storedValue == other.storedValue &&
          rescaledValue == other.rescaledValue &&
          unit == other.unit &&
          isHounsfield == other.isHounsfield &&
          isPadding == other.isPadding &&
          paletteIndex == other.paletteIndex;

  @override
  int get hashCode =>
      pixelColumn.hashCode ^
      pixelRow.hashCode ^
      isInside.hashCode ^
      storedValue.hashCode ^
      rescaledValue.hashCode ^
      unit.hashCode ^
      isHounsfield.hashCode ^
      isPadding.hashCode ^
      paletteIndex.hashCode;

  @override
  String toString() =>
      'DicomProbeResult(col: $pixelColumn, row: $pixelRow, inside: $isInside, stored: $storedValue, hu: $isHounsfield)';
}

/// Custom painter for rendering the pixel probe HUD and cursor reticle in viewport coordinates.
///
/// Internal to `dicom_viewer`.
class ProbeOverlayPainter extends CustomPainter {
  /// Creates a [ProbeOverlayPainter].
  const ProbeOverlayPainter({
    required this.probeResult,
    required this.viewportPosition,
    required this.transform,
  });

  /// The active probe result, or null if no probe is active.
  final DicomProbeResult? probeResult;

  /// Viewport position of the cursor.
  final Offset? viewportPosition;

  /// Coordinate transform pipeline.
  final ImageCoordinateTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    final result = probeResult;
    final vp = viewportPosition;
    if (result == null || vp == null || !result.isInside) return;

    // 1. Draw subtle pixel highlight & reticle crosshair at cursor
    _drawReticle(canvas, vp, result);

    // 2. Draw HUD badge adjacent to cursor
    _drawProbeBadge(canvas, size, vp, result);
  }

  void _drawReticle(Canvas canvas, Offset vp, DicomProbeResult result) {
    const reticleColor = Colors.cyanAccent;
    const shadowColor = Colors.black87;

    // Crosshair shadow
    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(vp.dx - 8, vp.dy),
      Offset(vp.dx + 8, vp.dy),
      shadowPaint,
    );
    canvas.drawLine(
      Offset(vp.dx, vp.dy - 8),
      Offset(vp.dx, vp.dy + 8),
      shadowPaint,
    );

    // Crosshair foreground
    final linePaint =
        Paint()
          ..color = reticleColor
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(vp.dx - 7, vp.dy),
      Offset(vp.dx + 7, vp.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(vp.dx, vp.dy - 7),
      Offset(vp.dx, vp.dy + 7),
      linePaint,
    );

    // Center dot
    final dotPaint =
        Paint()
          ..color = reticleColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(vp, 2.0, dotPaint);
  }

  void _drawProbeBadge(
    Canvas canvas,
    Size size,
    Offset vp,
    DicomProbeResult result,
  ) {
    final lines = result.formattedLines;
    if (lines.isEmpty) return;

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontFamily: 'monospace',
      height: 1.35,
    );

    const highlightStyle = TextStyle(
      color: Colors.cyanAccent,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
      height: 1.35,
    );

    // Build text spans with semantic coloring
    final spans = <TextSpan>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLast = i == lines.length - 1;
      final isHighlight = line.startsWith('HU:') || line.startsWith('RGB:');

      spans.add(
        TextSpan(
          text: isLast ? line : '$line\n',
          style: isHighlight ? highlightStyle : textStyle,
        ),
      );
    }

    final textPainter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 8.0;
    const paddingV = 6.0;
    final badgeWidth = textPainter.width + paddingH * 2;
    final badgeHeight = textPainter.height + paddingV * 2;

    // Calculate badge position: default top-right offset from cursor
    double badgeLeft = vp.dx + 16.0;
    double badgeTop = vp.dy - badgeHeight - 8.0;

    // Boundary clamping against viewport edges
    if (badgeTop < 8.0) {
      // Flip below cursor
      badgeTop = vp.dy + 20.0;
    }
    if (badgeLeft + badgeWidth > size.width - 8.0) {
      // Flip left of cursor
      badgeLeft = vp.dx - badgeWidth - 16.0;
    }

    // Clamp inside viewport
    badgeLeft = badgeLeft.clamp(
      8.0,
      math.max(8.0, size.width - badgeWidth - 8.0),
    );
    badgeTop = badgeTop.clamp(
      8.0,
      math.max(8.0, size.height - badgeHeight - 8.0),
    );

    final badgeRect = Rect.fromLTWH(
      badgeLeft,
      badgeTop,
      badgeWidth,
      badgeHeight,
    );
    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(5));

    // Shadow
    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(rrect.shift(const Offset(1, 2)), shadowPaint);

    // Background
    final bgPaint =
        Paint()
          ..color = const Color(0xEE111822)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Border
    final borderPaint =
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // Paint text inside badge
    textPainter.paint(
      canvas,
      Offset(badgeLeft + paddingH, badgeTop + paddingV),
    );
  }

  @override
  bool shouldRepaint(covariant ProbeOverlayPainter oldDelegate) {
    return oldDelegate.probeResult != probeResult ||
        oldDelegate.viewportPosition != viewportPosition ||
        oldDelegate.transform != transform;
  }
}
