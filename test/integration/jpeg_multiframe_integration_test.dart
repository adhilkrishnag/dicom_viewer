import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JPEG Multi-Frame Integration & Navigation Tests', () {
    late File ybrFile;
    late DicomDataset ybrDataset;

    setUpAll(() {
      ybrFile = File('test/fixtures/jpeg/examples_ybr_color.dcm');
      expect(ybrFile.existsSync(), isTrue);
      ybrDataset = DicomDataset.fromBytes(ybrFile.readAsBytesSync());
    });

    test('Asynchronous frame rendering across navigation sequence', () async {
      // Navigate forward: 0 -> 1 -> 14 -> 29
      final img0 = await DicomRenderer.renderToImage(ybrDataset, frameIndex: 0);
      expect(img0.width, equals(320));
      expect(img0.height, equals(240));

      final img1 = await DicomRenderer.renderToImage(ybrDataset, frameIndex: 1);
      expect(img1.width, equals(320));
      expect(img1.height, equals(240));

      final img14 = await DicomRenderer.renderToImage(
        ybrDataset,
        frameIndex: 14,
      );
      expect(img14.width, equals(320));
      expect(img14.height, equals(240));

      final img29 = await DicomRenderer.renderToImage(
        ybrDataset,
        frameIndex: 29,
      );
      expect(img29.width, equals(320));
      expect(img29.height, equals(240));

      // Navigate backward: 29 -> 14 -> 0
      final img14Back = await DicomRenderer.renderToImage(
        ybrDataset,
        frameIndex: 14,
      );
      expect(img14Back.width, equals(320));
      expect(img14Back.height, equals(240));

      final img0Back = await DicomRenderer.renderToImage(
        ybrDataset,
        frameIndex: 0,
      );
      expect(img0Back.width, equals(320));
      expect(img0Back.height, equals(240));
    });

    test(
      'Dataset switching across Multi-Frame JPEG, Multi-Frame RLE, Single-Frame .70, and Native CT',
      () {
        final rleFile = File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm');
        final jpg70File = File('test/fixtures/jpeg/JPEG-LL.dcm');
        final ctFile = File('test/fixtures/CT_small.dcm');

        final rleDataset = DicomDataset.fromBytes(rleFile.readAsBytesSync());
        final jpg70Dataset = DicomDataset.fromBytes(
          jpg70File.readAsBytesSync(),
        );
        final ctDataset = DicomDataset.fromBytes(ctFile.readAsBytesSync());

        // 1. Render Multi-frame JPEG .50 Frame 0
        final rgbaJpg0 = DicomRenderer.renderToRgba(ybrDataset, frameIndex: 0);
        expect(rgbaJpg0.length, equals(240 * 320 * 4));

        // 2. Switch to Multi-frame RLE Frame 1
        final rgbaRle1 = DicomRenderer.renderToRgba(rleDataset, frameIndex: 1);
        expect(rgbaRle1.length, equals(600 * 800 * 4));

        // 3. Switch to Single-frame JPEG Lossless .70
        final rgba70 = DicomRenderer.renderToRgba(jpg70Dataset, frameIndex: 0);
        expect(rgba70.length, equals(1024 * 256 * 4));

        // 4. Switch to Native Uncompressed CT
        final rgbaCt = DicomRenderer.renderToRgba(ctDataset, frameIndex: 0);
        expect(rgbaCt.length, equals(128 * 128 * 4));

        // 5. Switch back to Multi-frame JPEG .50 Frame 0 and verify exact identity
        final rgbaJpg0Back = DicomRenderer.renderToRgba(
          ybrDataset,
          frameIndex: 0,
        );
        expect(rgbaJpg0Back, equals(rgbaJpg0));
      },
    );

    testWidgets(
      'DicomImageWidget lifecycle and frameIndex update with DicomTool',
      (tester) async {
        Future<void> pumpAndRender() async {
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump();
        }

        // Frame 0
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DicomImageWidget(
              dataset: ybrDataset,
              frameIndex: 0,
              tool: DicomTool.pan,
            ),
          ),
        );
        await pumpAndRender();

        // Update to Frame 1
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DicomImageWidget(
              dataset: ybrDataset,
              frameIndex: 1,
              tool: DicomTool.pan,
            ),
          ),
        );
        await pumpAndRender();

        // Update to Frame 14
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DicomImageWidget(
              dataset: ybrDataset,
              frameIndex: 14,
              tool: DicomTool.pan,
            ),
          ),
        );
        await pumpAndRender();
      },
    );
  });
}
