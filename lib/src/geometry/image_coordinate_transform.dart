import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'dicom_image_geometry.dart';

/// Represents a 2D coordinate on a DICOM image in native pixel space and optional physical space.
///
/// Coordinate Conventions:
/// - **Pixel Origin**: `(0.0, 0.0)` at the top-left edge of pixel (column 0, row 0).
/// - **Horizontal Axis ([pixelX])**: Direction of columns, increasing to the right `[0.0, columns]`.
/// - **Vertical Axis ([pixelY])**: Direction of rows, increasing downwards `[0.0, rows]`.
/// - **Pixel Center**: Pixel `(c, r)` has its geometric center at `(c + 0.5, r + 0.5)`.
/// - **Physical Coordinates**:
///   - [physicalXMm] $= pixelX \times columnSpacing$ (in mm).
///   - [physicalYMm] $= pixelY \times rowSpacing$ (in mm).
class ImagePoint {
  /// Creates an [ImagePoint].
  const ImagePoint({
    required this.pixelX,
    required this.pixelY,
    this.physicalXMm,
    this.physicalYMm,
    required this.isInsideImage,
  });

  /// Native horizontal pixel coordinate (columns direction, `[0.0, columns]`).
  final double pixelX;

  /// Native vertical pixel coordinate (rows direction, `[0.0, rows]`).
  final double pixelY;

  /// Physical horizontal coordinate in millimeters on the image plane ($pixelX \times columnSpacing$),
  /// or null if physical spacing is unavailable.
  final double? physicalXMm;

  /// Physical vertical coordinate in millimeters on the image plane ($pixelY \times rowSpacing$),
  /// or null if physical spacing is unavailable.
  final double? physicalYMm;

  /// Whether this coordinate falls within the valid native image bounds
  /// `0.0 <= pixelX <= columns && 0.0 <= pixelY <= rows`.
  final bool isInsideImage;

  /// Whether physical millimeter coordinates are available for this point.
  bool get hasPhysicalCoordinate => physicalXMm != null && physicalYMm != null;

  /// Converts this point to a standard Flutter [Offset] in pixel space.
  Offset toPixelOffset() => Offset(pixelX, pixelY);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImagePoint &&
          runtimeType == other.runtimeType &&
          pixelX == other.pixelX &&
          pixelY == other.pixelY &&
          physicalXMm == other.physicalXMm &&
          physicalYMm == other.physicalYMm &&
          isInsideImage == other.isInsideImage;

  @override
  int get hashCode =>
      pixelX.hashCode ^
      pixelY.hashCode ^
      physicalXMm.hashCode ^
      physicalYMm.hashCode ^
      isInsideImage.hashCode;

  @override
  String toString() =>
      'ImagePoint(pixel: ($pixelX, $pixelY), physicalMm: ($physicalXMm, $physicalYMm), isInside: $isInsideImage)';
}

/// Result of a 2-point measurement across the 2D image plane.
///
/// Implements the strict boundary rule:
/// - Both endpoints inside image $\to$ [isValid] is `true`.
/// - Either endpoint outside image $\to$ [isValid] is `false`.
class TwoPointMeasurementResult {
  /// Creates a [TwoPointMeasurementResult].
  const TwoPointMeasurementResult({
    required this.start,
    required this.end,
    required this.deltaPixelX,
    required this.deltaPixelY,
    required this.pixelDistance,
    this.deltaPhysicalXMm,
    this.deltaPhysicalYMm,
    this.physicalDistanceMm,
    required this.isValid,
  });

  /// Starting point of the measurement.
  final ImagePoint start;

  /// Ending point of the measurement.
  final ImagePoint end;

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

  /// Whether both [start] and [end] are strictly inside the image bounds.
  ///
  /// If either endpoint is outside the image bounds, [isValid] is `false`.
  final bool isValid;

  /// Whether physical distance measurement is available.
  bool get hasPhysicalMeasurement =>
      physicalDistanceMm != null &&
      deltaPhysicalXMm != null &&
      deltaPhysicalYMm != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TwoPointMeasurementResult &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
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
      deltaPixelX.hashCode ^
      deltaPixelY.hashCode ^
      pixelDistance.hashCode ^
      deltaPhysicalXMm.hashCode ^
      deltaPhysicalYMm.hashCode ^
      physicalDistanceMm.hashCode ^
      isValid.hashCode;

  @override
  String toString() =>
      'TwoPointMeasurementResult(start: $start, end: $end, pixelDistance: $pixelDistance, physicalDistanceMm: $physicalDistanceMm, isValid: $isValid)';
}

/// Coordinate transformation pipeline between viewport/screen coordinates,
/// native pixel coordinates, and 2D physical image-plane coordinates.
///
/// Coordinate Conventions:
/// - **Viewport Origin**: `(0, 0)` at top-left of the viewport widget.
/// - **X Direction**: Positive rightwards.
/// - **Y Direction**: Positive downwards.
/// - **Pixel Origin**: `(0.0, 0.0)` at top-left edge of pixel (column 0, row 0).
/// - **Continuous Pixel Range**: `[0.0, columns]` horizontally, `[0.0, rows]` vertically.
/// - **Pixel Center**: Pixel `(c, r)` center is at `(c + 0.5, r + 0.5)`.
/// - **Physical Space**: Horizontal distance in mm = $pixelX \times columnSpacing$,
///   vertical distance in mm = $pixelY \times rowSpacing$.
class ImageCoordinateTransform {
  /// Creates an [ImageCoordinateTransform].
  const ImageCoordinateTransform({
    required this.geometry,
    required this.viewportSize,
    this.transformMatrix,
  });

  /// The 2D image geometry of the DICOM image.
  final DicomImageGeometry geometry;

  /// The total size of the viewport / viewer widget.
  final Size viewportSize;

  /// The pan/zoom transformation matrix (from InteractiveViewer or TransformationController).
  /// If null or identity, no pan/zoom scaling or translation is applied.
  final Matrix4? transformMatrix;

  /// Computes the unscaled, centered rectangle occupied by the displayed image within the viewport.
  ///
  /// Matches Flutter's `Center(child: AspectRatio(...))` layout logic.
  Rect get displayedImageRect {
    final w = viewportSize.width;
    final h = viewportSize.height;
    if (w <= 0 || h <= 0 || geometry.columns <= 0 || geometry.rows <= 0) {
      return Rect.zero;
    }

    final ar = geometry.displayAspectRatio;
    if (ar <= 0 || !ar.isFinite) {
      return Rect.zero;
    }

    final viewportAr = w / h;
    double displayedW;
    double displayedH;
    double left;
    double top;

    if (viewportAr > ar) {
      // Viewport is wider than image aspect ratio -> letterbox horizontally
      displayedH = h;
      displayedW = h * ar;
      left = (w - displayedW) / 2.0;
      top = 0.0;
    } else if (viewportAr < ar) {
      // Viewport is taller than image aspect ratio -> pillarbox vertically
      displayedW = w;
      displayedH = w / ar;
      left = 0.0;
      top = (h - displayedH) / 2.0;
    } else {
      // Exact aspect ratio match
      displayedW = w;
      displayedH = h;
      left = 0.0;
      top = 0.0;
    }

    return Rect.fromLTWH(left, top, displayedW, displayedH);
  }

  /// Converts a viewport coordinate (e.g. from a pointer or gesture event)
  /// into an [ImagePoint] in native pixel and physical image-plane space.
  ImagePoint viewportToImage(Offset viewportCoord) {
    final rect = displayedImageRect;
    if (rect.width <= 0 ||
        rect.height <= 0 ||
        geometry.columns <= 0 ||
        geometry.rows <= 0) {
      return const ImagePoint(
        pixelX: 0.0,
        pixelY: 0.0,
        physicalXMm: null,
        physicalYMm: null,
        isInsideImage: false,
      );
    }

    // Step 1: Invert pan/zoom matrix to map viewport coordinate to unscaled child coordinate
    Offset untransformedPoint;
    if (transformMatrix != null && !transformMatrix!.isIdentity()) {
      final inv = Matrix4.tryInvert(transformMatrix!) ?? Matrix4.identity();
      untransformedPoint = MatrixUtils.transformPoint(inv, viewportCoord);
    } else {
      untransformedPoint = viewportCoord;
    }

    // Step 2: Map to normalized continuous image space [0, 1] relative to displayedImageRect
    final u = (untransformedPoint.dx - rect.left) / rect.width;
    final v = (untransformedPoint.dy - rect.top) / rect.height;

    // Step 3: Compute continuous native pixel coordinates
    final pixelX = u * geometry.columns;
    final pixelY = v * geometry.rows;

    // Step 4: Strict boundary check [0.0, columns] x [0.0, rows]
    final isInside =
        pixelX >= 0.0 &&
        pixelX <= geometry.columns &&
        pixelY >= 0.0 &&
        pixelY <= geometry.rows;

    // Step 5: Physical coordinates (if available)
    double? physicalX;
    double? physicalY;
    if (geometry.hasPhysicalSpacing) {
      physicalX = pixelX * geometry.columnSpacing!;
      physicalY = pixelY * geometry.rowSpacing!;
    }

    return ImagePoint(
      pixelX: pixelX,
      pixelY: pixelY,
      physicalXMm: physicalX,
      physicalYMm: physicalY,
      isInsideImage: isInside,
    );
  }

  /// Converts a native pixel coordinate back to a viewport coordinate
  /// taking into account image centering, display aspect ratio, and pan/zoom transform.
  Offset pixelToViewport(Offset pixelCoord) {
    final rect = displayedImageRect;
    if (rect.width <= 0 ||
        rect.height <= 0 ||
        geometry.columns <= 0 ||
        geometry.rows <= 0) {
      return Offset.zero;
    }

    final u = pixelCoord.dx / geometry.columns;
    final v = pixelCoord.dy / geometry.rows;

    final untransformedPoint = Offset(
      rect.left + u * rect.width,
      rect.top + v * rect.height,
    );

    if (transformMatrix != null && !transformMatrix!.isIdentity()) {
      return MatrixUtils.transformPoint(transformMatrix!, untransformedPoint);
    }

    return untransformedPoint;
  }

  /// Converts a physical image-plane coordinate in millimeters back to a viewport coordinate.
  ///
  /// Returns null if physical spacing is unavailable.
  Offset? physicalToViewport(double physicalXmm, double physicalYmm) {
    if (!geometry.hasPhysicalSpacing) return null;
    final pixelX = physicalXmm / geometry.columnSpacing!;
    final pixelY = physicalYmm / geometry.rowSpacing!;
    return pixelToViewport(Offset(pixelX, pixelY));
  }

  /// Computes a [TwoPointMeasurementResult] between two native [ImagePoint]s.
  TwoPointMeasurementResult measureBetweenImagePoints(
    ImagePoint start,
    ImagePoint end,
  ) {
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

    return TwoPointMeasurementResult(
      start: start,
      end: end,
      deltaPixelX: dxPx,
      deltaPixelY: dyPx,
      pixelDistance: pixelDist,
      deltaPhysicalXMm: dxMm,
      deltaPhysicalYMm: dyMm,
      physicalDistanceMm: distMm,
      isValid: isValid,
    );
  }

  /// Computes a [TwoPointMeasurementResult] between two viewport coordinates.
  TwoPointMeasurementResult measureBetweenViewportCoordinates(
    Offset startViewport,
    Offset endViewport,
  ) {
    final start = viewportToImage(startViewport);
    final end = viewportToImage(endViewport);
    return measureBetweenImagePoints(start, end);
  }
}
