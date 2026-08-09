import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TagDictionary', () {
    test('Lookups standard DICOM tags correctly', () {
      expect(TagDictionary.getVR(DicomTag.rows), ValueRepresentation.us);
      expect(TagDictionary.getVR(DicomTag.columns), ValueRepresentation.us);
      expect(TagDictionary.getVR(DicomTag.patientName), ValueRepresentation.pn);
      expect(TagDictionary.getVR(DicomTag.modality), ValueRepresentation.cs);
      expect(TagDictionary.getVR(DicomTag.pixelData), ValueRepresentation.ow);
    });

    test('Returns UN for unknown tag', () {
      const unknownTag = DicomTag(0x9999, 0x9999);
      expect(TagDictionary.getVR(unknownTag), ValueRepresentation.un);
    });
  });
}
