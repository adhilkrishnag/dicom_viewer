import '../parsing/dicom_dataset.dart';

/// Pixel structure metadata extracted from DICOM tags.
class PixelDataInfo {
  /// Creates a [PixelDataInfo] instance with specified image pixel parameters.
  const PixelDataInfo({
    required this.rows,
    required this.columns,
    required this.samplesPerPixel,
    required this.bitsAllocated,
    required this.bitsStored,
    required this.highBit,
    required this.isSigned,
    required this.photometricInterpretation,
    this.isLittleEndian = true,
    this.planarConfiguration = 0,
    this.pixelPaddingValue,
    this.pixelPaddingRangeLimit,
  });

  /// Extracts pixel metadata from a [DicomDataset].
  factory PixelDataInfo.fromDataset(DicomDataset dataset) {
    return PixelDataInfo(
      rows: dataset.rows,
      columns: dataset.columns,
      samplesPerPixel: dataset.samplesPerPixel,
      bitsAllocated: dataset.bitsAllocated,
      bitsStored: dataset.bitsStored,
      highBit: dataset.highBit,
      isSigned: dataset.isSigned,
      photometricInterpretation: dataset.photometricInterpretation,
      isLittleEndian: dataset.isLittleEndian,
      planarConfiguration: dataset.planarConfiguration,
      pixelPaddingValue: dataset.pixelPaddingValue,
      pixelPaddingRangeLimit: dataset.pixelPaddingRangeLimit,
    );
  }

  /// Number of rows in image matrix (0028,0010).
  final int rows;

  /// Number of columns in image matrix (0028,0011).
  final int columns;

  /// Number of color samples per pixel (0028,0002).
  final int samplesPerPixel;

  /// Number of bits allocated per sample (0028,0100).
  final int bitsAllocated;

  /// Number of bits stored per sample (0028,0101).
  final int bitsStored;

  /// Most significant bit position (0028,0102).
  final int highBit;

  /// Whether pixel values are signed 2's complement integers.
  final bool isSigned;

  /// Photometric Interpretation (0028,0004).
  final String photometricInterpretation;

  /// Whether pixel data bytes use Little Endian encoding.
  final bool isLittleEndian;

  /// Planar configuration (0028,0006) for multi-sample images (0=interleaved, 1=separate planes).
  final int planarConfiguration;

  /// Pixel Padding Value (0028,0120) for background suppression.
  final int? pixelPaddingValue;

  /// Pixel Padding Range Limit (0028,0121).
  final int? pixelPaddingRangeLimit;

  /// Total number of pixels in a single frame (`rows * columns`).
  int get totalPixels => rows * columns;
}
