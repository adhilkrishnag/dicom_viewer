import '../parsing/dicom_dataset.dart';

/// Pixel structure metadata extracted from DICOM tags.
class PixelDataInfo {
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
  });

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
    );
  }

  final int rows;
  final int columns;
  final int samplesPerPixel;
  final int bitsAllocated;
  final int bitsStored;
  final int highBit;
  final bool isSigned;
  final String photometricInterpretation;
  final bool isLittleEndian;
  final int planarConfiguration;

  int get totalPixels => rows * columns;
}
