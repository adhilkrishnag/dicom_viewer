import '../parsing/dicom_dataset.dart';
import '../parsing/tag.dart';

/// Private tag for (0028,0034) Pixel Aspect Ratio.
const _pixelAspectRatioTag = DicomTag(0x0028, 0x0034);

/// Internal classification of the origin of 2D image geometry.
enum _GeometrySource {
  /// Geometry derived from explicit Pixel Spacing (0028,0030).
  explicitPixelSpacing,

  /// Geometry derived from Pixel Aspect Ratio (0028,0034) for display only.
  pixelAspectRatioOnly,

  /// Geometry derived from native pixel matrix dimensions (Rows/Columns) only.
  nativeMatrixOnly,
}

/// Internal classification of geometry quality and measurement validity.
enum _GeometryQuality {
  /// Valid, verified physical in-plane millimeter calibration.
  verifiedPhysical,

  /// Relative display-only geometry (e.g. Pixel Aspect Ratio). No physical scale.
  displayOnly,

  /// Pixel-matrix geometry without physical or aspect ratio calibration.
  pixelOnly,

  /// Image geometry is unavailable or invalid (e.g. missing/zero rows or columns).
  unavailable,
}

/// Internal 2D image geometry abstraction representing pixel matrix dimensions,
/// in-plane physical spacing, and display aspect ratio.
///
/// Distinguishes:
/// - Native pixel dimensions ([columns], [rows])
/// - Physical in-plane dimensions ([physicalWidthMm], [physicalHeightMm])
/// - Display aspect ratio ([displayAspectRatio])
class DicomImageGeometry {
  /// Creates a [DicomImageGeometry] with explicit dimensions, optional spacing,
  /// and optional pixel aspect ratio.
  const DicomImageGeometry({
    required this.columns,
    required this.rows,
    this.rowSpacing,
    this.columnSpacing,
    List<int>? pixelAspectRatio,
  }) : _pixelAspectRatio = pixelAspectRatio,
       _source =
           (columns <= 0 || rows <= 0
               ? null
               : (rowSpacing != null &&
                       columnSpacing != null &&
                       rowSpacing > 0 &&
                       columnSpacing > 0
                   ? _GeometrySource.explicitPixelSpacing
                   : (pixelAspectRatio != null
                       ? _GeometrySource.pixelAspectRatioOnly
                       : _GeometrySource.nativeMatrixOnly))),
       _quality =
           (columns <= 0 || rows <= 0
               ? _GeometryQuality.unavailable
               : (rowSpacing != null &&
                       columnSpacing != null &&
                       rowSpacing > 0 &&
                       columnSpacing > 0
                   ? _GeometryQuality.verifiedPhysical
                   : (pixelAspectRatio != null
                       ? _GeometryQuality.displayOnly
                       : _GeometryQuality.pixelOnly)));

  /// Extracts 2D image geometry from a [DicomDataset].
  ///
  /// Extracts [DicomDataset.columns], [DicomDataset.rows], [DicomDataset.pixelSpacing] (0028,0030),
  /// and (0028,0034) Pixel Aspect Ratio.
  ///
  /// Resolution Hierarchy:
  /// 1. **Unavailable:** If rows <= 0 or columns <= 0, quality is `unavailable`.
  /// 2. **Verified Physical:** If Pixel Spacing (0028,0030) has 2 valid, positive, finite values,
  ///    source is `explicitPixelSpacing` and quality is `verifiedPhysical`.
  /// 3. **Display Only:** If Pixel Spacing is unavailable/invalid, but Pixel Aspect Ratio (0028,0034)
  ///    has 2 valid positive integers, source is `pixelAspectRatioOnly` and quality is `displayOnly`.
  /// 4. **Pixel Only:** If both physical spacing and pixel aspect ratio are unavailable,
  ///    source is `nativeMatrixOnly` and quality is `pixelOnly`.
  factory DicomImageGeometry.fromDataset(DicomDataset dataset) {
    final cols = dataset.columns;
    final rows = dataset.rows;

    if (cols <= 0 || rows <= 0) {
      return DicomImageGeometry(columns: cols, rows: rows);
    }

    final spacing = dataset.pixelSpacing;
    if (spacing != null && spacing.length == 2) {
      final r = spacing[0];
      final c = spacing[1];
      if (r > 0 && c > 0 && r.isFinite && c.isFinite) {
        return DicomImageGeometry(
          columns: cols,
          rows: rows,
          rowSpacing: r,
          columnSpacing: c,
        );
      }
    }

    final parStrings = dataset.getStringList(_pixelAspectRatioTag);
    if (parStrings != null && parStrings.length == 2) {
      final v = int.tryParse(parStrings[0]);
      final h = int.tryParse(parStrings[1]);
      if (v != null && h != null && v > 0 && h > 0) {
        return DicomImageGeometry(
          columns: cols,
          rows: rows,
          pixelAspectRatio: [v, h],
        );
      }
    }

    return DicomImageGeometry(columns: cols, rows: rows);
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

  final List<int>? _pixelAspectRatio;
  final _GeometrySource? _source;
  final _GeometryQuality _quality;

  /// Whether valid, positive, finite physical pixel spacing is available.
  bool get hasPhysicalSpacing =>
      _quality == _GeometryQuality.verifiedPhysical &&
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

  /// Display aspect ratio (width / height) preserving physical pixel geometry or display aspect ratio.
  ///
  /// - For verified physical spacing: `(columns * columnSpacing) / (rows * rowSpacing)`
  /// - For display-only pixel aspect ratio: `(columns * par[1]) / (rows * par[0])`
  /// - For native pixel matrix: `columns / rows`
  /// - For unavailable geometry: `1.0`
  double get displayAspectRatio {
    if (columns <= 0 || rows <= 0 || _quality == _GeometryQuality.unavailable) {
      return 1.0;
    }

    if (_quality == _GeometryQuality.verifiedPhysical) {
      final pw = physicalWidthMm;
      final ph = physicalHeightMm;
      if (pw != null && ph != null && ph > 0) {
        final ar = pw / ph;
        if (ar > 0 && ar.isFinite) {
          return ar;
        }
      }
    } else if (_quality == _GeometryQuality.displayOnly &&
        _pixelAspectRatio != null) {
      final v = _pixelAspectRatio[0];
      final h = _pixelAspectRatio[1];
      if (v > 0 && h > 0) {
        final ar = (columns * h) / (rows * v);
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
          columnSpacing == other.columnSpacing &&
          _source == other._source &&
          _quality == other._quality;

  @override
  int get hashCode =>
      columns.hashCode ^
      rows.hashCode ^
      rowSpacing.hashCode ^
      columnSpacing.hashCode ^
      _source.hashCode ^
      _quality.hashCode;

  @override
  String toString() =>
      'DicomImageGeometry(columns: $columns, rows: $rows, rowSpacing: $rowSpacing, columnSpacing: $columnSpacing, source: $_source, quality: $_quality, hasPhysicalSpacing: $hasPhysicalSpacing, displayAspectRatio: $displayAspectRatio)';
}
