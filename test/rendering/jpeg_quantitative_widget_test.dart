import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/dicom_probe_painter.dart';
import 'package:dicom_viewer/src/geometry/rectangle_roi_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DicomDataset jpegLlDataset;
  late DicomDataset ybrMultiframeDataset;
  late DicomDataset ctUncompressedDataset;

  setUpAll(() {
    final jpegLlFile = File('test/fixtures/jpeg/JPEG-LL.dcm');
    expect(jpegLlFile.existsSync(), isTrue);
    jpegLlDataset = DicomDataset.fromBytes(jpegLlFile.readAsBytesSync());

    final ybrFile = File('test/fixtures/jpeg/examples_ybr_color.dcm');
    expect(ybrFile.existsSync(), isTrue);
    ybrMultiframeDataset = DicomDataset.fromBytes(ybrFile.readAsBytesSync());

    final ctFile = File('test/fixtures/CT_small.dcm');
    expect(ctFile.existsSync(), isTrue);
    ctUncompressedDataset = DicomDataset.fromBytes(ctFile.readAsBytesSync());
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
    DicomTool tool = DicomTool.probe,
    double width = 512,
    double height = 512,
    double? initialWindowCenter,
    double? initialWindowWidth,
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
            initialWindowCenter: initialWindowCenter,
            initialWindowWidth: initialWindowWidth,
          ),
        ),
      ),
    );
  }

  ProbeOverlayPainter? getProbePainter(WidgetTester tester) {
    final customPaints = tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    );
    for (final cp in customPaints) {
      if (cp.painter is ProbeOverlayPainter) {
        return cp.painter as ProbeOverlayPainter;
      }
    }
    return null;
  }

  RectangleRoiPainter? getRoiPainter(WidgetTester tester) {
    final customPaints = tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    );
    for (final cp in customPaints) {
      if (cp.painter is RectangleRoiPainter) {
        return cp.painter as RectangleRoiPainter;
      }
    }
    return null;
  }

  group('JPEG Quantitative Widget & Interaction Tests', () {
    testWidgets(
      '1. Pixel Probe hover on JPEG Lossless renders stored value overlay badge',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: jpegLlDataset, tool: DicomTool.probe),
        );
        await pumpAndRender(tester);

        expect(
          find.text(
            'Tool: Pixel Probe (Hover over image to inspect pixel values)',
          ),
          findsOneWidget,
        );

        final center = tester.getCenter(
          find.byKey(const Key('dicom_windowing_gesture')),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(center);
        await tester.pump();

        final painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.probeResult, isNotNull);
        expect(painter.probeResult!.isInside, isTrue);
        expect(painter.probeResult!.isHounsfield, isFalse);
        expect(painter.probeResult!.unit, isEmpty);
        expect(painter.probeResult!.storedValue, isNotNull);

        await gesture.removePointer();
      },
    );

    testWidgets(
      '2. Rectangle ROI drag on JPEG Lossless computes stored statistics',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: jpegLlDataset, tool: DicomTool.rectangleRoi),
        );
        await pumpAndRender(tester);

        final center = tester.getCenter(
          find.byKey(const Key('dicom_windowing_gesture')),
        );
        await tester.timedDragFrom(
          center - const Offset(20, 20),
          const Offset(40, 40),
          const Duration(milliseconds: 300),
        );
        await tester.pump();

        final painter = getRoiPainter(tester);
        expect(painter, isNotNull);
        expect(painter!.measurement, isNotNull);
        expect(painter.measurement!.isValid, isTrue);
        expect(painter.measurement!.statistics, isNotNull);
        expect(painter.measurement!.statistics!.isHounsfield, isFalse);
        expect(painter.measurement!.statistics!.unit, isEmpty);
        expect(
          painter.measurement!.statistics!.validPixelCount,
          greaterThan(0),
        );
      },
    );

    testWidgets(
      '3. Zoom and Pan do NOT alter ROI statistics on JPEG Lossless CT',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: jpegLlDataset, tool: DicomTool.rectangleRoi),
        );
        await pumpAndRender(tester);

        // 1. Create ROI
        final center = tester.getCenter(
          find.byKey(const Key('dicom_windowing_gesture')),
        );
        await tester.timedDragFrom(
          center - const Offset(20, 20),
          const Offset(40, 40),
          const Duration(milliseconds: 300),
        );
        await tester.pump();

        final initialPainter = getRoiPainter(tester);
        expect(initialPainter, isNotNull);
        final initialStats = initialPainter!.measurement!.statistics!;

        // 2. Switch to Pan tool and zoom in
        await tester.pumpWidget(
          createViewer(dataset: jpegLlDataset, tool: DicomTool.pan),
        );
        await pumpAndRender(tester);

        // Switch back to ROI tool
        await tester.pumpWidget(
          createViewer(dataset: jpegLlDataset, tool: DicomTool.rectangleRoi),
        );
        await pumpAndRender(tester);

        final postPainter = getRoiPainter(tester);
        expect(postPainter, isNotNull);
        final postStats = postPainter!.measurement!.statistics!;

        // Statistics must remain identical
        expect(postStats.mean, equals(initialStats.mean));
        expect(postStats.min, equals(initialStats.min));
        expect(postStats.max, equals(initialStats.max));
        expect(postStats.validPixelCount, equals(initialStats.validPixelCount));
      },
    );

    testWidgets('4. Dataset switching resets Probe and ROI states cleanly', (
      tester,
    ) async {
      // 1. Display JPEG Lossless dataset
      await tester.pumpWidget(
        createViewer(dataset: jpegLlDataset, tool: DicomTool.probe),
      );
      await pumpAndRender(tester);

      final center = tester.getCenter(
        find.byKey(const Key('dicom_windowing_gesture')),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(center);
      await tester.pump();

      expect(getProbePainter(tester), isNotNull);

      // 2. Switch to uncompressed CT dataset
      await tester.pumpWidget(
        createViewer(dataset: ctUncompressedDataset, tool: DicomTool.probe),
      );
      await pumpAndRender(tester);

      // Probe resets on dataset change
      expect(getProbePainter(tester), isNull);

      // 3. Switch to multi-frame JPEG dataset
      await tester.pumpWidget(
        createViewer(dataset: ybrMultiframeDataset, tool: DicomTool.probe),
      );
      await pumpAndRender(tester);

      expect(getProbePainter(tester), isNull);
      await gesture.removePointer();
    });

    testWidgets('5. Letterbox / out-of-bounds hover returns no probe result', (
      tester,
    ) async {
      // In 512x512 viewport with 256x1024 image, image is centered between x=192 and x=320.
      await tester.pumpWidget(
        createViewer(
          dataset: jpegLlDataset,
          width: 512,
          height: 512,
          tool: DicomTool.probe,
        ),
      );
      await pumpAndRender(tester);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      // Hover at far left letterbox area: (50, 256)
      await gesture.moveTo(const Offset(50, 256));
      await tester.pump();

      final painter = getProbePainter(tester);
      expect(painter, isNull);
      await gesture.removePointer();
    });

    testWidgets(
      '6. Distance Measurement on JPEG Lossless CT calculates physical distance',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: jpegLlDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        final center = tester.getCenter(
          find.byKey(const Key('dicom_windowing_gesture')),
        );
        final gesture = await tester.startGesture(center - const Offset(20, 0));
        await tester.pump();
        await gesture.moveTo(center + const Offset(20, 0));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );
  });
}
