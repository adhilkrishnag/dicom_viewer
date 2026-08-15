/// Represents a DICOM Data Element Tag, defined by a 16-bit group number
/// and a 16-bit element number (e.g., (0028, 0010) for Rows).
class DicomTag implements Comparable<DicomTag> {
  const DicomTag(this.group, this.element);

  /// 16-bit group number
  final int group;

  /// 16-bit element number
  final int element;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomTag &&
          runtimeType == other.runtimeType &&
          group == other.group &&
          element == other.element;

  @override
  int get hashCode => group.hashCode ^ element.hashCode;

  @override
  int compareTo(DicomTag other) {
    if (group != other.group) {
      return group.compareTo(other.group);
    }
    return element.compareTo(other.element);
  }

  @override
  String toString() {
    final gStr = group.toRadixString(16).padLeft(4, '0').toUpperCase();
    final eStr = element.toRadixString(16).padLeft(4, '0').toUpperCase();
    return '($gStr,$eStr)';
  }

  // --- Common DICOM Tags ---

  // Group 0002 - File Meta Information
  static const DicomTag fileMetaInformationGroupLength = DicomTag(
    0x0002,
    0x0000,
  );
  static const DicomTag fileMetaInformationVersion = DicomTag(0x0002, 0x0001);
  static const DicomTag mediaStorageSopClassUid = DicomTag(0x0002, 0x0002);
  static const DicomTag mediaStorageSopInstanceUid = DicomTag(0x0002, 0x0003);
  static const DicomTag transferSyntaxUid = DicomTag(0x0002, 0x0010);

  // Group 0008 - General Information
  static const DicomTag sopClassUid = DicomTag(0x0008, 0x0016);
  static const DicomTag sopInstanceUid = DicomTag(0x0008, 0x0018);
  static const DicomTag studyDate = DicomTag(0x0008, 0x0020);
  static const DicomTag seriesDate = DicomTag(0x0008, 0x0021);
  static const DicomTag acquisitionDate = DicomTag(0x0008, 0x0022);
  static const DicomTag contentDate = DicomTag(0x0008, 0x0023);
  static const DicomTag studyTime = DicomTag(0x0008, 0x0030);
  static const DicomTag seriesTime = DicomTag(0x0008, 0x0031);
  static const DicomTag acquisitionTime = DicomTag(0x0008, 0x0032);
  static const DicomTag modality = DicomTag(0x0008, 0x0060);
  static const DicomTag manufacturer = DicomTag(0x0008, 0x0070);
  static const DicomTag institutionName = DicomTag(0x0008, 0x0080);
  static const DicomTag studyDescription = DicomTag(0x0008, 0x1030);
  static const DicomTag seriesDescription = DicomTag(0x0008, 0x103E);

  // Group 0010 - Patient Identification
  static const DicomTag patientName = DicomTag(0x0010, 0x0010);
  static const DicomTag patientId = DicomTag(0x0010, 0x0020);
  static const DicomTag patientBirthDate = DicomTag(0x0010, 0x0030);
  static const DicomTag patientSex = DicomTag(0x0010, 0x0040);
  static const DicomTag patientAge = DicomTag(0x0010, 0x1010);

  // Group 0018 - Acquisition / Equipment
  static const DicomTag sliceThickness = DicomTag(0x0018, 0x0050);

  // Group 0020 - Relationship / Structure
  static const DicomTag studyInstanceUid = DicomTag(0x0020, 0x000D);
  static const DicomTag seriesInstanceUid = DicomTag(0x0020, 0x000E);
  static const DicomTag studyId = DicomTag(0x0020, 0x0010);
  static const DicomTag seriesNumber = DicomTag(0x0020, 0x0011);
  static const DicomTag instanceNumber = DicomTag(0x0020, 0x0013);

  // Group 0028 - Image Pixel Module
  static const DicomTag numberOfFrames = DicomTag(0x0028, 0x0008);
  static const DicomTag samplesPerPixel = DicomTag(0x0028, 0x0002);
  static const DicomTag photometricInterpretation = DicomTag(0x0028, 0x0004);
  static const DicomTag planarConfiguration = DicomTag(0x0028, 0x0006);
  static const DicomTag rows = DicomTag(0x0028, 0x0010);
  static const DicomTag columns = DicomTag(0x0028, 0x0011);
  static const DicomTag pixelSpacing = DicomTag(0x0028, 0x0030);
  static const DicomTag bitsAllocated = DicomTag(0x0028, 0x0100);
  static const DicomTag bitsStored = DicomTag(0x0028, 0x0101);
  static const DicomTag highBit = DicomTag(0x0028, 0x0102);
  static const DicomTag pixelRepresentation = DicomTag(0x0028, 0x0103);
  static const DicomTag pixelPaddingValue = DicomTag(0x0028, 0x0120);
  static const DicomTag pixelPaddingRangeLimit = DicomTag(0x0028, 0x0121);
  static const DicomTag smallestImagePixelValue = DicomTag(0x0028, 0x0106);
  static const DicomTag largestImagePixelValue = DicomTag(0x0028, 0x0107);

  // Group 0028 - Rescale & Windowing
  static const DicomTag rescaleIntercept = DicomTag(0x0028, 0x1052);
  static const DicomTag rescaleSlope = DicomTag(0x0028, 0x1053);
  static const DicomTag rescaleType = DicomTag(0x0028, 0x1054);
  static const DicomTag windowCenter = DicomTag(0x0028, 0x1050);
  static const DicomTag windowWidth = DicomTag(0x0028, 0x1051);
  static const DicomTag windowCenterWidthExplanation = DicomTag(0x0028, 0x1055);

  // Sequences
  static const DicomTag referencedStudySequence = DicomTag(0x0008, 0x1110);
  static const DicomTag referencedSeriesSequence = DicomTag(0x0008, 0x1115);
  static const DicomTag referencedImageSequence = DicomTag(0x0008, 0x1140);
  static const DicomTag requestAttributesSequence = DicomTag(0x0040, 0x0275);
  static const DicomTag contentSequence = DicomTag(0x0040, 0xA730);

  // Group 7FE0 - Pixel Data
  static const DicomTag pixelData = DicomTag(0x7FE0, 0x0010);
}
