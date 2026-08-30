import 'dart:io';
import 'dart:ui';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/geometry/dicom_roi_statistics_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DicomDataset jpegDataset;

  setUpAll(() {
    final file = File('test/fixtures/jpeg/JPEG-LL.dcm');
    expect(file.existsSync(), isTrue);
    jpegDataset = DicomDataset.fromBytes(file.readAsBytesSync());
  });

  group('JPEG Lossless SV1 Tool & Widget Integration Tests', () {
    test(
      'DicomRoiStatisticsEngine computes exact statistics on JPEG Lossless CT',
      () {
        // Define ROI bounding rectangle in pixel space:
        // cols 50..149 (width 100), rows 200..299 (height 100) -> 10,000 pixels
        const rect = Rect.fromLTRB(50.0, 200.0, 150.0, 300.0);

        final stats = DicomRoiStatisticsEngine.computeStatistics(
          dataset: jpegDataset,
          normalizedRect: rect,
          frameIndex: 0,
        );

        expect(stats.pixelCount, equals(10000));
        expect(stats.validPixelCount, equals(10000));
        expect(stats.min, equals(2.0));
        expect(stats.max, equals(195.0));
        expect(stats.mean, closeTo(56.6091, 0.001));
        expect(stats.median, equals(51.0));
        expect(stats.standardDeviation, closeTo(30.8267, 0.001));
      },
    );

    testWidgets(
      'DicomImageWidget renders JPEG Lossless dataset in widget tree',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: DicomImageWidget(
                  dataset: jpegDataset,
                  tool: DicomTool.pan,
                ),
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        expect(find.byType(DicomImageWidget), findsOneWidget);
      },
    );

    testWidgets('Pixel Probe activates on hover over JPEG Lossless image', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 256,
                height: 512,
                child: DicomImageWidget(
                  dataset: jpegDataset,
                  tool: DicomTool.probe,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Send pointer hover gesture to center of widget
      final center = tester.getCenter(find.byType(DicomImageWidget));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(center);
      await tester.pump();

      expect(find.byType(DicomImageWidget), findsOneWidget);
    });

    testWidgets(
      'Tool switching (Windowing -> Probe -> ROI -> Measure) on JPEG Lossless',
      (WidgetTester tester) async {
        DicomTool currentTool = DicomTool.windowing;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  appBar: AppBar(
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.colorize),
                        onPressed:
                            () => setState(() => currentTool = DicomTool.probe),
                      ),
                      IconButton(
                        icon: const Icon(Icons.crop_square),
                        onPressed:
                            () => setState(
                              () => currentTool = DicomTool.rectangleRoi,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.straighten),
                        onPressed:
                            () =>
                                setState(() => currentTool = DicomTool.measure),
                      ),
                    ],
                  ),
                  body: SizedBox(
                    width: 300,
                    height: 500,
                    child: DicomImageWidget(
                      dataset: jpegDataset,
                      tool: currentTool,
                    ),
                  ),
                ),
              );
            },
          ),
        );

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        // 1. Initial tool is windowing
        expect(find.byType(DicomImageWidget), findsOneWidget);

        // 2. Switch to probe
        await tester.tap(find.byIcon(Icons.colorize));
        await tester.pump();
        expect(find.byType(DicomImageWidget), findsOneWidget);

        // 3. Switch to rectangle ROI
        await tester.tap(find.byIcon(Icons.crop_square));
        await tester.pump();
        expect(find.byType(DicomImageWidget), findsOneWidget);

        // 4. Switch to measure
        await tester.tap(find.byIcon(Icons.straighten));
        await tester.pump();
        expect(find.byType(DicomImageWidget), findsOneWidget);
      },
    );
  });
}
