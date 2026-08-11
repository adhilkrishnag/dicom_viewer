import 'dart:typed_data';

import 'data_element.dart';
import 'dicom_parser.dart';
import 'tag.dart';
import 'transfer_syntax.dart';

/// Wraps parsed DICOM elements into a structured Dataset with convenience accessors.
class DicomDataset {
  DicomDataset(Iterable<DicomDataElement> elements)
    : _elements = {for (final e in elements) e.tag: e};

  /// Parse DICOM binary bytes into a [DicomDataset].
  factory DicomDataset.fromBytes(Uint8List bytes) {
    const parser = DicomParser();
    final elements = parser.parse(bytes);
    return DicomDataset(elements);
  }

  final Map<DicomTag, DicomDataElement> _elements;

  /// All parsed data elements mapped by tag.
  Map<DicomTag, DicomDataElement> get elements => Map.unmodifiable(_elements);

  /// Get element for tag, or null if not present.
  DicomDataElement? getElement(DicomTag tag) => _elements[tag];

  /// Get string value for tag.
  String? getString(DicomTag tag) => getElement(tag)?.asString;

  /// Get integer value for tag.
  int? getInt(DicomTag tag) => getElement(tag)?.asInt;

  /// Get double value for tag.
  double? getDouble(DicomTag tag) => getElement(tag)?.asDouble;

  // --- Convenience Metadata Getters ---

  String get transferSyntaxUid =>
      getString(DicomTag.transferSyntaxUid) ??
      TransferSyntax.explicitVRLittleEndian;

  String get patientName => getString(DicomTag.patientName) ?? 'Anonymous';
  String get patientId => getString(DicomTag.patientId) ?? '';
  String get studyDate => getString(DicomTag.studyDate) ?? '';
  String get modality => getString(DicomTag.modality) ?? 'UNKNOWN';
  String get studyDescription => getString(DicomTag.studyDescription) ?? '';
  String get seriesDescription => getString(DicomTag.seriesDescription) ?? '';

  // --- Image Pixel Attributes ---

  int get numberOfFrames => getInt(DicomTag.numberOfFrames) ?? 1;
  int get rows => getInt(DicomTag.rows) ?? 0;
  int get columns => getInt(DicomTag.columns) ?? 0;
  int get samplesPerPixel => getInt(DicomTag.samplesPerPixel) ?? 1;
  int get bitsAllocated => getInt(DicomTag.bitsAllocated) ?? 16;
  int get bitsStored => getInt(DicomTag.bitsStored) ?? bitsAllocated;
  int get highBit => getInt(DicomTag.highBit) ?? (bitsStored - 1);

  int get planarConfiguration => getInt(DicomTag.planarConfiguration) ?? 0;

  int? get pixelPaddingValue => getInt(DicomTag.pixelPaddingValue);
  int? get pixelPaddingRangeLimit => getInt(DicomTag.pixelPaddingRangeLimit);

  bool get isLittleEndian {
    final pixelElem = getElement(DicomTag.pixelData);
    if (pixelElem != null) return pixelElem.isLittleEndian;
    final syntax = TransferSyntaxDetails.fromUid(transferSyntaxUid);
    return syntax.isLittleEndian;
  }

  /// 0 = Unsigned integer, 1 = 2's Complement Signed integer
  int get pixelRepresentation => getInt(DicomTag.pixelRepresentation) ?? 0;
  bool get isSigned => pixelRepresentation == 1;

  String get photometricInterpretation =>
      getString(DicomTag.photometricInterpretation) ?? 'MONOCHROME2';

  // --- Rescale & Windowing Attributes ---

  double get rescaleSlope => getDouble(DicomTag.rescaleSlope) ?? 1.0;
  double get rescaleIntercept => getDouble(DicomTag.rescaleIntercept) ?? 0.0;

  double? get windowCenter {
    final elem = getElement(DicomTag.windowCenter);
    return elem?.asDouble;
  }

  double? get windowWidth {
    final elem = getElement(DicomTag.windowWidth);
    return elem?.asDouble;
  }

  /// List of multi-valued Window Center clinical presets (e.g. Brain, Bone).
  List<double> get windowCenterPresets {
    final elem = getElement(DicomTag.windowCenter);
    return elem?.asDoubleList ?? const [];
  }

  /// List of multi-valued Window Width clinical presets (e.g. Brain, Bone).
  List<double> get windowWidthPresets {
    final elem = getElement(DicomTag.windowWidth);
    return elem?.asDoubleList ?? const [];
  }

  /// Raw pixel data bytes.
  Uint8List? get pixelDataBytes => getElement(DicomTag.pixelData)?.valueBytes;
}
