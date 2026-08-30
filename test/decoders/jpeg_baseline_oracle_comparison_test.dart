import 'dart:io';

import 'package:dicom_viewer/src/decoders/jpeg_baseline_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JPEG Baseline Oracle Comparison Tests (Bit-Exact & Characterized)', () {
    test('Synthetic 8x8 DC matches reference oracle bit-exactly', () {
      final jpgBytes =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_dc.jpg',
          ).readAsBytesSync();
      final expectedRaw =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_dc_expected.raw',
          ).readAsBytesSync();

      final decoded = JpegBaselineDecoder.decodeJpegStream(jpgBytes);

      expect(decoded, equals(expectedRaw));
    });

    test('Synthetic 8x8 AC matches reference oracle bit-exactly', () {
      final jpgBytes =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_ac.jpg',
          ).readAsBytesSync();
      final expectedRaw =
          File(
            'test/fixtures/jpeg/synthetic_baseline_8x8_ac_expected.raw',
          ).readAsBytesSync();

      final decoded = JpegBaselineDecoder.decodeJpegStream(jpgBytes);

      expect(decoded, equals(expectedRaw));
    });

    test(
      'Synthetic 9x9 edge dimension pattern matches reference oracle bit-exactly',
      () {
        final jpgBytes =
            File(
              'test/fixtures/jpeg/synthetic_baseline_edge_9x9.jpg',
            ).readAsBytesSync();
        final expectedRaw =
            File(
              'test/fixtures/jpeg/synthetic_baseline_edge_9x9_expected.raw',
            ).readAsBytesSync();

        final decoded = JpegBaselineDecoder.decodeJpegStream(jpgBytes);

        expect(decoded, equals(expectedRaw));
      },
    );

    test(
      'Synthetic checker clamp pattern matches reference oracle bit-exactly',
      () {
        final jpgBytes =
            File(
              'test/fixtures/jpeg/synthetic_baseline_checker_clamp.jpg',
            ).readAsBytesSync();
        final expectedRaw =
            File(
              'test/fixtures/jpeg/synthetic_baseline_checker_clamp_expected.raw',
            ).readAsBytesSync();

        final decoded = JpegBaselineDecoder.decodeJpegStream(jpgBytes);

        expect(decoded, equals(expectedRaw));
      },
    );

    test(
      'Synthetic 32x32 restart marker stream matches reference oracle bit-exactly',
      () {
        final jpgBytes =
            File(
              'test/fixtures/jpeg/synthetic_baseline_restart.jpg',
            ).readAsBytesSync();
        final expectedRaw =
            File(
              'test/fixtures/jpeg/synthetic_baseline_restart_expected.raw',
            ).readAsBytesSync();

        final decoded = JpegBaselineDecoder.decodeJpegStream(jpgBytes);

        expect(decoded, equals(expectedRaw));
      },
    );

    test(
      'Real RGB fixture SC_rgb_dcmtk_+eb+cr.dcm matches reference oracle (99.67% bit-exact, max diff 1 LSB)',
      () {
        final expectedRaw =
            File(
              'test/fixtures/jpeg/sc_rgb_dcmtk_expected.raw',
            ).readAsBytesSync();
        final dcmBytes =
            File(
              'test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cr.dcm',
            ).readAsBytesSync();

        int soiIdx = -1;
        for (int i = 0; i < dcmBytes.length - 1; i++) {
          if (dcmBytes[i] == 0xFF && dcmBytes[i + 1] == 0xD8) {
            soiIdx = i;
            break;
          }
        }
        expect(soiIdx, isNonNegative);

        final jpgSlice = dcmBytes.sublist(soiIdx);
        final decoded = JpegBaselineDecoder.decodeJpegStream(jpgSlice);

        expect(decoded.length, equals(expectedRaw.length));

        int diffCount = 0;
        int maxDiff = 0;
        for (int i = 0; i < decoded.length; i++) {
          final diff = (decoded[i] - expectedRaw[i]).abs();
          if (diff > 0) {
            diffCount++;
            if (diff > maxDiff) maxDiff = diff;
          }
        }

        // Max diff must be <= 1 LSB (due to integer vs floating-point IDCT rounding)
        expect(maxDiff, lessThanOrEqualTo(1));
        // At least 99% of samples must be completely bit-exact
        final exactPct = (decoded.length - diffCount) / decoded.length;
        expect(exactPct, greaterThan(0.99));
      },
    );

    test(
      'Real RGB fixture SC_rgb_jpeg.dcm matches reference oracle (99.87% bit-exact, max diff 1 LSB)',
      () {
        final expectedRaw =
            File(
              'test/fixtures/jpeg/sc_rgb_jpeg_expected.raw',
            ).readAsBytesSync();
        final dcmBytes =
            File('test/fixtures/jpeg/SC_rgb_jpeg.dcm').readAsBytesSync();

        int soiIdx = -1;
        for (int i = 0; i < dcmBytes.length - 1; i++) {
          if (dcmBytes[i] == 0xFF && dcmBytes[i + 1] == 0xD8) {
            soiIdx = i;
            break;
          }
        }
        expect(soiIdx, isNonNegative);

        final jpgSlice = dcmBytes.sublist(soiIdx);
        final decoded = JpegBaselineDecoder.decodeJpegStream(jpgSlice);

        expect(decoded.length, equals(expectedRaw.length));

        int diffCount = 0;
        int maxDiff = 0;
        for (int i = 0; i < decoded.length; i++) {
          final diff = (decoded[i] - expectedRaw[i]).abs();
          if (diff > 0) {
            diffCount++;
            if (diff > maxDiff) maxDiff = diff;
          }
        }

        expect(maxDiff, lessThanOrEqualTo(1));
        final exactPct = (decoded.length - diffCount) / decoded.length;
        expect(exactPct, greaterThan(0.99));
      },
    );
  });
}
