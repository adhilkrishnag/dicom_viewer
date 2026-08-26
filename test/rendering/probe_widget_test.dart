import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/dicom_probe_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DicomDataset ctDataset;
  late DicomDataset mrDataset;
  late DicomDataset multiFrameDataset;

  setUpAll(() {
    final ctBytes = File('test/fixtures/CT_small.dcm').readAsBytesSync();
    ctDataset = DicomDataset.fromBytes(ctBytes);

    final mrBytes = File('test/fixtures/MR_small.dcm').readAsBytesSync();
    mrDataset = DicomDataset.fromBytes(mrBytes);

    final multiBytes =
        File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm').readAsBytesSync();
    multiFrameDataset = DicomDataset.fromBytes(multiBytes);
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

  group('Group 5: Widget Pointer, Hover & Letterbox Integration', () {
    testWidgets(
      '23. Hovering over image in DicomTool.probe mode renders probe overlay badge',
      (tester) async {
        await tester.pumpWidget(createViewer(dataset: ctDataset));
        await pumpAndRender(tester);

        expect(
          find.text(
            'Tool: Pixel Probe (Hover over image to inspect pixel values)',
          ),
          findsOneWidget,
        );
        expect(getProbePainter(tester), isNull);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();

        final painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.probeResult, isNotNull);
        expect(painter.probeResult!.isInside, isTrue);
        expect(painter.probeResult!.isHounsfield, isTrue);
        expect(painter.probeResult!.unit, 'HU');

        await gesture.removePointer();
      },
    );

    testWidgets(
      '24. Hovering in letterbox/pillarbox area outside image suppresses probe badge',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 1000, height: 512),
        );
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        // Letterbox area
        await gesture.moveTo(const Offset(50, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNull);

        // Inside image area
        await gesture.moveTo(const Offset(500, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNotNull);

        // Back to letterbox area
        await gesture.moveTo(const Offset(950, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNull);

        await gesture.removePointer();
      },
    );

    testWidgets('25. Pointer exit clears probe overlay badge', (tester) async {
      await tester.pumpWidget(createViewer(dataset: ctDataset));
      await pumpAndRender(tester);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      await gesture.moveTo(const Offset(256, 256));
      await tester.pump();
      expect(getProbePainter(tester), isNotNull);

      await gesture.removePointer();
      await tester.pump();
      expect(getProbePainter(tester), isNull);
    });

    testWidgets(
      '26. Moving pointer across boundary dynamically toggles badge visibility',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 1000, height: 512),
        );
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        // Outside
        await gesture.moveTo(const Offset(100, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNull);

        // Inside
        await gesture.moveTo(const Offset(500, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNotNull);

        // Outside
        await gesture.moveTo(const Offset(100, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNull);

        await gesture.removePointer();
      },
    );

    testWidgets(
      '27. Zoom + pan coordinate transformation: probe tracks correct discrete pixel',
      (tester) async {
        await tester.pumpWidget(createViewer(dataset: ctDataset));
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();

        final painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.probeResult!.isInside, isTrue);

        await gesture.removePointer();
      },
    );

    testWidgets(
      '28. Reticle crosshair rendering centered at discrete pixel cell',
      (tester) async {
        await tester.pumpWidget(createViewer(dataset: ctDataset));
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();

        final painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.viewportPosition, const Offset(256, 256));

        await gesture.removePointer();
      },
    );
  });

  group('Group 6: Tool, Frame, Dataset Lifecycle & Semantics', () {
    testWidgets(
      '29. Switching tool from Probe to Measure/Windowing/Pan hides probe HUD',
      (tester) async {
        var activeTool = DicomTool.probe;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 512,
                    height: 512,
                    child: DicomImageWidget(
                      dataset: ctDataset,
                      enableZoom: true,
                      tool: activeTool,
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        activeTool = DicomTool.measure;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNotNull);

        // Switch tool
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        expect(getProbePainter(tester), isNull);
        expect(
          find.text('Tool: Measure (Drag across image to measure distance)'),
          findsOneWidget,
        );

        await gesture.removePointer();
      },
    );

    testWidgets(
      '30. Switching tool back to Probe restores probe capability without stale badge',
      (tester) async {
        var activeTool = DicomTool.probe;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 512,
                    height: 512,
                    child: DicomImageWidget(
                      dataset: ctDataset,
                      enableZoom: true,
                      tool: activeTool,
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        activeTool =
                            activeTool == DicomTool.probe
                                ? DicomTool.windowing
                                : DicomTool.probe;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();
        expect(getProbePainter(tester), isNotNull);

        // Switch to windowing
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        expect(getProbePainter(tester), isNull);

        // Switch back to probe: overlay should be initially clear before pointer moves
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        expect(getProbePainter(tester), isNull);

        // Hover again
        await gesture.moveTo(const Offset(260, 260));
        await tester.pump();
        expect(getProbePainter(tester), isNotNull);

        await gesture.removePointer();
      },
    );

    testWidgets(
      '31. Multi-frame image navigation: frame index change invalidates probe cache and isolates frame pixels',
      (tester) async {
        var currentFrame = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 512,
                    height: 512,
                    child: DicomImageWidget(
                      dataset: multiFrameDataset,
                      frameIndex: currentFrame,
                      enableZoom: true,
                      tool: DicomTool.probe,
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        currentFrame = 1;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();

        var painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.probeResult!.isInside, isTrue);

        // Switch to frame 1
        await tester.tap(find.byType(FloatingActionButton));
        await pumpAndRender(tester);

        // Hover on frame 1
        await gesture.moveTo(const Offset(260, 260));
        await tester.pump();

        painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.probeResult!.isInside, isTrue);

        await gesture.removePointer();
      },
    );

    testWidgets(
      '32. Dataset change clears active probe result and invalidates frame pixel buffer',
      (tester) async {
        var activeDataset = ctDataset;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 512,
                    height: 512,
                    child: DicomImageWidget(
                      dataset: activeDataset,
                      enableZoom: true,
                      tool: DicomTool.probe,
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        activeDataset = mrDataset;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();

        var painter = getProbePainter(tester);
        expect(painter!.probeResult!.isHounsfield, isTrue);

        // Switch dataset to MR
        await tester.tap(find.byType(FloatingActionButton));
        await pumpAndRender(tester);

        // Hover on MR dataset
        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();

        painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.probeResult!.isHounsfield, isFalse);
        expect(painter.probeResult!.unit, '');

        await gesture.removePointer();
      },
    );

    testWidgets(
      '33. Accessible Semantics: CT exposes Hounsfield Units in screen reader label',
      (tester) async {
        await tester.pumpWidget(createViewer(dataset: ctDataset));
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        await gesture.moveTo(const Offset(256, 256));
        await tester.pump();

        final semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains('Hounsfield Units'),
        );
        expect(semanticsFinder, findsOneWidget);

        await gesture.removePointer();
      },
    );

    testWidgets(
      '34. Performance: Hovering does not trigger full image decoding or widget re-render',
      (tester) async {
        await tester.pumpWidget(createViewer(dataset: ctDataset));
        await pumpAndRender(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();

        // Rapidly move mouse over multiple locations
        for (int i = 0; i < 10; i++) {
          await gesture.moveTo(Offset(200.0 + i * 5, 200.0 + i * 5));
          await tester.pump();
        }

        final painter = getProbePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.probeResult!.isInside, isTrue);

        await gesture.removePointer();
      },
    );
  });
}
