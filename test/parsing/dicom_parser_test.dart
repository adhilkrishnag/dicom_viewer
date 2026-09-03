import 'dart:io';
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

    test(
      'Interoperability: parses malformed/mismatched dataset (SC_rgb_jpeg.dcm) with implicit VR fallback',
      () {
        final file = File('test/fixtures/jpeg/SC_rgb_jpeg.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.rows, equals(256));
        expect(dataset.columns, equals(256));
        expect(dataset.samplesPerPixel, equals(3));
        expect(dataset.photometricInterpretation, equals('RGB'));

        final pixelElem = dataset.getElement(DicomTag.pixelData);
        expect(pixelElem, isNotNull);
        expect(pixelElem!.encapsulatedData, isNotNull);
        expect(pixelElem.encapsulatedData!.fragments, isNotEmpty);
        expect(
          pixelElem.encapsulatedData!.fragments.first.payload.length,
          equals(3498),
        );
        expect(
          pixelElem.encapsulatedData!.fragments.first.payload[0],
          equals(0xFF),
        );
        expect(
          pixelElem.encapsulatedData!.fragments.first.payload[1],
          equals(0xD8),
        );
      },
    );
  });
}
