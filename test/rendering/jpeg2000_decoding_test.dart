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
      'DicomRenderer throws UnsupportedError on JPEG 2000 datasets (1.2.840.10008.1.2.4.91) with version-neutral message',
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

        // Verify synchronous RGBA rendering throws UnsupportedError with version-neutral message
        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsA(
            isA<UnsupportedError>()
                .having(
                  (e) => e.message,
                  'message',
                  equals(
                    'Unsupported Transfer Syntax: JPEG 2000 (1.2.840.10008.1.2.4.91).',
                  ),
                )
                .having(
                  (e) => e.message,
                  'message',
                  predicate<String?>(
                    (msg) => msg != null && !msg.contains('v0.2.0'),
                  ),
                ),
          ),
        );

        // Verify asynchronous image rendering throws UnsupportedError
        expect(
          () async => await DicomRenderer.renderToImage(dataset),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              equals(
                'Unsupported Transfer Syntax: JPEG 2000 (1.2.840.10008.1.2.4.91).',
              ),
            ),
          ),
        );
      },
    );

    test(
      'DicomRenderer throws UnsupportedError on JPEG Extended (1.2.840.10008.1.2.4.51) with version-neutral message',
      () async {
        final dummyJpegBytes = Uint8List.fromList([
          0xFF,
          0xD8, // SOI
          0xFF,
          0xE0,
          0x00,
          0x10,
          0x4A,
          0x46,
          0x49,
          0x46,
          0x00,
        ]);

        final bytes = SyntheticDicomGenerator.create(
          width: 16,
          height: 16,
          transferSyntaxUid: '1.2.840.10008.1.2.4.51',
          rawEncapsulatedBytes: dummyJpegBytes,
        );

        final dataset = DicomDataset.fromBytes(bytes);

        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              equals(
                'Unsupported Transfer Syntax: JPEG Extended (12-bit) (1.2.840.10008.1.2.4.51).',
              ),
            ),
          ),
        );

        expect(
          () async => await DicomRenderer.renderToImage(dataset),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test(
      'DicomRenderer throws UnsupportedError on JPEG 2000 Lossless (1.2.840.10008.1.2.4.90) with version-neutral message',
      () async {
        final dummyJ2kBytes = Uint8List.fromList([0xFF, 0x4F, 0xFF, 0x51]);

        final bytes = SyntheticDicomGenerator.create(
          width: 16,
          height: 16,
          transferSyntaxUid: '1.2.840.10008.1.2.4.90',
          rawEncapsulatedBytes: dummyJ2kBytes,
        );

        final dataset = DicomDataset.fromBytes(bytes);

        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              equals(
                'Unsupported Transfer Syntax: JPEG 2000 (1.2.840.10008.1.2.4.90).',
              ),
            ),
          ),
        );

        expect(
          () async => await DicomRenderer.renderToImage(dataset),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test(
      'DicomRenderer throws UnsupportedError on deferred JPEG Lossless Process 14 (1.2.840.10008.1.2.4.57) with version-neutral message',
      () async {
        final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xC3]);

        final bytes = SyntheticDicomGenerator.create(
          width: 16,
          height: 16,
          transferSyntaxUid: '1.2.840.10008.1.2.4.57',
          rawEncapsulatedBytes: dummyBytes,
        );

        final dataset = DicomDataset.fromBytes(bytes);

        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              equals(
                'Unsupported Transfer Syntax: JPEG Lossless (1.2.840.10008.1.2.4.57).',
              ),
            ),
          ),
        );
      },
    );

    test(
      'DicomRenderer throws UnsupportedError on JPEG-LS (.80 and .81) with version-neutral message',
      () async {
        for (final uid in [
          '1.2.840.10008.1.2.4.80',
          '1.2.840.10008.1.2.4.81',
        ]) {
          final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xF7]);
          final bytes = SyntheticDicomGenerator.create(
            width: 16,
            height: 16,
            transferSyntaxUid: uid,
            rawEncapsulatedBytes: dummyBytes,
          );

          final dataset = DicomDataset.fromBytes(bytes);

          expect(
            () => DicomRenderer.renderToRgba(dataset),
            throwsA(
              isA<UnsupportedError>().having(
                (e) => e.message,
                'message',
                equals(
                  'Unsupported Transfer Syntax: Transfer Syntax $uid ($uid).',
                ),
              ),
            ),
          );
        }
      },
    );
  });
}
