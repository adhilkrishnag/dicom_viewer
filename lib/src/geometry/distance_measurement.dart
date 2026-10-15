import 'package:flutter/widgets.dart';
import 'dicom_image_geometry.dart';
import 'dicom_measurement.dart';
import 'image_coordinate_transform.dart';

/// Represents a completed or in-progress 2D distance measurement on a DICOM image frame.
class DicomDistanceMeasurement implements DicomMeasurement {
  /// Creates a [DicomDistanceMeasurement].
  ///
  /// If [id] is omitted, a unique stable ID is generated automatically.
  DicomDistanceMeasurement({
    String? id,
    required this.start,
    required this.end,
    required this.frameIndex,
    required this.deltaPixelX,
    required this.deltaPixelY,
    required this.pixelDistance,
    this.deltaPhysicalXMm,
    this.deltaPhysicalYMm,
    this.physicalDistanceMm,
    required this.isValid,
    this.isVisible = true,
    this.isSelected = false,
  }) : id = id ?? DicomMeasurementIdGenerator.generate('dist');

  /// Creates a [DicomDistanceMeasurement] with an explicit, known [id].
  const DicomDistanceMeasurement.withExplicitId({
    required this.id,
    required this.start,
    required this.end,
    required this.frameIndex,
    required this.deltaPixelX,
    required this.deltaPixelY,
    required this.pixelDistance,
    this.deltaPhysicalXMm,
    this.deltaPhysicalYMm,
    this.physicalDistanceMm,
    required this.isValid,
    this.isVisible = true,
    this.isSelected = false,
  });

  /// Creates a [DicomDistanceMeasurement] directly from a [TwoPointMeasurementResult].
  factory DicomDistanceMeasurement.fromResult({
    String? id,
    required TwoPointMeasurementResult result,
    required int frameIndex,
    bool isVisible = true,
    bool isSelected = false,
  }) {
    return DicomDistanceMeasurement(
      id: id,
      start: result.start,
      end: result.end,
      frameIndex: frameIndex,
      deltaPixelX: result.deltaPixelX,
      deltaPixelY: result.deltaPixelY,
      pixelDistance: result.pixelDistance,
      deltaPhysicalXMm: result.deltaPhysicalXMm,
      deltaPhysicalYMm: result.deltaPhysicalYMm,
      physicalDistanceMm: result.physicalDistanceMm,
      isValid: result.isValid,
      isVisible: isVisible,
      isSelected: isSelected,
    );
  }

  /// Computes a [DicomDistanceMeasurement] from two continuous [ImagePoint]s and image [geometry]
  /// via [ImageCoordinateTransform].
  factory DicomDistanceMeasurement.fromPoints({
    String? id,
    required ImagePoint start,
    required ImagePoint end,
    required int frameIndex,
    required DicomImageGeometry geometry,
    bool isVisible = true,
    bool isSelected = false,
  }) {
    final transform = ImageCoordinateTransform(
      geometry: geometry,
      viewportSize: const Size(0, 0),
    );
    final result = transform.measureBetweenImagePoints(start, end);
    return DicomDistanceMeasurement.fromResult(
      id: id,
      result: result,
      frameIndex: frameIndex,
      isVisible: isVisible,
      isSelected: isSelected,
    );
  }

  /// Stable unique identifier for this measurement.
  @override
  final String id;

  /// The measurement type discriminator.
  @override
  DicomMeasurementType get type => DicomMeasurementType.distance;

  /// 2D line segment geometry in continuous native image coordinates.
  @override
  DicomLineGeometry get geometry => DicomLineGeometry(start: start, end: end);

  /// Whether this measurement is visible on the image overlay.
  @override
  final bool isVisible;

  /// Whether this measurement is currently selected.
  @override
  final bool isSelected;

  /// Starting point in continuous native image coordinates.
  final ImagePoint start;

  /// Ending point in continuous native image coordinates.
  final ImagePoint end;

  /// The multi-frame image index (0-indexed) this measurement belongs to.
  @override
  final int frameIndex;

  /// Horizontal pixel delta ($end.pixelX - start.pixelX$).
  final double deltaPixelX;

  /// Vertical pixel delta ($end.pixelY - start.pixelY$).
  final double deltaPixelY;

  /// Euclidean distance in native pixel units ($\sqrt{\Delta x_{px}^2 + \Delta y_{px}^2}$).
  final double pixelDistance;

  /// Horizontal physical delta in millimeters ($deltaPixelX \times columnSpacing$),
  /// or null if physical spacing is unavailable.
  final double? deltaPhysicalXMm;

  /// Vertical physical delta in millimeters ($deltaPixelY \times rowSpacing$),
  /// or null if physical spacing is unavailable.
  final double? deltaPhysicalYMm;

  /// Euclidean physical distance in millimeters ($\sqrt{\Delta x_{mm}^2 + \Delta y_{mm}^2}$),
  /// or null if physical spacing is unavailable.
  final double? physicalDistanceMm;

  /// Whether both [start] and [end] endpoints are strictly inside the image bounds.
  @override
  final bool isValid;

  /// Whether physical distance measurement is available.
  bool get hasPhysicalMeasurement =>
      physicalDistanceMm != null &&
      deltaPhysicalXMm != null &&
      deltaPhysicalYMm != null;

  /// User-facing formatted distance string (e.g. `42.7 mm` or `73.4 px (Physical unavailable)`).
  String get formattedDistance {
    if (!isValid) return 'Out of bounds';
    if (hasPhysicalMeasurement) {
      return '${physicalDistanceMm!.toStringAsFixed(1)} mm';
    }
    return '${pixelDistance.toStringAsFixed(1)} px (Physical unavailable)';
  }

  @override
  String get formattedValue => formattedDistance;

  @override
  String get semanticsLabel =>
      isValid
          ? (hasPhysicalMeasurement
              ? 'Distance measurement: ${physicalDistanceMm!.toStringAsFixed(1)} millimeters'
              : 'Distance measurement: ${pixelDistance.toStringAsFixed(1)} pixels')
          : 'Distance measurement: Out of bounds';

  /// Creates a copy of this measurement with optionally replaced fields.
  DicomDistanceMeasurement copyWith({
    String? id,
    ImagePoint? start,
    ImagePoint? end,
    int? frameIndex,
    double? deltaPixelX,
    double? deltaPixelY,
    double? pixelDistance,
    double? deltaPhysicalXMm,
    double? deltaPhysicalYMm,
    double? physicalDistanceMm,
    bool? isValid,
    bool? isVisible,
    bool? isSelected,
  }) {
    return DicomDistanceMeasurement.withExplicitId(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      frameIndex: frameIndex ?? this.frameIndex,
      deltaPixelX: deltaPixelX ?? this.deltaPixelX,
      deltaPixelY: deltaPixelY ?? this.deltaPixelY,
      pixelDistance: pixelDistance ?? this.pixelDistance,
      deltaPhysicalXMm: deltaPhysicalXMm ?? this.deltaPhysicalXMm,
      deltaPhysicalYMm: deltaPhysicalYMm ?? this.deltaPhysicalYMm,
      physicalDistanceMm: physicalDistanceMm ?? this.physicalDistanceMm,
      isValid: isValid ?? this.isValid,
      isVisible: isVisible ?? this.isVisible,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  DicomDistanceMeasurement copyWithMeasurement({
    bool? isVisible,
    bool? isSelected,
  }) {
    return copyWith(isVisible: isVisible, isSelected: isSelected);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomDistanceMeasurement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          start == other.start &&
          end == other.end &&
          frameIndex == other.frameIndex &&
          deltaPixelX == other.deltaPixelX &&
          deltaPixelY == other.deltaPixelY &&
          pixelDistance == other.pixelDistance &&
          deltaPhysicalXMm == other.deltaPhysicalXMm &&
          deltaPhysicalYMm == other.deltaPhysicalYMm &&
          physicalDistanceMm == other.physicalDistanceMm &&
          isValid == other.isValid &&
          isVisible == other.isVisible &&
          isSelected == other.isSelected;

  @override
  int get hashCode =>
      id.hashCode ^
      start.hashCode ^
      end.hashCode ^
      frameIndex.hashCode ^
      deltaPixelX.hashCode ^
      deltaPixelY.hashCode ^
      pixelDistance.hashCode ^
      deltaPhysicalXMm.hashCode ^
      deltaPhysicalYMm.hashCode ^
      physicalDistanceMm.hashCode ^
      isValid.hashCode ^
      isVisible.hashCode ^
      isSelected.hashCode;

  @override
  String toString() =>
      'DicomDistanceMeasurement(id: $id, frame: $frameIndex, start: $start, end: $end, distance: $formattedDistance, isValid: $isValid, isVisible: $isVisible, isSelected: $isSelected)';
}
