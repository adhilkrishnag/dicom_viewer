import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';
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

  /// Get list of double values for multi-valued tag (e.g. DS with '\\'), or null if tag is absent.
  List<double>? getDoubleList(DicomTag tag) {
    final elem = getElement(tag);
    if (elem == null || elem.valueBytes.isEmpty) return null;
    return elem.asDoubleList;
  }

  /// Get list of string values for multi-valued tag (e.g. separated by '\\'), or null if tag is absent.
  List<String>? getStringList(DicomTag tag) {
    final elem = getElement(tag);
    if (elem == null || elem.valueBytes.isEmpty) return null;
    return elem.asStringList;
  }

  // --- Convenience Metadata Getters ---

  String get transferSyntaxUid =>
      getString(DicomTag.transferSyntaxUid) ??
      TransferSyntax.explicitVRLittleEndian;

  /// Patient's Name (0010,0010). Defaults to 'Anonymous' if absent.
  ///
  /// Note: This attribute may contain Protected Health Information (PHI) in clinical datasets.
  String get patientName => getString(DicomTag.patientName) ?? 'Anonymous';

  /// Patient ID (0010,0020). Defaults to empty string if absent.
  ///
  /// Note: This attribute may contain Protected Health Information (PHI) in clinical datasets.
  String get patientId => getString(DicomTag.patientId) ?? '';

  String get studyDate => getString(DicomTag.studyDate) ?? '';
  String get modality => getString(DicomTag.modality) ?? 'UNKNOWN';
  String get studyDescription => getString(DicomTag.studyDescription) ?? '';
  String get seriesDescription => getString(DicomTag.seriesDescription) ?? '';

  // --- Study Level ---

  /// Study Instance UID (0020,000D). Unique identifier for the Study.
  /// Returns null if absent.
  String? get studyInstanceUid => getString(DicomTag.studyInstanceUid);

  /// Study Time (0008,0030) formatted as HHMMSS.FFFFFF.
  /// Returns null if absent.
  String? get studyTime => getString(DicomTag.studyTime);

  // --- Series Level ---

  /// Series Instance UID (0020,000E). Unique identifier for the Series.
  /// Returns null if absent.
  String? get seriesInstanceUid => getString(DicomTag.seriesInstanceUid);

  /// Series Number (0020,0011). Integer number identifying the Series.
  /// Returns null if absent.
  int? get seriesNumber => getInt(DicomTag.seriesNumber);

  // --- Instance Level ---

  /// SOP Class UID (0008,0016). Unique identifier for the SOP Class.
  /// Returns null if absent.
  String? get sopClassUid => getString(DicomTag.sopClassUid);

  /// SOP Instance UID (0008,0018). Unique identifier for the SOP Instance.
  /// Returns null if absent.
  String? get sopInstanceUid => getString(DicomTag.sopInstanceUid);

  /// Instance Number (0020,0013). Integer number identifying the Instance / slice.
  /// Returns null if absent.
  int? get instanceNumber => getInt(DicomTag.instanceNumber);

  // --- Acquisition & Institution ---

  /// Acquisition Date (0008,0022) formatted as YYYYMMDD.
  /// Returns null if absent.
  String? get acquisitionDate => getString(DicomTag.acquisitionDate);

  /// Acquisition Time (0008,0032) formatted as HHMMSS.FFFFFF.
  /// Returns null if absent.
  String? get acquisitionTime => getString(DicomTag.acquisitionTime);

  /// Institution Name (0008,0080).
  /// Returns null if absent.
  String? get institutionName => getString(DicomTag.institutionName);

  /// Manufacturer (0008,0070) of the equipment that produced the composite instances.
  /// Returns null if absent.
  String? get manufacturer => getString(DicomTag.manufacturer);

  // --- Geometry Metadata ---

  /// Physical distance between the center of each pixel, specified by a numeric pair:
  /// `[Row Spacing (vertical), Column Spacing (horizontal)]` in millimeters.
  ///
  /// Tag: (0028,0030).
  /// Returns `null` if the attribute is absent, empty, or malformed (does not contain
  /// exactly two valid floating point numbers).
  List<double>? get pixelSpacing {
    final elem = getElement(DicomTag.pixelSpacing);
    if (elem == null || elem.valueBytes.isEmpty) return null;
    final rawList = elem.asStringList;
    if (rawList.length != 2) return null;
    final row = double.tryParse(rawList[0]);
    final col = double.tryParse(rawList[1]);
    if (row == null || col == null) return null;
    return [row, col];
  }

  /// Slice Thickness (0018,0050) in millimeters.
  /// Returns null if absent.
  double? get sliceThickness => getDouble(DicomTag.sliceThickness);

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

  /// Internal encapsulated pixel data container.
  EncapsulatedPixelData? get encapsulatedData =>
      getElement(DicomTag.pixelData)?.encapsulatedData;

  /// Raw pixel data bytes. Derived lazily for encapsulated data.
  Uint8List? get pixelDataBytes {
    final enc = encapsulatedData;
    if (enc != null) return enc.flatBytes;
    return getElement(DicomTag.pixelData)?.valueBytes;
  }
}
