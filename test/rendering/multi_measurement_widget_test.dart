import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/dicom_image_geometry.dart';
import 'package:dicom_viewer/src/geometry/distance_measurement.dart';
import 'package:dicom_viewer/src/geometry/distance_measurement_painter.dart';
import 'package:dicom_viewer/src/geometry/image_coordinate_transform.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_measurement.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DicomDataset ctDataset;
  late DicomDataset multiFrameDataset;

  setUpAll(() {
    ctDataset = DicomDataset.fromBytes(
      File('test/fixtures/CT_small.dcm').readAsBytesSync(),
    );
    multiFrameDataset = DicomDataset.fromBytes(
      File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm').readAsBytesSync(),
    );
  });

  Future<void> pumpAndRender(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  Widget createViewer({
    required Key key,
    required DicomDataset dataset,
    int frameIndex = 0,
    DicomTool tool = DicomTool.rectangleRoi,
    double width = 800,
    double height = 600,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: DicomImageWidget(
              key: key,
              dataset: dataset,
              frameIndex: frameIndex,
              tool: tool,
              enableZoom: false,
            ),
          ),
        ),
      ),
    );
  }

  group('Multi-Measurement State & Model Integration Tests', () {
    testWidgets('1. Multiple rectangle ROIs coexist on the same frame', (
      tester,
    ) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(key: key, dataset: ctDataset, frameIndex: 0),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometry = DicomImageGeometry.fromDataset(ctDataset);

      final roiA = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'roi_A',
        start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
        end: const ImagePoint(pixelX: 50, pixelY: 50, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      final roiB = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'roi_B',
        start: const ImagePoint(pixelX: 60, pixelY: 60, isInsideImage: true),
        end: const ImagePoint(pixelX: 100, pixelY: 100, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      state.addMeasurement(roiA);
      state.addMeasurement(roiB);
      await tester.pump();

      final measurements = state.getMeasurements(0);
      expect(measurements.length, equals(2));
      expect(measurements[0].id, equals('roi_A'));
      expect(measurements[1].id, equals('roi_B'));

      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      final roiPaint = customPaints.firstWhere(
        (cp) => cp.painter is RectangleRoiPainter,
      );
      final painter = roiPaint.painter as RectangleRoiPainter;
      expect(painter.measurements.length, equals(2));
      expect(
        painter.measurements.map((m) => m.id),
        containsAll(['roi_A', 'roi_B']),
      );
    });

    testWidgets('2. Multiple distance measurements coexist on the same frame', (
      tester,
    ) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(
          key: key,
          dataset: ctDataset,
          frameIndex: 0,
          tool: DicomTool.measure,
        ),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometry = DicomImageGeometry.fromDataset(ctDataset);

      final distA = DicomDistanceMeasurement.fromPoints(
        id: 'dist_A',
        start: const ImagePoint(pixelX: 10, pixelY: 20, isInsideImage: true),
        end: const ImagePoint(pixelX: 50, pixelY: 20, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      final distB = DicomDistanceMeasurement.fromPoints(
        id: 'dist_B',
        start: const ImagePoint(pixelX: 20, pixelY: 80, isInsideImage: true),
        end: const ImagePoint(pixelX: 20, pixelY: 120, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      state.addMeasurement(distA);
      state.addMeasurement(distB);
      await tester.pump();

      final measurements = state
          .getMeasurementsOfType<DicomDistanceMeasurement>(0);
      expect(measurements.length, equals(2));
      expect(measurements.map((m) => m.id), containsAll(['dist_A', 'dist_B']));

      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      final distPaint = customPaints.firstWhere(
        (cp) => cp.painter is DistanceMeasurementPainter,
      );
      final painter = distPaint.painter as DistanceMeasurementPainter;
      expect(painter.measurements.length, equals(2));
      expect(
        painter.measurements.map((m) => m.id),
        containsAll(['dist_A', 'dist_B']),
      );
    });

    testWidgets('3. Mixed measurement types coexist on the same frame', (
      tester,
    ) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(key: key, dataset: ctDataset, frameIndex: 0),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometry = DicomImageGeometry.fromDataset(ctDataset);

      final roi = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'mixed_roi_1',
        start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
        end: const ImagePoint(pixelX: 40, pixelY: 40, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      final dist = DicomDistanceMeasurement.fromPoints(
        id: 'mixed_dist_1',
        start: const ImagePoint(pixelX: 50, pixelY: 50, isInsideImage: true),
        end: const ImagePoint(pixelX: 90, pixelY: 90, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      state.addMeasurement(roi);
      state.addMeasurement(dist);
      await tester.pump();

      final allFrame0 = state.getMeasurements(0);
      expect(allFrame0.length, equals(2));
      expect(
        state.getMeasurementsOfType<DicomRectangleRoiMeasurement>(0).length,
        equals(1),
      );
      expect(
        state.getMeasurementsOfType<DicomDistanceMeasurement>(0).length,
        equals(1),
      );

      // Verify each painter receives only its expected measurement type
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      final roiPaint = customPaints.firstWhere(
        (cp) => cp.painter is RectangleRoiPainter,
      );
      final distPaint = customPaints.firstWhere(
        (cp) => cp.painter is DistanceMeasurementPainter,
      );

      final roiPainter = roiPaint.painter as RectangleRoiPainter;
      final distPainter = distPaint.painter as DistanceMeasurementPainter;

      expect(roiPainter.measurements.length, equals(1));
      expect(roiPainter.measurements.first.id, equals('mixed_roi_1'));
      expect(distPainter.measurements.length, equals(1));
      expect(distPainter.measurements.first.id, equals('mixed_dist_1'));
    });

    testWidgets('4. Multi-frame isolation of measurements', (tester) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(key: key, dataset: multiFrameDataset, frameIndex: 0),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometry = DicomImageGeometry.fromDataset(multiFrameDataset);

      final frame0Roi = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'frame0_roi',
        start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
        end: const ImagePoint(pixelX: 40, pixelY: 40, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      final frame1Roi = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'frame1_roi',
        start: const ImagePoint(pixelX: 50, pixelY: 50, isInsideImage: true),
        end: const ImagePoint(pixelX: 80, pixelY: 80, isInsideImage: true),
        frameIndex: 1,
        geometry: geometry,
      );

      state.addMeasurement(frame0Roi);
      state.addMeasurement(frame1Roi);
      await tester.pump();

      // Check frame isolation in state
      final f0List = state.getMeasurements(0);
      final f1List = state.getMeasurements(1);
      expect(f0List.length, equals(1));
      expect(f0List.first.id, equals('frame0_roi'));
      expect(f1List.length, equals(1));
      expect(f1List.first.id, equals('frame1_roi'));

      // In frame 0, painter only shows frame 0 ROI
      var customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      var roiPainter =
          customPaints
                  .firstWhere((cp) => cp.painter is RectangleRoiPainter)
                  .painter
              as RectangleRoiPainter;
      expect(roiPainter.measurements.length, equals(1));
      expect(roiPainter.measurements.first.id, equals('frame0_roi'));

      // Switch widget to frame 1
      await tester.pumpWidget(
        createViewer(key: key, dataset: multiFrameDataset, frameIndex: 1),
      );
      await pumpAndRender(tester);

      customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      roiPainter =
          customPaints
                  .firstWhere((cp) => cp.painter is RectangleRoiPainter)
                  .painter
              as RectangleRoiPainter;
      expect(roiPainter.measurements.length, equals(1));
      expect(roiPainter.measurements.first.id, equals('frame1_roi'));
    });

    testWidgets('5. Independent visibility modification', (tester) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(key: key, dataset: ctDataset, frameIndex: 0),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometry = DicomImageGeometry.fromDataset(ctDataset);

      final m1 = DicomDistanceMeasurement.fromPoints(
        id: 'dist_vis_1',
        start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
        end: const ImagePoint(pixelX: 50, pixelY: 10, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      final m2 = DicomDistanceMeasurement.fromPoints(
        id: 'dist_vis_2',
        start: const ImagePoint(pixelX: 10, pixelY: 30, isInsideImage: true),
        end: const ImagePoint(pixelX: 50, pixelY: 30, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      state.addMeasurement(m1);
      state.addMeasurement(m2);
      await tester.pump();

      // Hide m1
      final updated = state.setMeasurementVisibility('dist_vis_1', false);
      expect(updated, isTrue);
      await tester.pump();

      final updatedM1 = state.getMeasurementById('dist_vis_1')!;
      final updatedM2 = state.getMeasurementById('dist_vis_2')!;

      expect(updatedM1.isVisible, isFalse);
      expect(updatedM2.isVisible, isTrue);
    });

    testWidgets('6. Independent selection modification', (tester) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(key: key, dataset: ctDataset, frameIndex: 0),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometry = DicomImageGeometry.fromDataset(ctDataset);

      final roi1 = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'roi_sel_1',
        start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
        end: const ImagePoint(pixelX: 40, pixelY: 40, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      final roi2 = DicomRectangleRoiMeasurement.fromImagePoints(
        id: 'roi_sel_2',
        start: const ImagePoint(pixelX: 50, pixelY: 50, isInsideImage: true),
        end: const ImagePoint(pixelX: 80, pixelY: 80, isInsideImage: true),
        frameIndex: 0,
        geometry: geometry,
      );

      state.addMeasurement(roi1);
      state.addMeasurement(roi2);
      await tester.pump();

      // Select roi1
      final updated = state.setMeasurementSelected('roi_sel_1', true);
      expect(updated, isTrue);
      await tester.pump();

      final current1 = state.getMeasurementById('roi_sel_1')!;
      final current2 = state.getMeasurementById('roi_sel_2')!;

      expect(current1.isSelected, isTrue);
      expect(current2.isSelected, isFalse);
    });

    testWidgets(
      '7. Measurement removal primitive preserves remaining measurements and IDs',
      (tester) async {
        final key = GlobalKey<DicomImageWidgetState>();
        await tester.pumpWidget(
          createViewer(key: key, dataset: ctDataset, frameIndex: 0),
        );
        await pumpAndRender(tester);

        final state = key.currentState!;
        final geometry = DicomImageGeometry.fromDataset(ctDataset);

        final roi1 = DicomRectangleRoiMeasurement.fromImagePoints(
          id: 'keep_1',
          start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
          end: const ImagePoint(pixelX: 40, pixelY: 40, isInsideImage: true),
          frameIndex: 0,
          geometry: geometry,
        );

        final roi2 = DicomRectangleRoiMeasurement.fromImagePoints(
          id: 'delete_me',
          start: const ImagePoint(pixelX: 50, pixelY: 50, isInsideImage: true),
          end: const ImagePoint(pixelX: 80, pixelY: 80, isInsideImage: true),
          frameIndex: 0,
          geometry: geometry,
        );

        final roi3 = DicomRectangleRoiMeasurement.fromImagePoints(
          id: 'keep_2',
          start: const ImagePoint(pixelX: 90, pixelY: 90, isInsideImage: true),
          end: const ImagePoint(pixelX: 120, pixelY: 120, isInsideImage: true),
          frameIndex: 0,
          geometry: geometry,
        );

        state.addMeasurement(roi1);
        state.addMeasurement(roi2);
        state.addMeasurement(roi3);
        await tester.pump();

        expect(state.getMeasurements(0).length, equals(3));

        // Remove roi2
        final removed = state.removeMeasurement('delete_me');
        expect(removed, isTrue);
        await tester.pump();

        final remaining = state.getMeasurements(0);
        expect(remaining.length, equals(2));
        expect(remaining[0].id, equals('keep_1'));
        expect(remaining[1].id, equals('keep_2'));
        expect(state.getMeasurementById('delete_me'), isNull);

        // Attempting to remove non-existent returns false
        expect(state.removeMeasurement('non_existent'), isFalse);
      },
    );

    testWidgets('8. Clear measurements primitive (per-frame and global)', (
      tester,
    ) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(key: key, dataset: multiFrameDataset, frameIndex: 0),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometry = DicomImageGeometry.fromDataset(multiFrameDataset);

      state.addMeasurement(
        DicomRectangleRoiMeasurement.fromImagePoints(
          id: 'f0_1',
          start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
          end: const ImagePoint(pixelX: 20, pixelY: 20, isInsideImage: true),
          frameIndex: 0,
          geometry: geometry,
        ),
      );
      state.addMeasurement(
        DicomRectangleRoiMeasurement.fromImagePoints(
          id: 'f1_1',
          start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
          end: const ImagePoint(pixelX: 20, pixelY: 20, isInsideImage: true),
          frameIndex: 1,
          geometry: geometry,
        ),
      );
      await tester.pump();

      expect(state.getMeasurements().length, equals(2));

      // Clear frame 0 only
      state.clearMeasurements(0);
      await tester.pump();

      expect(state.getMeasurements(0).isEmpty, isTrue);
      expect(state.getMeasurements(1).length, equals(1));
      expect(state.getMeasurements(1).first.id, equals('f1_1'));

      // Clear all
      state.clearMeasurements();
      await tester.pump();

      expect(state.getMeasurements().isEmpty, isTrue);
    });

    testWidgets('9. Interactive drag appends multiple ROIs on same frame', (
      tester,
    ) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(
          key: key,
          dataset: ctDataset,
          frameIndex: 0,
          tool: DicomTool.rectangleRoi,
        ),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final center = tester.getCenter(
        find.byKey(const Key('dicom_windowing_gesture')),
      );

      // Drag 1: ROI A
      var gesture = await tester.startGesture(center - const Offset(100, 50));
      await tester.pump();
      await gesture.moveTo(center - const Offset(40, 10));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(state.getMeasurements(0).length, equals(1));
      final roiA =
          state.getMeasurements(0).first as DicomRectangleRoiMeasurement;
      expect(roiA.isValid, isTrue);
      expect(roiA.statistics, isNotNull);

      // Drag 2: ROI B at different location
      gesture = await tester.startGesture(center + const Offset(20, 20));
      await tester.pump();
      await gesture.moveTo(center + const Offset(80, 80));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(state.getMeasurements(0).length, equals(2));
      final roiB =
          state.getMeasurements(0).last as DicomRectangleRoiMeasurement;
      expect(roiB.isValid, isTrue);
      expect(roiB.statistics, isNotNull);
      expect(roiA.id, isNot(equals(roiB.id)));

      // Verify both are present on painter
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      final roiPaint = customPaints.firstWhere(
        (cp) => cp.painter is RectangleRoiPainter,
      );
      final painter = roiPaint.painter as RectangleRoiPainter;
      expect(painter.measurements.length, equals(2));
      expect(painter.measurements[0].id, equals(roiA.id));
      expect(painter.measurements[1].id, equals(roiB.id));
    });

    testWidgets(
      '10. In-progress measurement gesture interrupted by frame switch does not leak',
      (tester) async {
        final key = GlobalKey<DicomImageWidgetState>();
        await tester.pumpWidget(
          createViewer(
            key: key,
            dataset: multiFrameDataset,
            frameIndex: 0,
            tool: DicomTool.rectangleRoi,
          ),
        );
        await pumpAndRender(tester);

        final state = key.currentState!;
        final center = tester.getCenter(
          find.byKey(const Key('dicom_windowing_gesture')),
        );

        // 1. User starts creating an ROI on Frame 0
        final gesture = await tester.startGesture(
          center - const Offset(50, 50),
        );
        await tester.pump();
        await gesture.moveTo(center);
        await tester.pump();

        // 2. Active frame changes to Frame 1 before gesture completes
        await tester.pumpWidget(
          createViewer(
            key: key,
            dataset: multiFrameDataset,
            frameIndex: 1,
            tool: DicomTool.rectangleRoi,
          ),
        );
        await pumpAndRender(tester);

        // 3. User continues / finishes interacting on Frame 1
        await gesture.moveTo(center + const Offset(50, 50));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        // Verify: Frame 1 must NOT receive a partially-created or completed measurement
        expect(state.getMeasurements(1).isEmpty, isTrue);

        // Verify: Frame 0 must NOT have leaked or accidentally completed the measurement
        expect(state.getMeasurements(0).isEmpty, isTrue);
        expect(state.getMeasurements().isEmpty, isTrue);

        // 4. Switch back to Frame 0 to verify it remains clean
        await tester.pumpWidget(
          createViewer(
            key: key,
            dataset: multiFrameDataset,
            frameIndex: 0,
            tool: DicomTool.rectangleRoi,
          ),
        );
        await pumpAndRender(tester);

        expect(state.getMeasurements(0).isEmpty, isTrue);
      },
    );

    testWidgets('11. Measurement state isolation across dataset changes', (
      tester,
    ) async {
      final key = GlobalKey<DicomImageWidgetState>();
      await tester.pumpWidget(
        createViewer(
          key: key,
          dataset: multiFrameDataset,
          frameIndex: 0,
          tool: DicomTool.rectangleRoi,
        ),
      );
      await pumpAndRender(tester);

      final state = key.currentState!;
      final geometryA = DicomImageGeometry.fromDataset(multiFrameDataset);

      // Add measurements to Dataset A on Frame 0 and Frame 1
      state.addMeasurement(
        DicomRectangleRoiMeasurement.fromImagePoints(
          id: 'datasetA_roi_f0',
          start: const ImagePoint(pixelX: 10, pixelY: 10, isInsideImage: true),
          end: const ImagePoint(pixelX: 30, pixelY: 30, isInsideImage: true),
          frameIndex: 0,
          geometry: geometryA,
        ),
      );
      state.addMeasurement(
        DicomDistanceMeasurement.fromPoints(
          id: 'datasetA_dist_f1',
          start: const ImagePoint(pixelX: 40, pixelY: 40, isInsideImage: true),
          end: const ImagePoint(pixelX: 80, pixelY: 80, isInsideImage: true),
          frameIndex: 1,
          geometry: geometryA,
        ),
      );
      await tester.pump();

      expect(state.getMeasurements(0).length, equals(1));
      expect(state.getMeasurements(1).length, equals(1));
      expect(state.getMeasurements().length, equals(2));

      // Switch to Dataset B (CT small)
      await tester.pumpWidget(
        createViewer(
          key: key,
          dataset: ctDataset,
          frameIndex: 0,
          tool: DicomTool.rectangleRoi,
        ),
      );
      await pumpAndRender(tester);

      // Verify Dataset B starts with zero measurements (no stale Dataset A data)
      expect(state.getMeasurements().isEmpty, isTrue);
      expect(state.getMeasurements(0).isEmpty, isTrue);
      expect(state.getMeasurements(1).isEmpty, isTrue);

      // Add a measurement on Dataset B
      final geometryB = DicomImageGeometry.fromDataset(ctDataset);
      state.addMeasurement(
        DicomRectangleRoiMeasurement.fromImagePoints(
          id: 'datasetB_roi_f0',
          start: const ImagePoint(pixelX: 5, pixelY: 5, isInsideImage: true),
          end: const ImagePoint(pixelX: 25, pixelY: 25, isInsideImage: true),
          frameIndex: 0,
          geometry: geometryB,
        ),
      );
      await tester.pump();

      expect(state.getMeasurements(0).length, equals(1));
      expect(state.getMeasurements(0).first.id, equals('datasetB_roi_f0'));

      // Switch back to Dataset A
      await tester.pumpWidget(
        createViewer(
          key: key,
          dataset: multiFrameDataset,
          frameIndex: 0,
          tool: DicomTool.rectangleRoi,
        ),
      );
      await pumpAndRender(tester);

      // Verify Dataset A also starts clean (measurements from Dataset B did not leak, nor did old Dataset A state resurrect)
      expect(state.getMeasurements().isEmpty, isTrue);
    });
  });
}
