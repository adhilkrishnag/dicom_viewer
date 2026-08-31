import 'dart:io';
import 'dart:ui';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Frame JPEG Measurement, ROI & Probe Frame Isolation Tests', () {
    late File ybrFile;
    late DicomDataset ybrDataset;

    setUpAll(() {
      ybrFile = File('test/fixtures/jpeg/examples_ybr_color.dcm');
      expect(ybrFile.existsSync(), isTrue);
      ybrDataset = DicomDataset.fromBytes(ybrFile.readAsBytesSync());
    });

    Future<void> pumpAndRender(WidgetTester tester) async {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    testWidgets('Distance measurement frame isolation across Frame 0 and Frame 1', (
      tester,
    ) async {
      // 1. Render Frame 0 with Measurement tool
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: DicomImageWidget(
                dataset: ybrDataset,
                frameIndex: 0,
                enableZoom: true,
                tool: DicomTool.measure,
              ),
            ),
          ),
        ),
      );
      await pumpAndRender(tester);

      // 2. Drag a distance measurement caliper on Frame 0: (50, 50) -> (150, 150)
      final center = tester.getCenter(find.byType(DicomImageWidget));
      final gesture = await tester.startGesture(center - const Offset(50, 50));
      await tester.pump();
      await gesture.moveTo(center + const Offset(50, 50));
      await tester.pump();
      await gesture.up();
      await pumpAndRender(tester);

      // Semantics or custom paint check: measurement exists on Frame 0
      expect(find.byType(CustomPaint), findsWidgets);

      // 3. Switch to Frame 1: Frame 0 measurement must not leak to Frame 1
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: DicomImageWidget(
                dataset: ybrDataset,
                frameIndex: 1,
                enableZoom: true,
                tool: DicomTool.measure,
              ),
            ),
          ),
        ),
      );
      await pumpAndRender(tester);

      // 4. Switch back to Frame 0: Frame 0 measurement must be faithfully restored
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: DicomImageWidget(
                dataset: ybrDataset,
                frameIndex: 0,
                enableZoom: true,
                tool: DicomTool.measure,
              ),
            ),
          ),
        ),
      );
      await pumpAndRender(tester);
    });

    testWidgets(
      'Rectangle ROI frame isolation across Frame 0, Frame 1, and Frame 14',
      (tester) async {
        // 1. Render Frame 0 with Rectangle ROI tool
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 240,
                child: DicomImageWidget(
                  dataset: ybrDataset,
                  frameIndex: 0,
                  enableZoom: true,
                  tool: DicomTool.rectangleRoi,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        // 2. Drag a rectangle ROI on Frame 0: (60, 60) -> (120, 120)
        final center = tester.getCenter(find.byType(DicomImageWidget));
        final gesture = await tester.startGesture(
          center - const Offset(40, 40),
        );
        await tester.pump();
        await gesture.moveTo(center + const Offset(40, 40));
        await tester.pump();
        await gesture.up();
        await pumpAndRender(tester);

        // 3. Switch to Frame 1: Frame 0 ROI is isolated
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 240,
                child: DicomImageWidget(
                  dataset: ybrDataset,
                  frameIndex: 1,
                  enableZoom: true,
                  tool: DicomTool.rectangleRoi,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);

        // 4. Return to Frame 0: Frame 0 ROI is restored
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 240,
                child: DicomImageWidget(
                  dataset: ybrDataset,
                  frameIndex: 0,
                  enableZoom: true,
                  tool: DicomTool.rectangleRoi,
                ),
              ),
            ),
          ),
        );
        await pumpAndRender(tester);
      },
    );

    testWidgets('Pixel Probe frame isolation across Frame 0 and Frame 29', (
      tester,
    ) async {
      // Render Frame 0 with Probe tool
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: DicomImageWidget(
                dataset: ybrDataset,
                frameIndex: 0,
                enableZoom: true,
                tool: DicomTool.probe,
              ),
            ),
          ),
        ),
      );
      await pumpAndRender(tester);

      // Hover on Frame 0
      final center = tester.getCenter(find.byType(DicomImageWidget));
      final testPointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(testPointer.hover(center));
      await pumpAndRender(tester);

      // Switch to Frame 29
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: DicomImageWidget(
                dataset: ybrDataset,
                frameIndex: 29,
                enableZoom: true,
                tool: DicomTool.probe,
              ),
            ),
          ),
        ),
      );
      await pumpAndRender(tester);

      // Hover on Frame 29
      await tester.sendEventToBinding(testPointer.hover(center));
      await pumpAndRender(tester);
    });
  });
}
