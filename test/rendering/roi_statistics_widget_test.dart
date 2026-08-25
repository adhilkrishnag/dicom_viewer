import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DicomDataset ctDataset;
  late DicomDataset mrDataset;
  late DicomDataset rleMultiFrameDataset;

  setUpAll(() {
    ctDataset = DicomDataset.fromBytes(
      File('test/fixtures/CT_small.dcm').readAsBytesSync(),
    );
    mrDataset = DicomDataset.fromBytes(
      File('test/fixtures/MR_small.dcm').readAsBytesSync(),
    );
    rleMultiFrameDataset = DicomDataset.fromBytes(
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
    required DicomDataset dataset,
    int frameIndex = 0,
    bool enableZoom = true,
    DicomTool tool = DicomTool.rectangleRoi,
    double width = 800,
    double height = 600,
    void Function(double, double)? onWindowChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: DicomImageWidget(
            dataset: dataset,
            frameIndex: frameIndex,
            enableZoom: enableZoom,
            tool: tool,
            onWindowChanged: onWindowChanged,
          ),
        ),
      ),
    );
  }

  RectangleRoiPainter getRoiPainter(WidgetTester tester) {
    final customPaints = tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    );
    final overlayPainter = customPaints.firstWhere(
      (cp) => cp.painter is RectangleRoiPainter,
    );
    return overlayPainter.painter! as RectangleRoiPainter;
  }

  group('Group 6: Widget & Lifecycle Integration Tests for ROI Statistics', () {
    testWidgets(
      '24. Dragging does not calculate statistics until pointer release',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 800, height: 600),
        );
        await pumpAndRender(tester);

        final center = tester.getCenter(find.byType(DicomImageWidget));
        final gesture = await tester.startGesture(center);
        await tester.pump();

        // Move pointer
        await gesture.moveTo(center + const Offset(100, 80));
        await tester.pump();

        // During active drag, statistics is null (lightweight geometry only)
        var painter = getRoiPainter(tester);
        expect(painter.measurement, isNotNull);
        expect(painter.measurement!.statistics, isNull);
        expect(painter.measurement!.formattedDimensions, contains('mm'));

        // Release pointer
        await gesture.up();
        await tester.pump();

        // After release, statistics is calculated and populated
        painter = getRoiPainter(tester);
        expect(painter.measurement, isNotNull);
        expect(painter.measurement!.statistics, isNotNull);
        expect(painter.measurement!.statistics!.hasValidPixels, isTrue);
        expect(painter.measurement!.statistics!.isHounsfield, isTrue);
        expect(painter.measurement!.statistics!.unit, 'HU');
      },
    );

    testWidgets(
      '25. CT dataset overlay displays HU statistics in semantics and formatted summary',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 800, height: 600),
        );
        await pumpAndRender(tester);

        final center = tester.getCenter(find.byType(DicomImageWidget));
        final gesture = await tester.startGesture(center);
        await tester.pump();
        await gesture.moveTo(center + const Offset(60, 60));
        await gesture.up();
        await tester.pump();

        final painter = getRoiPainter(tester);
        final stats = painter.measurement!.statistics!;
        expect(stats.isHounsfield, isTrue);
        expect(stats.unit, 'HU');
        expect(
          painter.measurement!.semanticsLabel,
          contains('Hounsfield Units'),
        );
        expect(stats.formattedLines.first, contains('HU'));
      },
    );

    testWidgets(
      '26. MR dataset overlay displays unitless statistics (no HU, no px in intensity)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: mrDataset, width: 800, height: 600),
        );
        await pumpAndRender(tester);

        final center = tester.getCenter(find.byType(DicomImageWidget));
        final gesture = await tester.startGesture(center);
        await tester.pump();
        await gesture.moveTo(center + const Offset(60, 60));
        await gesture.up();
        await tester.pump();

        final painter = getRoiPainter(tester);
        final stats = painter.measurement!.statistics!;
        expect(stats.isHounsfield, isFalse);
        expect(stats.unit, '');
        expect(stats.formattedLines.first, isNot(contains('HU')));
        expect(stats.formattedLines.first, isNot(contains('px')));
      },
    );

    testWidgets(
      '27. Multi-frame navigation preserves per-frame statistics across frame switches',
      (tester) async {
        // Frame 0: Create ROI A
        await tester.pumpWidget(
          createViewer(dataset: rleMultiFrameDataset, frameIndex: 0),
        );
        await pumpAndRender(tester);

        final center = tester.getCenter(find.byType(DicomImageWidget));
        var gesture = await tester.startGesture(center);
        await gesture.moveTo(center + const Offset(50, 50));
        await gesture.up();
        await tester.pump();

        var painter = getRoiPainter(tester);
        final stats0 = painter.measurement!.statistics;
        expect(stats0, isNotNull);

        // Switch to Frame 1: Initially no ROI on Frame 1
        await tester.pumpWidget(
          createViewer(dataset: rleMultiFrameDataset, frameIndex: 1),
        );
        await pumpAndRender(tester);

        painter = getRoiPainter(tester);
        expect(painter.measurement, isNull);

        // Create ROI B on Frame 1
        gesture = await tester.startGesture(center + const Offset(20, 20));
        await gesture.moveTo(center + const Offset(80, 80));
        await gesture.up();
        await tester.pump();

        painter = getRoiPainter(tester);
        final stats1 = painter.measurement!.statistics;
        expect(stats1, isNotNull);

        // Switch back to Frame 0: ROI A and Stats A are restored
        await tester.pumpWidget(
          createViewer(dataset: rleMultiFrameDataset, frameIndex: 0),
        );
        await pumpAndRender(tester);

        painter = getRoiPainter(tester);
        expect(painter.measurement, isNotNull);
        expect(painter.measurement!.statistics, equals(stats0));
      },
    );

    testWidgets(
      '28. Dataset change clears all ROI statistics across all frames',
      (tester) async {
        await tester.pumpWidget(createViewer(dataset: ctDataset));
        await pumpAndRender(tester);

        final center = tester.getCenter(find.byType(DicomImageWidget));
        final gesture = await tester.startGesture(center);
        await gesture.moveTo(center + const Offset(50, 50));
        await gesture.up();
        await tester.pump();

        var painter = getRoiPainter(tester);
        expect(painter.measurement, isNotNull);
        expect(painter.measurement!.statistics, isNotNull);

        // Change dataset to MR
        await tester.pumpWidget(createViewer(dataset: mrDataset));
        await pumpAndRender(tester);

        painter = getRoiPainter(tester);
        expect(painter.measurement, isNull);
      },
    );

    testWidgets(
      '29. Windowing adjustments do not alter computed ROI statistics',
      (tester) async {
        double? lastWc;
        double? lastWw;

        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            onWindowChanged: (wc, ww) {
              lastWc = wc;
              lastWw = ww;
            },
          ),
        );
        await pumpAndRender(tester);

        // Draw ROI
        final center = tester.getCenter(find.byType(DicomImageWidget));
        final gesture = await tester.startGesture(center);
        await gesture.moveTo(center + const Offset(50, 50));
        await gesture.up();
        await tester.pump();

        var painter = getRoiPainter(tester);
        final initialStats = painter.measurement!.statistics!;

        // Switch tool to windowing
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            tool: DicomTool.windowing,
            onWindowChanged: (wc, ww) {
              lastWc = wc;
              lastWw = ww;
            },
          ),
        );
        await pumpAndRender(tester);

        // Drag to adjust windowing
        await tester.timedDragFrom(
          center,
          const Offset(100, -50),
          const Duration(milliseconds: 300),
        );
        await tester.pump();

        expect(lastWc, isNotNull);
        expect(lastWw, isNotNull);

        // Check that ROI statistics did not change
        painter = getRoiPainter(tester);
        expect(painter.measurement, isNotNull);
        expect(painter.measurement!.statistics, equals(initialStats));
      },
    );
  });
}
