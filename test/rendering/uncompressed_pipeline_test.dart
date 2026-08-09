import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Uncompressed DICOM Rendering Pipeline Tests', () {
    late DicomDataset ctDataset;
    late DicomDataset mrDataset;

    setUpAll(() async {
      final ctFile = File('test/fixtures/CT_small.dcm');
      expect(
        ctFile.existsSync(),
        isTrue,
        reason: 'CT_small.dcm fixture missing',
      );
      final ctBytes = await ctFile.readAsBytes();
      ctDataset = DicomDataset.fromBytes(ctBytes);

      final mrFile = File('test/fixtures/MR_small.dcm');
      expect(
        mrFile.existsSync(),
        isTrue,
        reason: 'MR_small.dcm fixture missing',
      );
      final mrBytes = await mrFile.readAsBytes();
      mrDataset = DicomDataset.fromBytes(mrBytes);
    });

    test(
      'Renders CT_small.dcm (Explicit VR Little Endian) to RGBA buffer correctly',
      () {
        final rgbaBytes = DicomRenderer.renderToRgba(ctDataset);
        expect(rgbaBytes, isNotNull);
        // 128x128 image x 4 channels (RGBA) = 65,536 bytes
        expect(rgbaBytes.length, 128 * 128 * 4);
      },
    );

    test('Renders CT_small.dcm to ui.Image asynchronously', () async {
      final image = await DicomRenderer.renderToImage(ctDataset);
      expect(image, isNotNull);
      expect(image.width, 128);
      expect(image.height, 128);
    });

    test(
      'Renders MR_small.dcm to RGBA buffer and ui.Image correctly',
      () async {
        final rgbaBytes = DicomRenderer.renderToRgba(mrDataset);
        expect(rgbaBytes.length, 64 * 64 * 4);

        final image = await DicomRenderer.renderToImage(mrDataset);
        expect(image.width, 64);
        expect(image.height, 64);
      },
    );

    testWidgets(
      'DicomImageWidget renders CT_small.dcm fixture in Widget tree',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DicomImageWidget(dataset: ctDataset)),
          ),
        );

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        // Verify patient/modality overlay text from CT_small.dcm
        expect(find.textContaining('Modality: CT'), findsOneWidget);
        expect(find.textContaining('Size: 128 x 128'), findsOneWidget);
      },
    );
  });
}
