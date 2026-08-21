import 'dart:io';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  group('DicomImageGeometry Synthetic Tests', () {
    test(
      '1. Square Pixel Spacing with square matrix produces 1.0 aspect ratio',
      () {
        final bytes = SyntheticDicomGenerator.create(
          width: 512,
          height: 512,
          pixelSpacing: [0.5, 0.5],
        );
        final dataset = DicomDataset.fromBytes(bytes);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.columns, 512);
        expect(geometry.rows, 512);
        expect(geometry.rowSpacing, 0.5);
        expect(geometry.columnSpacing, 0.5);
        expect(geometry.hasPhysicalSpacing, isTrue);
        expect(geometry.physicalWidthMm, closeTo(256.0, 1e-5));
        expect(geometry.physicalHeightMm, closeTo(256.0, 1e-5));
        expect(geometry.displayAspectRatio, closeTo(1.0, 1e-5));
      },
    );

    test('2. Anisotropic (non-square) Pixel Spacing with square matrix', () {
      final bytes = SyntheticDicomGenerator.create(
        width: 512,
        height: 512,
        pixelSpacing: [
          1.25,
          0.85,
        ], // rowSpacing = 1.25 (y), columnSpacing = 0.85 (x)
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.columns, 512);
      expect(geometry.rows, 512);
      expect(geometry.rowSpacing, 1.25);
      expect(geometry.columnSpacing, 0.85);
      expect(geometry.hasPhysicalSpacing, isTrue);
      expect(geometry.physicalWidthMm, closeTo(512 * 0.85, 1e-5));
      expect(geometry.physicalHeightMm, closeTo(512 * 1.25, 1e-5));
      expect(geometry.displayAspectRatio, closeTo(0.85 / 1.25, 1e-5));
    });

    test(
      '3. Missing Pixel Spacing falls back to native pixel matrix aspect ratio',
      () {
        final bytes = SyntheticDicomGenerator.create(
          width: 64,
          height: 32,
          pixelSpacing: null,
        );
        final dataset = DicomDataset.fromBytes(bytes);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.columns, 64);
        expect(geometry.rows, 32);
        expect(geometry.rowSpacing, isNull);
        expect(geometry.columnSpacing, isNull);
        expect(geometry.hasPhysicalSpacing, isFalse);
        expect(geometry.physicalWidthMm, isNull);
        expect(geometry.physicalHeightMm, isNull);
        expect(geometry.displayAspectRatio, closeTo(2.0, 1e-5));
      },
    );

    test('4. Zero spacing values are rejected and fall back safely', () {
      const geometryBothZero = DicomImageGeometry(
        columns: 100,
        rows: 50,
        rowSpacing: 0.0,
        columnSpacing: 0.0,
      );
      expect(geometryBothZero.hasPhysicalSpacing, isFalse);
      expect(geometryBothZero.physicalWidthMm, isNull);
      expect(geometryBothZero.physicalHeightMm, isNull);
      expect(geometryBothZero.displayAspectRatio, closeTo(2.0, 1e-5));

      const geometryRowZero = DicomImageGeometry(
        columns: 100,
        rows: 50,
        rowSpacing: 0.0,
        columnSpacing: 0.5,
      );
      expect(geometryRowZero.hasPhysicalSpacing, isFalse);
      expect(geometryRowZero.displayAspectRatio, closeTo(2.0, 1e-5));

      const geometryColZero = DicomImageGeometry(
        columns: 100,
        rows: 50,
        rowSpacing: 0.5,
        columnSpacing: 0.0,
      );
      expect(geometryColZero.hasPhysicalSpacing, isFalse);
      expect(geometryColZero.displayAspectRatio, closeTo(2.0, 1e-5));
    });

    test('5. Negative spacing values are rejected and fall back safely', () {
      const geometryNegative = DicomImageGeometry(
        columns: 200,
        rows: 100,
        rowSpacing: -0.5,
        columnSpacing: 0.5,
      );
      expect(geometryNegative.hasPhysicalSpacing, isFalse);
      expect(geometryNegative.physicalWidthMm, isNull);
      expect(geometryNegative.physicalHeightMm, isNull);
      expect(geometryNegative.displayAspectRatio, closeTo(2.0, 1e-5));
    });

    test(
      '6. Non-finite spacing values (NaN, Infinity) are rejected and fall back safely',
      () {
        const geometryNan = DicomImageGeometry(
          columns: 100,
          rows: 100,
          rowSpacing: double.nan,
          columnSpacing: 0.5,
        );
        expect(geometryNan.hasPhysicalSpacing, isFalse);
        expect(geometryNan.displayAspectRatio, closeTo(1.0, 1e-5));

        const geometryInf = DicomImageGeometry(
          columns: 100,
          rows: 100,
          rowSpacing: 0.5,
          columnSpacing: double.infinity,
        );
        expect(geometryInf.hasPhysicalSpacing, isFalse);
        expect(geometryInf.displayAspectRatio, closeTo(1.0, 1e-5));
      },
    );

    test('7. Non-square matrix with square spacing', () {
      const geometry = DicomImageGeometry(
        columns: 800,
        rows: 600,
        rowSpacing: 0.5,
        columnSpacing: 0.5,
      );
      expect(geometry.hasPhysicalSpacing, isTrue);
      expect(geometry.physicalWidthMm, closeTo(400.0, 1e-5));
      expect(geometry.physicalHeightMm, closeTo(300.0, 1e-5));
      expect(geometry.displayAspectRatio, closeTo(800 / 600, 1e-5));
    });

    test('8. Non-square matrix with anisotropic spacing', () {
      const geometry = DicomImageGeometry(
        columns: 800,
        rows: 600,
        rowSpacing: 1.0,
        columnSpacing: 0.5,
      );
      expect(geometry.hasPhysicalSpacing, isTrue);
      expect(geometry.physicalWidthMm, closeTo(400.0, 1e-5));
      expect(geometry.physicalHeightMm, closeTo(600.0, 1e-5));
      expect(geometry.displayAspectRatio, closeTo(400.0 / 600.0, 1e-5));
    });

    test(
      '9. Invalid matrix dimensions (0 or negative) safely yield 1.0 aspect ratio',
      () {
        const geometryZeroCols = DicomImageGeometry(columns: 0, rows: 100);
        expect(geometryZeroCols.displayAspectRatio, 1.0);
        expect(geometryZeroCols.physicalWidthMm, isNull);

        const geometryZeroRows = DicomImageGeometry(columns: 100, rows: 0);
        expect(geometryZeroRows.displayAspectRatio, 1.0);
        expect(geometryZeroRows.physicalHeightMm, isNull);

        const geometryNegative = DicomImageGeometry(columns: -10, rows: -20);
        expect(geometryNegative.displayAspectRatio, 1.0);
      },
    );

    test('10. Value equality, hashCode, and toString formatting', () {
      const g1 = DicomImageGeometry(
        columns: 256,
        rows: 256,
        rowSpacing: 0.5,
        columnSpacing: 0.5,
      );
      const g2 = DicomImageGeometry(
        columns: 256,
        rows: 256,
        rowSpacing: 0.5,
        columnSpacing: 0.5,
      );
      const g3 = DicomImageGeometry(
        columns: 512,
        rows: 256,
        rowSpacing: 0.5,
        columnSpacing: 0.5,
      );

      expect(g1, equals(g2));
      expect(g1.hashCode, equals(g2.hashCode));
      expect(g1, isNot(equals(g3)));
      expect(g1.toString(), contains('DicomImageGeometry'));
      expect(g1.toString(), contains('columns: 256'));
    });
  });

  group('DicomImageGeometry Real DICOM Fixture Tests', () {
    test('1. CT_small.dcm geometry extraction (has physical spacing)', () {
      final file = File('test/fixtures/CT_small.dcm');
      expect(file.existsSync(), isTrue);

      final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.columns, 128);
      expect(geometry.rows, 128);
      expect(geometry.rowSpacing, isNotNull);
      expect(geometry.columnSpacing, isNotNull);
      expect(geometry.hasPhysicalSpacing, isTrue);
      expect(geometry.physicalWidthMm, isNotNull);
      expect(geometry.physicalHeightMm, isNotNull);
      expect(geometry.displayAspectRatio, closeTo(1.0, 1e-5));
    });

    test(
      '2. MR_small.dcm geometry extraction (has square physical spacing of 0.3125 mm)',
      () {
        final file = File('test/fixtures/MR_small.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.columns, 64);
        expect(geometry.rows, 64);
        expect(geometry.rowSpacing, closeTo(0.3125, 1e-5));
        expect(geometry.columnSpacing, closeTo(0.3125, 1e-5));
        expect(geometry.hasPhysicalSpacing, isTrue);
        expect(geometry.physicalWidthMm, closeTo(64 * 0.3125, 1e-5));
        expect(geometry.physicalHeightMm, closeTo(64 * 0.3125, 1e-5));
        expect(geometry.displayAspectRatio, closeTo(1.0, 1e-5));
      },
    );

    test(
      '3. OBXXXX1A_rle.dcm real RLE fixture geometry extraction (missing physical spacing -> native fallback)',
      () {
        final file = File('test/fixtures/rle/OBXXXX1A_rle.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.columns, 800);
        expect(geometry.rows, 600);
        expect(geometry.rowSpacing, isNull);
        expect(geometry.columnSpacing, isNull);
        expect(geometry.hasPhysicalSpacing, isFalse);
        expect(geometry.physicalWidthMm, isNull);
        expect(geometry.physicalHeightMm, isNull);
        expect(geometry.displayAspectRatio, closeTo(800 / 600, 1e-5));
      },
    );

    test(
      '4. emri_small_RLE.dcm real multi-frame RLE fixture geometry extraction (missing physical spacing -> native fallback)',
      () {
        final file = File('test/fixtures/rle/emri_small_RLE.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.columns, 64);
        expect(geometry.rows, 64);
        expect(geometry.rowSpacing, isNull);
        expect(geometry.columnSpacing, isNull);
        expect(geometry.hasPhysicalSpacing, isFalse);
        expect(geometry.physicalWidthMm, isNull);
        expect(geometry.physicalHeightMm, isNull);
        expect(geometry.displayAspectRatio, closeTo(1.0, 1e-5));
      },
    );
  });
}
