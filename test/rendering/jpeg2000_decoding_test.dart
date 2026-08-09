import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JPEG 2000 & Encapsulated Compressed DICOM Tests', () {
    test('Parses DICOM with JPEG 2000 Transfer Syntax correctly', () {
      // 1-pixel raw JPEG 2000 codestream header (SOC marker 0xFF4F)
      final dummyJ2kBytes = Uint8List.fromList([
        0xFF,
        0x4F,
        0xFF,
        0x51,
        0x00,
        0x2B,
        0x00,
        0x00,
      ]);

      final bytes = SyntheticDicomGenerator.create(
        width: 1,
        height: 1,
        transferSyntaxUid: TransferSyntax.jpeg2000,
        rawEncapsulatedBytes: dummyJ2kBytes,
      );

      final dataset = DicomDataset.fromBytes(bytes);
      expect(dataset.transferSyntaxUid, TransferSyntax.jpeg2000);
      expect(dataset.pixelDataBytes, isNotNull);
      expect(dataset.pixelDataBytes!.sublist(0, 2), equals([0xFF, 0x4F]));
    });

    test(
      'DicomRenderer throws UnsupportedError on JPEG 2000 datasets (v1 out of scope)',
      () async {
        final dummyJ2kBytes = Uint8List.fromList([
          0xFF,
          0x4F,
          0xFF,
          0x51,
          0x00,
          0x2B,
          0x00,
          0x00,
        ]);

        final bytes = SyntheticDicomGenerator.create(
          width: 16,
          height: 16,
          transferSyntaxUid: TransferSyntax.jpeg2000,
          rawEncapsulatedBytes: dummyJ2kBytes,
        );

        final dataset = DicomDataset.fromBytes(bytes);

        // Verify synchronous RGBA rendering throws UnsupportedError
        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsA(isA<UnsupportedError>()),
        );

        // Verify asynchronous image rendering throws UnsupportedError
        expect(
          () async => await DicomRenderer.renderToImage(dataset),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  });
}
