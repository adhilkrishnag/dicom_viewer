import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';
import 'data_element.dart';
import 'dicom_parser.dart';
import 'tag.dart';
import 'transfer_syntax.dart';

/// Wraps parsed DICOM elements into a structured Dataset with convenience accessors.
class DicomDataset {
  /// Creates a [DicomDataset] initialized with the provided [elements].
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

  /// Transfer Syntax UID (0002,0010). Defaults to Explicit VR Little Endian (`1.2.840.10008.1.2.1`) if absent.
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

  /// Study Date (0008,0020) formatted as YYYYMMDD. Defaults to empty string if absent.
  String get studyDate => getString(DicomTag.studyDate) ?? '';

  /// Modality (0008,0060) identifying the imaging modality (e.g., 'CT', 'MR', 'US'). Defaults to 'UNKNOWN' if absent.
  String get modality => getString(DicomTag.modality) ?? 'UNKNOWN';

  /// Study Description (0008,1030). Defaults to empty string if absent.
  String get studyDescription => getString(DicomTag.studyDescription) ?? '';

  /// Series Description (0008,103E). Defaults to empty string if absent.
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

  /// Number of Frames (0028,0008) in a multi-frame image. Defaults to 1 for single-frame images.
  int get numberOfFrames => getInt(DicomTag.numberOfFrames) ?? 1;

  /// Number of rows in the image matrix (0028,0010). Defaults to 0 if absent.
  int get rows => getInt(DicomTag.rows) ?? 0;

  /// Number of columns in the image matrix (0028,0011). Defaults to 0 if absent.
  int get columns => getInt(DicomTag.columns) ?? 0;

  /// Number of samples (color planes) per pixel (0028,0002). Typically 1 for grayscale/monochrome, 3 for RGB/YBR. Defaults to 1.
  int get samplesPerPixel => getInt(DicomTag.samplesPerPixel) ?? 1;

  /// Number of bits allocated for each pixel sample (0028,0100), e.g., 8, 16, or 32. Defaults to 16.
  int get bitsAllocated => getInt(DicomTag.bitsAllocated) ?? 16;

  /// Number of bits stored per pixel sample (0028,0101), e.g., 12 or 16. Defaults to [bitsAllocated].
  int get bitsStored => getInt(DicomTag.bitsStored) ?? bitsAllocated;

  /// Most significant bit position for pixel samples (0028,0102), 0-indexed. Defaults to `bitsStored - 1`.
  int get highBit => getInt(DicomTag.highBit) ?? (bitsStored - 1);

  /// Planar Configuration (0028,0006) for multi-sample images (0 = color-by-pixel RGBRGB..., 1 = color-by-plane RRR...GGG...BBB...). Defaults to 0.
  int get planarConfiguration => getInt(DicomTag.planarConfiguration) ?? 0;

  /// Pixel Padding Value (0028,0120) identifying background/padding pixels to suppress. Returns null if absent.
  int? get pixelPaddingValue => getInt(DicomTag.pixelPaddingValue);

  /// Pixel Padding Range Limit (0028,0121) defining the upper bound for pixel padding values. Returns null if absent.
  int? get pixelPaddingRangeLimit => getInt(DicomTag.pixelPaddingRangeLimit);

  /// Whether pixel data and dataset elements use Little Endian byte ordering.
  bool get isLittleEndian {
    final pixelElem = getElement(DicomTag.pixelData);
    if (pixelElem != null) return pixelElem.isLittleEndian;
    final syntax = TransferSyntaxDetails.fromUid(transferSyntaxUid);
    return syntax.isLittleEndian;
  }

  /// 0 = Unsigned integer, 1 = 2's Complement Signed integer (0028,0103).
  int get pixelRepresentation => getInt(DicomTag.pixelRepresentation) ?? 0;

  /// Whether stored pixel values are 2's complement signed integers (true when [pixelRepresentation] == 1).
  bool get isSigned => pixelRepresentation == 1;

  /// Photometric Interpretation (0028,0004) specifying the color space / grayscale model (e.g., 'MONOCHROME1', 'MONOCHROME2', 'RGB', 'PALETTE COLOR'). Defaults to 'MONOCHROME2'.
  String get photometricInterpretation =>
      getString(DicomTag.photometricInterpretation) ?? 'MONOCHROME2';

  // --- Rescale & Windowing Attributes ---

  /// Rescale Slope (0028,1053) for converting stored pixel values to output units (e.g., Hounsfield Units in CT). Defaults to 1.0.
  double get rescaleSlope => getDouble(DicomTag.rescaleSlope) ?? 1.0;

  /// Rescale Intercept (0028,1052) for converting stored pixel values to output units (e.g., Hounsfield Units in CT). Defaults to 0.0.
  double get rescaleIntercept => getDouble(DicomTag.rescaleIntercept) ?? 0.0;

  /// Default Window Center / brightness (0028,1050). Returns null if absent.
  double? get windowCenter {
    final elem = getElement(DicomTag.windowCenter);
    return elem?.asDouble;
  }

  /// Default Window Width / contrast (0028,1051). Returns null if absent.
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
