import 'dart:io';
import 'dart:math' as math;
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageCoordinateTransform Synthetic Tests', () {
    test('1. Identity transform with exact matching viewport', () {
      const geometry = DicomImageGeometry(
        columns: 512,
        rows: 512,
        rowSpacing: 0.5,
        columnSpacing: 0.5,
      );
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(512, 512),
      );

      final ptCenter = transform.viewportToImage(const Offset(256, 256));
      expect(ptCenter.pixelX, closeTo(256.0, 1e-5));
      expect(ptCenter.pixelY, closeTo(256.0, 1e-5));
      expect(ptCenter.physicalXMm, closeTo(128.0, 1e-5));
      expect(ptCenter.physicalYMm, closeTo(128.0, 1e-5));
      expect(ptCenter.isInsideImage, isTrue);

      final backToViewport = transform.pixelToViewport(const Offset(256, 256));
      expect(backToViewport.dx, closeTo(256.0, 1e-5));
      expect(backToViewport.dy, closeTo(256.0, 1e-5));
    });

    test('2. Centered square image in rectangular letterboxed viewport', () {
      // 512x512 square image in 800x400 viewport
      // displayAspectRatio = 1.0.
      // In 800x400: height is constrained to 400, width = 400.
      // Centered horizontally: left = (800 - 400)/2 = 200, top = 0.
      const geometry = DicomImageGeometry(
        columns: 512,
        rows: 512,
        rowSpacing: 0.5,
        columnSpacing: 0.5,
      );
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(800, 400),
      );

      expect(
        transform.displayedImageRect,
        const Rect.fromLTWH(200, 0, 400, 400),
      );

      // Image top-left corner in viewport is (200, 0)
      final ptTopLeft = transform.viewportToImage(const Offset(200, 0));
      expect(ptTopLeft.pixelX, closeTo(0.0, 1e-5));
      expect(ptTopLeft.pixelY, closeTo(0.0, 1e-5));
      expect(ptTopLeft.isInsideImage, isTrue);

      // Image center in viewport is (400, 200)
      final ptCenter = transform.viewportToImage(const Offset(400, 200));
      expect(ptCenter.pixelX, closeTo(256.0, 1e-5));
      expect(ptCenter.pixelY, closeTo(256.0, 1e-5));
      expect(ptCenter.physicalXMm, closeTo(128.0, 1e-5));
      expect(ptCenter.physicalYMm, closeTo(128.0, 1e-5));

      // Image bottom-right corner in viewport is (600, 400)
      final ptBottomRight = transform.viewportToImage(const Offset(600, 400));
      expect(ptBottomRight.pixelX, closeTo(512.0, 1e-5));
      expect(ptBottomRight.pixelY, closeTo(512.0, 1e-5));
      expect(ptBottomRight.isInsideImage, isTrue);
    });

    test('3. Non-square Pixel Spacing physical coordinate scaling', () {
      // 512x512 image with rowSpacing = 0.5 (Sy), columnSpacing = 1.0 (Sx)
      // displayAspectRatio = (512 * 1.0) / (512 * 0.5) = 2.0
      const geometry = DicomImageGeometry(
        columns: 512,
        rows: 512,
        rowSpacing: 0.5,
        columnSpacing: 1.0,
      );
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(1000, 500),
      );

      // In 1000x500 viewport, AR = 2.0 matches exactly: 1000/500 = 2.0.
      expect(
        transform.displayedImageRect,
        const Rect.fromLTWH(0, 0, 1000, 500),
      );

      final pt = transform.viewportToImage(const Offset(100, 50));
      // u = 100/1000 = 0.1 -> pixelX = 51.2
      // v = 50/500 = 0.1 -> pixelY = 51.2
      expect(pt.pixelX, closeTo(51.2, 1e-5));
      expect(pt.pixelY, closeTo(51.2, 1e-5));
      // physicalXMm = 51.2 * 1.0 = 51.2 mm
      // physicalYMm = 51.2 * 0.5 = 25.6 mm
      expect(pt.physicalXMm, closeTo(51.2, 1e-5));
      expect(pt.physicalYMm, closeTo(25.6, 1e-5));

      // Physical to viewport round-trip
      final vp = transform.physicalToViewport(51.2, 25.6);
      expect(vp, isNotNull);
      expect(vp!.dx, closeTo(100.0, 1e-5));
      expect(vp.dy, closeTo(50.0, 1e-5));
    });

    test('4. Zoomed image transformation (2x zoom)', () {
      const geometry = DicomImageGeometry(
        columns: 500,
        rows: 500,
        rowSpacing: 1.0,
        columnSpacing: 1.0,
      );
      // Zoom 2x centered: Matrix4 scale by 2.0
      final matrix = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(500, 500),
        transformMatrix: matrix,
      );

      // Viewport center (250, 250) under 2x zoom (origin at top-left) maps to untransformed (125, 125)
      // which corresponds to pixel (125, 125).
      final pt = transform.viewportToImage(const Offset(250, 250));
      expect(pt.pixelX, closeTo(125.0, 1e-5));
      expect(pt.pixelY, closeTo(125.0, 1e-5));
      expect(pt.physicalXMm, closeTo(125.0, 1e-5));
      expect(pt.physicalYMm, closeTo(125.0, 1e-5));

      // Round trip back
      final vp = transform.pixelToViewport(const Offset(125, 125));
      expect(vp.dx, closeTo(250.0, 1e-5));
      expect(vp.dy, closeTo(250.0, 1e-5));
    });

    test('5. Panned image transformation (Tx = 100, Ty = 50)', () {
      const geometry = DicomImageGeometry(
        columns: 500,
        rows: 500,
        rowSpacing: 1.0,
        columnSpacing: 1.0,
      );
      final matrix = Matrix4.translationValues(100.0, 50.0, 0.0);
      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(500, 500),
        transformMatrix: matrix,
      );

      // Viewport point (100, 50) maps to untransformed (0, 0) -> pixel (0, 0)
      final pt = transform.viewportToImage(const Offset(100, 50));
      expect(pt.pixelX, closeTo(0.0, 1e-5));
      expect(pt.pixelY, closeTo(0.0, 1e-5));
      expect(pt.isInsideImage, isTrue);

      // Round trip
      final vp = transform.pixelToViewport(const Offset(0, 0));
      expect(vp.dx, closeTo(100.0, 1e-5));
      expect(vp.dy, closeTo(50.0, 1e-5));
    });

    test('6. Zoom + Pan combined transformation', () {
      const geometry = DicomImageGeometry(
        columns: 400,
        rows: 400,
        rowSpacing: 0.5,
        columnSpacing: 0.5,
      );
      // 2x zoom + translation of (-100, -100)
      final matrix =
          Matrix4.identity()
            ..multiply(Matrix4.translationValues(-100.0, -100.0, 0.0))
            ..multiply(Matrix4.diagonal3Values(2.0, 2.0, 1.0));

      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(400, 400),
        transformMatrix: matrix,
      );

      final pt = transform.viewportToImage(const Offset(300, 300));
      // Untransformed: (300 - (-100)) / 2 = 200
      // pixel (200, 200)
      expect(pt.pixelX, closeTo(200.0, 1e-5));
      expect(pt.pixelY, closeTo(200.0, 1e-5));
      expect(pt.physicalXMm, closeTo(100.0, 1e-5));
      expect(pt.physicalYMm, closeTo(100.0, 1e-5));
      expect(pt.isInsideImage, isTrue);

      // Round trip
      final vp = transform.pixelToViewport(const Offset(200, 200));
      expect(vp.dx, closeTo(300.0, 1e-5));
      expect(vp.dy, closeTo(300.0, 1e-5));
    });

    test('7. Aspect-ratio pillarboxed layout with centering', () {
      // 400x800 tall image (AR = 0.5) inside a 500x500 viewport
      // In 500x500: height is 500, width = 500 * 0.5 = 250.
      // left = (500 - 250)/2 = 125, top = 0.
      const geometry = DicomImageGeometry(
        columns: 400,
        rows: 800,
        rowSpacing: 1.0,
        columnSpacing: 1.0,
      );
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(500, 500),
      );

      expect(
        transform.displayedImageRect,
        const Rect.fromLTWH(125, 0, 250, 500),
      );

      final pt = transform.viewportToImage(const Offset(250, 250));
      // center of displayed rect (125 + 125, 250) -> image center (200, 400)
      expect(pt.pixelX, closeTo(200.0, 1e-5));
      expect(pt.pixelY, closeTo(400.0, 1e-5));
      expect(pt.isInsideImage, isTrue);
    });

    test('8. Points inside image are marked isInsideImage = true', () {
      const geometry = DicomImageGeometry(columns: 100, rows: 100);
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(100, 100),
      );

      final pt = transform.viewportToImage(const Offset(50, 50));
      expect(pt.isInsideImage, isTrue);
      expect(pt.pixelX, closeTo(50.0, 1e-5));
      expect(pt.pixelY, closeTo(50.0, 1e-5));
    });

    test('9. Points exactly on image boundaries are inside', () {
      const geometry = DicomImageGeometry(columns: 100, rows: 100);
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(100, 100),
      );

      final ptTopLeft = transform.viewportToImage(const Offset(0, 0));
      expect(ptTopLeft.isInsideImage, isTrue);
      expect(ptTopLeft.pixelX, closeTo(0.0, 1e-5));
      expect(ptTopLeft.pixelY, closeTo(0.0, 1e-5));

      final ptBottomRight = transform.viewportToImage(const Offset(100, 100));
      expect(ptBottomRight.isInsideImage, isTrue);
      expect(ptBottomRight.pixelX, closeTo(100.0, 1e-5));
      expect(ptBottomRight.pixelY, closeTo(100.0, 1e-5));
    });

    test(
      '10. Points outside image (in letterbox areas) are marked isInsideImage = false',
      () {
        // 100x100 square image in 300x100 viewport (left = 100, right = 200)
        const geometry = DicomImageGeometry(columns: 100, rows: 100);
        const transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: Size(300, 100),
        );

        // (50, 50) is in left letterbox space
        final ptLeft = transform.viewportToImage(const Offset(50, 50));
        expect(ptLeft.isInsideImage, isFalse);
        expect(ptLeft.pixelX, closeTo(-50.0, 1e-5));

        // (250, 50) is in right letterbox space
        final ptRight = transform.viewportToImage(const Offset(250, 50));
        expect(ptRight.isInsideImage, isFalse);
        expect(ptRight.pixelX, closeTo(150.0, 1e-5));
      },
    );

    test('11. Negative coordinates are marked isInsideImage = false', () {
      const geometry = DicomImageGeometry(columns: 100, rows: 100);
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(100, 100),
      );

      final ptNeg = transform.viewportToImage(const Offset(-10, -20));
      expect(ptNeg.isInsideImage, isFalse);
      expect(ptNeg.pixelX, closeTo(-10.0, 1e-5));
      expect(ptNeg.pixelY, closeTo(-20.0, 1e-5));
    });

    test(
      '12. Coordinates beyond image dimensions are marked isInsideImage = false',
      () {
        const geometry = DicomImageGeometry(columns: 100, rows: 100);
        const transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: Size(100, 100),
        );

        final ptBeyond = transform.viewportToImage(const Offset(150, 200));
        expect(ptBeyond.isInsideImage, isFalse);
        expect(ptBeyond.pixelX, closeTo(150.0, 1e-5));
        expect(ptBeyond.pixelY, closeTo(200.0, 1e-5));
      },
    );

    test(
      '13. Invalid/missing Pixel Spacing marks physical coordinates unavailable',
      () {
        const geometryNoSpacing = DicomImageGeometry(
          columns: 100,
          rows: 100,
          rowSpacing: null,
          columnSpacing: null,
        );
        const transform = ImageCoordinateTransform(
          geometry: geometryNoSpacing,
          viewportSize: Size(100, 100),
        );

        final pt = transform.viewportToImage(const Offset(50, 50));
        expect(pt.pixelX, closeTo(50.0, 1e-5));
        expect(pt.pixelY, closeTo(50.0, 1e-5));
        expect(pt.physicalXMm, isNull);
        expect(pt.physicalYMm, isNull);
        expect(pt.hasPhysicalCoordinate, isFalse);

        final measurement = transform.measureBetweenViewportCoordinates(
          const Offset(10, 10),
          const Offset(40, 50),
        );
        expect(measurement.isValid, isTrue);
        expect(
          measurement.pixelDistance,
          closeTo(50.0, 1e-5),
        ); // 30-40-50 triangle
        expect(measurement.physicalDistanceMm, isNull);
        expect(measurement.deltaPhysicalXMm, isNull);
        expect(measurement.deltaPhysicalYMm, isNull);
        expect(measurement.hasPhysicalMeasurement, isFalse);
      },
    );

    test(
      '14. Physical-coordinate delta calculation with anisotropic spacing',
      () {
        // rowSpacing = 0.5 (Sy), columnSpacing = 1.0 (Sx)
        const geometry = DicomImageGeometry(
          columns: 512,
          rows: 512,
          rowSpacing: 0.5,
          columnSpacing: 1.0,
        );
        const transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: Size(512, 512),
        );

        // Start at pixel (10, 10), end at pixel (30, 20)
        // dxPx = 20, dyPx = 10
        // dxMm = 20 * 1.0 = 20.0 mm
        // dyMm = 10 * 0.5 = 5.0 mm
        const p1 = ImagePoint(
          pixelX: 10,
          pixelY: 10,
          physicalXMm: 10,
          physicalYMm: 5,
          isInsideImage: true,
        );
        const p2 = ImagePoint(
          pixelX: 30,
          pixelY: 20,
          physicalXMm: 30,
          physicalYMm: 10,
          isInsideImage: true,
        );

        final res = transform.measureBetweenImagePoints(p1, p2);
        expect(res.deltaPixelX, closeTo(20.0, 1e-5));
        expect(res.deltaPixelY, closeTo(10.0, 1e-5));
        expect(res.pixelDistance, closeTo(math.sqrt(20 * 20 + 10 * 10), 1e-5));
        expect(res.deltaPhysicalXMm, closeTo(20.0, 1e-5));
        expect(res.deltaPhysicalYMm, closeTo(5.0, 1e-5));
        expect(
          res.physicalDistanceMm,
          closeTo(math.sqrt(20 * 20 + 5 * 5), 1e-5),
        );
        expect(res.isValid, isTrue);
        expect(res.hasPhysicalMeasurement, isTrue);
      },
    );

    test('15. Distance calculation (Euclidean physical distance)', () {
      const geometry = DicomImageGeometry(
        columns: 512,
        rows: 512,
        rowSpacing: 0.75,
        columnSpacing: 0.75,
      );
      const transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: Size(512, 512),
      );

      const p1 = ImagePoint(
        pixelX: 0,
        pixelY: 0,
        physicalXMm: 0,
        physicalYMm: 0,
        isInsideImage: true,
      );
      const p2 = ImagePoint(
        pixelX: 40,
        pixelY: 30,
        physicalXMm: 30,
        physicalYMm: 22.5,
        isInsideImage: true,
      );

      final res = transform.measureBetweenImagePoints(p1, p2);
      expect(res.pixelDistance, closeTo(50.0, 1e-5));
      expect(res.physicalDistanceMm, closeTo(50.0 * 0.75, 1e-5));
      expect(res.isValid, isTrue);
    });

    test(
      '16. No accidental half-pixel shift: continuous sub-pixel round-trip',
      () {
        const geometry = DicomImageGeometry(
          columns: 512,
          rows: 256,
          rowSpacing: 0.8,
          columnSpacing: 0.4,
        );
        // Test across identity, zoom, and pan configurations
        final transforms = [
          const ImageCoordinateTransform(
            geometry: geometry,
            viewportSize: Size(800, 600),
          ),
          ImageCoordinateTransform(
            geometry: geometry,
            viewportSize: const Size(800, 600),
            transformMatrix: Matrix4.diagonal3Values(2.5, 2.5, 1.0),
          ),
          ImageCoordinateTransform(
            geometry: geometry,
            viewportSize: const Size(800, 600),
            transformMatrix:
                Matrix4.identity()
                  ..multiply(Matrix4.translationValues(75.5, -42.3, 0.0))
                  ..multiply(Matrix4.diagonal3Values(1.75, 1.75, 1.0)),
          ),
        ];

        for (final transform in transforms) {
          // Test grid including fractional/sub-pixel points
          for (double px = 0.12345; px < 512; px += 47.6543) {
            for (double py = 0.54321; py < 256; py += 29.8765) {
              final vp = transform.pixelToViewport(Offset(px, py));
              final back = transform.viewportToImage(vp);
              expect(back.pixelX, closeTo(px, 1e-4));
              expect(back.pixelY, closeTo(py, 1e-4));
              expect(back.isInsideImage, isTrue);
            }
          }
        }
      },
    );

    test(
      '17. Two-point measurement boundary rule: invalid when either endpoint is outside',
      () {
        // 100x100 square image in 300x100 viewport (displayed rect is [100, 0, 100, 100])
        const geometry = DicomImageGeometry(
          columns: 100,
          rows: 100,
          rowSpacing: 1.0,
          columnSpacing: 1.0,
        );
        const transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: Size(300, 100),
        );

        // Start inside (150, 50) -> pixel (50, 50), End outside (50, 50) -> pixel (-50, 50)
        final res1 = transform.measureBetweenViewportCoordinates(
          const Offset(150, 50),
          const Offset(50, 50),
        );
        expect(res1.start.isInsideImage, isTrue);
        expect(res1.end.isInsideImage, isFalse);
        expect(res1.isValid, isFalse);

        // Start outside (50, 50), End inside (150, 50)
        final res2 = transform.measureBetweenViewportCoordinates(
          const Offset(50, 50),
          const Offset(150, 50),
        );
        expect(res2.start.isInsideImage, isFalse);
        expect(res2.end.isInsideImage, isTrue);
        expect(res2.isValid, isFalse);

        // Both outside
        final res3 = transform.measureBetweenViewportCoordinates(
          const Offset(50, 50),
          const Offset(250, 50),
        );
        expect(res3.start.isInsideImage, isFalse);
        expect(res3.end.isInsideImage, isFalse);
        expect(res3.isValid, isFalse);
      },
    );

    test(
      '18. Two-point measurement becomes valid when both endpoints are inside bounds',
      () {
        // 100x100 square image in 300x100 viewport (displayed rect is [100, 0, 100, 100])
        const geometry = DicomImageGeometry(
          columns: 100,
          rows: 100,
          rowSpacing: 1.0,
          columnSpacing: 1.0,
        );
        const transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: Size(300, 100),
        );

        final res = transform.measureBetweenViewportCoordinates(
          const Offset(120, 20),
          const Offset(180, 80),
        );
        expect(res.start.isInsideImage, isTrue);
        expect(res.end.isInsideImage, isTrue);
        expect(res.isValid, isTrue);
        expect(res.deltaPixelX, closeTo(60.0, 1e-5));
        expect(res.deltaPixelY, closeTo(60.0, 1e-5));
        expect(
          res.physicalDistanceMm,
          closeTo(math.sqrt(60 * 60 + 60 * 60), 1e-5),
        );
      },
    );

    test(
      '19. Value equality, hashCode, and toString for ImagePoint & TwoPointMeasurementResult',
      () {
        const p1 = ImagePoint(
          pixelX: 10,
          pixelY: 20,
          physicalXMm: 5,
          physicalYMm: 10,
          isInsideImage: true,
        );
        const p2 = ImagePoint(
          pixelX: 10,
          pixelY: 20,
          physicalXMm: 5,
          physicalYMm: 10,
          isInsideImage: true,
        );
        const p3 = ImagePoint(
          pixelX: 15,
          pixelY: 20,
          physicalXMm: 7.5,
          physicalYMm: 10,
          isInsideImage: true,
        );

        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1, isNot(equals(p3)));
        expect(p1.toPixelOffset(), const Offset(10, 20));
        expect(p1.toString(), contains('ImagePoint'));

        const res1 = TwoPointMeasurementResult(
          start: p1,
          end: p3,
          deltaPixelX: 5,
          deltaPixelY: 0,
          pixelDistance: 5,
          deltaPhysicalXMm: 2.5,
          deltaPhysicalYMm: 0,
          physicalDistanceMm: 2.5,
          isValid: true,
        );
        const res2 = TwoPointMeasurementResult(
          start: p1,
          end: p3,
          deltaPixelX: 5,
          deltaPixelY: 0,
          pixelDistance: 5,
          deltaPhysicalXMm: 2.5,
          deltaPhysicalYMm: 0,
          physicalDistanceMm: 2.5,
          isValid: true,
        );

        expect(res1, equals(res2));
        expect(res1.hashCode, equals(res2.hashCode));
        expect(res1.toString(), contains('TwoPointMeasurementResult'));
      },
    );
  });

  group('ImageCoordinateTransform Real DICOM Fixture Tests', () {
    test('1. CT_small.dcm coordinate transform & physical measurement', () {
      final file = File('test/fixtures/CT_small.dcm');
      expect(file.existsSync(), isTrue);

      final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
      final geometry = DicomImageGeometry.fromDataset(dataset);
      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(512, 512),
      );

      // CT_small is 128x128
      final centerPoint = transform.viewportToImage(const Offset(256, 256));
      expect(centerPoint.pixelX, closeTo(64.0, 1e-5));
      expect(centerPoint.pixelY, closeTo(64.0, 1e-5));
      expect(
        centerPoint.physicalXMm,
        closeTo(64.0 * geometry.columnSpacing!, 1e-4),
      );
      expect(
        centerPoint.physicalYMm,
        closeTo(64.0 * geometry.rowSpacing!, 1e-4),
      );
      expect(centerPoint.isInsideImage, isTrue);

      // Measure a horizontal line across 100 pixels
      final measurement = transform.measureBetweenImagePoints(
        const ImagePoint(pixelX: 10, pixelY: 64, isInsideImage: true),
        const ImagePoint(pixelX: 110, pixelY: 64, isInsideImage: true),
      );
      expect(measurement.isValid, isTrue);
      expect(measurement.deltaPixelX, closeTo(100.0, 1e-5));
      expect(
        measurement.physicalDistanceMm,
        closeTo(100.0 * geometry.columnSpacing!, 1e-4),
      );
    });

    test('2. MR_small.dcm coordinate transform with 0.3125 mm spacing', () {
      final file = File('test/fixtures/MR_small.dcm');
      expect(file.existsSync(), isTrue);

      final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
      final geometry = DicomImageGeometry.fromDataset(dataset);
      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(256, 256),
      );

      // MR_small is 64x64 with pixelSpacing [0.3125, 0.3125]
      final pt = transform.viewportToImage(const Offset(128, 128));
      expect(pt.pixelX, closeTo(32.0, 1e-5));
      expect(pt.pixelY, closeTo(32.0, 1e-5));
      expect(pt.physicalXMm, closeTo(32.0 * 0.3125, 1e-5));
      expect(pt.physicalYMm, closeTo(32.0 * 0.3125, 1e-5));
      expect(pt.isInsideImage, isTrue);
    });
  });
}
