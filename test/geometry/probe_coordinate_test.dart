import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/dicom_probe_painter.dart';
import 'package:dicom_viewer/src/geometry/dicom_roi_statistics_engine.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:dicom_viewer/src/parsing/dicom_dataset.dart';
import '../generate_fixture.dart';

void main() {
  group('Group 1: Discrete Pixel Selection & Coordinate Transform Rules', () {
    const geometry = DicomImageGeometry(columns: 100, rows: 100);
    const transform = ImageCoordinateTransform(
      geometry: geometry,
      viewportSize: Size(200, 200),
    );

    test(
      '1. Floor rule: continuous coordinate (0.0, 0.0) -> discrete cell (0, 0)',
      () {
        final p0 = transform.viewportToImage(const Offset(0.0, 0.0));
        expect(p0.pixelX.floor(), 0);
        expect(p0.pixelY.floor(), 0);
      },
    );

    test(
      '2. Floor rule: sub-pixel coordinates (0.1, 0.9) -> discrete cell (0, 0)',
      () {
        final pSub = transform.viewportToImage(
          const Offset(0.2, 1.8),
        ); // 0.1, 0.9 in image space
        expect(pSub.pixelX.floor(), 0);
        expect(pSub.pixelY.floor(), 0);
      },
    );

    test(
      '3. Floor rule: boundary transition (0.999 -> 1.000) -> cell (0, 0) to (1, 1)',
      () {
        final pBefore = transform.viewportToImage(const Offset(1.99, 1.99));
        expect(pBefore.pixelX.floor(), 0);
        expect(pBefore.pixelY.floor(), 0);

        final pAfter = transform.viewportToImage(const Offset(2.0, 2.0));
        expect(pAfter.pixelX.floor(), 1);
        expect(pAfter.pixelY.floor(), 1);
      },
    );

    test(
      '4. Floor rule: bottom-right corner (W-0.001, H-0.001) -> cell (W-1, H-1)',
      () {
        final pLast = transform.viewportToImage(const Offset(199.9, 199.9));
        expect(pLast.pixelX.floor(), 99);
        expect(pLast.pixelY.floor(), 99);
      },
    );

    test(
      '5. Out-of-bounds rejection: coordinates < 0.0 or >= columns/rows -> isInside = false',
      () {
        final pLeft = transform.viewportToImage(const Offset(-5, 50));
        expect(pLeft.isInsideImage, isFalse);

        final pRight = transform.viewportToImage(const Offset(205, 50));
        expect(pRight.isInsideImage, isFalse);

        final pTop = transform.viewportToImage(const Offset(50, -5));
        expect(pTop.isInsideImage, isFalse);

        final pBottom = transform.viewportToImage(const Offset(50, 205));
        expect(pBottom.isInsideImage, isFalse);
      },
    );
  });

  group('Group 2: Synthetic Modality & Explicit Rescale Semantics', () {
    test(
      '6. CT + explicit slope + explicit intercept -> isHounsfield = true, unit = "HU"',
      () {
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 16; i++) {
          bd.setUint16(i * 2, 1087, Endian.little);
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          modality: 'CT',
          photometricInterpretation: 'MONOCHROME2',
          bitsAllocated: 16,
          bitsStored: 12,
          highBit: 11,
          pixelRepresentation: 0,
          rescaleSlope: 1.0,
          rescaleIntercept: -1024.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final result = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 2,
          pixelRow: 2,
          rawPixels: rawPixels,
        );

        expect(result.isInside, isTrue);
        expect(result.pixelColumn, 2);
        expect(result.pixelRow, 2);
        expect(result.storedValue, 1087);
        expect(result.rescaledValue, 63.0);
        expect(result.isHounsfield, isTrue);
        expect(result.unit, 'HU');
        expect(result.formattedLines, [
          'Pixel: (2, 2)',
          'Stored: 1087',
          'HU: 63.0 HU',
        ]);
      },
    );

    test(
      '7. CT + missing Rescale Slope -> isHounsfield = false, unit = "", no "HU" label',
      () {
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 16; i++) {
          bd.setUint16(i * 2, 1087, Endian.little);
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          modality: 'CT',
          photometricInterpretation: 'MONOCHROME2',
          bitsAllocated: 16,
          bitsStored: 12,
          highBit: 11,
          pixelRepresentation: 0,
          includeRescaleSlope: false,
          rescaleIntercept: -1024.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final result = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 1,
          pixelRow: 1,
          rawPixels: rawPixels,
        );

        expect(result.isHounsfield, isFalse);
        expect(result.unit, '');
        expect(result.formattedLines, [
          'Pixel: (1, 1)',
          'Stored: 1087',
          'Value: 63.0',
        ]);
      },
    );

    test(
      '8. CT + missing Rescale Intercept -> isHounsfield = false, unit = "", no "HU" label',
      () {
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 16; i++) {
          bd.setUint16(i * 2, 1087, Endian.little);
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          modality: 'CT',
          photometricInterpretation: 'MONOCHROME2',
          bitsAllocated: 16,
          bitsStored: 12,
          highBit: 11,
          pixelRepresentation: 0,
          rescaleSlope: 1.0,
          includeRescaleIntercept: false,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final result = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 1,
          pixelRow: 1,
          rawPixels: rawPixels,
        );

        expect(result.isHounsfield, isFalse);
        expect(result.unit, '');
        expect(result.formattedLines, [
          'Pixel: (1, 1)',
          'Stored: 1087',
          'Value: 1087.0',
        ]);
      },
    );

    test(
      '9. CT + non-positive Rescale Slope (<= 0.0) -> falls back cleanly to stored value',
      () {
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 16; i++) {
          bd.setUint16(i * 2, 500, Endian.little);
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          modality: 'CT',
          photometricInterpretation: 'MONOCHROME2',
          bitsAllocated: 16,
          bitsStored: 12,
          highBit: 11,
          pixelRepresentation: 0,
          rescaleSlope: 0.0,
          rescaleIntercept: 0.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final result = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 0,
          pixelRow: 0,
          rawPixels: rawPixels,
        );

        expect(result.isHounsfield, isFalse);
        expect(result.unit, '');
        expect(result.storedValue, 500);
        expect(result.formattedLines, [
          'Pixel: (0, 0)',
          'Stored: 500',
          'Value: 500.0',
        ]);
      },
    );

    test(
      '10. MR modality with rescale tags present -> isHounsfield = false, unit = "", no "HU" label',
      () {
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 16; i++) {
          bd.setUint16(i * 2, 428, Endian.little);
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          modality: 'MR',
          photometricInterpretation: 'MONOCHROME2',
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          pixelRepresentation: 0,
          rescaleSlope: 1.0,
          rescaleIntercept: 0.0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final result = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 0,
          pixelRow: 0,
          rawPixels: rawPixels,
        );

        expect(result.isHounsfield, isFalse);
        expect(result.unit, '');
        expect(result.storedValue, 428);
        expect(result.formattedLines, [
          'Pixel: (0, 0)',
          'Stored: 428',
          'Value: 428.0',
        ]);
      },
    );

    test(
      '11. CR / DX modality -> isHounsfield = false, unit = "", no "HU" label',
      () {
        final pixelBytes = Uint8List(4 * 4 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        for (int i = 0; i < 16; i++) {
          bd.setUint16(i * 2, 1820, Endian.little);
        }

        final bytes = SyntheticDicomGenerator.create(
          width: 4,
          height: 4,
          modality: 'DX',
          photometricInterpretation: 'MONOCHROME2',
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          pixelRepresentation: 0,
          includeRescaleSlope: false,
          includeRescaleIntercept: false,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final result = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 1,
          pixelRow: 1,
          rawPixels: rawPixels,
        );

        expect(result.isHounsfield, isFalse);
        expect(result.unit, '');
        expect(result.storedValue, 1820);
        expect(result.formattedLines, ['Pixel: (1, 1)', 'Value: 1820']);
      },
    );
  });

  group('Group 3: Pixel Depth, Representation & Padding Semantics', () {
    test('12. Unsigned 8-bit (0..255) value extraction', () {
      final pixelBytes = Uint8List.fromList([10, 50, 100, 255]);
      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        modality: 'OT',
        photometricInterpretation: 'MONOCHROME2',
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        pixelRepresentation: 0,
        includeRescaleSlope: false,
        includeRescaleIntercept: false,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);

      final result = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 1,
        pixelRow: 1,
        rawPixels: rawPixels,
      );

      expect(result.storedValue, 255);
      expect(result.formattedLines, ['Pixel: (1, 1)', 'Value: 255']);
    });

    test('13. Unsigned 16-bit (0..4095) value extraction with bit masking', () {
      final pixelBytes = Uint8List(2 * 2 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      bd.setUint16(0, 0x0FFF, Endian.little); // 4095
      bd.setUint16(
        2,
        0x1FFF,
        Endian.little,
      ); // Masked to 4095 with 12 bitsStored

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 1,
        modality: 'CT',
        photometricInterpretation: 'MONOCHROME2',
        bitsAllocated: 16,
        bitsStored: 12,
        highBit: 11,
        pixelRepresentation: 0,
        includeRescaleSlope: false,
        includeRescaleIntercept: false,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);

      final result = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 1,
        pixelRow: 0,
        rawPixels: rawPixels,
      );

      expect(result.storedValue, 4095);
    });

    test('14. Signed 16-bit two\'s complement negative value extraction', () {
      final pixelBytes = Uint8List(2 * 1 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      bd.setInt16(0, -1024, Endian.little);

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 1,
        modality: 'CT',
        photometricInterpretation: 'MONOCHROME2',
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        pixelRepresentation: 1, // Signed
        rescaleSlope: 1.0,
        rescaleIntercept: 0.0,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);

      final result = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 0,
        pixelRow: 0,
        rawPixels: rawPixels,
      );

      expect(result.storedValue, -1024);
      expect(result.rescaledValue, -1024.0);
      expect(result.formattedLines, [
        'Pixel: (0, 0)',
        'Stored: -1024',
        'HU: -1024.0 HU',
      ]);
    });

    test(
      '15. Single Pixel Padding Value match -> isPadding = true, formatted as "(Padding)"',
      () {
        final pixelBytes = Uint8List(2 * 1 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setUint16(0, 0, Endian.little);

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 1,
          modality: 'CT',
          photometricInterpretation: 'MONOCHROME2',
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          pixelRepresentation: 0,
          rescaleSlope: 1.0,
          rescaleIntercept: 0.0,
          pixelPaddingValue: 0,
          customPixelData: pixelBytes,
        );
        final dataset = DicomDataset.fromBytes(bytes);
        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );

        final result = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 0,
          pixelRow: 0,
          rawPixels: rawPixels,
        );

        expect(result.isPadding, isTrue);
        expect(result.formattedLines, [
          'Pixel: (0, 0)',
          'Stored: 0 (Padding)',
          'HU: 0.0 HU',
        ]);
      },
    );

    test('16. Pixel Padding Range match -> isPadding = true', () {
      final pixelBytes = Uint8List(2 * 1 * 2);
      final bd = ByteData.sublistView(pixelBytes);
      bd.setUint16(0, 5, Endian.little);

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 1,
        modality: 'CT',
        photometricInterpretation: 'MONOCHROME2',
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        pixelRepresentation: 0,
        rescaleSlope: 1.0,
        rescaleIntercept: 0.0,
        pixelPaddingValue: 0,
        pixelPaddingRangeLimit: 10,
        customPixelData: pixelBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);

      final result = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 0,
        pixelRow: 0,
        rawPixels: rawPixels,
      );

      expect(result.isPadding, isTrue);
      expect(result.formattedLines, [
        'Pixel: (0, 0)',
        'Stored: 5 (Padding)',
        'HU: 5.0 HU',
      ]);
    });

    test(
      '17. Palette Color LUT dataset -> extracts RGB triplet and palette index',
      () {
        final file = File('test/fixtures/rle/OBXXXX1A_rle.dcm');
        final bytes = file.readAsBytesSync();
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final probe = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 100,
          pixelRow: 100,
          rawPixels: rawPixels,
        );

        expect(probe.isInside, isTrue);
        expect(probe.rgb, isNotNull);
        expect(probe.rgb!.length, 3);
        expect(probe.paletteIndex, isNotNull);
        expect(probe.formattedLines.any((l) => l.startsWith('RGB:')), isTrue);
        expect(probe.formattedLines.any((l) => l.startsWith('Index:')), isTrue);
      },
    );
  });

  group('Group 4: Real DICOM Fixtures Probe Evaluation', () {
    test('18. CT_small.dcm: probes brain parenchyma in HU', () {
      final file = File('test/fixtures/CT_small.dcm');
      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);

      final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);
      final probe = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 64,
        pixelRow: 64,
        rawPixels: rawPixels,
      );

      expect(probe.isInside, isTrue);
      expect(probe.isHounsfield, isTrue);
      expect(probe.unit, 'HU');
      expect(probe.storedValue, isNotNull);
      expect(probe.rescaledValue, isNotNull);
      expect(probe.rescaledValue, probe.storedValue! * 1.0 - 1024.0);
    });

    test(
      '19. MR_small.dcm: probes unitless scalar value (no HU, no px in intensity)',
      () {
        final file = File('test/fixtures/MR_small.dcm');
        final bytes = file.readAsBytesSync();
        final dataset = DicomDataset.fromBytes(bytes);

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final probe = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 32,
          pixelRow: 32,
          rawPixels: rawPixels,
        );

        expect(probe.isInside, isTrue);
        expect(probe.isHounsfield, isFalse);
        expect(probe.unit, '');
        expect(probe.storedValue, isNotNull);
        expect(probe.formattedLines.any((l) => l.contains('HU')), isFalse);
        expect(probe.formattedLines.any((l) => l.contains('px')), isFalse);
      },
    );

    test('20. emri_small_RLE.dcm: probes RLE-compressed 16-bit grayscale', () {
      final file = File('test/fixtures/rle/emri_small_RLE.dcm');
      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);

      final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);
      expect(rawPixels.length, 64 * 64);

      final probe = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 32,
        pixelRow: 32,
        rawPixels: rawPixels,
      );

      expect(probe.isInside, isTrue);
      expect(probe.storedValue, isNotNull);
    });

    test('21. OBXXXX1A_rle.dcm: probes Palette Color LUT with RGB triplet', () {
      final file = File('test/fixtures/rle/OBXXXX1A_rle.dcm');
      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);

      final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);
      final probe = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 50,
        pixelRow: 50,
        rawPixels: rawPixels,
      );

      expect(probe.isInside, isTrue);
      expect(probe.rgb, isNotNull);
      expect(probe.paletteIndex, isNotNull);
    });

    test('22. OBXXXX1A_rle_2frame.dcm: multi-frame isolation', () {
      final file = File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm');
      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);
      expect(dataset.numberOfFrames, 2);

      final rawPixelsF0 = DicomRoiStatisticsEngine.extractFramePixels(
        dataset,
        0,
      );
      final rawPixelsF1 = DicomRoiStatisticsEngine.extractFramePixels(
        dataset,
        1,
      );

      final probeF0 = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 50,
        pixelRow: 50,
        rawPixels: rawPixelsF0,
      );

      final probeF1 = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 50,
        pixelRow: 50,
        rawPixels: rawPixelsF1,
      );

      expect(probeF0.isInside, isTrue);
      expect(probeF1.isInside, isTrue);
      expect(probeF0.rgb, isNotNull);
      expect(probeF1.rgb, isNotNull);
    });
  });
}
