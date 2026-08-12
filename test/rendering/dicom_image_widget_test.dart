import 'dart:ui' as ui;
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DicomImageWidget Windowing Drag & Behavioral Tests', () {
    testWidgets(
      'Horizontal and vertical drag gestures accurately change WW, WC, emit callbacks, and update rendered Image',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'SMITH^ALICE',
          modality: 'MR',
          windowCenter: 40.0,
          windowWidth: 400.0,
        );

        final dataset = DicomDataset.fromBytes(bytes);

        double? lastCenter;
        double? lastWidth;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                sensitivity: 2.0,
                onWindowChanged: (center, width) {
                  lastCenter = center;
                  lastWidth = width;
                },
              ),
            ),
          ),
        );

        // Wait for initial image render
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        // Initial Overlay Check
        expect(find.textContaining('WC: 40  WW: 400'), findsOneWidget);
        final rawImageFinder = find.byType(RawImage);
        expect(rawImageFinder, findsOneWidget);
        final initialRawImage = tester.widget<RawImage>(rawImageFinder);
        final ui.Image? initialUiImage = initialRawImage.image;
        expect(initialUiImage, isNotNull);

        final gestureFinder = find.byKey(const Key('dicom_windowing_gesture'));
        expect(gestureFinder, findsOneWidget);

        // 1. Horizontal Drag Test (+50px X -> windowWidth increases)
        await tester.drag(gestureFinder, const Offset(50, 0));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        expect(lastWidth, greaterThan(400.0));
        expect(lastCenter, equals(40.0));
        expect(
          find.textContaining('WC: 40  WW: ${lastWidth!.round()}'),
          findsOneWidget,
        );

        // 2. Vertical Drag Test (-30px Y -> windowCenter increases)
        await tester.drag(gestureFinder, const Offset(0, -30));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        expect(lastCenter, greaterThan(40.0));
        expect(
          find.textContaining(
            'WC: ${lastCenter!.round()}  WW: ${lastWidth!.round()}',
          ),
          findsOneWidget,
        );

        // 3. Confirm rendered RawImage's ui.Image handle updated
        final updatedRawImage = tester.widget<RawImage>(rawImageFinder);
        expect(updatedRawImage.image, isNotNull);
        // The newly rendered ui.Image instance is distinct from initial instance
        expect(updatedRawImage.image, isNot(same(initialUiImage)));
      },
    );

    testWidgets(
      'Interactive mode (enableZoom: true) renders InteractiveViewer and handles pan/zoom & double-tap reset',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'SMITH^ALICE',
          modality: 'CT',
          windowCenter: 40.0,
          windowWidth: 400.0,
        );

        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                enableZoom: true,
                onViewChanged: (scale, offset) {},
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        // Verify InteractiveViewer is present in the tree
        final interactiveViewerFinder = find.byType(InteractiveViewer);
        expect(interactiveViewerFinder, findsOneWidget);

        final widget = tester.widget<InteractiveViewer>(
          interactiveViewerFinder,
        );
        expect(widget.panEnabled, isTrue);
        expect(widget.scaleEnabled, isTrue);

        // Verify double-tap reset calls resetWindowing
        final gestureFinder = find.byKey(const Key('dicom_windowing_gesture'));
        await tester.tap(gestureFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(gestureFinder);
        await tester.pumpAndSettle();

        expect(find.textContaining('WC: 40  WW: 400'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching enableZoom dynamically toggles InteractiveViewer presence',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'DOE^JOHN',
          modality: 'CT',
        );

        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(dataset: dataset, enableZoom: false),
            ),
          ),
        );

        expect(find.byType(InteractiveViewer), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(dataset: dataset, enableZoom: true),
            ),
          ),
        );

        expect(find.byType(InteractiveViewer), findsOneWidget);
      },
    );

    testWidgets(
      'Interactive mode with DicomTool.windowing enables windowing drag while maintaining InteractiveViewer',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'TOOL^TEST',
          modality: 'CT',
          windowCenter: 40.0,
          windowWidth: 400.0,
        );

        final dataset = DicomDataset.fromBytes(bytes);

        double? lastCenter;
        double? lastWidth;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                enableZoom: true,
                tool: DicomTool.windowing,
                onWindowChanged: (center, width) {
                  lastCenter = center;
                  lastWidth = width;
                },
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        // Verify Transform widget is used to preserve matrix while enabling windowing drag
        final transformFinder = find.byType(Transform);
        expect(transformFinder, findsWidgets);

        // Verify drag adjusts WC/WW
        final gestureFinder = find.byKey(const Key('dicom_windowing_gesture'));
        await tester.drag(gestureFinder, const Offset(50, -20));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        expect(lastCenter, greaterThan(40.0));
        expect(lastWidth, greaterThan(400.0));
      },
    );

    // -------------------------------------------------------------------------
    // Tool-switching state-preservation tests
    // -------------------------------------------------------------------------

    testWidgets(
      'Tool switch preserves drag-modified WC/WW: onWindowChanged values are '
      'used as initialWindowCenter/Width when widget recreates',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'PRESERVE^TEST',
          modality: 'CT',
          windowCenter: 40.0,
          windowWidth: 400.0,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        // Tracks the latest WC/WW reported by onWindowChanged (mirrors what
        // the example app does with _activeWc/_activeWw).
        double trackedWc = 40.0;
        double trackedWw = 400.0;
        DicomTool currentTool = DicomTool.windowing;
        const int generation =
            0; // incremented only on preset/reset, not tool switch

        Widget buildWidget() => MaterialApp(
          home: Scaffold(
            body: DicomImageWidget(
              key: const ValueKey('test-$generation'),
              dataset: dataset,
              enableZoom: true,
              tool: currentTool,
              initialWindowCenter: trackedWc,
              initialWindowWidth: trackedWw,
              onWindowChanged: (c, w) {
                // Silent tracking: no setState, mirrors example-app pattern.
                trackedWc = c;
                trackedWw = w;
              },
            ),
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        // Step 1: Drag in windowing tool to modify WC/WW.
        final gestureFinder = find.byKey(const Key('dicom_windowing_gesture'));
        await tester.drag(gestureFinder, const Offset(100, -50));
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(trackedWc, greaterThan(40.0)); // drag increased WC
        expect(trackedWw, greaterThan(400.0)); // drag increased WW
        final modifiedWc = trackedWc;
        final modifiedWw = trackedWw;

        // Step 2: Switch to pan tool — no generation change (no key change).
        // Widget rebuilds with new `tool` but same key → internal state kept.
        currentTool = DicomTool.pan;
        await tester.pumpWidget(buildWidget());
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        // Step 3: Switch back to windowing — still no generation change.
        currentTool = DicomTool.windowing;
        await tester.pumpWidget(buildWidget());
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        // Internal WC/WW state was preserved through both tool switches.
        expect(
          find.textContaining(
            'WC: ${modifiedWc.round()}  WW: ${modifiedWw.round()}',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Explicit preset recreates widget with new WC/WW (generation increment)',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'PRESET^TEST',
          modality: 'CT',
          windowCenter: 40.0,
          windowWidth: 400.0,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        double trackedWc = 40.0;
        double trackedWw = 400.0;
        int generation = 0;

        Widget buildWidget() => MaterialApp(
          home: Scaffold(
            body: DicomImageWidget(
              key: ValueKey('test-$generation'),
              dataset: dataset,
              enableZoom: true,
              tool: DicomTool.windowing,
              initialWindowCenter: trackedWc,
              initialWindowWidth: trackedWw,
              onWindowChanged: (c, w) {
                trackedWc = c;
                trackedWw = w;
              },
            ),
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        // Confirm initial overlay.
        expect(find.textContaining('WC: 40  WW: 400'), findsOneWidget);

        // Simulate applying the Brain preset (WC=40, WW=80 — different WW).
        // In the example app this sets _activeWc/_activeWw and increments
        // _presetGeneration, which changes the key and recreates the widget.
        trackedWc = 40.0;
        trackedWw = 80.0;
        generation++; // preset increment
        await tester.pumpWidget(buildWidget());
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(find.textContaining('WC: 40  WW: 80'), findsOneWidget);

        // Simulate applying the Lung preset.
        trackedWc = -600.0;
        trackedWw = 1500.0;
        generation++;
        await tester.pumpWidget(buildWidget());
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(find.textContaining('WC: -600  WW: 1500'), findsOneWidget);
      },
    );

    testWidgets(
      'Double-tap reset after drag returns to initialWindowCenter/Width, '
      'not to the dragged values',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'RESET^TEST',
          modality: 'CT',
          windowCenter: 40.0,
          windowWidth: 400.0,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                enableZoom: true,
                tool: DicomTool.windowing,
                initialWindowCenter: 40.0,
                initialWindowWidth: 400.0,
              ),
            ),
          ),
        );

        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        // Drag to modify WC/WW away from initial values.
        final gestureFinder = find.byKey(const Key('dicom_windowing_gesture'));
        await tester.drag(gestureFinder, const Offset(200, -100));
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        // Confirm WC/WW have changed from initial values.
        expect(find.textContaining('WC: 40  WW: 400'), findsNothing);

        // Double-tap triggers resetWindowing().
        await tester.tap(gestureFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(gestureFinder);
        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();

        // Should have returned to the initialWindowCenter/Width values.
        expect(find.textContaining('WC: 40  WW: 400'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching tool to DicomTool.windowing uses Transform without center alignment '
      'so matrix coordinate origin matches InteractiveViewer',
      (WidgetTester tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'ALIGN^TEST',
          modality: 'CT',
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                enableZoom: true,
                tool: DicomTool.windowing,
              ),
            ),
          ),
        );

        await tester.runAsync(
          () async => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        // Verify Transform widget exists and has null alignment (default top-left origin)
        final transformFinder = find.byType(Transform);
        expect(transformFinder, findsWidgets);

        // Find the Transform widget that holds the image content
        final transforms = tester.widgetList<Transform>(transformFinder);
        final imageTransform = transforms.firstWhere(
          (t) => t.alignment == null,
        );
        expect(imageTransform.alignment, isNull);

        // Verify ClipRect wraps the Transform to prevent overflow out of bounds
        final clipRectFinder = find.ancestor(
          of: find.byWidget(imageTransform),
          matching: find.byType(ClipRect),
        );
        expect(clipRectFinder, findsOneWidget);
      },
    );
  });
}
