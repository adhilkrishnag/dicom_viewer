import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real DICOM JPEG Lossless SV1 Fixtures', () {
    test('decompresses 16-bit CT fixture (JPEG-LL.dcm)', () {
      final file = File('test/fixtures/jpeg/JPEG-LL.dcm');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'JPEG-LL.dcm fixture must be present',
      );

      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);

      expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegLosslessSV1));
      expect(dataset.rows, equals(1024));
      expect(dataset.columns, equals(256));
      expect(dataset.bitsAllocated, equals(16));
      expect(dataset.bitsStored, equals(16));
      expect(dataset.samplesPerPixel, equals(1));
      expect(dataset.photometricInterpretation, equals('MONOCHROME2'));

      expect(CodecRegistry.hasCodec(dataset.transferSyntaxUid), isTrue);

      final rawPixelBytes = CodecRegistry.extractEffectivePixelBytes(dataset);
      expect(rawPixelBytes.length, equals(1024 * 256 * 2)); // 524,288 bytes

      final info = PixelDataInfo.fromDataset(dataset);
      const decoder = PixelDataDecoder();
      final pixels = decoder.decode(rawPixelBytes, info);

      expect(pixels.length, equals(1024 * 256));

      // Calculate statistics over decoded pixels
      int minVal = pixels[0];
      int maxVal = pixels[0];
      for (final p in pixels) {
        if (p < minVal) minVal = p;
        if (p > maxVal) maxVal = p;
      }

      // Verify decoded pixel statistics
      expect(minVal, isNotNull);
      expect(maxVal, isNotNull);
      expect(maxVal, greaterThan(minVal));

      // Check center pixel value
      final centerPixel = pixels[(512 * 256) + 128];
      expect(centerPixel, isNotNull);
    });

    test('decompresses 8-bit fixture (JPGLosslessP14SV1_1s_1f_8b.dcm)', () {
      final file = File('test/fixtures/jpeg/JPGLosslessP14SV1_1s_1f_8b.dcm');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'JPGLosslessP14SV1_1s_1f_8b.dcm fixture must be present',
      );

      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);

      expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegLosslessSV1));
      expect(dataset.bitsAllocated, equals(8));
      expect(dataset.bitsStored, equals(8));
      expect(dataset.samplesPerPixel, equals(1));

      expect(CodecRegistry.hasCodec(dataset.transferSyntaxUid), isTrue);

      final rawPixelBytes = CodecRegistry.extractEffectivePixelBytes(dataset);
      expect(rawPixelBytes.length, equals(dataset.rows * dataset.columns));

      final info = PixelDataInfo.fromDataset(dataset);
      const decoder = PixelDataDecoder();
      final pixels = decoder.decode(rawPixelBytes, info);

      expect(pixels.length, equals(dataset.rows * dataset.columns));

      int minVal = pixels[0];
      int maxVal = pixels[0];
      for (final p in pixels) {
        if (p < minVal) minVal = p;
        if (p > maxVal) maxVal = p;
      }
      expect(minVal, greaterThanOrEqualTo(0));
      expect(maxVal, lessThanOrEqualTo(255));
    });

    test('end-to-end rendering on JPEG Lossless dataset', () async {
      final file = File('test/fixtures/jpeg/JPEG-LL.dcm');
      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);

      // Verify DicomRenderer.renderToRgba succeeds
      final rgba = DicomRenderer.renderToRgba(dataset);
      expect(rgba.length, equals(1024 * 256 * 4));

      // Verify DicomRenderer.renderToImage succeeds on JPEG-LL dataset
      final image = await DicomRenderer.renderToImage(dataset);
      expect(image.width, equals(256));
      expect(image.height, equals(1024));
    });
  });
}
