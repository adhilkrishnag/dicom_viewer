import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/distance_measurement.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_measurement.dart';

import '../generate_fixture.dart';

void main() {
  group('1. Verified Physical Geometry (Explicit Pixel Spacing 0028,0030)', () {
    test('Valid Pixel Spacing establishes verified physical geometry', () {
      final bytes = SyntheticDicomGenerator.create(
        width: 512,
        height: 256,
        pixelSpacing: [1.0, 0.5], // rowSpacing=1.0, colSpacing=0.5
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.hasPhysicalSpacing, isTrue);
      expect(geometry.rowSpacing, closeTo(1.0, 1e-6));
      expect(geometry.columnSpacing, closeTo(0.5, 1e-6));
      // physicalWidth = 512 * 0.5 = 256mm
      expect(geometry.physicalWidthMm, closeTo(256.0, 1e-6));
      // physicalHeight = 256 * 1.0 = 256mm
      expect(geometry.physicalHeightMm, closeTo(256.0, 1e-6));
      // displayAspectRatio = (512 * 0.5) / (256 * 1.0) = 1.0
      expect(geometry.displayAspectRatio, closeTo(1.0, 1e-6));
    });

    test(
      'Distance and Rectangle ROI compute verified physical millimeters',
      () {
        const geometry = DicomImageGeometry(
          columns: 512,
          rows: 512,
          rowSpacing: 0.5,
          columnSpacing: 0.5,
        );

        const p1 = ImagePoint(pixelX: 100, pixelY: 100, isInsideImage: true);
        const p2 = ImagePoint(pixelX: 200, pixelY: 200, isInsideImage: true);

        final distance = DicomDistanceMeasurement.fromPoints(
          start: p1,
          end: p2,
          frameIndex: 0,
          geometry: geometry,
        );

        expect(distance.hasPhysicalMeasurement, isTrue);
        // deltaX = 100 * 0.5 = 50mm, deltaY = 100 * 0.5 = 50mm
        // dist = sqrt(50^2 + 50^2) = 70.710678 mm
        expect(distance.physicalDistanceMm, closeTo(70.710678, 1e-4));
        expect(distance.formattedDistance, contains('mm'));
        expect(distance.formattedDistance, isNot(contains('px')));

        final roi = DicomRectangleRoiMeasurement.fromImagePoints(
          start: p1,
          end: p2,
          frameIndex: 0,
          geometry: geometry,
        );

        expect(roi.hasPhysicalMeasurement, isTrue);
        expect(roi.physicalWidthMm, closeTo(50.0, 1e-6));
        expect(roi.physicalHeightMm, closeTo(50.0, 1e-6));
        expect(roi.areaMm2, closeTo(2500.0, 1e-6));
        expect(roi.formattedDimensions, contains('mm'));
        expect(roi.formattedDimensions, contains('mm\u00B2'));
      },
    );

    test(
      'Pixel Spacing takes strict precedence when Pixel Aspect Ratio also present',
      () {
        final bytes = SyntheticDicomGenerator.create(
          width: 512,
          height: 256,
          pixelSpacing: [0.5, 0.5],
          pixelAspectRatio: [
            4,
            3,
          ], // Should be ignored because Pixel Spacing is valid
        );
        final dataset = DicomDataset.fromBytes(bytes);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.hasPhysicalSpacing, isTrue);
        expect(geometry.rowSpacing, closeTo(0.5, 1e-6));
        expect(geometry.columnSpacing, closeTo(0.5, 1e-6));
        // Aspect ratio must be based on physical spacing, not PAR:
        // (512 * 0.5) / (256 * 0.5) = 2.0
        expect(geometry.displayAspectRatio, closeTo(2.0, 1e-6));
      },
    );
  });

  group('2. Display-Only Geometry (Pixel Aspect Ratio 0028,0034 Fallback)', () {
    test('Pixel Aspect Ratio provides display aspect ratio correction only', () {
      final bytes = SyntheticDicomGenerator.create(
        width: 512,
        height: 512,
        pixelAspectRatio: [4, 3], // vertical=4, horizontal=3
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final geometry = DicomImageGeometry.fromDataset(dataset);

      // Display aspect ratio = (columns * h) / (rows * v) = (512 * 3) / (512 * 4) = 0.75
      expect(geometry.displayAspectRatio, closeTo(0.75, 1e-6));
      expect(geometry.hasPhysicalSpacing, isFalse);
      expect(geometry.rowSpacing, isNull);
      expect(geometry.columnSpacing, isNull);
      expect(geometry.physicalWidthMm, isNull);
      expect(geometry.physicalHeightMm, isNull);
    });

    test(
      'Pixel Aspect Ratio strictly prohibits deriving millimeters for Distance Measurement',
      () {
        final bytes = SyntheticDicomGenerator.create(
          width: 512,
          height: 512,
          pixelAspectRatio: [16, 9],
        );
        final dataset = DicomDataset.fromBytes(bytes);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        const p1 = ImagePoint(pixelX: 50, pixelY: 50, isInsideImage: true);
        const p2 = ImagePoint(pixelX: 150, pixelY: 150, isInsideImage: true);

        final distance = DicomDistanceMeasurement.fromPoints(
          start: p1,
          end: p2,
          frameIndex: 0,
          geometry: geometry,
        );

        expect(distance.hasPhysicalMeasurement, isFalse);
        expect(distance.physicalDistanceMm, isNull);
        expect(distance.deltaPhysicalXMm, isNull);
        expect(distance.deltaPhysicalYMm, isNull);
        expect(distance.pixelDistance, closeTo(141.421356, 1e-4));
        expect(distance.formattedDistance, contains('px'));
        expect(distance.formattedDistance, isNot(contains('mm')));
      },
    );

    test(
      'Pixel Aspect Ratio strictly prohibits deriving millimeters for Rectangle ROI',
      () {
        final bytes = SyntheticDicomGenerator.create(
          width: 512,
          height: 512,
          pixelAspectRatio: [4, 3],
        );
        final dataset = DicomDataset.fromBytes(bytes);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        const p1 = ImagePoint(pixelX: 100, pixelY: 100, isInsideImage: true);
        const p2 = ImagePoint(pixelX: 300, pixelY: 200, isInsideImage: true);

        final roi = DicomRectangleRoiMeasurement.fromImagePoints(
          start: p1,
          end: p2,
          frameIndex: 0,
          geometry: geometry,
        );

        expect(roi.hasPhysicalMeasurement, isFalse);
        expect(roi.physicalWidthMm, isNull);
        expect(roi.physicalHeightMm, isNull);
        expect(roi.areaMm2, isNull);
        expect(roi.pixelWidth, closeTo(200.0, 1e-6));
        expect(roi.pixelHeight, closeTo(100.0, 1e-6));
        expect(roi.areaPx, closeTo(20000.0, 1e-6));
        expect(roi.formattedDimensions, contains('px'));
        expect(roi.formattedDimensions, contains('px\u00B2'));
        expect(roi.formattedDimensions, isNot(contains('mm')));
      },
    );
  });

  group('3. Pixel-Only Geometry (Native Matrix Fallback)', () {
    test(
      'Native Matrix produces 1:1 pixel aspect ratio fallback and no physical scale',
      () {
        final bytes = SyntheticDicomGenerator.create(width: 640, height: 480);
        final dataset = DicomDataset.fromBytes(bytes);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.hasPhysicalSpacing, isFalse);
        expect(geometry.rowSpacing, isNull);
        expect(geometry.columnSpacing, isNull);
        expect(geometry.physicalWidthMm, isNull);
        expect(geometry.physicalHeightMm, isNull);
        // Native aspect ratio = 640 / 480 = 1.333333
        expect(geometry.displayAspectRatio, closeTo(640 / 480, 1e-6));
      },
    );

    test('Distance and Rectangle ROI operate in pure pixel mode', () {
      const geometry = DicomImageGeometry(columns: 512, rows: 512);

      const p1 = ImagePoint(pixelX: 0, pixelY: 0, isInsideImage: true);
      const p2 = ImagePoint(pixelX: 100, pixelY: 100, isInsideImage: true);

      final distance = DicomDistanceMeasurement.fromPoints(
        start: p1,
        end: p2,
        frameIndex: 0,
        geometry: geometry,
      );

      expect(distance.hasPhysicalMeasurement, isFalse);
      expect(distance.physicalDistanceMm, isNull);
      expect(distance.pixelDistance, closeTo(141.421356, 1e-4));
      expect(distance.formattedDistance, contains('px (Physical unavailable)'));

      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: p1,
        end: p2,
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.hasPhysicalMeasurement, isFalse);
      expect(roi.physicalWidthMm, isNull);
      expect(roi.physicalHeightMm, isNull);
      expect(roi.areaMm2, isNull);
      expect(roi.pixelWidth, closeTo(100.0, 1e-6));
      expect(roi.pixelHeight, closeTo(100.0, 1e-6));
      expect(roi.areaPx, closeTo(10000.0, 1e-6));
      expect(roi.formattedDimensions, contains('px'));
    });
  });

  group('4. Unavailable Geometry State', () {
    test('Zero or negative matrix dimensions classify as unavailable', () {
      const gZeroCols = DicomImageGeometry(columns: 0, rows: 512);
      expect(gZeroCols.hasPhysicalSpacing, isFalse);
      expect(gZeroCols.physicalWidthMm, isNull);
      expect(gZeroCols.physicalHeightMm, isNull);
      expect(gZeroCols.displayAspectRatio, equals(1.0));

      const gZeroRows = DicomImageGeometry(columns: 512, rows: 0);
      expect(gZeroRows.hasPhysicalSpacing, isFalse);
      expect(gZeroRows.displayAspectRatio, equals(1.0));

      const gNeg = DicomImageGeometry(columns: -10, rows: -10);
      expect(gNeg.hasPhysicalSpacing, isFalse);
      expect(gNeg.displayAspectRatio, equals(1.0));
    });

    test(
      'Empty dataset produces unavailable geometry with safe 1.0 display aspect ratio',
      () {
        final dataset = DicomDataset(const []);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.columns, equals(0));
        expect(geometry.rows, equals(0));
        expect(geometry.hasPhysicalSpacing, isFalse);
        expect(geometry.displayAspectRatio, equals(1.0));
      },
    );
  });

  group('5. Fallback Hierarchy & Malformed Tag Resolution', () {
    test('Zero Pixel Spacing falls back to Pixel Aspect Ratio if present', () {
      final bytes = SyntheticDicomGenerator.create(
        width: 512,
        height: 512,
        pixelSpacing: [0.0, 0.0], // Invalid zero spacing
        pixelAspectRatio: [4, 3], // Valid PAR
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.hasPhysicalSpacing, isFalse);
      // Falls back to PAR: (512 * 3) / (512 * 4) = 0.75
      expect(geometry.displayAspectRatio, closeTo(0.75, 1e-6));
    });

    test(
      'Negative Pixel Spacing falls back to Native Matrix when PAR absent',
      () {
        final bytes = SyntheticDicomGenerator.create(
          width: 600,
          height: 300,
          pixelSpacing: [-0.5, 0.5], // Invalid negative spacing
        );
        final dataset = DicomDataset.fromBytes(bytes);
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.hasPhysicalSpacing, isFalse);
        // Falls back to native matrix: 600 / 300 = 2.0
        expect(geometry.displayAspectRatio, closeTo(2.0, 1e-6));
      },
    );

    test('Non-finite (NaN / Infinity) Pixel Spacing falls back cleanly', () {
      final bytes = SyntheticDicomGenerator.create(
        width: 400,
        height: 400,
        pixelSpacing: [double.nan, 0.5],
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.hasPhysicalSpacing, isFalse);
      expect(geometry.displayAspectRatio, closeTo(1.0, 1e-6));
    });

    test('Zero / Negative Pixel Aspect Ratio falls back to Native Matrix', () {
      final bytes = SyntheticDicomGenerator.create(
        width: 800,
        height: 400,
        pixelAspectRatio: [0, 1], // Invalid 0 ratio
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.hasPhysicalSpacing, isFalse);
      // Falls back to native matrix: 800 / 400 = 2.0
      expect(geometry.displayAspectRatio, closeTo(2.0, 1e-6));
    });

    test(
      'Deferred Source: Imager Pixel Spacing (0018,1164) is ignored in v0.4.0',
      () {
        // Create dataset with Imager Pixel Spacing (0018,1164)
        final rawBytes = SyntheticDicomGenerator.create(
          width: 512,
          height: 512,
        );
        // Add tag (0018,1164) manually to test dataset
        const imagerSpacingTag = DicomTag(0x0018, 0x1164);
        final valueBytes = Uint8List.fromList('0.25\\0.25'.codeUnits);
        final elem = DicomDataElement(
          tag: imagerSpacingTag,
          vr: ValueRepresentation.ds,
          valueLength: valueBytes.length,
          valueBytes: valueBytes,
        );
        final baseDataset = DicomDataset.fromBytes(rawBytes);
        final combinedElements = Map<DicomTag, DicomDataElement>.from(
          baseDataset.elements,
        );
        combinedElements[imagerSpacingTag] = elem;
        final datasetWithImagerSpacing = DicomDataset(combinedElements.values);

        final geometry = DicomImageGeometry.fromDataset(
          datasetWithImagerSpacing,
        );

        // Imager Pixel Spacing MUST NOT be used to derive physical scale in v0.4.0
        expect(geometry.hasPhysicalSpacing, isFalse);
        expect(geometry.physicalWidthMm, isNull);
        expect(geometry.physicalHeightMm, isNull);
        expect(geometry.displayAspectRatio, closeTo(1.0, 1e-6));
      },
    );
  });

  group('6. Real DICOM Fixtures Verification', () {
    test('CT_small.dcm classifies as verified physical with Pixel Spacing', () {
      final dataset = DicomDataset.fromBytes(
        File('test/fixtures/CT_small.dcm').readAsBytesSync(),
      );
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.hasPhysicalSpacing, isTrue);
      expect(geometry.columns, equals(128));
      expect(geometry.rows, equals(128));
      expect(geometry.rowSpacing, isNotNull);
      expect(geometry.columnSpacing, isNotNull);
      expect(geometry.rowSpacing!, greaterThan(0));
      expect(geometry.columnSpacing!, greaterThan(0));
      expect(geometry.physicalWidthMm, isNotNull);
      expect(geometry.physicalHeightMm, isNotNull);
    });

    test('MR_small.dcm classifies as verified physical with Pixel Spacing', () {
      final dataset = DicomDataset.fromBytes(
        File('test/fixtures/MR_small.dcm').readAsBytesSync(),
      );
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.hasPhysicalSpacing, isTrue);
      expect(geometry.columns, equals(64));
      expect(geometry.rows, equals(64));
      expect(geometry.rowSpacing, isNotNull);
      expect(geometry.columnSpacing, isNotNull);
      expect(geometry.rowSpacing!, greaterThan(0));
      expect(geometry.columnSpacing!, greaterThan(0));
      expect(geometry.physicalWidthMm, isNotNull);
      expect(geometry.physicalHeightMm, isNotNull);
    });
  });
}
