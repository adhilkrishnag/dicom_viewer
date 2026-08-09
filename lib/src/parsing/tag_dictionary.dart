import 'tag.dart';
import 'value_representation.dart';

/// Tag definition metadata.
class TagInfo {
  const TagInfo({
    required this.tag,
    required this.name,
    required this.vr,
    this.keyword = '',
  });

  final DicomTag tag;
  final String name;
  final ValueRepresentation vr;
  final String keyword;
}

/// Static dictionary of essential standard DICOM tags for Implicit VR lookup.
class TagDictionary {
  static final Map<DicomTag, TagInfo> _entries = {
    // Group 0002 File Meta Info
    DicomTag.fileMetaInformationGroupLength: const TagInfo(
      tag: DicomTag.fileMetaInformationGroupLength,
      name: 'File Meta Information Group Length',
      vr: ValueRepresentation.ul,
      keyword: 'FileMetaInformationGroupLength',
    ),
    DicomTag.fileMetaInformationVersion: const TagInfo(
      tag: DicomTag.fileMetaInformationVersion,
      name: 'File Meta Information Version',
      vr: ValueRepresentation.ob,
      keyword: 'FileMetaInformationVersion',
    ),
    DicomTag.mediaStorageSopClassUid: const TagInfo(
      tag: DicomTag.mediaStorageSopClassUid,
      name: 'Media Storage SOP Class UID',
      vr: ValueRepresentation.ui,
      keyword: 'MediaStorageSOPClassUID',
    ),
    DicomTag.mediaStorageSopInstanceUid: const TagInfo(
      tag: DicomTag.mediaStorageSopInstanceUid,
      name: 'Media Storage SOP Instance UID',
      vr: ValueRepresentation.ui,
      keyword: 'MediaStorageSOPInstanceUID',
    ),
    DicomTag.transferSyntaxUid: const TagInfo(
      tag: DicomTag.transferSyntaxUid,
      name: 'Transfer Syntax UID',
      vr: ValueRepresentation.ui,
      keyword: 'TransferSyntaxUID',
    ),

    // Group 0008 General
    DicomTag.studyDate: const TagInfo(
      tag: DicomTag.studyDate,
      name: 'Study Date',
      vr: ValueRepresentation.da,
      keyword: 'StudyDate',
    ),
    DicomTag.seriesDate: const TagInfo(
      tag: DicomTag.seriesDate,
      name: 'Series Date',
      vr: ValueRepresentation.da,
      keyword: 'SeriesDate',
    ),
    DicomTag.studyTime: const TagInfo(
      tag: DicomTag.studyTime,
      name: 'Study Time',
      vr: ValueRepresentation.tm,
      keyword: 'StudyTime',
    ),
    DicomTag.seriesTime: const TagInfo(
      tag: DicomTag.seriesTime,
      name: 'Series Time',
      vr: ValueRepresentation.tm,
      keyword: 'SeriesTime',
    ),
    DicomTag.modality: const TagInfo(
      tag: DicomTag.modality,
      name: 'Modality',
      vr: ValueRepresentation.cs,
      keyword: 'Modality',
    ),
    DicomTag.manufacturer: const TagInfo(
      tag: DicomTag.manufacturer,
      name: 'Manufacturer',
      vr: ValueRepresentation.lo,
      keyword: 'Manufacturer',
    ),
    DicomTag.institutionName: const TagInfo(
      tag: DicomTag.institutionName,
      name: 'Institution Name',
      vr: ValueRepresentation.lo,
      keyword: 'InstitutionName',
    ),
    DicomTag.studyDescription: const TagInfo(
      tag: DicomTag.studyDescription,
      name: 'Study Description',
      vr: ValueRepresentation.lo,
      keyword: 'StudyDescription',
    ),
    DicomTag.seriesDescription: const TagInfo(
      tag: DicomTag.seriesDescription,
      name: 'Series Description',
      vr: ValueRepresentation.lo,
      keyword: 'SeriesDescription',
    ),

    // Group 0010 Patient
    DicomTag.patientName: const TagInfo(
      tag: DicomTag.patientName,
      name: "Patient's Name",
      vr: ValueRepresentation.pn,
      keyword: 'PatientName',
    ),
    DicomTag.patientId: const TagInfo(
      tag: DicomTag.patientId,
      name: 'Patient ID',
      vr: ValueRepresentation.lo,
      keyword: 'PatientID',
    ),
    DicomTag.patientBirthDate: const TagInfo(
      tag: DicomTag.patientBirthDate,
      name: "Patient's Birth Date",
      vr: ValueRepresentation.da,
      keyword: 'PatientBirthDate',
    ),
    DicomTag.patientSex: const TagInfo(
      tag: DicomTag.patientSex,
      name: "Patient's Sex",
      vr: ValueRepresentation.cs,
      keyword: 'PatientSex',
    ),

    // Group 0020 Relationship
    DicomTag.studyInstanceUid: const TagInfo(
      tag: DicomTag.studyInstanceUid,
      name: 'Study Instance UID',
      vr: ValueRepresentation.ui,
      keyword: 'StudyInstanceUID',
    ),
    DicomTag.seriesInstanceUid: const TagInfo(
      tag: DicomTag.seriesInstanceUid,
      name: 'Series Instance UID',
      vr: ValueRepresentation.ui,
      keyword: 'SeriesInstanceUID',
    ),
    DicomTag.seriesNumber: const TagInfo(
      tag: DicomTag.seriesNumber,
      name: 'Series Number',
      vr: ValueRepresentation.isVR,
      keyword: 'SeriesNumber',
    ),
    DicomTag.instanceNumber: const TagInfo(
      tag: DicomTag.instanceNumber,
      name: 'Instance Number',
      vr: ValueRepresentation.isVR,
      keyword: 'InstanceNumber',
    ),

    // Group 0028 Image Pixel
    DicomTag.samplesPerPixel: const TagInfo(
      tag: DicomTag.samplesPerPixel,
      name: 'Samples per Pixel',
      vr: ValueRepresentation.us,
      keyword: 'SamplesPerPixel',
    ),
    DicomTag.photometricInterpretation: const TagInfo(
      tag: DicomTag.photometricInterpretation,
      name: 'Photometric Interpretation',
      vr: ValueRepresentation.cs,
      keyword: 'PhotometricInterpretation',
    ),
    DicomTag.planarConfiguration: const TagInfo(
      tag: DicomTag.planarConfiguration,
      name: 'Planar Configuration',
      vr: ValueRepresentation.us,
      keyword: 'PlanarConfiguration',
    ),
    DicomTag.rows: const TagInfo(
      tag: DicomTag.rows,
      name: 'Rows',
      vr: ValueRepresentation.us,
      keyword: 'Rows',
    ),
    DicomTag.columns: const TagInfo(
      tag: DicomTag.columns,
      name: 'Columns',
      vr: ValueRepresentation.us,
      keyword: 'Columns',
    ),
    DicomTag.bitsAllocated: const TagInfo(
      tag: DicomTag.bitsAllocated,
      name: 'Bits Allocated',
      vr: ValueRepresentation.us,
      keyword: 'BitsAllocated',
    ),
    DicomTag.bitsStored: const TagInfo(
      tag: DicomTag.bitsStored,
      name: 'Bits Stored',
      vr: ValueRepresentation.us,
      keyword: 'BitsStored',
    ),
    DicomTag.highBit: const TagInfo(
      tag: DicomTag.highBit,
      name: 'High Bit',
      vr: ValueRepresentation.us,
      keyword: 'HighBit',
    ),
    DicomTag.pixelRepresentation: const TagInfo(
      tag: DicomTag.pixelRepresentation,
      name: 'Pixel Representation',
      vr: ValueRepresentation.us,
      keyword: 'PixelRepresentation',
    ),
    DicomTag.rescaleIntercept: const TagInfo(
      tag: DicomTag.rescaleIntercept,
      name: 'Rescale Intercept',
      vr: ValueRepresentation.ds,
      keyword: 'RescaleIntercept',
    ),
    DicomTag.rescaleSlope: const TagInfo(
      tag: DicomTag.rescaleSlope,
      name: 'Rescale Slope',
      vr: ValueRepresentation.ds,
      keyword: 'RescaleSlope',
    ),
    DicomTag.rescaleType: const TagInfo(
      tag: DicomTag.rescaleType,
      name: 'Rescale Type',
      vr: ValueRepresentation.lo,
      keyword: 'RescaleType',
    ),
    DicomTag.windowCenter: const TagInfo(
      tag: DicomTag.windowCenter,
      name: 'Window Center',
      vr: ValueRepresentation.ds,
      keyword: 'WindowCenter',
    ),
    DicomTag.windowWidth: const TagInfo(
      tag: DicomTag.windowWidth,
      name: 'Window Width',
      vr: ValueRepresentation.ds,
      keyword: 'WindowWidth',
    ),

    // Group 7FE0 Pixel Data
    DicomTag.pixelData: const TagInfo(
      tag: DicomTag.pixelData,
      name: 'Pixel Data',
      vr: ValueRepresentation.ow,
      keyword: 'PixelData',
    ),
  };

  /// Lookup VR for a tag. Returns UN if tag is unknown.
  static ValueRepresentation getVR(DicomTag tag) {
    // Meta information (Group 0002) is always Explicit VR Little Endian per DICOM standard
    final info = _entries[tag];
    if (info != null) return info.vr;

    // Group length tags (x, 0000) are always UL
    if (tag.element == 0x0000) return ValueRepresentation.ul;

    return ValueRepresentation.un;
  }

  /// Lookup TagInfo for a tag.
  static TagInfo? lookup(DicomTag tag) => _entries[tag];
}
