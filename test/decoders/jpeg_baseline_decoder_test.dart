import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/jpeg_baseline_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JpegBaselineDecoder Unit & Synthetic Tests', () {
    test('Decodes 8x8 DC-only synthetic Baseline stream', () {
      final bytes =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_dc.jpg',
          ).readAsBytesSync();
      final expected =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_dc_expected.raw',
          ).readAsBytesSync();

      final decoded = JpegBaselineDecoder.decodeJpegStream(bytes);

      expect(decoded.length, equals(64));
      expect(decoded, equals(expected));
    });

    test('Decodes 8x8 DC + AC synthetic Baseline stream bit-exactly', () {
      final bytes =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_ac.jpg',
          ).readAsBytesSync();
      final expected =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_ac_expected.raw',
          ).readAsBytesSync();

      final decoded = JpegBaselineDecoder.decodeJpegStream(bytes);

      expect(decoded.length, equals(64));
      expect(decoded, equals(expected));
    });

    test('Decodes 9x9 partial/edge dimension block correctly', () {
      final bytes =
          File(
            'test/fixtures/jpeg/synthetic_baseline_edge_9x9.jpg',
          ).readAsBytesSync();
      final expected =
          File(
            'test/fixtures/jpeg/synthetic_baseline_edge_9x9_expected.raw',
          ).readAsBytesSync();

      final decoded = JpegBaselineDecoder.decodeJpegStream(bytes);

      expect(decoded.length, equals(81));
      expect(decoded, equals(expected));
    });

    test(
      'Exercises IDCT clamping to both 0 and 255 boundaries on high-contrast pattern',
      () {
        final bytes =
            File(
              'test/fixtures/jpeg/synthetic_baseline_checker_clamp.jpg',
            ).readAsBytesSync();
        final expected =
            File(
              'test/fixtures/jpeg/synthetic_baseline_checker_clamp_expected.raw',
            ).readAsBytesSync();

        final decoded = JpegBaselineDecoder.decodeJpegStream(bytes);

        expect(decoded.length, equals(64));
        expect(decoded, equals(expected));
        expect(decoded.contains(0) || decoded.any((v) => v < 10), isTrue);
        expect(decoded.contains(255) || decoded.any((v) => v > 245), isTrue);
      },
    );

    test('Decodes stream with DRI and RST0-RST7 restart markers', () {
      final bytes =
          File(
            'test/fixtures/jpeg/synthetic_baseline_restart.jpg',
          ).readAsBytesSync();
      final expected =
          File(
            'test/fixtures/jpeg/synthetic_baseline_restart_expected.raw',
          ).readAsBytesSync();

      final decoded = JpegBaselineDecoder.decodeJpegStream(bytes);

      expect(decoded.length, equals(1024)); // 32x32
      expect(decoded, equals(expected));
    });

    group('Error Handling & Malformed Streams', () {
      test('Throws FormatException on missing SOI marker', () {
        final corrupt = Uint8List.fromList([0x00, 0x00, 0xFF, 0xC0]);
        expect(
          () => JpegBaselineDecoder.decodeJpegStream(corrupt),
          throwsA(isA<FormatException>()),
        );
      });

      test('Throws FormatException on short stream (< 4 bytes)', () {
        final shortBytes = Uint8List.fromList([0xFF, 0xD8]);
        expect(
          () => JpegBaselineDecoder.decodeJpegStream(shortBytes),
          throwsA(isA<FormatException>()),
        );
      });

      test(
        'Throws FormatException on unsupported SOF marker (e.g. SOF3 Lossless)',
        () {
          final sof3Stream = Uint8List.fromList([
            0xFF, 0xD8, // SOI
            0xFF, 0xC3, // SOF3 (Lossless)
            0x00, 0x0B, 0x10, 0x00, 0x20, 0x00, 0x20, 0x01, 0x01, 0x11, 0x00,
          ]);
          expect(
            () => JpegBaselineDecoder.decodeJpegStream(sof3Stream),
            throwsA(isA<FormatException>()),
          );
        },
      );

      test('Throws FormatException on missing SOS marker', () {
        final missingSos = Uint8List.fromList([
          0xFF, 0xD8, // SOI
          0xFF, 0xC0, // SOF0
          0x00, 0x0B, 0x08, 0x00, 0x08, 0x00, 0x08, 0x01, 0x01, 0x11, 0x00,
          0xFF, 0xD9, // EOI
        ]);
        expect(
          () => JpegBaselineDecoder.decodeJpegStream(missingSos),
          throwsA(isA<FormatException>()),
        );
      });

      test(
        'Throws FormatException on invalid quantization table precision (16-bit)',
        () {
          final dqt16Bit = Uint8List.fromList([
            0xFF, 0xD8, // SOI
            0xFF, 0xDB, // DQT
            0x00, 0x43, // Length
            0x10, // Pq=1 (16-bit), Tq=0
            ...List.filled(64, 1),
          ]);
          expect(
            () => JpegBaselineDecoder.decodeJpegStream(dqt16Bit),
            throwsA(isA<FormatException>()),
          );
        },
      );
    });
  });
}
