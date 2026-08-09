import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  group('DicomParser & DicomDataset', () {
    test('Parses valid synthetic DICOM file header and tags', () {
      final bytes = SyntheticDicomGenerator.create(
        width: 64,
        height: 64,
        modality: 'CT',
        patientName: 'DOE^JOHN',
      );

      final dataset = DicomDataset.fromBytes(bytes);

      expect(dataset.rows, 64);
      expect(dataset.columns, 64);
      expect(dataset.modality, 'CT');
      expect(dataset.patientName, 'DOE^JOHN');
      expect(dataset.bitsAllocated, 16);
      expect(dataset.bitsStored, 12);
      expect(dataset.highBit, 11);
      expect(dataset.rescaleIntercept, -1024.0);
      expect(dataset.rescaleSlope, 1.0);
      expect(dataset.windowCenter, 40.0);
      expect(dataset.windowWidth, 400.0);
      expect(dataset.pixelDataBytes, isNotNull);
      expect(dataset.pixelDataBytes!.length, 64 * 64 * 2);
    });

    test('Throws FormatException on truncated file', () {
      final shortBytes = Uint8List(50);
      expect(() => DicomDataset.fromBytes(shortBytes), throwsFormatException);
    });
  });
}
