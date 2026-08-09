import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RGB 3-Channel Pixel Data Tests', () {
    test('Parses RGB DICOM tags correctly (samplesPerPixel == 3, RGB)', () {
      final rgbBytes = Uint8List.fromList([
        255, 0, 0, // Red pixel
        0, 255, 0, // Green pixel
        0, 0, 255, // Blue pixel
        255, 255, 255, // White pixel
      ]);

      final dicomBytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        samplesPerPixel: 3,
        photometricInterpretation: 'RGB',
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        customRgbBytes: rgbBytes,
      );

      final dataset = DicomDataset.fromBytes(dicomBytes);
      expect(dataset.samplesPerPixel, 3);
      expect(dataset.photometricInterpretation, 'RGB');
      expect(dataset.rows, 2);
      expect(dataset.columns, 2);
    });

    test(
      'Maps 3-channel RGB pixel data to 4-channel RGBA output buffer accurately',
      () {
        // 2x2 image with distinct colors: Red, Green, Blue, Yellow
        final rgbPixelBytes = Uint8List.fromList([
          255, 0, 0, // Pixel 0: Red
          0, 255, 0, // Pixel 1: Green
          0, 0, 255, // Pixel 2: Blue
          255, 255, 0, // Pixel 3: Yellow
        ]);

        final dicomBytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          samplesPerPixel: 3,
          photometricInterpretation: 'RGB',
          bitsAllocated: 8,
          bitsStored: 8,
          highBit: 7,
          customRgbBytes: rgbPixelBytes,
        );

        final dataset = DicomDataset.fromBytes(dicomBytes);
        final rgbaBuffer = DicomRenderer.renderToRgba(dataset);

        // Output must be 2 * 2 * 4 = 16 bytes
        expect(rgbaBuffer.length, 16);

        // Pixel 0: Red (255, 0, 0, 255)
        expect(rgbaBuffer[0], 255); // R
        expect(rgbaBuffer[1], 0); // G
        expect(rgbaBuffer[2], 0); // B
        expect(rgbaBuffer[3], 255); // A

        // Pixel 1: Green (0, 255, 0, 255)
        expect(rgbaBuffer[4], 0); // R
        expect(rgbaBuffer[5], 255); // G
        expect(rgbaBuffer[6], 0); // B
        expect(rgbaBuffer[7], 255); // A

        // Pixel 2: Blue (0, 0, 255, 255)
        expect(rgbaBuffer[8], 0); // R
        expect(rgbaBuffer[9], 0); // G
        expect(rgbaBuffer[10], 255); // B
        expect(rgbaBuffer[11], 255); // A

        // Pixel 3: Yellow (255, 255, 0, 255)
        expect(rgbaBuffer[12], 255); // R
        expect(rgbaBuffer[13], 255); // G
        expect(rgbaBuffer[14], 0); // B
        expect(rgbaBuffer[15], 255); // A
      },
    );

    test('Renders RGB DICOM to ui.Image without errors', () async {
      final rgbPixelBytes = Uint8List.fromList([255, 128, 64, 10, 20, 30]);

      final dicomBytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 1,
        samplesPerPixel: 3,
        photometricInterpretation: 'RGB',
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        customRgbBytes: rgbPixelBytes,
      );

      final dataset = DicomDataset.fromBytes(dicomBytes);
      final image = await DicomRenderer.renderToImage(dataset);

      expect(image.width, 2);
      expect(image.height, 1);
    });
  });
}
