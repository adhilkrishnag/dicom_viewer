import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'dicom_image_geometry.dart';
import 'dicom_measurement.dart';
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
/// ## Multi-Measurement Integration
///
/// Implements [DicomMeasurement], exposing a stable [id], [type] ([DicomMeasurementType.rectangleRoi]),
/// [frameIndex], normalized [geometry] ([Rect]), and independent [isVisible] / [isSelected] state.
class DicomRectangleRoiMeasurement implements DicomMeasurement {
  /// Creates a [DicomRectangleRoiMeasurement].
  ///
  /// If [id] is omitted, a unique stable ID is generated automatically.
  DicomRectangleRoiMeasurement({
    String? id,
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
    this.isVisible = true,
    this.isSelected = false,
  }) : id = id ?? DicomMeasurementIdGenerator.generate('roi');

  /// Creates a [DicomRectangleRoiMeasurement] with an explicit, known [id].
  const DicomRectangleRoiMeasurement.withExplicitId({
    required this.id,
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
    this.isVisible = true,
    this.isSelected = false,
  });

  /// Computes a [DicomRectangleRoiMeasurement] from two continuous [ImagePoint]s
  /// and the image [geometry].
  ///
  /// The two points represent opposite corners of the ROI rectangle.
  /// The rectangle is normalized so that the top-left corner has the minimum
  /// coordinates regardless of drag direction.
  factory DicomRectangleRoiMeasurement.fromImagePoints({
    String? id,
    required ImagePoint start,
    required ImagePoint end,
    required int frameIndex,
    required DicomImageGeometry geometry,
    DicomRoiStatistics? statistics,
    bool isVisible = true,
    bool isSelected = false,
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
      id: id,
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
      isVisible: isVisible,
      isSelected: isSelected,
    );
  }

  /// Stable unique identifier for this measurement.
  @override
  final String id;

  /// The measurement type discriminator.
  @override
  DicomMeasurementType get type => DicomMeasurementType.rectangleRoi;

  /// Normalized rectangle in continuous native pixel coordinates.
  @override
  Rect get geometry => normalizedRect;

  /// Whether this measurement is visible on the image overlay.
  @override
  final bool isVisible;

  /// Whether this measurement is currently selected.
  @override
  final bool isSelected;

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
  @override
  final bool isValid;

  /// The multi-frame image index (0-indexed) this ROI belongs to.
  @override
  final int frameIndex;

  /// Quantitative pixel statistics calculated for this ROI, or null if in-progress/uncalculated.
  final DicomRoiStatistics? statistics;

  /// Creates a copy of this measurement with optionally updated fields.
  DicomRectangleRoiMeasurement copyWith({
    String? id,
    ImagePoint? startPoint,
    ImagePoint? endPoint,
    Rect? normalizedRect,
    double? pixelWidth,
    double? pixelHeight,
    double? areaPx,
    double? physicalWidthMm,
    double? physicalHeightMm,
    double? areaMm2,
    bool? isValid,
    int? frameIndex,
    DicomRoiStatistics? statistics,
    bool? isVisible,
    bool? isSelected,
  }) {
    return DicomRectangleRoiMeasurement.withExplicitId(
      id: id ?? this.id,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      normalizedRect: normalizedRect ?? this.normalizedRect,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      areaPx: areaPx ?? this.areaPx,
      physicalWidthMm: physicalWidthMm ?? this.physicalWidthMm,
      physicalHeightMm: physicalHeightMm ?? this.physicalHeightMm,
      areaMm2: areaMm2 ?? this.areaMm2,
      isValid: isValid ?? this.isValid,
      frameIndex: frameIndex ?? this.frameIndex,
      statistics: statistics ?? this.statistics,
      isVisible: isVisible ?? this.isVisible,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  DicomRectangleRoiMeasurement copyWithMeasurement({
    bool? isVisible,
    bool? isSelected,
  }) {
    return copyWith(isVisible: isVisible, isSelected: isSelected);
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

  @override
  String get formattedValue => formattedDimensions;

  /// Accessibility-friendly label for screen readers.
  @override
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
          id == other.id &&
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
          statistics == other.statistics &&
          isVisible == other.isVisible &&
          isSelected == other.isSelected;

  @override
  int get hashCode =>
      id.hashCode ^
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
      statistics.hashCode ^
      isVisible.hashCode ^
      isSelected.hashCode;

  @override
  String toString() =>
      'DicomRectangleRoiMeasurement(id: $id, frame: $frameIndex, rect: $normalizedRect, '
      'dimensions: $formattedDimensions, stats: $statistics, isValid: $isValid, '
      'isVisible: $isVisible, isSelected: $isSelected)';
}
