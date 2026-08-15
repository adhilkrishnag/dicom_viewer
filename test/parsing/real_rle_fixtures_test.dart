import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real DICOM RLE Fixture Tests (pydicom MIT License)', () {
    test(
      'Parses and decompresses real OBXXXX1A_rle.dcm RLE fixture (RLE parsing/decompression validation only)',
      () async {
        // Note: OBXXXX1A_rle.dcm is a PALETTE COLOR RLE dataset used for real RLE parsing & decompression validation.
        // It validates encapsulated RLE payload extraction and RLE segment decompression. Full Palette Color LUT mapping is out of scope.
        final file = File('test/fixtures/rle/OBXXXX1A_rle.dcm');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'OBXXXX1A_rle.dcm fixture missing',
        );

        final bytes = await file.readAsBytes();
        final dataset = DicomDataset.fromBytes(bytes);

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.rleLossless));
        expect(dataset.rows, equals(600));
        expect(dataset.columns, equals(800));
        expect(dataset.bitsAllocated, equals(8));
        expect(dataset.samplesPerPixel, equals(1));
        expect(dataset.photometricInterpretation, equals('PALETTE COLOR'));

        // Internal encapsulated data check
        final encData = dataset.encapsulatedData;
        expect(encData, isNotNull);
        expect(encData!.fragments.length, equals(1));

        // Render to RGBA
        final rgbaBytes = DicomRenderer.renderToRgba(dataset);
        expect(rgbaBytes, isNotNull);
        expect(rgbaBytes.length, equals(600 * 800 * 4));

        // Render to ui.Image without errors
        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(800));
        expect(image.height, equals(600));
      },
    );

    test(
      'Parses and renders real 16-bit MONOCHROME2 emri_small_RLE.dcm fixture (Full MONOCHROME2 RLE rendering pipeline validation)',
      () async {
        final file = File('test/fixtures/rle/emri_small_RLE.dcm');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'emri_small_RLE.dcm fixture missing',
        );

        final bytes = await file.readAsBytes();
        final dataset = DicomDataset.fromBytes(bytes);

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.rleLossless));
        expect(dataset.rows, equals(64));
        expect(dataset.columns, equals(64));
        expect(dataset.bitsAllocated, equals(16));

        final encData = dataset.encapsulatedData;
        expect(encData, isNotNull);

        final rgbaBytes = DicomRenderer.renderToRgba(dataset);
        expect(rgbaBytes.length, equals(64 * 64 * 4));

        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(64));
        expect(image.height, equals(64));
      },
    );

    test(
      'Parses and renders real multi-frame OBXXXX1A_rle_2frame.dcm RLE fixture across all frames (Real Multi-Frame RLE validation)',
      () async {
        // Note: OBXXXX1A_rle_2frame.dcm is a 2-frame PALETTE COLOR RLE dataset from pydicom/pydicom-data (MIT License).
        // Validates multi-frame encapsulated RLE parsing, BOT empty rule, fragment-to-frame extraction, and frame-by-frame rendering.
        final file = File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'OBXXXX1A_rle_2frame.dcm fixture missing',
        );

        final bytes = await file.readAsBytes();
        final dataset = DicomDataset.fromBytes(bytes);

        // 1. Metadata Verification
        expect(dataset.transferSyntaxUid, equals(TransferSyntax.rleLossless));
        expect(dataset.numberOfFrames, equals(2));
        expect(dataset.rows, equals(600));
        expect(dataset.columns, equals(800));
        expect(dataset.bitsAllocated, equals(8));
        expect(dataset.samplesPerPixel, equals(1));
        expect(dataset.photometricInterpretation, equals('PALETTE COLOR'));

        // 2. Encapsulated Data Structure Verification
        final encData = dataset.encapsulatedData;
        expect(encData, isNotNull);
        expect(encData!.botOffsets, isEmpty); // Empty BOT
        expect(encData.fragments.length, equals(2)); // 2 fragments = 2 frames

        // 3. Render Frame 0 to RGBA & ui.Image
        final rgbaFrame0 = DicomRenderer.renderToRgba(dataset, frameIndex: 0);
        expect(rgbaFrame0.length, equals(600 * 800 * 4));
        final imageFrame0 = await DicomRenderer.renderToImage(
          dataset,
          frameIndex: 0,
        );
        expect(imageFrame0.width, equals(800));
        expect(imageFrame0.height, equals(600));

        // 4. Render Frame 1 to RGBA & ui.Image
        final rgbaFrame1 = DicomRenderer.renderToRgba(dataset, frameIndex: 1);
        expect(rgbaFrame1.length, equals(600 * 800 * 4));
        final imageFrame1 = await DicomRenderer.renderToImage(
          dataset,
          frameIndex: 1,
        );
        expect(imageFrame1.width, equals(800));
        expect(imageFrame1.height, equals(600));

        // 5. Deterministic Pixel Difference Verification
        var differCount = 0;
        for (var i = 0; i < rgbaFrame0.length; i++) {
          if (rgbaFrame0[i] != rgbaFrame1[i]) {
            differCount++;
          }
        }
        expect(
          differCount,
          greaterThan(0),
          reason:
              'Frame 0 and Frame 1 RGBA outputs must differ for real multi-frame dataset.',
        );
        expect(
          differCount,
          equals(600 * 800 * 3),
          reason:
              'Exactly 1,440,000 RGB sample bytes (100% of RGB channels) differ between Frame 0 and Frame 1.',
        );

        // 6. Out-of-bounds Frame Range Verification
        expect(
          () => DicomRenderer.renderToRgba(dataset, frameIndex: -1),
          throwsRangeError,
        );
        expect(
          () => DicomRenderer.renderToRgba(dataset, frameIndex: 2),
          throwsRangeError,
        );
      },
    );
  });
}
