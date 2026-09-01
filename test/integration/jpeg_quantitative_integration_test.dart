import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/jpeg_lossless_decoder.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/dicom_probe_painter.dart';
import 'package:dicom_viewer/src/geometry/dicom_roi_statistics_engine.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_measurement.dart';

void main() {
  group('Task 8: Quantitative ROI Statistics & Pixel Probe on JPEG Datasets', () {
    late File jpegLlFile;
    late DicomDataset jpegLlDataset;

    late File jpeg8bFile;
    late DicomDataset jpeg8bDataset;

    late File ybrMultiframeFile;
    late DicomDataset ybrMultiframeDataset;

    late File rgbDcmtkFile;
    late DicomDataset rgbDcmtkDataset;

    late File ybrDcmtkFile;
    late DicomDataset ybrDcmtkDataset;

    late File ctFile;
    late DicomDataset ctDataset;

    setUpAll(() {
      jpegLlFile = File('test/fixtures/jpeg/JPEG-LL.dcm');
      expect(jpegLlFile.existsSync(), isTrue);
      jpegLlDataset = DicomDataset.fromBytes(jpegLlFile.readAsBytesSync());

      jpeg8bFile = File('test/fixtures/jpeg/JPGLosslessP14SV1_1s_1f_8b.dcm');
      expect(jpeg8bFile.existsSync(), isTrue);
      jpeg8bDataset = DicomDataset.fromBytes(jpeg8bFile.readAsBytesSync());

      ybrMultiframeFile = File('test/fixtures/jpeg/examples_ybr_color.dcm');
      expect(ybrMultiframeFile.existsSync(), isTrue);
      ybrMultiframeDataset = DicomDataset.fromBytes(
        ybrMultiframeFile.readAsBytesSync(),
      );

      rgbDcmtkFile = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cr.dcm');
      expect(rgbDcmtkFile.existsSync(), isTrue);
      rgbDcmtkDataset = DicomDataset.fromBytes(rgbDcmtkFile.readAsBytesSync());

      ybrDcmtkFile = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cy+s2.dcm');
      expect(ybrDcmtkFile.existsSync(), isTrue);
      ybrDcmtkDataset = DicomDataset.fromBytes(ybrDcmtkFile.readAsBytesSync());

      ctFile = File('test/fixtures/CT_small.dcm');
      expect(ctFile.existsSync(), isTrue);
      ctDataset = DicomDataset.fromBytes(ctFile.readAsBytesSync());
    });

    group('Group 1: JPEG Lossless SV1 .70 Quantitative Accuracy', () {
      test(
        '1.1 Stored pixel extraction matches reference oracle bit-for-bit',
        () {
          final expectedFile = File('test/fixtures/jpeg/jpeg_ll_expected.raw');
          expect(expectedFile.existsSync(), isTrue);
          final expectedBytes = expectedFile.readAsBytesSync();
          final expectedBd = ByteData.sublistView(expectedBytes);

          final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
            jpegLlDataset,
            0,
          );
          expect(rawPixels.length, equals(256 * 1024));

          for (int i = 0; i < rawPixels.length; i++) {
            final expVal = expectedBd.getInt16(i * 2, Endian.little);
            expect(
              rawPixels[i],
              equals(expVal),
              reason: 'Mismatch at pixel $i',
            );
          }
        },
      );

      test(
        '1.2 ROI Statistics on Center 100x100 ROI match exact reference stored values',
        () {
          // Continuous rectangle mapping to discrete cols 78..177, rows 462..561
          const rect = Rect.fromLTRB(78.0, 462.0, 178.0, 562.0);

          final stats = DicomRoiStatisticsEngine.computeStatistics(
            dataset: jpegLlDataset,
            normalizedRect: rect,
            frameIndex: 0,
          );

          expect(stats.pixelCount, equals(10000));
          expect(stats.validPixelCount, equals(10000));
          expect(stats.excludedPaddingCount, equals(0));
          expect(stats.isHounsfield, isFalse);
          expect(stats.unit, isEmpty);
          expect(stats.hasValidPixels, isTrue);

          // Reference statistics computed from oracle raw dump with stored values:
          // Min: 0.0, Max: 75.0, Mean: 22.3231, Median: 22.0, StdDev: 12.5854
          expect(stats.min, equals(0.0));
          expect(stats.max, equals(75.0));
          expect(stats.mean, closeTo(22.3231, 0.01));
          expect(stats.median, equals(22.0));
          expect(stats.standardDeviation, closeTo(12.5854, 0.01));
        },
      );

      test(
        '1.3 ROI Statistics on Top-Left 50x50 ROI match exact reference stored values',
        () {
          // Continuous rectangle mapping to discrete cols 10..59, rows 10..59
          const rect = Rect.fromLTRB(10.0, 10.0, 60.0, 60.0);

          final stats = DicomRoiStatisticsEngine.computeStatistics(
            dataset: jpegLlDataset,
            normalizedRect: rect,
            frameIndex: 0,
          );

          expect(stats.pixelCount, equals(2500));
          expect(stats.validPixelCount, equals(2500));
          expect(stats.min, equals(0.0));
          expect(stats.max, equals(2.0));
          expect(stats.mean, closeTo(0.0472, 0.01));
          expect(stats.median, equals(0.0));
          expect(stats.standardDeviation, closeTo(0.2267, 0.01));
        },
      );

      test(
        '1.4 Pixel Probe on JPEG Lossless reads exact stored scalar values',
        () {
          final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
            jpegLlDataset,
            0,
          );

          // Probe coordinate (128, 512)
          final pCenter = DicomProbeResult.evaluate(
            dataset: jpegLlDataset,
            pixelColumn: 128,
            pixelRow: 512,
            rawPixels: rawPixels,
          );

          expect(pCenter.isInside, isTrue);
          expect(pCenter.isHounsfield, isFalse);
          expect(pCenter.unit, isEmpty);
          expect(pCenter.storedValue, isNotNull);
          expect(pCenter.storedValue, equals(rawPixels[512 * 256 + 128]));

          // Probe coordinate (0, 0)
          final pOrigin = DicomProbeResult.evaluate(
            dataset: jpegLlDataset,
            pixelColumn: 0,
            pixelRow: 0,
            rawPixels: rawPixels,
          );
          expect(pOrigin.isInside, isTrue);
          expect(pOrigin.storedValue, equals(0));
        },
      );

      test(
        '1.5 8-bit JPEG Lossless SV1 ROI Statistics & Probe match oracle reference',
        () {
          final expectedFile = File('test/fixtures/jpeg/jpg_8b_expected.raw');
          expect(expectedFile.existsSync(), isTrue);
          final expectedBytes = expectedFile.readAsBytesSync();

          final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
            jpeg8bDataset,
            0,
          );
          expect(rawPixels.length, equals(1024 * 768));
          expect(rawPixels, equals(expectedBytes));

          // Center 100x100 ROI (cols 462..561, rows 334..433)
          const rect = Rect.fromLTRB(462.0, 334.0, 562.0, 434.0);
          final stats = DicomRoiStatisticsEngine.computeStatistics(
            dataset: jpeg8bDataset,
            normalizedRect: rect,
            frameIndex: 0,
          );

          expect(stats.pixelCount, equals(10000));
          expect(stats.validPixelCount, equals(10000));
          expect(stats.isHounsfield, isFalse);
          expect(stats.unit, isEmpty);
          expect(stats.min, equals(0.0));
          expect(stats.max, equals(134.0));
          expect(stats.mean, closeTo(23.4769, 0.01));
          expect(stats.median, equals(19.0));
          expect(stats.standardDeviation, closeTo(20.5426, 0.01));

          // Probe at (512, 384)
          final probe = DicomProbeResult.evaluate(
            dataset: jpeg8bDataset,
            pixelColumn: 512,
            pixelRow: 384,
            rawPixels: rawPixels,
          );
          expect(probe.isInside, isTrue);
          expect(probe.storedValue, equals(expectedBytes[384 * 1024 + 512]));
          expect(probe.isHounsfield, isFalse);
          expect(probe.unit, isEmpty);
        },
      );
    });

    group('Group 2: JPEG Baseline .50 Grayscale Quantitative Accuracy', () {
      test(
        '2.1 Grayscale Baseline synthetic fixture probes exact decoded values',
        () {
          final fixtureFile = File(
            'test/fixtures/jpeg/synthetic_baseline_grayscale.dcm',
          );
          expect(fixtureFile.existsSync(), isTrue);
          final dataset = DicomDataset.fromBytes(fixtureFile.readAsBytesSync());

          final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
            dataset,
            0,
          );
          expect(rawPixels.length, equals(32 * 32));

          final probe = DicomProbeResult.evaluate(
            dataset: dataset,
            pixelColumn: 16,
            pixelRow: 16,
            rawPixels: rawPixels,
          );

          expect(probe.isInside, isTrue);
          expect(probe.storedValue, equals(rawPixels[16 * 32 + 16]));
          expect(probe.isHounsfield, isFalse);

          // Full ROI on 32x32 synthetic image
          const rect = Rect.fromLTRB(0.0, 0.0, 32.0, 32.0);
          final stats = DicomRoiStatisticsEngine.computeStatistics(
            dataset: dataset,
            normalizedRect: rect,
            frameIndex: 0,
          );

          expect(stats.pixelCount, equals(1024));
          expect(stats.validPixelCount, equals(1024));
          expect(stats.hasValidPixels, isTrue);
        },
      );
    });

    group('Group 3: JPEG Baseline RGB & YBR Color Probe', () {
      test('3.1 RGB Baseline fixture probes discrete RGB channel triplets', () {
        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          rgbDcmtkDataset,
          0,
        );
        expect(rawPixels.length, equals(100 * 100 * 3));

        final probe = DicomProbeResult.evaluate(
          dataset: rgbDcmtkDataset,
          pixelColumn: 50,
          pixelRow: 50,
          rawPixels: rawPixels,
        );

        expect(probe.isInside, isTrue);
        expect(probe.rgb, isNotNull);
        expect(probe.rgb!.length, equals(3));
        expect(probe.isHounsfield, isFalse);
        expect(probe.storedValue, isNull);

        const pIdx = 50 * 100 + 50;
        expect(probe.rgb![0], equals(rawPixels[pIdx * 3]));
        expect(probe.rgb![1], equals(rawPixels[pIdx * 3 + 1]));
        expect(probe.rgb![2], equals(rawPixels[pIdx * 3 + 2]));
        expect(probe.formattedLines.any((l) => l.startsWith('RGB:')), isTrue);
      });

      test(
        '3.2 YBR_FULL_422 Baseline fixture probes color-converted RGB channel triplets',
        () {
          final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
            ybrDcmtkDataset,
            0,
          );
          expect(rawPixels.length, equals(100 * 100 * 3));

          final probe = DicomProbeResult.evaluate(
            dataset: ybrDcmtkDataset,
            pixelColumn: 50,
            pixelRow: 50,
            rawPixels: rawPixels,
          );

          expect(probe.isInside, isTrue);
          expect(probe.rgb, isNotNull);
          expect(probe.rgb!.length, equals(3));
          expect(probe.isHounsfield, isFalse);

          const pIdx = 50 * 100 + 50;
          // Stored samples in rawPixels are [Y, Cb, Cr]
          final y = rawPixels[pIdx * 3].toDouble();
          final cb = rawPixels[pIdx * 3 + 1].toDouble() - 128.0;
          final cr = rawPixels[pIdx * 3 + 2].toDouble() - 128.0;

          final expR = (y + 1.402 * cr).round().clamp(0, 255);
          final expG = (y - 0.344136 * cb - 0.714136 * cr).round().clamp(
            0,
            255,
          );
          final expB = (y + 1.772 * cb).round().clamp(0, 255);

          expect(probe.rgb![0], equals(expR));
          expect(probe.rgb![1], equals(expG));
          expect(probe.rgb![2], equals(expB));

          // Matches rendered RGBA output at pixel (50, 50)
          final rgba = DicomRenderer.renderToRgba(ybrDcmtkDataset);
          expect(probe.rgb![0], equals(rgba[pIdx * 4]));
          expect(probe.rgb![1], equals(rgba[pIdx * 4 + 1]));
          expect(probe.rgb![2], equals(rgba[pIdx * 4 + 2]));
        },
      );
    });

    group('Group 4: Multi-Frame Quantitative Isolation', () {
      test(
        '4.1 Multi-frame JPEG Probe across Frame 0, Frame 14, and Frame 29',
        () {
          // Frame 0
          final raw0 = DicomRoiStatisticsEngine.extractFramePixels(
            ybrMultiframeDataset,
            0,
          );
          final p0 = DicomProbeResult.evaluate(
            dataset: ybrMultiframeDataset,
            pixelColumn: 160,
            pixelRow: 120,
            rawPixels: raw0,
          );

          // Frame 14
          final raw14 = DicomRoiStatisticsEngine.extractFramePixels(
            ybrMultiframeDataset,
            14,
          );
          final p14 = DicomProbeResult.evaluate(
            dataset: ybrMultiframeDataset,
            pixelColumn: 160,
            pixelRow: 120,
            rawPixels: raw14,
          );

          // Frame 29
          final raw29 = DicomRoiStatisticsEngine.extractFramePixels(
            ybrMultiframeDataset,
            29,
          );
          final p29 = DicomProbeResult.evaluate(
            dataset: ybrMultiframeDataset,
            pixelColumn: 160,
            pixelRow: 120,
            rawPixels: raw29,
          );

          expect(p0.isInside, isTrue);
          expect(p14.isInside, isTrue);
          expect(p29.isInside, isTrue);
          expect(p0.rgb, isNotNull);
          expect(p14.rgb, isNotNull);
          expect(p29.rgb, isNotNull);

          // Load reference raw dumps for frames
          final f0Raw =
              File(
                'test/fixtures/jpeg/examples_ybr_frame_00_expected.raw',
              ).readAsBytesSync();
          final f14Raw =
              File(
                'test/fixtures/jpeg/examples_ybr_frame_14_expected.raw',
              ).readAsBytesSync();
          final f29Raw =
              File(
                'test/fixtures/jpeg/examples_ybr_frame_29_expected.raw',
              ).readAsBytesSync();

          const pIdx = 120 * 320 + 160;
          // Verify against reference dump within characterized tolerance
          expect(p0.rgb![0], closeTo(f0Raw[pIdx * 3], 15));
          expect(p14.rgb![0], closeTo(f14Raw[pIdx * 3], 15));
          expect(p29.rgb![0], closeTo(f29Raw[pIdx * 3], 15));
        },
      );
    });

    group('Group 5: Windowing Invariance for Quantitative Tools', () {
      test(
        '5.1 Changing windowing parameters does NOT change ROI Statistics',
        () {
          const rect = Rect.fromLTRB(50.0, 200.0, 150.0, 300.0);

          // Compute statistics at default windowing
          final statsDefault = DicomRoiStatisticsEngine.computeStatistics(
            dataset: jpegLlDataset,
            normalizedRect: rect,
            frameIndex: 0,
          );

          // Render with extreme bone window (W:2000, C:500)
          DicomRenderer.renderToRgba(
            jpegLlDataset,
            windowCenter: 500,
            windowWidth: 2000,
          );

          // Compute statistics again
          final statsBone = DicomRoiStatisticsEngine.computeStatistics(
            dataset: jpegLlDataset,
            normalizedRect: rect,
            frameIndex: 0,
          );

          // Render with extreme soft tissue window (W:400, C:40)
          DicomRenderer.renderToRgba(
            jpegLlDataset,
            windowCenter: 40,
            windowWidth: 400,
          );

          final statsSoft = DicomRoiStatisticsEngine.computeStatistics(
            dataset: jpegLlDataset,
            normalizedRect: rect,
            frameIndex: 0,
          );

          expect(statsDefault, equals(statsBone));
          expect(statsDefault, equals(statsSoft));
        },
      );

      test(
        '5.2 Changing windowing parameters does NOT change Pixel Probe stored value',
        () {
          final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
            jpegLlDataset,
            0,
          );

          final probeDefault = DicomProbeResult.evaluate(
            dataset: jpegLlDataset,
            pixelColumn: 100,
            pixelRow: 200,
            rawPixels: rawPixels,
          );

          // Windowing adjustments
          DicomRenderer.renderToRgba(
            jpegLlDataset,
            windowCenter: -100,
            windowWidth: 50,
          );

          final probeAfter = DicomProbeResult.evaluate(
            dataset: jpegLlDataset,
            pixelColumn: 100,
            pixelRow: 200,
            rawPixels: rawPixels,
          );

          expect(probeDefault.storedValue, equals(probeAfter.storedValue));
          expect(probeDefault.rescaledValue, equals(probeAfter.rescaledValue));
          expect(probeDefault.isHounsfield, equals(probeAfter.isHounsfield));
        },
      );
    });

    group('Group 6: Rescale, Signedness, Padding & Spacing Semantics', () {
      test(
        '6.1 Rescale Slope and Intercept calculation: CT dataset evaluates HU = stored * slope + intercept',
        () {
          expect(ctDataset.modality, equals('CT'));
          expect(ctDataset.rescaleSlope, equals(1.0));
          expect(ctDataset.rescaleIntercept, equals(-1024.0));

          final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
            ctDataset,
            0,
          );
          final probe = DicomProbeResult.evaluate(
            dataset: ctDataset,
            pixelColumn: 64,
            pixelRow: 64,
            rawPixels: rawPixels,
          );

          expect(probe.isInside, isTrue);
          expect(probe.isHounsfield, isTrue);
          expect(probe.unit, equals('HU'));
          expect(
            probe.rescaledValue,
            equals(probe.storedValue! * 1.0 - 1024.0),
          );
        },
      );

      test(
        '6.2 Pixel Spacing and physical area calculation on JPEG dataset with spacing',
        () {
          expect(jpegLlDataset.pixelSpacing, equals([2.26, 2.26]));
          final rowSpacing = jpegLlDataset.pixelSpacing![0];
          final colSpacing = jpegLlDataset.pixelSpacing![1];

          // 100 x 50 pixels ROI
          final roi = DicomRectangleRoiMeasurement.fromImagePoints(
            start: const ImagePoint(
              pixelX: 50.0,
              pixelY: 100.0,
              isInsideImage: true,
            ),
            end: const ImagePoint(
              pixelX: 150.0,
              pixelY: 150.0,
              isInsideImage: true,
            ),
            frameIndex: 0,
            geometry: DicomImageGeometry(
              columns: 256,
              rows: 1024,
              rowSpacing: rowSpacing,
              columnSpacing: colSpacing,
            ),
          );

          expect(roi.isValid, isTrue);
          expect(roi.pixelWidth, equals(100));
          expect(roi.pixelHeight, equals(50));
          expect(roi.areaPx, equals(5000));
          expect(roi.hasPhysicalMeasurement, isTrue);
          expect(roi.physicalWidthMm, closeTo(100 * colSpacing, 0.001));
          expect(roi.physicalHeightMm, closeTo(50 * rowSpacing, 0.001));
          expect(roi.areaMm2, closeTo(5000 * rowSpacing * colSpacing, 0.001));
        },
      );
    });

    group('Group 7: Malformed JPEG Payload Error Handling', () {
      test(
        '7.1 Truncated or corrupt frame throws explicit FormatException',
        () {
          final corruptBytes = Uint8List.fromList([
            0xFF,
            0xD8,
            0xFF,
            0xC0,
            0x00,
            0x04,
          ]);
          expect(
            () => const JpegLosslessDecoder().decodeFrame(
              frameBytes: corruptBytes,
              info: PixelDataInfo.fromDataset(jpegLlDataset),
            ),
            throwsFormatException,
          );
        },
      );
    });
  });
}
