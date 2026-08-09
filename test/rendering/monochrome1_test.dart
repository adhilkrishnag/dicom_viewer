import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MONOCHROME1 Photometric Interpretation Tests', () {
    test(
      'MONOCHROME1 pixel values are strictly inverted relative to MONOCHROME2',
      () {
        // Generate byte-accurate synthetic MONOCHROME2 DICOM dataset
        final mono2Bytes = SyntheticDicomGenerator.create(
          width: 16,
          height: 16,
          photometricInterpretation: 'MONOCHROME2',
          windowCenter: 2048,
          windowWidth: 4096,
        );

        // Generate byte-accurate synthetic MONOCHROME1 DICOM dataset with identical pixels
        final mono1Bytes = SyntheticDicomGenerator.create(
          width: 16,
          height: 16,
          photometricInterpretation: 'MONOCHROME1',
          windowCenter: 2048,
          windowWidth: 4096,
        );

        final mono2Dataset = DicomDataset.fromBytes(mono2Bytes);
        final mono1Dataset = DicomDataset.fromBytes(mono1Bytes);

        expect(mono2Dataset.photometricInterpretation, 'MONOCHROME2');
        expect(mono1Dataset.photometricInterpretation, 'MONOCHROME1');

        final mono2Rgba = DicomRenderer.renderToRgba(mono2Dataset);
        final mono1Rgba = DicomRenderer.renderToRgba(mono1Dataset);

        expect(mono2Rgba.length, mono1Rgba.length);
        expect(mono2Rgba.length, 16 * 16 * 4);

        // Verify each pixel (R channel) is strictly inverted: mono1[i] == 255 - mono2[i]
        for (int i = 0; i < 16 * 16; i++) {
          final mono2Intensity = mono2Rgba[i * 4];
          final mono1Intensity = mono1Rgba[i * 4];
          expect(
            mono1Intensity,
            equals(255 - mono2Intensity),
            reason:
                'Pixel $i in MONOCHROME1 should be exactly 255 - MONOCHROME2 intensity',
          );
        }
      },
    );

    test('Renders MONOCHROME1 to ui.Image without throwing', () async {
      final mono1Bytes = SyntheticDicomGenerator.create(
        width: 16,
        height: 16,
        photometricInterpretation: 'MONOCHROME1',
      );
      final dataset = DicomDataset.fromBytes(mono1Bytes);

      final image = await DicomRenderer.renderToImage(dataset);
      expect(image.width, 16);
      expect(image.height, 16);
    });
  });
}
