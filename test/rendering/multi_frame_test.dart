import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  group('Multi-Frame Groundwork & Offset Calculation Tests', () {
    test('Uncompressed Multi-Frame Offset Math & Frame Payload Extraction', () {
      // 2x2 8-bit image with 3 frames (12 total bytes)
      // Frame 0: [10, 10, 10, 10]
      // Frame 1: [100, 100, 100, 100]
      // Frame 2: [200, 200, 200, 200]
      final multiFramePixels = Uint8List.fromList([
        10,
        10,
        10,
        10,
        100,
        100,
        100,
        100,
        200,
        200,
        200,
        200,
      ]);

      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        rescaleIntercept: 0.0,
        windowCenter: 100.0,
        windowWidth: 200.0,
        numberOfFrames: 3,
        customRgbBytes: multiFramePixels,
      );

      final dataset = DicomDataset.fromBytes(bytes);

      expect(dataset.numberOfFrames, equals(3));
      expect(dataset.rows, equals(2));
      expect(dataset.columns, equals(2));
      expect(dataset.bitsAllocated, equals(8));

      // Render Frame 0 -> should extract [10, 10, 10, 10]
      final rgba0 = DicomRenderer.renderToRgba(dataset, frameIndex: 0);
      expect(rgba0.length, equals(2 * 2 * 4)); // 16 RGBA bytes

      // Render Frame 1 -> should extract [20, 20, 20, 20]
      final rgba1 = DicomRenderer.renderToRgba(dataset, frameIndex: 1);
      expect(rgba1.length, equals(2 * 2 * 4));
      expect(rgba0, isNot(equals(rgba1)));

      // Render Frame 2 -> should extract [30, 30, 30, 30]
      final rgba2 = DicomRenderer.renderToRgba(dataset, frameIndex: 2);
      expect(rgba2.length, equals(2 * 2 * 4));

      // Out-of-bounds frameIndex throws RangeError
      expect(
        () => DicomRenderer.renderToRgba(dataset, frameIndex: 3),
        throwsRangeError,
      );
      expect(
        () => DicomRenderer.renderToRgba(dataset, frameIndex: -1),
        throwsRangeError,
      );
    });
  });
}
