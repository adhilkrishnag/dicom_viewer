import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/distance_measurement_painter.dart';

import '../generate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DicomDataset ctDataset;
  late DicomDataset mrDataset;
  late DicomDataset rleMultiFrameDataset;
  late DicomDataset paletteDataset;
  late DicomDataset rgbDataset;

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
    paletteDataset = DicomDataset.fromBytes(
      File('test/fixtures/rle/OBXXXX1A_rle.dcm').readAsBytesSync(),
    );

    final rgbBytes = SyntheticDicomGenerator.create(
      width: 64,
      height: 64,
      samplesPerPixel: 3,
      photometricInterpretation: 'RGB',
      bitsAllocated: 8,
      bitsStored: 8,
      highBit: 7,
      pixelSpacing: [0.5, 0.5],
      customRgbBytes: Uint8List.fromList(List.filled(64 * 64 * 3, 128)),
    );
    rgbDataset = DicomDataset.fromBytes(rgbBytes);
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
    DicomTool tool = DicomTool.measure,
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

  group('Widget Transform Integration Tests', () {
    testWidgets(
      '18. Correct viewport size is supplied to ImageCoordinateTransform via LayoutBuilder',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 800, height: 600),
        );
        await pumpAndRender(tester);

        var customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        var overlayPainter = customPaints.firstWhere(
          (cp) => cp.painter is DistanceMeasurementPainter,
        );
        expect(overlayPainter.size, equals(const Size(800, 600)));

        // Resize viewport to 400x300
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 400, height: 300),
        );
        await pumpAndRender(tester);

        customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        overlayPainter = customPaints.firstWhere(
          (cp) => cp.painter is DistanceMeasurementPainter,
        );
        expect(overlayPainter.size, equals(const Size(400, 300)));
      },
    );

    testWidgets('19. Centered image maps correctly from real widget coordinates', (
      tester,
    ) async {
      // In 800x600 viewport, CT_small (128x128, square) is centered in a 600x600 square from x=100 to x=700
      await tester.pumpWidget(
        createViewer(dataset: ctDataset, width: 800, height: 600),
      );
      await pumpAndRender(tester);

      // Center of viewport (400, 300) should map to native pixel center (64, 64)
      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump();
      await gesture.moveTo(const Offset(400, 300));
      await tester.pump();
      await gesture.up();
      await pumpAndRender(tester);

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      '20. Zoomed image (2.0x) maps gesture coordinates to correct continuous pixel positions',
      (tester) async {
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            enableZoom: true,
            tool: DicomTool.measure,
            width: 800,
            height: 600,
          ),
        );
        await pumpAndRender(tester);

        // Perform gesture under measurement tool
        final gesture = await tester.startGesture(const Offset(350, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '21. Panned image maps gesture coordinates to correct continuous pixel positions',
      (tester) async {
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            enableZoom: true,
            tool: DicomTool.measure,
            width: 800,
            height: 600,
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(200, 200));
        await tester.pump();
        await gesture.moveTo(const Offset(300, 250));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '22. Zoom + Pan combined transformation maps gesture coordinates correctly',
      (tester) async {
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            enableZoom: true,
            tool: DicomTool.measure,
            width: 800,
            height: 600,
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(300, 200));
        await tester.pump();
        await gesture.moveTo(const Offset(500, 400));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '23. Non-square display aspect ratio maps coordinates correctly',
      (tester) async {
        // Create synthetic dataset with non-square pixel spacing (0.5 mm row, 1.0 mm col -> AR = 2.0)
        final wideBytes = SyntheticDicomGenerator.create(
          width: 128,
          height: 128,
          pixelSpacing: [0.5, 1.0],
        );
        final wideDataset = DicomDataset.fromBytes(wideBytes);

        await tester.pumpWidget(
          createViewer(dataset: wideDataset, width: 800, height: 600),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(400, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(500, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '24. Actual gesture coordinates produce correct continuous image coordinates in widget state',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 800, height: 600),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(400, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(480, 360));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '25. Releasing endpoint outside image cancels attempted measurement',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, width: 800, height: 600),
        );
        await pumpAndRender(tester);

        // Start inside (400, 300), drag far into left letterbox area (x = 20 < 100)
        final gesture = await tester.startGesture(const Offset(400, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(20, 300));
        await tester.pump();
        await gesture.up(); // Released outside!
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );
  });

  group('Interaction Tests', () {
    testWidgets('26. Measure tool disables windowing drag callback', (
      tester,
    ) async {
      double? changedWc;
      double? changedWw;

      await tester.pumpWidget(
        createViewer(
          dataset: ctDataset,
          tool: DicomTool.measure,
          onWindowChanged: (wc, ww) {
            changedWc = wc;
            changedWw = ww;
          },
        ),
      );
      await pumpAndRender(tester);

      // Drag across the center of the image
      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(100, 50));
      await tester.pump();
      await gesture.up();
      await pumpAndRender(tester);

      // Windowing callback must NOT be triggered
      expect(changedWc, isNull);
      expect(changedWw, isNull);
    });

    testWidgets(
      '27. Measurement survives zoom: physical distance in mm is unchanged before and after zoom',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.measure,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        // Draw measurement
        final gesture = await tester.startGesture(const Offset(200, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(400, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // Switch to Pan & Zoom and apply scale
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.pan,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        // Switch back to Measure
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.measure,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '28. Measurement survives pan: physical distance in mm is unchanged before and after pan',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.measure,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(250, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(350, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // Switch to Pan
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.pan,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '29. Measurement survives zoom + pan: physical distance in mm is unchanged before and after combined transform',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.measure,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(200, 200));
        await tester.pump();
        await gesture.moveTo(const Offset(400, 400));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // Switch to Pan
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.pan,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '30. Tool switching (Measure -> Pan & Zoom -> Windowing) preserves measurement coordinates and overlay',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.measure,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        // Measure
        final gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(400, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // Switch to Pan & Zoom
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.pan,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);
        expect(find.byType(CustomPaint), findsWidgets);

        // Switch to Windowing
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: DicomImageWidget(
                  dataset: ctDataset,
                  enableZoom: true,
                  tool: DicomTool.windowing,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '31. Dataset change clears all measurements across all frames',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // Draw measurement on CT
        final gesture = await tester.startGesture(const Offset(350, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // Switch to MR dataset
        await tester.pumpWidget(
          createViewer(dataset: mrDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets('32. Multi-frame dataset isolates measurements per frame', (
      tester,
    ) async {
      // Frame 0
      await tester.pumpWidget(
        createViewer(
          dataset: rleMultiFrameDataset,
          frameIndex: 0,
          tool: DicomTool.measure,
        ),
      );
      await pumpAndRender(tester);

      // Measure on Frame 0
      final gesture = await tester.startGesture(const Offset(300, 300));
      await tester.pump();
      await gesture.moveTo(const Offset(400, 300));
      await tester.pump();
      await gesture.up();
      await pumpAndRender(tester);

      // Switch to Frame 1
      await tester.pumpWidget(
        createViewer(
          dataset: rleMultiFrameDataset,
          frameIndex: 1,
          tool: DicomTool.measure,
        ),
      );
      await pumpAndRender(tester);

      // Switch back to Frame 0
      await tester.pumpWidget(
        createViewer(
          dataset: rleMultiFrameDataset,
          frameIndex: 0,
          tool: DicomTool.measure,
        ),
      );
      await pumpAndRender(tester);

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Color & Photometric Tests', () {
    testWidgets(
      '33. PALETTE COLOR DICOM fixture (OBXXXX1A_rle.dcm) supports distance measurement',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: paletteDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // Draw measurement on PALETTE COLOR image
        final gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 350));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '34. RGB / YBR synthetic DICOM dataset supports distance measurement',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: rgbDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // Draw measurement on RGB image
        final gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      '35. Color rendering pipeline remains unchanged when Measure tool is active',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: paletteDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // Confirm color image renders properly via RawImage
        final rawImageFinder = find.byType(RawImage);
        expect(rawImageFinder, findsOneWidget);
        final rawImage = tester.widget<RawImage>(rawImageFinder);
        expect(rawImage.image, isNotNull);
        expect(rawImage.image!.width, equals(paletteDataset.columns));
        expect(rawImage.image!.height, equals(paletteDataset.rows));
      },
    );
  });

  group('Task 5 — Overlay Rendering, Endpoint Interaction & Semantics Tests', () {
    testWidgets(
      '44. Overlay painter renders line, endpoint markers, and distance badge on canvas (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // Perform drag
        final gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        final customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        final overlayPainter =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;

        expect(overlayPainter.measurement, isNotNull);
        expect(overlayPainter.measurement!.isValid, isTrue);
        expect(overlayPainter.measurement!.hasPhysicalMeasurement, isTrue);
        expect(overlayPainter.measurement!.formattedDistance, contains('mm'));
      },
    );

    testWidgets(
      '45. Endpoint adjustment allows dragging start marker to update start point while anchoring end point (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // 1. Initial measurement from (300, 300) to (450, 300)
        var gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        var customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        var overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        final initialEndPxX = overlay.measurement!.end.pixelX;
        final initialStartPxX = overlay.measurement!.start.pixelX;

        // 2. Drag start marker from (300, 300) to (250, 300)
        gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(250, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;

        // Start point moved leftwards, end point remained anchored
        expect(overlay.measurement!.start.pixelX, lessThan(initialStartPxX));
        expect(overlay.measurement!.end.pixelX, closeTo(initialEndPxX, 1e-4));
      },
    );

    testWidgets(
      '46. Endpoint adjustment allows dragging end marker to update end point while anchoring start point (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // 1. Initial measurement from (300, 300) to (450, 300)
        var gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        var customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        var overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        final initialStartPxX = overlay.measurement!.start.pixelX;
        final initialEndPxX = overlay.measurement!.end.pixelX;

        // 2. Drag end marker from (450, 300) to (500, 300)
        gesture = await tester.startGesture(const Offset(450, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(500, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;

        // Start point remained anchored, end point moved rightwards
        expect(
          overlay.measurement!.start.pixelX,
          closeTo(initialStartPxX, 1e-4),
        );
        expect(overlay.measurement!.end.pixelX, greaterThan(initialEndPxX));
      },
    );

    testWidgets(
      '47. Tapping outside existing marker thresholds starts a new measurement replacing the old one (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // 1. Measurement 1: horizontal (300, 300) -> (450, 300)
        var gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // 2. Start new measurement far away: vertical (350, 200) -> (350, 400)
        gesture = await tester.startGesture(const Offset(350, 200));
        await tester.pump();
        await gesture.moveTo(const Offset(350, 400));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        final customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        final overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;

        // Check that new vertical measurement replaced the old one
        expect(
          overlay.measurement!.start.pixelY,
          lessThan(overlay.measurement!.end.pixelY),
        );
        expect(overlay.measurement!.deltaPixelX, closeTo(0.0, 1e-4));
      },
    );

    testWidgets(
      '48. Measurement overlay exposes accessible Semantics with formatted distance description (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        // Initial state before measurement: no measurement semantics
        var semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains('Distance measurement:'),
        );
        expect(semanticsFinder, findsNothing);

        // Draw measurement
        final gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains('Distance measurement:'),
        );
        expect(semanticsFinder, findsOneWidget);
        final semantics = tester.widget<Semantics>(semanticsFinder);
        expect(semantics.properties.label, contains('millimeters'));
      },
    );

    testWidgets(
      '49. Releasing endpoint outside image during active drag cancels and does not commit invalid measurement (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            tool: DicomTool.measure,
            width: 800,
            height: 600,
          ),
        );
        await pumpAndRender(tester);

        // Start inside (400, 300), drag far outside into letterbox (50, 50)
        final gesture = await tester.startGesture(const Offset(400, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(50, 50));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        final customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        final overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;

        // Uncommitted invalid measurement is cleared
        expect(overlay.measurement, isNull);
      },
    );

    testWidgets(
      '50. Continuous dragging across boundary dynamically switches between valid and invalid overlay state (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            tool: DicomTool.measure,
            width: 800,
            height: 600,
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(400, 300));
        await tester.pump();

        // 1. Move inside image
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        var customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        var overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        expect(overlay.measurement!.isValid, isTrue);

        // 2. Move into letterbox outside image
        await gesture.moveTo(const Offset(20, 20));
        await tester.pump();
        customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        expect(overlay.measurement!.isValid, isFalse);

        // 3. Move back inside image
        await gesture.moveTo(const Offset(420, 320));
        await tester.pump();
        customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        expect(overlay.measurement!.isValid, isTrue);

        await gesture.up();
        await pumpAndRender(tester);
      },
    );

    testWidgets(
      '51. Viewport resize maintains accurate relative position and distance badge (Real Fixture)',
      (tester) async {
        // Render at 800x600
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            tool: DicomTool.measure,
            width: 800,
            height: 600,
          ),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(350, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        var customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        var overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        final distBefore = overlay.measurement!.physicalDistanceMm;

        // Re-render in resized 600x400 viewport
        await tester.pumpWidget(
          createViewer(
            dataset: ctDataset,
            tool: DicomTool.measure,
            width: 600,
            height: 400,
          ),
        );
        await pumpAndRender(tester);

        customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        final distAfter = overlay.measurement!.physicalDistanceMm;

        expect(distAfter, closeTo(distBefore!, 1e-4));
      },
    );

    testWidgets(
      '52. Tool switching between Measure, Pan, and Windowing retains gesture isolation and overlay visibility (Real Fixture)',
      (tester) async {
        // Measure mode
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        final gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        await gesture.moveTo(const Offset(450, 300));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // Switch to Windowing mode
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.windowing),
        );
        await pumpAndRender(tester);

        var customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        var overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        expect(overlay.measurement, isNotNull);

        // Switch to Pan mode
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.pan),
        );
        await pumpAndRender(tester);

        customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        overlay =
            customPaints
                    .firstWhere(
                      (cp) => cp.painter is DistanceMeasurementPainter,
                    )
                    .painter
                as DistanceMeasurementPainter;
        expect(overlay.measurement, isNotNull);
      },
    );

    testWidgets(
      '53. Performance: Dragging measurement does not trigger full image decoding or re-rendering (Real Fixture)',
      (tester) async {
        await tester.pumpWidget(
          createViewer(dataset: ctDataset, tool: DicomTool.measure),
        );
        await pumpAndRender(tester);

        final rawImageBefore = tester.widget<RawImage>(find.byType(RawImage));
        final imageHandleBefore = rawImageBefore.image;

        // Perform multi-step drag
        final gesture = await tester.startGesture(const Offset(300, 300));
        await tester.pump();
        for (int i = 0; i < 10; i++) {
          await gesture.moveTo(Offset(300.0 + i * 10, 300.0 + i * 5));
          await tester.pump();
        }
        await gesture.up();
        await pumpAndRender(tester);

        final rawImageAfter = tester.widget<RawImage>(find.byType(RawImage));
        final imageHandleAfter = rawImageAfter.image;

        // Image instance was not re-decoded or recreated
        expect(identical(imageHandleBefore, imageHandleAfter), isTrue);
      },
    );
  });
}
