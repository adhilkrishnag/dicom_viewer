import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/dicom_measurement.dart';
import 'package:dicom_viewer/src/geometry/distance_measurement.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_measurement.dart';

void main() {
  group('DicomMeasurement Abstraction & Core Model Tests', () {
    const geometry = DicomImageGeometry(
      columns: 512,
      rows: 512,
      rowSpacing: 0.5,
      columnSpacing: 0.5,
    );

    ImagePoint pt(double x, double y) =>
        ImagePoint(pixelX: x, pixelY: y, isInsideImage: true);

    setUp(() {
      DicomMeasurementIdGenerator.resetForTesting();
    });

    test('1. Measurement ID uniqueness and stability', () {
      final id1 = DicomMeasurementIdGenerator.generate('roi');
      final id2 = DicomMeasurementIdGenerator.generate('roi');
      final id3 = DicomMeasurementIdGenerator.generate('dist');

      expect(id1, isNot(equals(id2)));
      expect(id1, isNot(equals(id3)));
      expect(id1, startsWith('roi_'));
      expect(id3, startsWith('dist_'));
    });

    test('2. DicomLineGeometry properties and value equality', () {
      final p1 = pt(10, 20);
      final p2 = pt(50, 60);
      final line1 = DicomLineGeometry(start: p1, end: p2);
      final line2 = DicomLineGeometry(start: p1, end: p2);
      final line3 = DicomLineGeometry(start: p1, end: pt(50, 61));

      expect(line1, equals(line2));
      expect(line1.hashCode, equals(line2.hashCode));
      expect(line1, isNot(equals(line3)));
      expect(line1.toString(), contains('start: $p1'));
    });

    test('3. DicomDistanceMeasurement conforms to DicomMeasurement', () {
      final m = DicomDistanceMeasurement.fromPoints(
        start: pt(10, 10),
        end: pt(40, 50),
        frameIndex: 2,
        geometry: geometry,
      );

      // Verify interface typing
      expect(m, isA<DicomMeasurement>());

      // Verify common abstraction properties
      expect(m.id, isNotEmpty);
      expect(m.type, equals(DicomMeasurementType.distance));
      expect(m.frameIndex, equals(2));
      expect(m.geometry, isA<DicomLineGeometry>());
      final line = m.geometry;
      expect(line.start, equals(pt(10, 10)));
      expect(line.end, equals(pt(40, 50)));
      expect(m.isVisible, isTrue);
      expect(m.isSelected, isFalse);
      expect(m.isValid, isTrue);
      expect(m.formattedValue, equals(m.formattedDistance));
      expect(m.semanticsLabel, contains('Distance measurement:'));
    });

    test('4. DicomRectangleRoiMeasurement conforms to DicomMeasurement', () {
      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        start: pt(20, 30),
        end: pt(100, 150),
        frameIndex: 1,
        geometry: geometry,
      );

      // Verify interface typing
      expect(roi, isA<DicomMeasurement>());

      // Verify common abstraction properties
      expect(roi.id, isNotEmpty);
      expect(roi.type, equals(DicomMeasurementType.rectangleRoi));
      expect(roi.frameIndex, equals(1));
      expect(roi.geometry, isA<Rect>());
      final rect = roi.geometry;
      expect(rect.left, equals(20.0));
      expect(rect.top, equals(30.0));
      expect(rect.right, equals(100.0));
      expect(rect.bottom, equals(150.0));
      expect(roi.isVisible, isTrue);
      expect(roi.isSelected, isFalse);
      expect(roi.isValid, isTrue);
      expect(roi.formattedValue, equals(roi.formattedDimensions));
      expect(roi.semanticsLabel, contains('Rectangle ROI:'));
    });

    test(
      '5. Distance copyWithMeasurement updates visibility and selection',
      () {
        final m = DicomDistanceMeasurement.fromPoints(
          start: pt(10, 10),
          end: pt(40, 50),
          frameIndex: 0,
          geometry: geometry,
        );

        final hidden = m.copyWithMeasurement(isVisible: false);
        expect(hidden.id, equals(m.id));
        expect(hidden.isVisible, isFalse);
        expect(hidden.isSelected, isFalse);
        expect(hidden.frameIndex, equals(m.frameIndex));
        expect(hidden.pixelDistance, equals(m.pixelDistance));

        final selected = hidden.copyWithMeasurement(isSelected: true);
        expect(selected.id, equals(m.id));
        expect(selected.isVisible, isFalse);
        expect(selected.isSelected, isTrue);
      },
    );

    test(
      '6. Rectangle ROI copyWithMeasurement updates visibility and selection',
      () {
        final roi = DicomRectangleRoiMeasurement.fromImagePoints(
          start: pt(20, 30),
          end: pt(100, 150),
          frameIndex: 0,
          geometry: geometry,
        );

        final hidden = roi.copyWithMeasurement(isVisible: false);
        expect(hidden.id, equals(roi.id));
        expect(hidden.isVisible, isFalse);
        expect(hidden.isSelected, isFalse);
        expect(hidden.frameIndex, equals(roi.frameIndex));
        expect(hidden.areaPx, equals(roi.areaPx));

        final selected = hidden.copyWithMeasurement(isSelected: true);
        expect(selected.id, equals(roi.id));
        expect(selected.isVisible, isFalse);
        expect(selected.isSelected, isTrue);
      },
    );

    test('7. Explicit ID instantiation is preserved', () {
      final dist = DicomDistanceMeasurement.fromPoints(
        id: 'explicit_dist_42',
        start: pt(0, 0),
        end: pt(10, 10),
        frameIndex: 0,
        geometry: geometry,
      );
      expect(dist.id, equals('explicit_dist_42'));

      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'explicit_roi_99',
        start: pt(0, 0),
        end: pt(50, 50),
        frameIndex: 0,
        geometry: geometry,
      );
      expect(roi.id, equals('explicit_roi_99'));
    });
  });
}
