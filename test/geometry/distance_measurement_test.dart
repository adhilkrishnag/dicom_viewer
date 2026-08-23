import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/distance_measurement.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:dicom_viewer/src/parsing/dicom_dataset.dart';

void main() {
  group('Distance Measurement Math Tests (Synthetic)', () {
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

    test('1. Horizontal distance calculation with square spacing', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 100.0,
          pixelY: 200.0,
          physicalXMm: 50.0,
          physicalYMm: 100.0,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 200.0,
          pixelY: 200.0,
          physicalXMm: 100.0,
          physicalYMm: 100.0,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(m.deltaPixelX, closeTo(100.0, 1e-6));
      expect(m.deltaPixelY, closeTo(0.0, 1e-6));
      expect(m.pixelDistance, closeTo(100.0, 1e-6));
      expect(m.hasPhysicalMeasurement, isTrue);
      expect(m.deltaPhysicalXMm, closeTo(50.0, 1e-6));
      expect(m.deltaPhysicalYMm, closeTo(0.0, 1e-6));
      expect(m.physicalDistanceMm, closeTo(50.0, 1e-6));
      expect(m.formattedDistance, equals('50.0 mm'));
      expect(m.isValid, isTrue);
    });

    test('2. Vertical distance calculation with square spacing', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 100.0,
          pixelY: 100.0,
          physicalXMm: 50.0,
          physicalYMm: 50.0,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 100.0,
          pixelY: 250.0,
          physicalXMm: 50.0,
          physicalYMm: 125.0,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(m.deltaPixelX, closeTo(0.0, 1e-6));
      expect(m.deltaPixelY, closeTo(150.0, 1e-6));
      expect(m.pixelDistance, closeTo(150.0, 1e-6));
      expect(m.hasPhysicalMeasurement, isTrue);
      expect(m.physicalDistanceMm, closeTo(75.0, 1e-6));
      expect(m.formattedDistance, equals('75.0 mm'));
      expect(m.isValid, isTrue);
    });

    test('3. Diagonal Euclidean distance calculation', () {
      // 30 px dx, 40 px dy -> 50 px hypotenuse
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 10.0,
          pixelY: 10.0,
          physicalXMm: 5.0,
          physicalYMm: 5.0,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 40.0,
          pixelY: 50.0,
          physicalXMm: 20.0,
          physicalYMm: 25.0,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(m.pixelDistance, closeTo(50.0, 1e-6));
      expect(m.physicalDistanceMm, closeTo(25.0, 1e-6));
      expect(m.formattedDistance, equals('25.0 mm'));
    });

    test('4. Square Pixel Spacing calculation', () {
      const geom = DicomImageGeometry(
        columns: 256,
        rows: 256,
        rowSpacing: 0.75,
        columnSpacing: 0.75,
      );
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(pixelX: 0, pixelY: 0, isInsideImage: true),
        end: const ImagePoint(pixelX: 100, pixelY: 0, isInsideImage: true),
        frameIndex: 0,
        geometry: geom,
      );
      expect(m.pixelDistance, closeTo(100.0, 1e-6));
      expect(m.physicalDistanceMm, closeTo(75.0, 1e-6));
      expect(m.formattedDistance, equals('75.0 mm'));
    });

    test('5. Anisotropic Pixel Spacing physical calculation', () {
      // dx = 60 px * 0.5 mm/px = 30 mm
      // dy = 40 px * 1.0 mm/px = 40 mm
      // physical hypotenuse = sqrt(30^2 + 40^2) = 50 mm
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 10.0,
          pixelY: 10.0,
          physicalXMm: 5.0,
          physicalYMm: 10.0,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 70.0,
          pixelY: 50.0,
          physicalXMm: 35.0,
          physicalYMm: 50.0,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometryAnisotropic,
      );

      expect(m.pixelDistance, closeTo(math.sqrt(60 * 60 + 40 * 40), 1e-6));
      expect(m.deltaPhysicalXMm, closeTo(30.0, 1e-6));
      expect(m.deltaPhysicalYMm, closeTo(40.0, 1e-6));
      expect(m.physicalDistanceMm, closeTo(50.0, 1e-6));
      expect(m.formattedDistance, equals('50.0 mm'));
    });

    test('6. Pixel-only fallback when physical spacing is unavailable', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 10.0,
          pixelY: 10.0,
          physicalXMm: null,
          physicalYMm: null,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 70.0,
          pixelY: 90.0,
          physicalXMm: null,
          physicalYMm: null,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometryNoSpacing,
      );

      expect(m.hasPhysicalMeasurement, isFalse);
      expect(m.physicalDistanceMm, isNull);
      expect(m.deltaPhysicalXMm, isNull);
      expect(m.deltaPhysicalYMm, isNull);
      expect(m.pixelDistance, closeTo(100.0, 1e-6));
      expect(m.formattedDistance, equals('100.0 px (Physical unavailable)'));
      expect(m.isValid, isTrue);
    });

    test('7. Invalid spacing (zero/negative) falls back to pixel distance', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
        end: const ImagePoint(pixelX: 50, pixelY: 40, isInsideImage: true),
        frameIndex: 0,
        geometry: geometryInvalidSpacing,
      );

      expect(geometryInvalidSpacing.hasPhysicalSpacing, isFalse);
      expect(m.hasPhysicalMeasurement, isFalse);
      expect(m.physicalDistanceMm, isNull);
      expect(m.pixelDistance, closeTo(50.0, 1e-6));
      expect(m.formattedDistance, equals('50.0 px (Physical unavailable)'));
    });

    test('8. Zero-length measurement (start == end)', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 128.0,
          pixelY: 128.0,
          physicalXMm: 64.0,
          physicalYMm: 64.0,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 128.0,
          pixelY: 128.0,
          physicalXMm: 64.0,
          physicalYMm: 64.0,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(m.pixelDistance, equals(0.0));
      expect(m.physicalDistanceMm, equals(0.0));
      expect(m.formattedDistance, equals('0.0 mm'));
      expect(m.isValid, isTrue);
    });

    test('9. Continuous sub-pixel endpoints', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 10.25,
          pixelY: 20.75,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 40.25,
          pixelY: 60.75,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(m.deltaPixelX, closeTo(30.0, 1e-6));
      expect(m.deltaPixelY, closeTo(40.0, 1e-6));
      expect(m.pixelDistance, closeTo(50.0, 1e-6));
      expect(m.physicalDistanceMm, closeTo(25.0, 1e-6));
    });

    test('10. Floating-point precision verification', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 1.0000000001,
          pixelY: 2.0000000002,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 4.0000000001,
          pixelY: 6.0000000002,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      expect(m.pixelDistance, closeTo(5.0, 1e-9));
      expect(m.physicalDistanceMm, closeTo(2.5, 1e-9));
    });

    test('11. Displayed rounding does not alter stored underlying value', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 10.123456,
          pixelY: 20.654321,
          physicalXMm: 5.061728,
          physicalYMm: 10.3271605,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 52.861747,
          pixelY: 63.392612,
          physicalXMm: 26.4308735,
          physicalYMm: 31.696306,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometrySquare,
      );

      const expectedDx = 52.861747 - 10.123456;
      const expectedDy = 63.392612 - 20.654321;
      final expectedPixelDist = math.sqrt(
        expectedDx * expectedDx + expectedDy * expectedDy,
      );
      final expectedPhysicalDist = expectedPixelDist * 0.5;

      expect(m.pixelDistance, closeTo(expectedPixelDist, 1e-6));
      expect(m.physicalDistanceMm, closeTo(expectedPhysicalDist, 1e-6));
      // Display string rounds to 1 decimal place without modifying underlying continuous double
      expect(
        m.formattedDistance,
        equals('${expectedPhysicalDist.toStringAsFixed(1)} mm'),
      );
    });
  });

  group('Boundary Behavior Tests (Synthetic)', () {
    const geometry = DicomImageGeometry(
      columns: 512,
      rows: 512,
      rowSpacing: 0.5,
      columnSpacing: 0.5,
    );

    test('12. Both endpoints inside image -> valid measurement', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 100,
          pixelY: 100,
          physicalXMm: 50,
          physicalYMm: 50,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 200,
          pixelY: 200,
          physicalXMm: 100,
          physicalYMm: 100,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(m.isValid, isTrue);
      expect(m.formattedDistance, isNot(equals('Out of bounds')));
    });

    test('13. Endpoints exactly on boundary [0, 512] -> valid measurement', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 0,
          pixelY: 0,
          physicalXMm: 0,
          physicalYMm: 0,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 512,
          pixelY: 512,
          physicalXMm: 256,
          physicalYMm: 256,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(m.isValid, isTrue);
    });

    test('14. First endpoint outside -> invalid measurement', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: -5.0,
          pixelY: 100.0,
          physicalXMm: null,
          physicalYMm: null,
          isInsideImage: false,
        ),
        end: const ImagePoint(
          pixelX: 200.0,
          pixelY: 200.0,
          physicalXMm: 100.0,
          physicalYMm: 100.0,
          isInsideImage: true,
        ),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(m.isValid, isFalse);
      expect(m.formattedDistance, equals('Out of bounds'));
    });

    test('15. Second endpoint outside -> invalid measurement', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: 100.0,
          pixelY: 100.0,
          physicalXMm: 50.0,
          physicalYMm: 50.0,
          isInsideImage: true,
        ),
        end: const ImagePoint(
          pixelX: 520.0,
          pixelY: 200.0,
          physicalXMm: null,
          physicalYMm: null,
          isInsideImage: false,
        ),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(m.isValid, isFalse);
      expect(m.formattedDistance, equals('Out of bounds'));
    });

    test('16. Both endpoints outside -> invalid measurement', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: const ImagePoint(
          pixelX: -10.0,
          pixelY: -10.0,
          physicalXMm: null,
          physicalYMm: null,
          isInsideImage: false,
        ),
        end: const ImagePoint(
          pixelX: 600.0,
          pixelY: 600.0,
          physicalXMm: null,
          physicalYMm: null,
          isInsideImage: false,
        ),
        frameIndex: 0,
        geometry: geometry,
      );

      expect(m.isValid, isFalse);
      expect(m.formattedDistance, equals('Out of bounds'));
    });

    test(
      '17. Dragging outside and back inside dynamically toggles validity',
      () {
        const start = ImagePoint(pixelX: 100, pixelY: 100, isInsideImage: true);
        const insidePoint1 = ImagePoint(
          pixelX: 200,
          pixelY: 200,
          isInsideImage: true,
        );
        const outsidePoint = ImagePoint(
          pixelX: 600,
          pixelY: 200,
          isInsideImage: false,
        );
        const insidePoint2 = ImagePoint(
          pixelX: 300,
          pixelY: 200,
          isInsideImage: true,
        );

        // Phase 1: Inside -> Valid
        final m1 = DicomDistanceMeasurement.fromPoints(
          start: start,
          end: insidePoint1,
          frameIndex: 0,
          geometry: geometry,
        );
        expect(m1.isValid, isTrue);
        expect(m1.formattedDistance, equals('70.7 mm'));

        // Phase 2: Drag moves outside -> Invalid
        final m2 = DicomDistanceMeasurement.fromPoints(
          start: start,
          end: outsidePoint,
          frameIndex: 0,
          geometry: geometry,
        );
        expect(m2.isValid, isFalse);
        expect(m2.formattedDistance, equals('Out of bounds'));

        // Phase 3: Drag moves back inside -> Valid again and updates distance
        final m3 = DicomDistanceMeasurement.fromPoints(
          start: start,
          end: insidePoint2,
          frameIndex: 0,
          geometry: geometry,
        );
        expect(m3.isValid, isTrue);
        expect(m3.formattedDistance, equals('111.8 mm'));
      },
    );
  });

  group('Real DICOM Fixtures Distance Measurement Tests', () {
    test('36. Real CT_small.dcm fixture measurement math', () {
      final dataset = DicomDataset.fromBytes(
        File('test/fixtures/CT_small.dcm').readAsBytesSync(),
      );
      final geometry = DicomImageGeometry.fromDataset(dataset);

      expect(geometry.columns, equals(128));
      expect(geometry.rows, equals(128));
      expect(geometry.hasPhysicalSpacing, isTrue);

      final transform = ImageCoordinateTransform(
        geometry: geometry,
        viewportSize: const Size(512, 512),
      );

      // Measure top-left to bottom-right across the CT slice
      final p1 = transform.viewportToImage(const Offset(0, 0));
      final p2 = transform.viewportToImage(const Offset(512, 512));

      final m = DicomDistanceMeasurement.fromPoints(
        start: p1,
        end: p2,
        frameIndex: 0,
        geometry: geometry,
      );

      expect(m.isValid, isTrue);
      expect(m.pixelDistance, closeTo(math.sqrt(128 * 128 + 128 * 128), 1e-4));
      expect(m.hasPhysicalMeasurement, isTrue);
    });

    test(
      '37. Real MR_small.dcm fixture measurement math with 0.3125 mm spacing',
      () {
        final dataset = DicomDataset.fromBytes(
          File('test/fixtures/MR_small.dcm').readAsBytesSync(),
        );
        final geometry = DicomImageGeometry.fromDataset(dataset);

        expect(geometry.columns, equals(64));
        expect(geometry.rows, equals(64));
        expect(geometry.rowSpacing, closeTo(0.3125, 1e-4));
        expect(geometry.columnSpacing, closeTo(0.3125, 1e-4));

        final transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: const Size(640, 640),
        );

        // Measure 32 pixels horizontally (half the FOV = 10.0 mm)
        final p1 = transform.viewportToImage(const Offset(160, 320));
        final p2 = transform.viewportToImage(const Offset(480, 320));

        final m = DicomDistanceMeasurement.fromPoints(
          start: p1,
          end: p2,
          frameIndex: 0,
          geometry: geometry,
        );

        expect(m.isValid, isTrue);
        expect(m.pixelDistance, closeTo(32.0, 1e-4));
        expect(m.physicalDistanceMm, closeTo(10.0, 1e-4));
        expect(m.formattedDistance, equals('10.0 mm'));
      },
    );

    test(
      '38. Real Multi-Frame RLE OBXXXX1A_rle_2frame.dcm frame-aware measurement',
      () {
        final dataset = DicomDataset.fromBytes(
          File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm').readAsBytesSync(),
        );
        final geometry = DicomImageGeometry.fromDataset(dataset);

        final transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: const Size(800, 600),
        );

        final p1 = transform.viewportToImage(const Offset(200, 200));
        final p2 = transform.viewportToImage(const Offset(400, 300));

        final mFrame0 = DicomDistanceMeasurement.fromPoints(
          start: p1,
          end: p2,
          frameIndex: 0,
          geometry: geometry,
        );

        final mFrame1 = DicomDistanceMeasurement.fromPoints(
          start: p1,
          end: p2,
          frameIndex: 1,
          geometry: geometry,
        );

        expect(mFrame0.frameIndex, equals(0));
        expect(mFrame1.frameIndex, equals(1));
        expect(mFrame0, isNot(equals(mFrame1)));
      },
    );
  });
}
