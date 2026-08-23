import 'dart:math' as math;
import 'dicom_image_geometry.dart';
import 'image_coordinate_transform.dart';

/// Represents a completed or in-progress 2D distance measurement on a DICOM image frame.
class DicomDistanceMeasurement {
  /// Creates a [DicomDistanceMeasurement].
  const DicomDistanceMeasurement({
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
  });

  /// Computes a [DicomDistanceMeasurement] from two continuous [ImagePoint]s and image [geometry].
  factory DicomDistanceMeasurement.fromPoints({
    required ImagePoint start,
    required ImagePoint end,
    required int frameIndex,
    required DicomImageGeometry geometry,
  }) {
    final dxPx = end.pixelX - start.pixelX;
    final dyPx = end.pixelY - start.pixelY;
    final pixelDist = math.sqrt(dxPx * dxPx + dyPx * dyPx);

    final isValid = start.isInsideImage && end.isInsideImage;

    double? dxMm;
    double? dyMm;
    double? distMm;

    if (geometry.hasPhysicalSpacing) {
      dxMm = dxPx * geometry.columnSpacing!;
      dyMm = dyPx * geometry.rowSpacing!;
      distMm = math.sqrt(dxMm * dxMm + dyMm * dyMm);
    }

    return DicomDistanceMeasurement(
      start: start,
      end: end,
      frameIndex: frameIndex,
      deltaPixelX: dxPx,
      deltaPixelY: dyPx,
      pixelDistance: pixelDist,
      deltaPhysicalXMm: dxMm,
      deltaPhysicalYMm: dyMm,
      physicalDistanceMm: distMm,
      isValid: isValid,
    );
  }

  /// Starting point in continuous native image coordinates.
  final ImagePoint start;

  /// Ending point in continuous native image coordinates.
  final ImagePoint end;

  /// The multi-frame image index (0-indexed) this measurement belongs to.
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomDistanceMeasurement &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          frameIndex == other.frameIndex &&
          deltaPixelX == other.deltaPixelX &&
          deltaPixelY == other.deltaPixelY &&
          pixelDistance == other.pixelDistance &&
          deltaPhysicalXMm == other.deltaPhysicalXMm &&
          deltaPhysicalYMm == other.deltaPhysicalYMm &&
          physicalDistanceMm == other.physicalDistanceMm &&
          isValid == other.isValid;

  @override
  int get hashCode =>
      start.hashCode ^
      end.hashCode ^
      frameIndex.hashCode ^
      deltaPixelX.hashCode ^
      deltaPixelY.hashCode ^
      pixelDistance.hashCode ^
      deltaPhysicalXMm.hashCode ^
      deltaPhysicalYMm.hashCode ^
      physicalDistanceMm.hashCode ^
      isValid.hashCode;

  @override
  String toString() =>
      'DicomDistanceMeasurement(frame: $frameIndex, start: $start, end: $end, distance: $formattedDistance, isValid: $isValid)';
}
