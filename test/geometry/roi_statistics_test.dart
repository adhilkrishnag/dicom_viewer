import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dicom_viewer/src/geometry/dicom_roi_statistics_engine.dart';
import 'package:dicom_viewer/src/parsing/dicom_dataset.dart';
import '../generate_fixture.dart';

void main() {
  group('Group 1: Synthetic Pixel Data Unit Tests', () {
    test('1. Single-pixel ROI (1x1) extraction and exact value match', () {
      // 4x4 image, pixel (2,2) = 150. Stored 150, Slope=1.0, Intercept=-1024.0 => -874.0 HU
      final pixelBytes = Uint8List(4 * 4 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      for (int i = 0; i < 16; i++) {
        bd.setUint16(i * 2, 0, Endian.little);
      }
      bd.setUint16((2 * 4 + 2) * 2, 150, Endian.little);

      final bytes = SyntheticDicomGenerator.create(
        width: 4,
        height: 4,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        rescaleSlope: 1.0,
        rescaleIntercept: -1024.0,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      // Continuous pixel (2,2) center is (2.5, 2.5). Box [2.1, 2.1] to [2.9, 2.9]
      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(2.1, 2.1, 2.9, 2.9),
        frameIndex: 0,
      );

      expect(stats.pixelCount, 1);
      expect(stats.validPixelCount, 1);
      expect(stats.excludedPaddingCount, 0);
      expect(stats.hasValidPixels, isTrue);
      expect(stats.min, -874.0);
      expect(stats.max, -874.0);
      expect(stats.mean, -874.0);
      expect(stats.median, -874.0);
      expect(stats.standardDeviation, 0.0);
      expect(stats.unit, 'HU');
      expect(stats.isHounsfield, isTrue);
    });

    test(
      '2. Uniform pixel ROI returns zero variance and matching min/max/mean/median',
      () {
        final pixelBytes = Uint8List(8 * 8 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 64; i++) {
          bd.setUint16(
            i * 2,
            1024,
            Endian.little,
          ); // 1024 * 1.0 - 1024.0 = 0.0 HU (water)
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 8,
          height: 8,
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          rescaleSlope: 1.0,
          rescaleIntercept: -1024.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(1.0, 1.0, 5.0, 5.0),
          frameIndex: 0,
        );

        expect(
          stats.validPixelCount,
          16,
        ); // 4x4 pixels enclosed: cols 1..4, rows 1..4
        expect(stats.min, 0.0);
        expect(stats.max, 0.0);
        expect(stats.mean, 0.0);
        expect(stats.median, 0.0);
        expect(stats.standardDeviation, 0.0);
      },
    );

    test(
      '3. Bimodal distribution verification with known population SD (denominator N)',
      () {
        // 4x4 image, 8 pixels of value 10 (HU: -1014.0) and 8 pixels of value 20 (HU: -1004.0)
        // N = 8 pixels inside a 2x4 ROI (4 pixels of -1014, 4 pixels of -1004)
        // Mean = -1009.0
        // Variance = (4 * 25 + 4 * 25) / 8 = 200 / 8 = 25.0
        // Population SD = sqrt(25.0) = 5.0
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int r = 0; r < 4; r++) {
          for (int c = 0; c < 4; c++) {
            final val = (r < 2) ? 10 : 20;
            bd.setUint16((r * 4 + c) * 2, val, Endian.little);
          }
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          rescaleSlope: 1.0,
          rescaleIntercept: -1024.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(
            0.0,
            1.0,
            4.0,
            3.0,
          ), // rows 1 and 2 (4 of val 10, 4 of val 20)
          frameIndex: 0,
        );

        expect(stats.validPixelCount, 8);
        expect(stats.min, -1014.0);
        expect(stats.max, -1004.0);
        expect(stats.mean, -1009.0);
        expect(stats.median, -1009.0);
        expect(stats.standardDeviation, closeTo(5.0, 1e-6));
      },
    );

    test('4. Sub-pixel continuous ROI inclusion rules (pixel-center test)', () {
      // 4x4 image
      final pixelBytes = Uint8List(4 * 4 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      for (int i = 0; i < 16; i++) {
        bd.setUint16(i * 2, i * 10, Endian.little);
      }

      final bytes = SyntheticDicomGenerator.create(
        width: 4,
        height: 4,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      // Box [0.6, 0.6] to [1.4, 1.4] contains no pixel centers (centers are at 0.5 and 1.5)
      // (0.6 - 0.5).ceil() = 1, (1.4 - 0.5).floor() = 0 => minCol(1) > maxCol(0) => empty
      final emptyStats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.6, 0.6, 1.4, 1.4),
        frameIndex: 0,
      );
      expect(emptyStats.pixelCount, 0);
      expect(emptyStats.hasValidPixels, isFalse);

      // Box [0.4, 0.4] to [1.6, 1.6] contains centers (0.5, 0.5), (1.5, 0.5), (0.5, 1.5), (1.5, 1.5) => 4 pixels
      final fourStats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.4, 0.4, 1.6, 1.6),
        frameIndex: 0,
      );
      expect(fourStats.validPixelCount, 4);
    });

    test(
      '5. Swapped / Reversed drag corners normalization produces identical statistics',
      () {
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 16; i++) {
          bd.setUint16(i * 2, i + 1, Endian.little);
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        // Top-left to bottom-right
        const rectForward = Rect.fromLTRB(0.0, 0.0, 2.0, 2.0);
        final statsForward = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: rectForward,
          frameIndex: 0,
        );

        // Bottom-right to top-left normalized
        final rectReversed = Rect.fromLTRB(
          math.min(2.0, 0.0),
          math.min(2.0, 0.0),
          math.max(2.0, 0.0),
          math.max(2.0, 0.0),
        );
        final statsReversed = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: rectReversed,
          frameIndex: 0,
        );

        expect(statsForward, equals(statsReversed));
      },
    );

    test('6. Image boundary corners ([0,0] and [W,H]) clamped safely', () {
      final pixelBytes = Uint8List(4 * 4 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      for (int i = 0; i < 16; i++) {
        bd.setUint16(i * 2, 50, Endian.little);
      }

      final bytes = SyntheticDicomGenerator.create(
        width: 4,
        height: 4,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      final statsFull = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.0, 0.0, 4.0, 4.0),
        frameIndex: 0,
      );

      expect(statsFull.validPixelCount, 16);
    });

    test('7. Zero-area ROI returns empty / invalid statistics', () {
      final bytes = SyntheticDicomGenerator.create(width: 4, height: 4);
      final dataset = DicomDataset.fromBytes(bytes);

      final statsZero = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(1.0, 1.0, 1.0, 1.0),
        frameIndex: 0,
      );

      expect(statsZero.pixelCount, 0);
      expect(statsZero.validPixelCount, 0);
      expect(statsZero.hasValidPixels, isFalse);
    });
  });

  group('Group 2: Explicit Rescale & Hounsfield Unit Semantics Tests', () {
    test(
      '8. Explicit CT rescale (slope=1.0, intercept=-1024.0) derives negative/positive HU with unit "HU"',
      () {
        // Stored 0 => -1024 HU (Air), Stored 2024 => +1000 HU (Dense bone)
        final pixelBytes = Uint8List(2 * 2 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setUint16(0, 0, Endian.little);
        bd.setUint16(2, 2024, Endian.little);
        bd.setUint16(4, 1024, Endian.little); // 0 HU
        bd.setUint16(6, 1064, Endian.little); // +40 HU

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          modality: 'CT',
          rescaleSlope: 1.0,
          rescaleIntercept: -1024.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
          frameIndex: 0,
        );

        expect(stats.isHounsfield, isTrue);
        expect(stats.unit, 'HU');
        expect(stats.min, -1024.0);
        expect(stats.max, 1000.0);
        expect(stats.formattedLines.first, contains('HU'));
      },
    );

    test(
      '9. Non-integer rescale slope (0.5) and non-zero intercept (+50.0)',
      () {
        final pixelBytes = Uint8List(2 * 2 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setUint16(0, 100, Endian.little); // 100 * 0.5 + 50.0 = 100.0
        bd.setUint16(2, 200, Endian.little); // 200 * 0.5 + 50.0 = 150.0
        bd.setUint16(4, 300, Endian.little); // 300 * 0.5 + 50.0 = 200.0
        bd.setUint16(6, 400, Endian.little); // 400 * 0.5 + 50.0 = 250.0

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          modality: 'CT',
          rescaleSlope: 0.5,
          rescaleIntercept: 50.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
          frameIndex: 0,
        );

        expect(stats.isHounsfield, isTrue);
        expect(stats.unit, 'HU');
        expect(stats.min, 100.0);
        expect(stats.max, 250.0);
        expect(stats.mean, 175.0);
      },
    );

    test(
      '10. CT modality with MISSING Rescale Slope strictly prohibits HU unit label (unitless)',
      () {
        final pixelBytes = Uint8List(2 * 2 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setUint16(0, 500, Endian.little);
        bd.setUint16(2, 600, Endian.little);
        bd.setUint16(4, 700, Endian.little);
        bd.setUint16(6, 800, Endian.little);

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          modality: 'CT',
          includeRescaleSlope: false, // Omit Rescale Slope tag
          rescaleIntercept: 0.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
          frameIndex: 0,
        );

        expect(stats.isHounsfield, isFalse);
        expect(stats.unit, '');
        expect(stats.formattedLines.first, isNot(contains('HU')));
        expect(stats.formattedLines.first, isNot(contains('px')));
      },
    );

    test(
      '11. MR modality with rescale tags strictly prohibits HU unit label (unitless)',
      () {
        final pixelBytes = Uint8List(2 * 2 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setUint16(0, 100, Endian.little);
        bd.setUint16(2, 200, Endian.little);
        bd.setUint16(4, 300, Endian.little);
        bd.setUint16(6, 400, Endian.little);

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          modality: 'MR',
          rescaleSlope: 1.0,
          rescaleIntercept: 0.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
          frameIndex: 0,
        );

        expect(stats.isHounsfield, isFalse);
        expect(stats.unit, '');
        expect(stats.mean, 250.0);
        expect(stats.formattedLines.first, isNot(contains('HU')));
        expect(stats.formattedLines.first, isNot(contains('px')));
      },
    );

    test(
      '12. Malformed / Non-positive rescale slope (e.g. 0.0) falls back cleanly to stored values',
      () {
        final pixelBytes = Uint8List(2 * 2 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setUint16(0, 100, Endian.little);
        bd.setUint16(2, 200, Endian.little);
        bd.setUint16(4, 300, Endian.little);
        bd.setUint16(6, 400, Endian.little);

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          modality: 'CT',
          rescaleSlopeString: '0.0', // Non-positive slope
          rescaleIntercept: 0.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
          frameIndex: 0,
        );

        expect(stats.isHounsfield, isFalse);
        expect(stats.unit, '');
        expect(stats.mean, 250.0); // Uses stored values with slope fallback 1.0
      },
    );
  });

  group('Group 3: Pixel Representation & Bit Depth Tests', () {
    test('13. Unsigned 8-bit pixel statistics (0..255)', () {
      final pixelBytes = Uint8List.fromList([10, 20, 30, 40]);
      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        modality: 'CR',
        rescaleIntercept: 0.0,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
        frameIndex: 0,
      );

      expect(stats.validPixelCount, 4);
      expect(stats.min, 10.0);
      expect(stats.max, 40.0);
      expect(stats.mean, 25.0);
      expect(stats.median, 25.0);
    });

    test('14. Unsigned 16-bit pixel statistics (0..4095)', () {
      final pixelBytes = Uint8List(2 * 2 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      bd.setUint16(0, 1000, Endian.little);
      bd.setUint16(2, 2000, Endian.little);
      bd.setUint16(4, 3000, Endian.little);
      bd.setUint16(6, 4000, Endian.little);

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        bitsAllocated: 16,
        bitsStored: 12,
        highBit: 11,
        modality: 'DX',
        rescaleIntercept: 0.0,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
        frameIndex: 0,
      );

      expect(stats.validPixelCount, 4);
      expect(stats.min, 1000.0);
      expect(stats.max, 4000.0);
      expect(stats.mean, 2500.0);
    });

    test('15. Signed 16-bit 2\'s complement negative value statistics', () {
      final pixelBytes = Uint8List(2 * 2 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      bd.setInt16(0, -1000, Endian.little);
      bd.setInt16(2, -500, Endian.little);
      bd.setInt16(4, 0, Endian.little);
      bd.setInt16(6, 500, Endian.little);

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        pixelRepresentation: 1, // Signed
        modality: 'MR',
        rescaleSlope: 1.0,
        rescaleIntercept: 0.0,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
        frameIndex: 0,
      );

      expect(stats.validPixelCount, 4);
      expect(stats.min, -1000.0);
      expect(stats.max, 500.0);
      expect(stats.mean, -250.0);
      expect(stats.median, -250.0);
    });
  });

  group('Group 4: Pixel Padding Exclusion Tests', () {
    test('17. Single PixelPaddingValue (0) is excluded from statistics', () {
      // 2x2 image: pixels are 0, 100, 200, 300. Padding = 0
      final pixelBytes = Uint8List(2 * 2 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      bd.setUint16(0, 0, Endian.little); // Padding
      bd.setUint16(2, 100, Endian.little);
      bd.setUint16(4, 200, Endian.little);
      bd.setUint16(6, 300, Endian.little);

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        modality: 'MR',
        rescaleIntercept: 0.0,
        pixelPaddingValue: 0,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
        frameIndex: 0,
      );

      expect(stats.pixelCount, 4);
      expect(stats.validPixelCount, 3);
      expect(stats.excludedPaddingCount, 1);
      expect(stats.min, 100.0);
      expect(stats.max, 300.0);
      expect(stats.mean, 200.0);
      expect(stats.median, 200.0);
    });

    test(
      '18. PixelPaddingValue + PixelPaddingRangeLimit [0..10] range is excluded',
      () {
        final pixelBytes = Uint8List(2 * 2 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setUint16(0, 0, Endian.little); // in padding range
        bd.setUint16(2, 5, Endian.little); // in padding range
        bd.setUint16(4, 10, Endian.little); // in padding range
        bd.setUint16(6, 50, Endian.little); // valid

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          modality: 'MR',
          rescaleIntercept: 0.0,
          pixelPaddingValue: 0,
          pixelPaddingRangeLimit: 10,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
          frameIndex: 0,
        );

        expect(stats.pixelCount, 4);
        expect(stats.validPixelCount, 1);
        expect(stats.excludedPaddingCount, 3);
        expect(stats.min, 50.0);
        expect(stats.max, 50.0);
        expect(stats.mean, 50.0);
        expect(stats.standardDeviation, 0.0);
      },
    );

    test('20. All-padding ROI -> hasValidPixels == false without NaN', () {
      final pixelBytes = Uint8List(2 * 2 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      bd.setUint16(0, 0, Endian.little);
      bd.setUint16(2, 0, Endian.little);
      bd.setUint16(4, 0, Endian.little);
      bd.setUint16(6, 0, Endian.little);

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        modality: 'CT',
        pixelPaddingValue: 0,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);

      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(0.0, 0.0, 2.0, 2.0),
        frameIndex: 0,
      );

      expect(stats.pixelCount, 4);
      expect(stats.validPixelCount, 0);
      expect(stats.excludedPaddingCount, 4);
      expect(stats.hasValidPixels, isFalse);
      expect(stats.mean.isNaN, isFalse);
      expect(stats.standardDeviation.isNaN, isFalse);
      expect(stats.formattedLines.first, 'Pixels: 0 valid (All padding)');
    });
  });

  group('Group 5: Real DICOM Fixture Tests', () {
    test(
      '21. CT_small.dcm real anatomical ROI calculation verifies "HU" unit',
      () {
        final file = File('test/fixtures/CT_small.dcm');
        if (!file.existsSync()) return;

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        // Sample a 20x20 region inside brain tissue
        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(50.0, 50.0, 70.0, 70.0),
          frameIndex: 0,
        );

        expect(stats.validPixelCount, greaterThan(0));
        expect(stats.isHounsfield, isTrue);
        expect(stats.unit, 'HU');
        expect(stats.formattedLines.first, contains('HU'));
        expect(stats.mean.isFinite, isTrue);
        expect(stats.standardDeviation, greaterThanOrEqualTo(0.0));
      },
    );

    test(
      '22. MR_small.dcm real ROI intensity statistics verifies unitless output (no HU, no px)',
      () {
        final file = File('test/fixtures/MR_small.dcm');
        if (!file.existsSync()) return;

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: dataset,
          normalizedRect: const Rect.fromLTRB(30.0, 30.0, 60.0, 60.0),
          frameIndex: 0,
        );

        expect(stats.validPixelCount, greaterThan(0));
        expect(stats.isHounsfield, isFalse);
        expect(stats.unit, '');
        expect(stats.formattedLines.first, isNot(contains('HU')));
        expect(stats.formattedLines.first, isNot(contains('px')));
      },
    );

    test('23. emri_small_RLE.dcm real RLE grayscale statistics extraction', () {
      final file = File('test/fixtures/emri_small_RLE.dcm');
      if (!file.existsSync()) return;

      final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTRB(10.0, 10.0, 30.0, 30.0),
        frameIndex: 0,
      );

      expect(stats.validPixelCount, greaterThan(0));
      expect(stats.isHounsfield, isFalse);
      expect(stats.mean.isFinite, isTrue);
    });
  });
}
