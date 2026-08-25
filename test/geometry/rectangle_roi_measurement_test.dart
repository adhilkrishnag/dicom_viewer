import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_measurement.dart';
import 'package:dicom_viewer/src/parsing/dicom_dataset.dart';

void main() {
  group('ROI Geometry Tests (Synthetic)', () {
    const geometrySquare = DicomImageGeometry(
      columns: 512,
      rows: 512,
      rowSpacing: 0.5,
      columnSpacing: 0.5,
    );

    const geometryAnisotropic = DicomImageGeometry(
      columns: 512,
      rows: 256,
      rowSpacing: 1.0,
      columnSpacing: 0.5,
    );

    const geometryNoSpacing = DicomImageGeometry(columns: 512, rows: 512);

    const geometryInvalidSpacing = DicomImageGeometry(
      columns: 512,
      rows: 512,
      rowSpacing: 0.0,
      columnSpacing: -0.5,
    );

    ImagePoint insidePoint(double x, double y) =>
        ImagePoint(pixelX: x, pixelY: y, isInsideImage: true);

    test('1. Horizontal rectangle (wide, short)', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 200.0),
        end: insidePoint(300.0, 220.0),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.pixelWidth, closeTo(200.0, 1e-6));
      expect(roi.pixelHeight, closeTo(20.0, 1e-6));
      expect(roi.areaPx, closeTo(4000.0, 1e-6));
      expect(roi.isValid, isTrue);
    });

    test('2. Vertical rectangle (narrow, tall)', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(200.0, 50.0),
        end: insidePoint(220.0, 400.0),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.pixelWidth, closeTo(20.0, 1e-6));
      expect(roi.pixelHeight, closeTo(350.0, 1e-6));
      expect(roi.areaPx, closeTo(7000.0, 1e-6));
      expect(roi.isValid, isTrue);
    });

    test('3. Normal top-left → bottom-right rectangle', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(300.0, 250.0),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.normalizedRect.left, closeTo(100.0, 1e-6));
      expect(roi.normalizedRect.top, closeTo(100.0, 1e-6));
      expect(roi.normalizedRect.right, closeTo(300.0, 1e-6));
      expect(roi.normalizedRect.bottom, closeTo(250.0, 1e-6));
      expect(roi.pixelWidth, closeTo(200.0, 1e-6));
      expect(roi.pixelHeight, closeTo(150.0, 1e-6));
      expect(roi.isValid, isTrue);
    });

    test('4. Reverse bottom-right → top-left rectangle (normalization)', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(300.0, 250.0),
        end: insidePoint(100.0, 100.0),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.normalizedRect.left, closeTo(100.0, 1e-6));
      expect(roi.normalizedRect.top, closeTo(100.0, 1e-6));
      expect(roi.normalizedRect.right, closeTo(300.0, 1e-6));
      expect(roi.normalizedRect.bottom, closeTo(250.0, 1e-6));
      expect(roi.pixelWidth, closeTo(200.0, 1e-6));
      expect(roi.pixelHeight, closeTo(150.0, 1e-6));
      expect(roi.isValid, isTrue);
    });

    test('5. Swapped X/Y ordering normalization (top-right → bottom-left)', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(300.0, 100.0),
        end: insidePoint(100.0, 250.0),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.normalizedRect.left, closeTo(100.0, 1e-6));
      expect(roi.normalizedRect.top, closeTo(100.0, 1e-6));
      expect(roi.normalizedRect.right, closeTo(300.0, 1e-6));
      expect(roi.normalizedRect.bottom, closeTo(250.0, 1e-6));
      expect(roi.pixelWidth, closeTo(200.0, 1e-6));
      expect(roi.pixelHeight, closeTo(150.0, 1e-6));
    });

    test('6. Square Pixel Spacing physical dimensions', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(300.0, 250.0),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.hasPhysicalMeasurement, isTrue);
      // pixelWidth=200 * columnSpacing=0.5 = 100mm
      expect(roi.physicalWidthMm, closeTo(100.0, 1e-6));
      // pixelHeight=150 * rowSpacing=0.5 = 75mm
      expect(roi.physicalHeightMm, closeTo(75.0, 1e-6));
      // area = 100 * 75 = 7500 mm²
      expect(roi.areaMm2, closeTo(7500.0, 1e-6));
    });

    test('7. Anisotropic Pixel Spacing physical dimensions', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 50.0),
        end: insidePoint(300.0, 150.0),
        frameIndex: 0,
        geometry: geometryAnisotropic,
      );

      expect(roi.hasPhysicalMeasurement, isTrue);
      // pixelWidth=200 * columnSpacing=0.5 = 100mm
      expect(roi.physicalWidthMm, closeTo(100.0, 1e-6));
      // pixelHeight=100 * rowSpacing=1.0 = 100mm
      expect(roi.physicalHeightMm, closeTo(100.0, 1e-6));
      // area = 100 * 100 = 10000 mm²
      expect(roi.areaMm2, closeTo(10000.0, 1e-6));
    });

    test('8. Physical width uses columnSpacing', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(0.0, 0.0),
        end: insidePoint(100.0, 50.0),
        frameIndex: 0,
        geometry: geometryAnisotropic,
      );

      // pixelWidth=100 * columnSpacing=0.5 = 50mm
      expect(roi.physicalWidthMm, closeTo(50.0, 1e-6));
    });

    test('9. Physical height uses rowSpacing', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(0.0, 0.0),
        end: insidePoint(100.0, 50.0),
        frameIndex: 0,
        geometry: geometryAnisotropic,
      );

      // pixelHeight=50 * rowSpacing=1.0 = 50mm
      expect(roi.physicalHeightMm, closeTo(50.0, 1e-6));
    });

    test('10. Physical area = widthMm × heightMm', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 50.0),
        end: insidePoint(200.0, 100.0),
        frameIndex: 0,
        geometry: geometryAnisotropic,
      );

      const expectedWidth = 100.0 * 0.5; // 50mm
      const expectedHeight = 50.0 * 1.0; // 50mm
      const expectedArea = expectedWidth * expectedHeight; // 2500mm²

      expect(roi.physicalWidthMm, closeTo(expectedWidth, 1e-6));
      expect(roi.physicalHeightMm, closeTo(expectedHeight, 1e-6));
      expect(roi.areaMm2, closeTo(expectedArea, 1e-6));
    });

    test('11. Pixel-only width/height/area (no spacing)', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(220.0, 180.0),
        frameIndex: 0,
        geometry: geometryNoSpacing,
      );

      expect(roi.hasPhysicalMeasurement, isFalse);
      expect(roi.physicalWidthMm, isNull);
      expect(roi.physicalHeightMm, isNull);
      expect(roi.areaMm2, isNull);
      expect(roi.pixelWidth, closeTo(120.0, 1e-6));
      expect(roi.pixelHeight, closeTo(80.0, 1e-6));
      expect(roi.areaPx, closeTo(9600.0, 1e-6));
      expect(roi.isValid, isTrue);
    });

    test('12. Invalid/missing spacing', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(200.0, 200.0),
        frameIndex: 0,
        geometry: geometryInvalidSpacing,
      );

      expect(roi.hasPhysicalMeasurement, isFalse);
      expect(roi.physicalWidthMm, isNull);
      expect(roi.physicalHeightMm, isNull);
      expect(roi.areaMm2, isNull);
      expect(roi.pixelWidth, closeTo(100.0, 1e-6));
      expect(roi.pixelHeight, closeTo(100.0, 1e-6));
      expect(roi.areaPx, closeTo(10000.0, 1e-6));
    });

    test('13. Sub-pixel ROI coordinates', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.3, 200.7),
        end: insidePoint(300.8, 250.2),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.normalizedRect.left, closeTo(100.3, 1e-6));
      expect(roi.normalizedRect.top, closeTo(200.7, 1e-6));
      expect(roi.normalizedRect.right, closeTo(300.8, 1e-6));
      expect(roi.normalizedRect.bottom, closeTo(250.2, 1e-6));
      expect(roi.pixelWidth, closeTo(200.5, 1e-6));
      expect(roi.pixelHeight, closeTo(49.5, 1e-6));
      expect(roi.isValid, isTrue);
    });

    test('14. Floating-point precision', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(0.1, 0.1),
        end: insidePoint(0.3, 0.3),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      // pixelWidth = 0.2, pixelHeight = 0.2, areaPx = 0.04
      expect(roi.pixelWidth, closeTo(0.2, 1e-6));
      expect(roi.pixelHeight, closeTo(0.2, 1e-6));
      expect(roi.areaPx, closeTo(0.04, 1e-6));
      // physical: 0.2 * 0.5 = 0.1mm each, area = 0.01 mm²
      expect(roi.physicalWidthMm, closeTo(0.1, 1e-6));
      expect(roi.physicalHeightMm, closeTo(0.1, 1e-6));
      expect(roi.areaMm2, closeTo(0.01, 1e-6));
      expect(roi.isValid, isTrue);
    });

    test('15. Zero-area ROI (start == end) → invalid', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(256.0, 256.0),
        end: insidePoint(256.0, 256.0),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(roi.pixelWidth, closeTo(0.0, 1e-6));
      expect(roi.pixelHeight, closeTo(0.0, 1e-6));
      expect(roi.areaPx, closeTo(0.0, 1e-6));
      expect(roi.isValid, isFalse);
    });
  });

  group('ROI Boundary Tests (Synthetic)', () {
    const geometry = DicomImageGeometry(
      columns: 512,
      rows: 512,
      rowSpacing: 0.5,
      columnSpacing: 0.5,
    );

    ImagePoint insidePoint(double x, double y) =>
        ImagePoint(pixelX: x, pixelY: y, isInsideImage: true);

    ImagePoint outsidePoint(double x, double y) =>
        ImagePoint(pixelX: x, pixelY: y, isInsideImage: false);

    test('16. Both corners inside → valid', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(10.0, 10.0),
        end: insidePoint(500.0, 500.0),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.isValid, isTrue);
    });

    test('17. Corners exactly on boundary → valid', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(0.0, 0.0),
        end: insidePoint(512.0, 512.0),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.isValid, isTrue);
    });

    test('18. First corner outside → invalid', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: outsidePoint(-1.0, -1.0),
        end: insidePoint(200.0, 200.0),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.isValid, isFalse);
    });

    test('19. Second corner outside → invalid', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(200.0, 200.0),
        end: outsidePoint(600.0, 600.0),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.isValid, isFalse);
    });

    test('20. Both corners outside → invalid', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: outsidePoint(-10.0, -10.0),
        end: outsidePoint(600.0, 600.0),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.isValid, isFalse);
    });
  });

  group('ROI Formatted Output Tests (Synthetic)', () {
    const geometryWithSpacing = DicomImageGeometry(
      columns: 512,
      rows: 512,
      rowSpacing: 0.5,
      columnSpacing: 0.5,
    );

    const geometryNoSpacing = DicomImageGeometry(columns: 512, rows: 512);

    ImagePoint insidePoint(double x, double y) =>
        ImagePoint(pixelX: x, pixelY: y, isInsideImage: true);

    ImagePoint outsidePoint(double x, double y) =>
        ImagePoint(pixelX: x, pixelY: y, isInsideImage: false);

    test('formattedDimensions with physical spacing', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(200.0, 200.0),
        frameIndex: 0,
        geometry: geometryWithSpacing,
      );

      expect(roi.formattedDimensions, contains('mm'));
      expect(roi.formattedDimensions, contains('mm\u00B2'));
      expect(roi.formattedDimensions, isNot(contains('px')));
    });

    test('formattedDimensions with pixel fallback', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(200.0, 200.0),
        frameIndex: 0,
        geometry: geometryNoSpacing,
      );

      expect(roi.formattedDimensions, contains('px'));
      expect(roi.formattedDimensions, contains('px\u00B2'));
      expect(roi.formattedDimensions, isNot(contains('mm')));
    });

    test('formattedDimensions out of bounds', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: outsidePoint(-10.0, -10.0),
        end: insidePoint(200.0, 200.0),
        frameIndex: 0,
        geometry: geometryWithSpacing,
      );

      expect(roi.formattedDimensions, equals('Out of bounds'));
    });

    test('semanticsLabel with physical spacing', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(200.0, 200.0),
        frameIndex: 0,
        geometry: geometryWithSpacing,
      );

      expect(roi.semanticsLabel, contains('millimeters'));
      expect(roi.semanticsLabel, contains('square millimeters'));
    });

    test('semanticsLabel with pixel fallback', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: insidePoint(100.0, 100.0),
        end: insidePoint(200.0, 200.0),
        frameIndex: 0,
        geometry: geometryNoSpacing,
      );

      expect(roi.semanticsLabel, contains('pixels'));
      expect(roi.semanticsLabel, contains('square pixels'));
    });
  });

  group('ROI Real DICOM Fixture Tests', () {
    late DicomDataset ctDataset;
    late DicomDataset mrDataset;

    setUpAll(() {
      ctDataset = DicomDataset.fromBytes(
        File('test/fixtures/CT_small.dcm').readAsBytesSync(),
      );
      mrDataset = DicomDataset.fromBytes(
        File('test/fixtures/MR_small.dcm').readAsBytesSync(),
      );
    });

    test('21. CT physical ROI via ImageCoordinateTransform', () {
      final geometry = DicomImageGeometry.fromDataset(ctDataset);
      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(800, 600),
      );

      // Convert viewport coordinates to image points
      final start = transform.viewportToImage(const Offset(200, 150));
      final end = transform.viewportToImage(const Offset(600, 450));

      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: start,
        end: end,
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.isValid, isTrue);
      expect(roi.pixelWidth, greaterThan(0));
      expect(roi.pixelHeight, greaterThan(0));
      expect(roi.areaPx, greaterThan(0));

      if (geometry.hasPhysicalSpacing) {
        expect(roi.hasPhysicalMeasurement, isTrue);
        expect(roi.physicalWidthMm, greaterThan(0));
        expect(roi.physicalHeightMm, greaterThan(0));
        expect(roi.areaMm2, greaterThan(0));
        // Verify formula: widthMm = pixelWidth * columnSpacing
        expect(
          roi.physicalWidthMm,
          closeTo(roi.pixelWidth * geometry.columnSpacing!, 1e-4),
        );
        // heightMm = pixelHeight * rowSpacing
        expect(
          roi.physicalHeightMm,
          closeTo(roi.pixelHeight * geometry.rowSpacing!, 1e-4),
        );
        // areaMm2 = widthMm * heightMm
        expect(
          roi.areaMm2,
          closeTo(roi.physicalWidthMm! * roi.physicalHeightMm!, 1e-4),
        );
      }
    });

    test('22. MR physical ROI via ImageCoordinateTransform', () {
      final geometry = DicomImageGeometry.fromDataset(mrDataset);
      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(800, 600),
      );

      final start = transform.viewportToImage(const Offset(200, 150));
      final end = transform.viewportToImage(const Offset(500, 400));

      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: start,
        end: end,
        frameIndex: 0,
        geometry: geometry,
      );

      expect(roi.isValid, isTrue);
      expect(roi.pixelWidth, greaterThan(0));
      expect(roi.pixelHeight, greaterThan(0));
      expect(roi.areaPx, greaterThan(0));

      if (geometry.hasPhysicalSpacing) {
        expect(roi.hasPhysicalMeasurement, isTrue);
        expect(
          roi.physicalWidthMm,
          closeTo(roi.pixelWidth * geometry.columnSpacing!, 1e-4),
        );
        expect(
          roi.physicalHeightMm,
          closeTo(roi.pixelHeight * geometry.rowSpacing!, 1e-4),
        );
        expect(
          roi.areaMm2,
          closeTo(roi.physicalWidthMm! * roi.physicalHeightMm!, 1e-4),
        );
      }
    });
  });
}
