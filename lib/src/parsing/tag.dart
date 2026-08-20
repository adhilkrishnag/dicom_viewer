/// Represents a DICOM Data Element Tag, defined by a 16-bit group number
/// and a 16-bit element number (e.g., (0028, 0010) for Rows).
class DicomTag implements Comparable<DicomTag> {
  /// Creates a [DicomTag] with the given 16-bit [group] and [element] numbers.
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

  /// (0002,0000) File Meta Information Group Length (VR: UL).
  static const DicomTag fileMetaInformationGroupLength = DicomTag(
    0x0002,
    0x0000,
  );

  /// (0002,0001) File Meta Information Version (VR: OB).
  static const DicomTag fileMetaInformationVersion = DicomTag(0x0002, 0x0001);

  /// (0002,0002) Media Storage SOP Class UID (VR: UI).
  static const DicomTag mediaStorageSopClassUid = DicomTag(0x0002, 0x0002);

  /// (0002,0003) Media Storage SOP Instance UID (VR: UI).
  static const DicomTag mediaStorageSopInstanceUid = DicomTag(0x0002, 0x0003);

  /// (0002,0010) Transfer Syntax UID (VR: UI).
  static const DicomTag transferSyntaxUid = DicomTag(0x0002, 0x0010);

  // Group 0008 - General Information

  /// (0008,0016) SOP Class UID (VR: UI).
  static const DicomTag sopClassUid = DicomTag(0x0008, 0x0016);

  /// (0008,0018) SOP Instance UID (VR: UI).
  static const DicomTag sopInstanceUid = DicomTag(0x0008, 0x0018);

  /// (0008,0020) Study Date (VR: DA).
  static const DicomTag studyDate = DicomTag(0x0008, 0x0020);

  /// (0008,0021) Series Date (VR: DA).
  static const DicomTag seriesDate = DicomTag(0x0008, 0x0021);

  /// (0008,0022) Acquisition Date (VR: DA).
  static const DicomTag acquisitionDate = DicomTag(0x0008, 0x0022);

  /// (0008,0023) Content Date (VR: DA).
  static const DicomTag contentDate = DicomTag(0x0008, 0x0023);

  /// (0008,0030) Study Time (VR: TM).
  static const DicomTag studyTime = DicomTag(0x0008, 0x0030);

  /// (0008,0031) Series Time (VR: TM).
  static const DicomTag seriesTime = DicomTag(0x0008, 0x0031);

  /// (0008,0032) Acquisition Time (VR: TM).
  static const DicomTag acquisitionTime = DicomTag(0x0008, 0x0032);

  /// (0008,0060) Modality (VR: CS).
  static const DicomTag modality = DicomTag(0x0008, 0x0060);

  /// (0008,0070) Manufacturer (VR: LO).
  static const DicomTag manufacturer = DicomTag(0x0008, 0x0070);

  /// (0008,0080) Institution Name (VR: LO).
  static const DicomTag institutionName = DicomTag(0x0008, 0x0080);

  /// (0008,1030) Study Description (VR: LO).
  static const DicomTag studyDescription = DicomTag(0x0008, 0x1030);

  /// (0008,103E) Series Description (VR: LO).
  static const DicomTag seriesDescription = DicomTag(0x0008, 0x103E);

  // Group 0010 - Patient Identification

  /// (0010,0010) Patient's Name (VR: PN).
  static const DicomTag patientName = DicomTag(0x0010, 0x0010);

  /// (0010,0020) Patient ID (VR: LO).
  static const DicomTag patientId = DicomTag(0x0010, 0x0020);

  /// (0010,0030) Patient's Birth Date (VR: DA).
  static const DicomTag patientBirthDate = DicomTag(0x0010, 0x0030);

  /// (0010,0040) Patient's Sex (VR: CS).
  static const DicomTag patientSex = DicomTag(0x0010, 0x0040);

  /// (0010,1010) Patient's Age (VR: AS).
  static const DicomTag patientAge = DicomTag(0x0010, 0x1010);

  // Group 0018 - Acquisition / Equipment

  /// (0018,0050) Slice Thickness (VR: DS) in millimeters.
  static const DicomTag sliceThickness = DicomTag(0x0018, 0x0050);

  // Group 0020 - Relationship / Structure

  /// (0020,000D) Study Instance UID (VR: UI).
  static const DicomTag studyInstanceUid = DicomTag(0x0020, 0x000D);

  /// (0020,000E) Series Instance UID (VR: UI).
  static const DicomTag seriesInstanceUid = DicomTag(0x0020, 0x000E);

  /// (0020,0010) Study ID (VR: SH).
  static const DicomTag studyId = DicomTag(0x0020, 0x0010);

  /// (0020,0011) Series Number (VR: IS).
  static const DicomTag seriesNumber = DicomTag(0x0020, 0x0011);

  /// (0020,0013) Instance Number (VR: IS).
  static const DicomTag instanceNumber = DicomTag(0x0020, 0x0013);

  // Group 0028 - Image Pixel Module

  /// (0028,0008) Number of Frames (VR: IS).
  static const DicomTag numberOfFrames = DicomTag(0x0028, 0x0008);

  /// (0028,0002) Samples per Pixel (VR: US).
  static const DicomTag samplesPerPixel = DicomTag(0x0028, 0x0002);

  /// (0028,0004) Photometric Interpretation (VR: CS).
  static const DicomTag photometricInterpretation = DicomTag(0x0028, 0x0004);

  /// (0028,0006) Planar Configuration (VR: US).
  static const DicomTag planarConfiguration = DicomTag(0x0028, 0x0006);

  /// (0028,0010) Rows (VR: US).
  static const DicomTag rows = DicomTag(0x0028, 0x0010);

  /// (0028,0011) Columns (VR: US).
  static const DicomTag columns = DicomTag(0x0028, 0x0011);

  /// (0028,0030) Pixel Spacing (VR: DS) [row spacing, column spacing] in mm.
  static const DicomTag pixelSpacing = DicomTag(0x0028, 0x0030);

  /// (0028,0100) Bits Allocated (VR: US).
  static const DicomTag bitsAllocated = DicomTag(0x0028, 0x0100);

  /// (0028,0101) Bits Stored (VR: US).
  static const DicomTag bitsStored = DicomTag(0x0028, 0x0101);

  /// (0028,0102) High Bit (VR: US).
  static const DicomTag highBit = DicomTag(0x0028, 0x0102);

  /// (0028,0103) Pixel Representation (VR: US, 0=unsigned, 1=signed).
  static const DicomTag pixelRepresentation = DicomTag(0x0028, 0x0103);

  /// (0028,0120) Pixel Padding Value (VR: US or SS).
  static const DicomTag pixelPaddingValue = DicomTag(0x0028, 0x0120);

  /// (0028,0121) Pixel Padding Range Limit (VR: US or SS).
  static const DicomTag pixelPaddingRangeLimit = DicomTag(0x0028, 0x0121);

  /// (0028,0106) Smallest Image Pixel Value (VR: US or SS).
  static const DicomTag smallestImagePixelValue = DicomTag(0x0028, 0x0106);

  /// (0028,0107) Largest Image Pixel Value (VR: US or SS).
  static const DicomTag largestImagePixelValue = DicomTag(0x0028, 0x0107);

  // Group 0028 - Rescale & Windowing

  /// (0028,1052) Rescale Intercept (VR: DS).
  static const DicomTag rescaleIntercept = DicomTag(0x0028, 0x1052);

  /// (0028,1053) Rescale Slope (VR: DS).
  static const DicomTag rescaleSlope = DicomTag(0x0028, 0x1053);

  /// (0028,1054) Rescale Type (VR: LO).
  static const DicomTag rescaleType = DicomTag(0x0028, 0x1054);

  /// (0028,1050) Window Center (VR: DS).
  static const DicomTag windowCenter = DicomTag(0x0028, 0x1050);

  /// (0028,1051) Window Width (VR: DS).
  static const DicomTag windowWidth = DicomTag(0x0028, 0x1051);

  /// (0028,1055) Window Center & Width Explanation (VR: LO).
  static const DicomTag windowCenterWidthExplanation = DicomTag(0x0028, 0x1055);

  // Group 0028 - Palette Color Lookup Table

  /// (0028,1101) Red Palette Color Lookup Table Descriptor (VR: US or SS).
  static const DicomTag redPaletteColorLookupTableDescriptor = DicomTag(
    0x0028,
    0x1101,
  );

  /// (0028,1102) Green Palette Color Lookup Table Descriptor (VR: US or SS).
  static const DicomTag greenPaletteColorLookupTableDescriptor = DicomTag(
    0x0028,
    0x1102,
  );

  /// (0028,1103) Blue Palette Color Lookup Table Descriptor (VR: US or SS).
  static const DicomTag bluePaletteColorLookupTableDescriptor = DicomTag(
    0x0028,
    0x1103,
  );

  /// (0028,1201) Red Palette Color Lookup Table Data (VR: OW).
  static const DicomTag redPaletteColorLookupTableData = DicomTag(
    0x0028,
    0x1201,
  );

  /// (0028,1202) Green Palette Color Lookup Table Data (VR: OW).
  static const DicomTag greenPaletteColorLookupTableData = DicomTag(
    0x0028,
    0x1202,
  );

  /// (0028,1203) Blue Palette Color Lookup Table Data (VR: OW).
  static const DicomTag bluePaletteColorLookupTableData = DicomTag(
    0x0028,
    0x1203,
  );

  /// (0028,1221) Segmented Red Palette Color Lookup Table Data (VR: OW).
  static const DicomTag segmentedRedPaletteColorLookupTableData = DicomTag(
    0x0028,
    0x1221,
  );

  /// (0028,1222) Segmented Green Palette Color Lookup Table Data (VR: OW).
  static const DicomTag segmentedGreenPaletteColorLookupTableData = DicomTag(
    0x0028,
    0x1222,
  );

  /// (0028,1223) Segmented Blue Palette Color Lookup Table Data (VR: OW).
  static const DicomTag segmentedBluePaletteColorLookupTableData = DicomTag(
    0x0028,
    0x1223,
  );

  /// (0028,1104) Alpha Palette Color Lookup Table Descriptor (VR: US or SS).
  static const DicomTag alphaPaletteColorLookupTableDescriptor = DicomTag(
    0x0028,
    0x1104,
  );

  /// (0028,1204) Alpha Palette Color Lookup Table Data (VR: OW).
  static const DicomTag alphaPaletteColorLookupTableData = DicomTag(
    0x0028,
    0x1204,
  );

  /// (0028,140B) Enhanced Palette Color Lookup Table Sequence (VR: SQ).
  static const DicomTag enhancedPaletteColorLookupTableSequence = DicomTag(
    0x0028,
    0x140B,
  );

  // Sequences

  /// (0008,1110) Referenced Study Sequence (VR: SQ).
  static const DicomTag referencedStudySequence = DicomTag(0x0008, 0x1110);

  /// (0008,1115) Referenced Series Sequence (VR: SQ).
  static const DicomTag referencedSeriesSequence = DicomTag(0x0008, 0x1115);

  /// (0008,1140) Referenced Image Sequence (VR: SQ).
  static const DicomTag referencedImageSequence = DicomTag(0x0008, 0x1140);

  /// (0040,0275) Request Attributes Sequence (VR: SQ).
  static const DicomTag requestAttributesSequence = DicomTag(0x0040, 0x0275);

  /// (0040,A730) Content Sequence (VR: SQ).
  static const DicomTag contentSequence = DicomTag(0x0040, 0xA730);

  // Group 7FE0 - Pixel Data

  /// (7FE0,0010) Pixel Data (VR: OB or OW).
  static const DicomTag pixelData = DicomTag(0x7FE0, 0x0010);
}
