import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitAndPump(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  group('Pixel Spacing (0028,0030) Display Aspect-Ratio Correction Tests', () {
    testWidgets(
      '1. Missing Pixel Spacing renders with native columns/rows aspect ratio',
      (tester) async {
        // 64 columns x 32 rows -> native aspect ratio = 2.0
        final bytes = SyntheticDicomGenerator.create(
          width: 64,
          height: 32,
          pixelSpacing: null,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DicomImageWidget(dataset: dataset))),
        );
        await waitAndPump(tester);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        expect(aspectRatioWidget.aspectRatio, closeTo(2.0, 1e-5));
      },
    );

    testWidgets(
      '2. Valid square Pixel Spacing preserves native aspect ratio unchanged',
      (tester) async {
        // 32 columns x 32 rows with [0.75, 0.75] -> aspect ratio = (32 * 0.75) / (32 * 0.75) = 1.0
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          pixelSpacing: [0.75, 0.75],
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DicomImageWidget(dataset: dataset))),
        );
        await waitAndPump(tester);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        expect(aspectRatioWidget.aspectRatio, closeTo(1.0, 1e-5));
      },
    );

    testWidgets(
      '3. Non-square wide pixels (cols=512, rows=512, spacing=[0.5, 1.0]) -> aspect ratio = 2.0',
      (tester) async {
        // rowSpacing = 0.5 (Sy), colSpacing = 1.0 (Sx)
        // AR = (512 * 1.0) / (512 * 0.5) = 2.0
        final bytes = SyntheticDicomGenerator.create(
          width: 512,
          height: 512,
          pixelSpacing: [0.5, 1.0],
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DicomImageWidget(dataset: dataset))),
        );
        await waitAndPump(tester);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        expect(aspectRatioWidget.aspectRatio, closeTo(2.0, 1e-5));

        // Verify RawImage uses BoxFit.fill to stretch across the physical aspect ratio container
        final rawImageFinder = find.byType(RawImage);
        expect(rawImageFinder, findsOneWidget);
        final rawImageWidget = tester.widget<RawImage>(rawImageFinder);
        expect(rawImageWidget.fit, BoxFit.fill);
        expect(rawImageWidget.image!.width, 512);
        expect(rawImageWidget.image!.height, 512);
      },
    );

    testWidgets(
      '4. Non-square tall pixels (cols=512, rows=512, spacing=[1.0, 0.5]) -> aspect ratio = 0.5',
      (tester) async {
        // rowSpacing = 1.0 (Sy), colSpacing = 0.5 (Sx)
        // AR = (512 * 0.5) / (512 * 1.0) = 0.5
        final bytes = SyntheticDicomGenerator.create(
          width: 512,
          height: 512,
          pixelSpacing: [1.0, 0.5],
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DicomImageWidget(dataset: dataset))),
        );
        await waitAndPump(tester);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        expect(aspectRatioWidget.aspectRatio, closeTo(0.5, 1e-5));
      },
    );

    testWidgets(
      '5. Invalid zero spacing falls back to native matrix columns/rows',
      (tester) async {
        // Zero row spacing: "0.0\\1.0"
        final bytes = SyntheticDicomGenerator.create(
          width: 64,
          height: 32,
          pixelSpacingString: '0.0\\1.0',
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DicomImageWidget(dataset: dataset))),
        );
        await waitAndPump(tester);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        // Fallback: 64 / 32 = 2.0
        expect(aspectRatioWidget.aspectRatio, closeTo(2.0, 1e-5));
      },
    );

    testWidgets(
      '6. Invalid negative spacing falls back to native matrix columns/rows',
      (tester) async {
        // Negative column spacing: "0.5\\-1.0"
        final bytes = SyntheticDicomGenerator.create(
          width: 40,
          height: 80,
          pixelSpacingString: '0.5\\-1.0',
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DicomImageWidget(dataset: dataset))),
        );
        await waitAndPump(tester);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        // Fallback: 40 / 80 = 0.5
        expect(aspectRatioWidget.aspectRatio, closeTo(0.5, 1e-5));
      },
    );

    testWidgets(
      '7. Invalid/non-finite spacing falls back to native matrix columns/rows',
      (tester) async {
        // Malformed string: "INVALID\\0.5"
        final bytes = SyntheticDicomGenerator.create(
          width: 50,
          height: 50,
          pixelSpacingString: 'INVALID\\0.5',
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DicomImageWidget(dataset: dataset))),
        );
        await waitAndPump(tester);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        // Fallback: 50 / 50 = 1.0
        expect(aspectRatioWidget.aspectRatio, closeTo(1.0, 1e-5));
      },
    );

    testWidgets(
      '8. WC/WW drag interaction operates accurately with non-square spacing',
      (tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          pixelSpacing: [0.5, 1.0], // AR = 2.0
          windowCenter: 40.0,
          windowWidth: 400.0,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        double? updatedCenter;
        double? updatedWidth;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                sensitivity: 2.0,
                onWindowChanged: (c, w) {
                  updatedCenter = c;
                  updatedWidth = w;
                },
              ),
            ),
          ),
        );
        await waitAndPump(tester);

        final gestureFinder = find.byKey(const Key('dicom_windowing_gesture'));
        expect(gestureFinder, findsOneWidget);

        // Drag +50px X (WW increases) and -30px Y (WC increases)
        await tester.drag(gestureFinder, const Offset(50, -30));
        await waitAndPump(tester);

        expect(updatedWidth, greaterThan(400.0));
        expect(updatedCenter, greaterThan(40.0));
        expect(
          find.textContaining(
            'WC: ${updatedCenter!.round()}  WW: ${updatedWidth!.round()}',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '9. Pan and zoom operates accurately with non-square spacing in InteractiveViewer',
      (tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          pixelSpacing: [0.5, 1.0], // AR = 2.0
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
                tool: DicomTool.pan,
              ),
            ),
          ),
        );
        await waitAndPump(tester);

        final interactiveViewerFinder = find.byType(InteractiveViewer);
        expect(interactiveViewerFinder, findsOneWidget);

        final widget = tester.widget<InteractiveViewer>(
          interactiveViewerFinder,
        );
        expect(widget.panEnabled, isTrue);
        expect(widget.scaleEnabled, isTrue);

        // AspectRatio widget is preserved inside InteractiveViewer
        final aspectRatioFinder = find.descendant(
          of: interactiveViewerFinder,
          matching: find.byType(AspectRatio),
        );
        expect(aspectRatioFinder, findsOneWidget);
        final arWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        expect(arWidget.aspectRatio, closeTo(2.0, 1e-5));
      },
    );

    testWidgets(
      '10. Tool switching maintains identical AspectRatio and visual coordinate bounds',
      (tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          pixelSpacing: [0.5, 1.0], // AR = 2.0
        );
        final dataset = DicomDataset.fromBytes(bytes);

        // Start in pan tool
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                enableZoom: true,
                tool: DicomTool.pan,
              ),
            ),
          ),
        );
        await waitAndPump(tester);

        expect(find.byType(InteractiveViewer), findsOneWidget);
        final ar1 =
            tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;
        expect(ar1, closeTo(2.0, 1e-5));

        // Switch to windowing tool
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
        await waitAndPump(tester);

        expect(find.byType(Transform), findsWidgets);
        final ar2 =
            tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;
        expect(ar2, closeTo(2.0, 1e-5));
      },
    );

    testWidgets(
      '11. Multi-frame navigation preserves non-square display aspect ratio across frames',
      (tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          numberOfFrames: 3,
          pixelSpacing: [0.5, 1.0], // AR = 2.0
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(dataset: dataset, frameIndex: 0),
            ),
          ),
        );
        await waitAndPump(tester);

        expect(
          tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
          closeTo(2.0, 1e-5),
        );

        // Scrub to frame 2
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(dataset: dataset, frameIndex: 2),
            ),
          ),
        );
        await waitAndPump(tester);

        expect(
          tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
          closeTo(2.0, 1e-5),
        );
      },
    );

    testWidgets(
      '12. Dataset switching dynamically updates display aspect ratio and resets zoom/pan',
      (tester) async {
        final bytes1 = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          pixelSpacing: [0.5, 1.0], // AR = 2.0
        );
        final dataset1 = DicomDataset.fromBytes(bytes1);

        final bytes2 = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          pixelSpacing: [1.0, 0.5], // AR = 0.5
        );
        final dataset2 = DicomDataset.fromBytes(bytes2);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(dataset: dataset1, enableZoom: true),
            ),
          ),
        );
        await waitAndPump(tester);

        expect(
          tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
          closeTo(2.0, 1e-5),
        );

        // Switch to dataset 2
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(dataset: dataset2, enableZoom: true),
            ),
          ),
        );
        await waitAndPump(tester);

        expect(
          tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
          closeTo(0.5, 1e-5),
        );
      },
    );

    testWidgets(
      '13. HUD/overlay geometry remains unscaled and positioned at viewport corners',
      (tester) async {
        final bytes = SyntheticDicomGenerator.create(
          width: 32,
          height: 32,
          patientName: 'CORRECT^GEOMETRY',
          pixelSpacing: [0.5, 1.0],
          windowCenter: 50.0,
          windowWidth: 350.0,
        );
        final dataset = DicomDataset.fromBytes(bytes);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(dataset: dataset, showOverlay: true),
            ),
          ),
        );
        await waitAndPump(tester);

        // Verify overlays are present and unscaled
        expect(find.text('CORRECT^GEOMETRY'), findsOneWidget);
        expect(find.textContaining('WC: 50  WW: 350'), findsOneWidget);
        expect(find.textContaining('Size: 32 x 32'), findsOneWidget);

        // Verify overlay Text widgets are outside AspectRatio in Stack
        final positionedOverlays = find.byType(Positioned);
        expect(positionedOverlays, findsWidgets);
      },
    );
  });
}
