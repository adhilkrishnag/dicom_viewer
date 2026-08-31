import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'JPEG Multi-Frame Oracle Comparison Tests (30-Frame examples_ybr_color.dcm)',
    () {
      late File dcmFile;
      late DicomDataset dataset;

      setUpAll(() {
        dcmFile = File('test/fixtures/jpeg/examples_ybr_color.dcm');
        expect(
          dcmFile.existsSync(),
          isTrue,
          reason: 'examples_ybr_color.dcm fixture missing',
        );
        dataset = DicomDataset.fromBytes(dcmFile.readAsBytesSync());
      });

      test('Verify multi-frame DICOM metadata attributes', () {
        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.numberOfFrames, equals(30));
        expect(dataset.rows, equals(240));
        expect(dataset.columns, equals(320));
        expect(dataset.samplesPerPixel, equals(3));
        expect(dataset.photometricInterpretation, equals('YBR_FULL_422'));
        expect(dataset.bitsAllocated, equals(8));
        expect(dataset.bitsStored, equals(8));

        final encData = dataset.encapsulatedData;
        expect(encData, isNotNull);
        expect(encData!.botOffsets.length, equals(30));
        expect(encData.fragments.length, equals(30));
      });

      test(
        'Frame 00 matches independent reference RGB oracle within characterized tolerance',
        () {
          final rawFile = File(
            'test/fixtures/jpeg/examples_ybr_frame_00_expected.raw',
          );
          expect(rawFile.existsSync(), isTrue);
          final expectedRgb = rawFile.readAsBytesSync();

          final rgba = DicomRenderer.renderToRgba(dataset, frameIndex: 0);
          final totalPixels = dataset.rows * dataset.columns;
          final totalSamples = totalPixels * 3;
          expect(rgba.length, equals(totalPixels * 4));

          int maxDiff = 0;
          int exactMatches = 0;
          int within1Lsb = 0;
          int sumDiff = 0;

          for (int i = 0; i < totalPixels; i++) {
            final actualR = rgba[i * 4];
            final actualG = rgba[i * 4 + 1];
            final actualB = rgba[i * 4 + 2];

            final expR = expectedRgb[i * 3];
            final expG = expectedRgb[i * 3 + 1];
            final expB = expectedRgb[i * 3 + 2];

            final dR = (actualR - expR).abs();
            final dG = (actualG - expG).abs();
            final dB = (actualB - expB).abs();

            for (final d in [dR, dG, dB]) {
              if (d == 0) {
                exactMatches++;
                within1Lsb++;
              } else if (d == 1) {
                within1Lsb++;
              }
              if (d > maxDiff) maxDiff = d;
              sumDiff += d;
            }
          }

          final exactPct = exactMatches / totalSamples * 100;
          final within1Pct = within1Lsb / totalSamples * 100;
          final meanDiff = sumDiff / totalSamples;

          expect(exactPct, greaterThanOrEqualTo(96.5));
          expect(within1Pct, greaterThanOrEqualTo(99.0));
          expect(meanDiff, lessThan(0.05));
          expect(maxDiff, lessThanOrEqualTo(15));
        },
      );

      test(
        'Middle Frame 14 matches independent reference RGB oracle within characterized tolerance',
        () {
          final rawFile = File(
            'test/fixtures/jpeg/examples_ybr_frame_14_expected.raw',
          );
          expect(rawFile.existsSync(), isTrue);
          final expectedRgb = rawFile.readAsBytesSync();

          final rgba = DicomRenderer.renderToRgba(dataset, frameIndex: 14);
          final totalPixels = dataset.rows * dataset.columns;
          final totalSamples = totalPixels * 3;
          expect(rgba.length, equals(totalPixels * 4));

          int maxDiff = 0;
          int exactMatches = 0;
          int within1Lsb = 0;
          int sumDiff = 0;

          for (int i = 0; i < totalPixels; i++) {
            final actualR = rgba[i * 4];
            final actualG = rgba[i * 4 + 1];
            final actualB = rgba[i * 4 + 2];

            final expR = expectedRgb[i * 3];
            final expG = expectedRgb[i * 3 + 1];
            final expB = expectedRgb[i * 3 + 2];

            final dR = (actualR - expR).abs();
            final dG = (actualG - expG).abs();
            final dB = (actualB - expB).abs();

            for (final d in [dR, dG, dB]) {
              if (d == 0) {
                exactMatches++;
                within1Lsb++;
              } else if (d == 1) {
                within1Lsb++;
              }
              if (d > maxDiff) maxDiff = d;
              sumDiff += d;
            }
          }

          final exactPct = exactMatches / totalSamples * 100;
          final within1Pct = within1Lsb / totalSamples * 100;
          final meanDiff = sumDiff / totalSamples;

          expect(exactPct, greaterThanOrEqualTo(96.5));
          expect(within1Pct, greaterThanOrEqualTo(99.0));
          expect(meanDiff, lessThan(0.05));
          expect(maxDiff, lessThanOrEqualTo(15));
        },
      );

      test(
        'Final Frame 29 matches independent reference RGB oracle within characterized tolerance',
        () {
          final rawFile = File(
            'test/fixtures/jpeg/examples_ybr_frame_29_expected.raw',
          );
          expect(rawFile.existsSync(), isTrue);
          final expectedRgb = rawFile.readAsBytesSync();

          final rgba = DicomRenderer.renderToRgba(dataset, frameIndex: 29);
          final totalPixels = dataset.rows * dataset.columns;
          final totalSamples = totalPixels * 3;
          expect(rgba.length, equals(totalPixels * 4));

          int maxDiff = 0;
          int exactMatches = 0;
          int within1Lsb = 0;
          int sumDiff = 0;

          for (int i = 0; i < totalPixels; i++) {
            final actualR = rgba[i * 4];
            final actualG = rgba[i * 4 + 1];
            final actualB = rgba[i * 4 + 2];

            final expR = expectedRgb[i * 3];
            final expG = expectedRgb[i * 3 + 1];
            final expB = expectedRgb[i * 3 + 2];

            final dR = (actualR - expR).abs();
            final dG = (actualG - expG).abs();
            final dB = (actualB - expB).abs();

            for (final d in [dR, dG, dB]) {
              if (d == 0) {
                exactMatches++;
                within1Lsb++;
              } else if (d == 1) {
                within1Lsb++;
              }
              if (d > maxDiff) maxDiff = d;
              sumDiff += d;
            }
          }

          final exactPct = exactMatches / totalSamples * 100;
          final within1Pct = within1Lsb / totalSamples * 100;
          final meanDiff = sumDiff / totalSamples;

          expect(exactPct, greaterThanOrEqualTo(96.5));
          expect(within1Pct, greaterThanOrEqualTo(99.0));
          expect(meanDiff, lessThan(0.05));
          expect(maxDiff, lessThanOrEqualTo(15));
        },
      );

      test(
        'All 30 frames decode without error and produce distinct frame payloads',
        () {
          final totalPixels = dataset.rows * dataset.columns;
          final decodedFrames = <int, int>{};

          for (int f = 0; f < 30; f++) {
            final rgba = DicomRenderer.renderToRgba(dataset, frameIndex: f);
            expect(rgba.length, equals(totalPixels * 4));

            // Sample a specific pixel on each frame
            decodedFrames[f] =
                rgba[100 * 320 * 4 +
                    150 * 4]; // R component of pixel (150, 100)
          }

          // Verify that pixel values change across frames in the cine sequence
          final uniqueValues = decodedFrames.values.toSet();
          expect(
            uniqueValues.length,
            greaterThan(1),
            reason: 'Frames must not be identical copies',
          );
        },
      );

      test('Out-of-bounds frameIndex throws RangeError', () {
        expect(
          () => DicomRenderer.renderToRgba(dataset, frameIndex: -1),
          throwsRangeError,
        );
        expect(
          () => DicomRenderer.renderToRgba(dataset, frameIndex: 30),
          throwsRangeError,
        );
        expect(
          () => DicomRenderer.renderToRgba(dataset, frameIndex: 100),
          throwsRangeError,
        );
      });
    },
  );
}
