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

        final gestureFinder = find.byType(GestureDetector);
        expect(gestureFinder, findsOneWidget);

        // 1. Horizontal Drag Test (+50px X -> windowWidth should increase by +50 * 2.0 = +100 to 500)
        await tester.drag(gestureFinder, const Offset(50, 0));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        expect(lastWidth, equals(500.0));
        expect(lastCenter, equals(40.0));
        expect(find.textContaining('WC: 40  WW: 500'), findsOneWidget);

        // 2. Vertical Drag Test (-30px Y -> windowCenter should increase by -(-30) * 2.0 = +60 to 100)
        await tester.drag(gestureFinder, const Offset(0, -30));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        expect(lastWidth, equals(500.0));
        expect(lastCenter, equals(100.0));
        expect(find.textContaining('WC: 100  WW: 500'), findsOneWidget);

        // 3. Confirm rendered RawImage's ui.Image handle updated
        final updatedRawImage = tester.widget<RawImage>(rawImageFinder);
        expect(updatedRawImage.image, isNotNull);
        // The newly rendered ui.Image instance is distinct from initial instance
        expect(updatedRawImage.image, isNot(same(initialUiImage)));
      },
    );
  });
}
