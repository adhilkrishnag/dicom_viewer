import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JPEG Baseline Color Pipeline Integration & Interoperability Tests', () {
    test(
      'End-to-end DicomRenderer on real RGB Baseline fixture (SC_rgb_dcmtk_+eb+cr.dcm)',
      () async {
        final file = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cr.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.photometricInterpretation, equals('RGB'));
        expect(dataset.rows, equals(100));
        expect(dataset.columns, equals(100));
        expect(dataset.samplesPerPixel, equals(3));

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, equals(100 * 100 * 4));

        // Asynchronous image rendering
        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(100));
        expect(image.height, equals(100));
      },
    );

    test(
      'End-to-end DicomRenderer on real YBR_FULL_422 Baseline fixture (SC_rgb_dcmtk_+eb+cy+s2.dcm)',
      () async {
        final file = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cy+s2.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.photometricInterpretation, equals('YBR_FULL_422'));
        expect(dataset.rows, equals(100));
        expect(dataset.columns, equals(100));
        expect(dataset.samplesPerPixel, equals(3));

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, equals(100 * 100 * 4));

        // First pixel in test pattern is pure red in RGB space
        expect(rgba[0], equals(254)); // R
        expect(rgba[1], equals(0)); // G
        expect(rgba[2], equals(0)); // B
        expect(rgba[3], equals(255)); // A (Opaque)

        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(100));
        expect(image.height, equals(100));
      },
    );

    test(
      'End-to-end DicomRenderer on 3x3 odd dimension YBR_FULL fixture (SC_rgb_small_odd_jpeg.dcm)',
      () async {
        final file = File('test/fixtures/jpeg/SC_rgb_small_odd_jpeg.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.photometricInterpretation, equals('YBR_FULL'));
        expect(dataset.rows, equals(3));
        expect(dataset.columns, equals(3));

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, equals(3 * 3 * 4));

        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(3));
        expect(image.height, equals(3));
      },
    );

    test('ITU-R BT.601 YBR_FULL conversion math and boundary cases', () {
      const info = PixelDataInfo(
        rows: 1,
        columns: 6,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        samplesPerPixel: 3,
        isSigned: false,
        photometricInterpretation: 'YBR_FULL',
        planarConfiguration: 0,
        isLittleEndian: true,
      );

      // Y, Cb, Cr test tuples
      // 1. Black: Y=0, Cb=128, Cr=128 -> R=0, G=0, B=0
      // 2. White: Y=255, Cb=128, Cr=128 -> R=255, G=255, B=255
      // 3. Neutral Gray: Y=128, Cb=128, Cr=128 -> R=128, G=128, B=128
      // 4. Primary Red: Y=76, Cb=85, Cr=255 -> R=254, G=0, B=0
      // 5. Primary Green: Y=150, Cb=44, Cr=21 -> R=0, G=255, B=1
      // 6. Primary Blue: Y=29, Cb=255, Cr=107 -> R=0, G=0, B=254
      final ybrPixels = <int>[
        0, 128, 128, // Black
        255, 128, 128, // White
        128, 128, 128, // Neutral Gray
        76, 85, 255, // Red
        150, 44, 21, // Green
        29, 255, 107, // Blue
      ];

      final rgba = Windowing.processPixelData(ybrPixels, info);
      expect(rgba.length, equals(6 * 4));

      // Black
      expect(rgba[0], equals(0));
      expect(rgba[1], equals(0));
      expect(rgba[2], equals(0));

      // White
      expect(rgba[4], equals(255));
      expect(rgba[5], equals(255));
      expect(rgba[6], equals(255));

      // Neutral Gray
      expect(rgba[8], equals(128));
      expect(rgba[9], equals(128));
      expect(rgba[10], equals(128));

      // Red dominant
      expect(rgba[12], greaterThanOrEqualTo(250));
      expect(rgba[13], lessThanOrEqualTo(2));
      expect(rgba[14], lessThanOrEqualTo(2));

      // Green dominant
      expect(rgba[16], lessThanOrEqualTo(2));
      expect(rgba[17], greaterThanOrEqualTo(250));
      expect(rgba[18], lessThanOrEqualTo(2));

      // Blue dominant
      expect(rgba[20], lessThanOrEqualTo(2));
      expect(rgba[21], lessThanOrEqualTo(2));
      expect(rgba[22], greaterThanOrEqualTo(250));
    });

    test(
      'Dataset switching between Color Baseline, Grayscale Baseline, and Native CT',
      () {
        final ybrFile = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cy+s2.dcm');
        final grayFile = File(
          'test/fixtures/jpeg/synthetic_baseline_grayscale.dcm',
        );
        final ctFile = File('test/fixtures/CT_small.dcm');

        final ybrDataset = DicomDataset.fromBytes(ybrFile.readAsBytesSync());
        final grayDataset = DicomDataset.fromBytes(grayFile.readAsBytesSync());
        final ctDataset = DicomDataset.fromBytes(ctFile.readAsBytesSync());

        // Render YBR Color
        final rgbaYbr1 = DicomRenderer.renderToRgba(ybrDataset);
        expect(rgbaYbr1.length, equals(100 * 100 * 4));
        expect(rgbaYbr1[0], equals(254)); // Pure red pixel

        // Switch to Grayscale Baseline
        final rgbaGray = DicomRenderer.renderToRgba(grayDataset);
        expect(rgbaGray.length, equals(32 * 32 * 4));

        // Switch to Native Uncompressed CT
        final rgbaCt = DicomRenderer.renderToRgba(ctDataset);
        expect(rgbaCt.length, equals(128 * 128 * 4));

        // Switch back to YBR Color
        final rgbaYbr2 = DicomRenderer.renderToRgba(ybrDataset);
        expect(rgbaYbr2, equals(rgbaYbr1));
      },
    );

    test(
      'Windowing adjustments on color datasets do not alter underlying RGB/YBR values',
      () {
        final ybrFile = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cy+s2.dcm');
        final dataset = DicomDataset.fromBytes(ybrFile.readAsBytesSync());

        // Render with default windowing
        final rgba1 = DicomRenderer.renderToRgba(dataset);

        // Render with custom windowCenter and windowWidth
        final rgba2 = DicomRenderer.renderToRgba(
          dataset,
          windowCenter: 50.0,
          windowWidth: 100.0,
        );

        // In DICOM, windowing is clinical for grayscale/HU; color channels remain faithful to their RGB values
        expect(rgba1, equals(rgba2));
      },
    );

    test(
      'End-to-end production rendering on mismatched VR JPEG Baseline fixture (SC_rgb_jpeg.dcm)',
      () async {
        final file = File('test/fixtures/jpeg/SC_rgb_jpeg.dcm');
        expect(file.existsSync(), isTrue);

        // Path: DicomParser -> DicomDataset
        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.rows, equals(256));
        expect(dataset.columns, equals(256));
        expect(dataset.samplesPerPixel, equals(3));
        expect(dataset.photometricInterpretation, equals('RGB'));

        // Path: DicomRenderer -> CodecRegistry -> JPEG Baseline decoder
        // Must NOT throw "DICOM Dataset contains no Pixel Data (7FE0,0010)"
        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, equals(256 * 256 * 4));

        // 3-channel RGB characteristics: opaque alpha channel across pixels
        expect(rgba[3], equals(255)); // Alpha of first pixel
        expect(rgba[256 * 256 * 4 - 1], equals(255)); // Alpha of last pixel

        // Render to ui.Image asynchronously
        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(256));
        expect(image.height, equals(256));
      },
    );
  });
}
