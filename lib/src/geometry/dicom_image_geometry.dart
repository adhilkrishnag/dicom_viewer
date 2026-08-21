import '../parsing/dicom_dataset.dart';

/// Internal 2D image geometry abstraction representing pixel matrix dimensions,
/// in-plane physical spacing, and display aspect ratio.
///
/// Distinguishes:
/// - Native pixel dimensions ([columns], [rows])
/// - Physical in-plane dimensions ([physicalWidthMm], [physicalHeightMm])
/// - Display aspect ratio ([displayAspectRatio])
class DicomImageGeometry {
  /// Creates a [DicomImageGeometry] with explicit dimensions and optional spacing.
  const DicomImageGeometry({
    required this.columns,
    required this.rows,
    this.rowSpacing,
    this.columnSpacing,
  });

  /// Extracts 2D image geometry from a [DicomDataset].
  ///
  /// Extracts [DicomDataset.columns], [DicomDataset.rows], and [DicomDataset.pixelSpacing] (0028,0030).
  ///
  /// Per DICOM PS3.3 Section 10.7.1.3:
  /// - `pixelSpacing[0]` is Row Spacing (vertical spacing between adjacent row centers, $S_y$, in mm).
  /// - `pixelSpacing[1]` is Column Spacing (horizontal spacing between adjacent column centers, $S_x$, in mm).
  ///
  /// If [DicomDataset.pixelSpacing] is missing, does not contain 2 values, contains non-positive or non-finite values,
  /// [hasPhysicalSpacing] is set to `false`, and [rowSpacing] and [columnSpacing] are `null`.
  factory DicomImageGeometry.fromDataset(DicomDataset dataset) {
    final cols = dataset.columns;
    final rows = dataset.rows;
    final spacing = dataset.pixelSpacing;

    double? rowSpacing;
    double? colSpacing;

    if (spacing != null && spacing.length == 2) {
      final r = spacing[0];
      final c = spacing[1];
      if (r > 0 && c > 0 && r.isFinite && c.isFinite) {
        rowSpacing = r;
        colSpacing = c;
      }
    }

    return DicomImageGeometry(
      columns: cols,
      rows: rows,
      rowSpacing: rowSpacing,
      columnSpacing: colSpacing,
    );
  }

  /// Number of columns (image width in pixels, 0028,0011).
  final int columns;

  /// Number of rows (image height in pixels, 0028,0010).
  final int rows;

  /// Vertical physical distance between adjacent row centers in millimeters ($S_y$).
  /// Null if physical spacing is not available or invalid.
  final double? rowSpacing;

  /// Horizontal physical distance between adjacent column centers in millimeters ($S_x$).
  /// Null if physical spacing is not available or invalid.
  final double? columnSpacing;

  /// Whether valid, positive, finite physical pixel spacing is available.
  bool get hasPhysicalSpacing =>
      rowSpacing != null &&
      columnSpacing != null &&
      rowSpacing! > 0 &&
      columnSpacing! > 0 &&
      rowSpacing!.isFinite &&
      columnSpacing!.isFinite;

  /// Physical in-plane image width in millimeters ($columns \times columnSpacing$),
  /// or null if physical spacing is not available or [columns] <= 0.
  double? get physicalWidthMm {
    if (!hasPhysicalSpacing || columns <= 0) return null;
    return columns * columnSpacing!;
  }

  /// Physical in-plane image height in millimeters ($rows \times rowSpacing$),
  /// or null if physical spacing is not available or [rows] <= 0.
  double? get physicalHeightMm {
    if (!hasPhysicalSpacing || rows <= 0) return null;
    return rows * rowSpacing!;
  }

  /// Display aspect ratio (width / height) preserving physical pixel geometry.
  ///
  /// For valid physical spacing:
  /// `(columns * columnSpacing) / (rows * rowSpacing)`
  ///
  /// When physical spacing is unavailable, falls back to native matrix aspect ratio:
  /// `columns / rows` (or `1.0` if dimensions are invalid <= 0).
  double get displayAspectRatio {
    if (columns <= 0 || rows <= 0) return 1.0;

    if (hasPhysicalSpacing) {
      final pw = physicalWidthMm;
      final ph = physicalHeightMm;
      if (pw != null && ph != null && ph > 0) {
        final ar = pw / ph;
        if (ar > 0 && ar.isFinite) {
          return ar;
        }
      }
    }

    final nativeAr = columns / rows;
    if (nativeAr > 0 && nativeAr.isFinite) {
      return nativeAr;
    }
    return 1.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomImageGeometry &&
          runtimeType == other.runtimeType &&
          columns == other.columns &&
          rows == other.rows &&
          rowSpacing == other.rowSpacing &&
          columnSpacing == other.columnSpacing;

  @override
  int get hashCode =>
      columns.hashCode ^
      rows.hashCode ^
      rowSpacing.hashCode ^
      columnSpacing.hashCode;

  @override
  String toString() =>
      'DicomImageGeometry(columns: $columns, rows: $rows, rowSpacing: $rowSpacing, columnSpacing: $columnSpacing, hasPhysicalSpacing: $hasPhysicalSpacing, displayAspectRatio: $displayAspectRatio)';
}
