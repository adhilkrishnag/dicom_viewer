import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'dicom_image_geometry.dart';
import 'dicom_roi_statistics_engine.dart';
import 'image_coordinate_transform.dart';

/// Represents a completed or in-progress rectangular Region of Interest (ROI)
/// measurement on a single DICOM image frame.
///
/// ## Coordinate Model
///
/// Both corners originate from [ImageCoordinateTransform.viewportToImage],
/// producing continuous native pixel coordinates in `[0, columns] × [0, rows]`.
///
/// ## Rectangle Normalization
///
/// Given raw corners `(x1, y1)` and `(x2, y2)`:
/// ```
/// left   = min(x1, x2)
/// right  = max(x1, x2)
/// top    = min(y1, y2)
/// bottom = max(y1, y2)
/// ```
///
/// This ensures consistent geometry regardless of drag direction.
///
/// ## Physical Dimensions
///
/// Per DICOM PS3.3 Section 10.7.1.3:
/// - X (horizontal/columns) → [DicomImageGeometry.columnSpacing]
/// - Y (vertical/rows) → [DicomImageGeometry.rowSpacing]
///
/// ```
/// widthMm  = pixelWidth  × columnSpacing
/// heightMm = pixelHeight × rowSpacing
/// areaMm2  = widthMm × heightMm
/// ```
///
/// ## Boundary Rules
///
/// Both corners must be inside the image for the ROI to be valid.
/// Corners are NOT silently clamped.
///
/// ## Zero-Area ROI
///
/// When `startPoint == endPoint` (zero pixel area), [isValid] is `false`.
///
/// ## Per-Frame Behavior
///
/// Each ROI belongs to a specific [frameIndex]. At most one ROI exists per frame.
/// Frame changes hide/restore per-frame ROIs. Dataset changes clear all ROI state.
class DicomRectangleRoiMeasurement {
  /// Creates a [DicomRectangleRoiMeasurement].
  const DicomRectangleRoiMeasurement({
    required this.startPoint,
    required this.endPoint,
    required this.normalizedRect,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.areaPx,
    this.physicalWidthMm,
    this.physicalHeightMm,
    this.areaMm2,
    required this.isValid,
    required this.frameIndex,
    this.statistics,
  });

  /// Computes a [DicomRectangleRoiMeasurement] from two continuous [ImagePoint]s
  /// and the image [geometry].
  ///
  /// The two points represent opposite corners of the ROI rectangle.
  /// The rectangle is normalized so that the top-left corner has the minimum
  /// coordinates regardless of drag direction.
  factory DicomRectangleRoiMeasurement.fromImagePoints({
    required ImagePoint start,
    required ImagePoint end,
    required int frameIndex,
    required DicomImageGeometry geometry,
    DicomRoiStatistics? statistics,
  }) {
    // Normalize rectangle: ensure left <= right, top <= bottom
    final left = math.min(start.pixelX, end.pixelX);
    final right = math.max(start.pixelX, end.pixelX);
    final top = math.min(start.pixelY, end.pixelY);
    final bottom = math.max(start.pixelY, end.pixelY);

    final normalizedRect = Rect.fromLTRB(left, top, right, bottom);

    final pixelWidth = right - left;
    final pixelHeight = bottom - top;
    final areaPx = pixelWidth * pixelHeight;

    // Both corners must be inside image
    final cornersInside = start.isInsideImage && end.isInsideImage;

    // Zero-area ROI is invalid
    final hasArea = areaPx > 0;

    final isValid = cornersInside && hasArea;

    // Physical dimensions
    double? widthMm;
    double? heightMm;
    double? area;

    if (geometry.hasPhysicalSpacing) {
      widthMm = pixelWidth * geometry.columnSpacing!;
      heightMm = pixelHeight * geometry.rowSpacing!;
      area = widthMm * heightMm;
    }

    return DicomRectangleRoiMeasurement(
      startPoint: start,
      endPoint: end,
      normalizedRect: normalizedRect,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      areaPx: areaPx,
      physicalWidthMm: widthMm,
      physicalHeightMm: heightMm,
      areaMm2: area,
      isValid: isValid,
      frameIndex: frameIndex,
      statistics: statistics,
    );
  }

  /// First corner in continuous native image coordinates.
  final ImagePoint startPoint;

  /// Second (opposite) corner in continuous native image coordinates.
  final ImagePoint endPoint;

  /// Normalized rectangle in continuous native pixel coordinates.
  /// `left = min(x1, x2)`, `right = max(x1, x2)`,
  /// `top = min(y1, y2)`, `bottom = max(y1, y2)`.
  final Rect normalizedRect;

  /// Width of the ROI in continuous pixel units (`right - left`).
  final double pixelWidth;

  /// Height of the ROI in continuous pixel units (`bottom - top`).
  final double pixelHeight;

  /// Area of the ROI in pixel² units (`pixelWidth × pixelHeight`).
  final double areaPx;

  /// Physical width in millimeters (`pixelWidth × columnSpacing`),
  /// or null if physical spacing is unavailable.
  final double? physicalWidthMm;

  /// Physical height in millimeters (`pixelHeight × rowSpacing`),
  /// or null if physical spacing is unavailable.
  final double? physicalHeightMm;

  /// Physical area in mm² (`widthMm × heightMm`),
  /// or null if physical spacing is unavailable.
  final double? areaMm2;

  /// Whether both corners are inside the image and the ROI has non-zero area.
  final bool isValid;

  /// The multi-frame image index (0-indexed) this ROI belongs to.
  final int frameIndex;

  /// Quantitative pixel statistics calculated for this ROI, or null if in-progress/uncalculated.
  final DicomRoiStatistics? statistics;

  /// Creates a copy of this measurement with optionally updated [statistics].
  DicomRectangleRoiMeasurement copyWith({DicomRoiStatistics? statistics}) {
    return DicomRectangleRoiMeasurement(
      startPoint: startPoint,
      endPoint: endPoint,
      normalizedRect: normalizedRect,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      areaPx: areaPx,
      physicalWidthMm: physicalWidthMm,
      physicalHeightMm: physicalHeightMm,
      areaMm2: areaMm2,
      isValid: isValid,
      frameIndex: frameIndex,
      statistics: statistics ?? this.statistics,
    );
  }

  /// Whether physical millimeter measurements are available.
  bool get hasPhysicalMeasurement =>
      physicalWidthMm != null && physicalHeightMm != null && areaMm2 != null;

  /// User-facing formatted dimensions string.
  ///
  /// When valid with physical spacing:
  /// `"W: 42.7 mm  H: 31.2 mm  A: 1332.2 mm²"`
  ///
  /// When valid without physical spacing:
  /// `"W: 120.0 px  H: 80.0 px  A: 9600.0 px²"`
  ///
  /// When invalid:
  /// `"Out of bounds"`
  String get formattedDimensions {
    if (!isValid) return 'Out of bounds';
    if (hasPhysicalMeasurement) {
      return 'W: ${physicalWidthMm!.toStringAsFixed(1)} mm  '
          'H: ${physicalHeightMm!.toStringAsFixed(1)} mm  '
          'A: ${areaMm2!.toStringAsFixed(1)} mm\u00B2';
    }
    return 'W: ${pixelWidth.toStringAsFixed(1)} px  '
        'H: ${pixelHeight.toStringAsFixed(1)} px  '
        'A: ${areaPx.toStringAsFixed(1)} px\u00B2';
  }

  /// Accessibility-friendly label for screen readers.
  String get semanticsLabel {
    if (!isValid) return 'Rectangle ROI: Out of bounds';
    final geoStr =
        hasPhysicalMeasurement
            ? 'Rectangle ROI: '
                'Width ${physicalWidthMm!.toStringAsFixed(1)} millimeters, '
                'Height ${physicalHeightMm!.toStringAsFixed(1)} millimeters, '
                'Area ${areaMm2!.toStringAsFixed(1)} square millimeters'
            : 'Rectangle ROI: '
                'Width ${pixelWidth.toStringAsFixed(1)} pixels, '
                'Height ${pixelHeight.toStringAsFixed(1)} pixels, '
                'Area ${areaPx.toStringAsFixed(1)} square pixels';

    if (statistics != null) {
      return '$geoStr. ${statistics!.semanticsSummary}';
    }
    return geoStr;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomRectangleRoiMeasurement &&
          runtimeType == other.runtimeType &&
          startPoint == other.startPoint &&
          endPoint == other.endPoint &&
          normalizedRect == other.normalizedRect &&
          pixelWidth == other.pixelWidth &&
          pixelHeight == other.pixelHeight &&
          areaPx == other.areaPx &&
          physicalWidthMm == other.physicalWidthMm &&
          physicalHeightMm == other.physicalHeightMm &&
          areaMm2 == other.areaMm2 &&
          isValid == other.isValid &&
          frameIndex == other.frameIndex &&
          statistics == other.statistics;

  @override
  int get hashCode =>
      startPoint.hashCode ^
      endPoint.hashCode ^
      normalizedRect.hashCode ^
      pixelWidth.hashCode ^
      pixelHeight.hashCode ^
      areaPx.hashCode ^
      physicalWidthMm.hashCode ^
      physicalHeightMm.hashCode ^
      areaMm2.hashCode ^
      isValid.hashCode ^
      frameIndex.hashCode ^
      statistics.hashCode;

  @override
  String toString() =>
      'DicomRectangleRoiMeasurement(frame: $frameIndex, rect: $normalizedRect, '
      'dimensions: $formattedDimensions, stats: $statistics, isValid: $isValid)';
}
