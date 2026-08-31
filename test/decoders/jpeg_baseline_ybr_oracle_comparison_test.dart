import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JPEG Baseline YBR Oracle Comparison Tests (Bit-Exact & Characterized)', () {
    test(
      'Real 4:2:2 YBR_FULL_422 fixture SC_rgb_dcmtk_+eb+cy+s2.dcm matches reference RGB oracle bit-exactly (100%)',
      () {
        final dcmFile = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cy+s2.dcm');
        final rawFile = File(
          'test/fixtures/jpeg/sc_rgb_dcmtk_s2_expected_rgb.raw',
        );

        expect(dcmFile.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(dcmFile.readAsBytesSync());
        final expectedRgb = rawFile.readAsBytesSync();

        expect(dataset.photometricInterpretation, equals('YBR_FULL_422'));
        expect(dataset.rows, equals(100));
        expect(dataset.columns, equals(100));

        final rgba = DicomRenderer.renderToRgba(dataset);
        final totalPixels = dataset.rows * dataset.columns;
        expect(rgba.length, equals(totalPixels * 4));

        int diffCount = 0;
        int maxDiff = 0;

        for (int i = 0; i < totalPixels; i++) {
          final actualR = rgba[i * 4];
          final actualG = rgba[i * 4 + 1];
          final actualB = rgba[i * 4 + 2];

          final expectedR = expectedRgb[i * 3];
          final expectedG = expectedRgb[i * 3 + 1];
          final expectedB = expectedRgb[i * 3 + 2];

          final diffR = (actualR - expectedR).abs();
          final diffG = (actualG - expectedG).abs();
          final diffB = (actualB - expectedB).abs();

          for (final d in [diffR, diffG, diffB]) {
            if (d > 0) {
              diffCount++;
              if (d > maxDiff) maxDiff = d;
            }
          }
        }

        // 4:2:2 horizontal subsampling must match the independent reference oracle 100% bit-exactly
        expect(diffCount, equals(0));
        expect(maxDiff, equals(0));
      },
    );

    test(
      'Real 3x3 odd dimension YBR_FULL fixture SC_rgb_small_odd_jpeg.dcm matches reference RGB oracle bit-exactly (100%)',
      () {
        final dcmFile = File('test/fixtures/jpeg/SC_rgb_small_odd_jpeg.dcm');
        final rawFile = File(
          'test/fixtures/jpeg/sc_rgb_small_odd_expected_rgb.raw',
        );

        expect(dcmFile.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(dcmFile.readAsBytesSync());
        final expectedRgb = rawFile.readAsBytesSync();

        expect(dataset.photometricInterpretation, equals('YBR_FULL'));
        expect(dataset.rows, equals(3));
        expect(dataset.columns, equals(3));

        final rgba = DicomRenderer.renderToRgba(dataset);
        final totalPixels = dataset.rows * dataset.columns;
        expect(rgba.length, equals(totalPixels * 4));

        int diffCount = 0;
        int maxDiff = 0;

        for (int i = 0; i < totalPixels; i++) {
          final actualR = rgba[i * 4];
          final actualG = rgba[i * 4 + 1];
          final actualB = rgba[i * 4 + 2];

          final expectedR = expectedRgb[i * 3];
          final expectedG = expectedRgb[i * 3 + 1];
          final expectedB = expectedRgb[i * 3 + 2];

          final diffR = (actualR - expectedR).abs();
          final diffG = (actualG - expectedG).abs();
          final diffB = (actualB - expectedB).abs();

          for (final d in [diffR, diffG, diffB]) {
            if (d > 0) {
              diffCount++;
              if (d > maxDiff) maxDiff = d;
            }
          }
        }

        expect(diffCount, equals(0));
        expect(maxDiff, equals(0));
      },
    );
  });
}
