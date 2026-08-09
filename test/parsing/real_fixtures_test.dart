import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Real DICOM Fixture Tests (pydicom)', () {
    test('Parses CT_small.dcm correctly', () async {
      final file = File('test/fixtures/CT_small.dcm');
      expect(file.existsSync(), isTrue, reason: 'CT_small.dcm fixture missing');

      final bytes = await file.readAsBytes();
      final dataset = DicomDataset.fromBytes(bytes);

      expect(dataset.rows, 128);
      expect(dataset.columns, 128);
      expect(dataset.bitsAllocated, 16);
      expect(dataset.bitsStored, 16);
      expect(dataset.highBit, 15);
      expect(dataset.pixelRepresentation, 1); // Signed (2's complement)
      expect(dataset.rescaleIntercept, -1024.0);
      expect(dataset.rescaleSlope, 1.0);
      expect(dataset.pixelDataBytes, isNotNull);
      expect(dataset.pixelDataBytes!.length, 128 * 128 * 2);
    });

    test('Parses MR_small.dcm correctly', () async {
      final file = File('test/fixtures/MR_small.dcm');
      expect(file.existsSync(), isTrue, reason: 'MR_small.dcm fixture missing');

      final bytes = await file.readAsBytes();
      final dataset = DicomDataset.fromBytes(bytes);

      expect(dataset.rows, 64);
      expect(dataset.columns, 64);
      expect(dataset.bitsAllocated, 16);
      expect(dataset.pixelDataBytes, isNotNull);
      expect(dataset.pixelDataBytes!.length, 64 * 64 * 2);
    });
  });
}
