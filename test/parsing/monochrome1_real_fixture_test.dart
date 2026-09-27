import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
import 'package:dicom_viewer/src/geometry/dicom_probe_painter.dart';
import 'package:dicom_viewer/src/geometry/dicom_roi_statistics_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

int computeAdler32(Uint8List bytes) {
  var a = 1;
  var b = 0;
  const mod = 65521;
  for (var i = 0; i < bytes.length; i++) {
    a = (a + bytes[i]) % mod;
    b = (b + a) % mod;
  }
  return (b << 16) | a;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real MONOCHROME1 Fixture Validation (CR1_6154.dcm)', () {
    late File file;
    late Uint8List fileBytes;
    late DicomDataset dataset;

    setUpAll(() async {
      file = File('test/fixtures/uncompressed/CR1_6154.dcm');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'CR1_6154.dcm fixture must exist in test/fixtures/uncompressed/',
      );
      fileBytes = await file.readAsBytes();
      dataset = DicomDataset.fromBytes(fileBytes);
    });

    test('1. Metadata & Structure Verification (Group A)', () {
      // Transfer Syntax: Explicit VR Little Endian (1.2.840.10008.1.2.1)
      expect(
        dataset.transferSyntaxUid,
        equals(TransferSyntax.explicitVRLittleEndian),
      );
      expect(dataset.transferSyntaxUid, equals('1.2.840.10008.1.2.1'));

      // Modality & Identification
      expect(dataset.modality, equals('CR'));
      expect(
        dataset.getString(DicomTag.sopClassUid),
        equals(
          '1.2.840.10008.5.1.4.1.1.1',
        ), // Computed Radiography Image Storage
      );

      // Photometric and Samples Attributes
      expect(dataset.samplesPerPixel, equals(1));
      expect(dataset.photometricInterpretation, equals('MONOCHROME1'));
      expect(dataset.planarConfiguration, equals(0));

      // Image Dimensions & Framing
      expect(dataset.rows, equals(16));
      expect(dataset.columns, equals(16));
      expect(dataset.numberOfFrames, equals(1));

      // Bit Depth & Representation
      expect(dataset.bitsAllocated, equals(16));
      expect(dataset.bitsStored, equals(12));
      expect(dataset.highBit, equals(11));
      expect(dataset.pixelRepresentation, equals(0));
      expect(dataset.isSigned, isFalse);

      // VOI Window & Rescale Parameters
      expect(dataset.windowCenter, equals(1600.0));
      expect(dataset.windowWidth, equals(2800.0));
      expect(dataset.rescaleIntercept, equals(200.0));
      expect(dataset.rescaleSlope, equals(0.684));

      // Pixel Data Element Size
      final pixelElem = dataset.getElement(DicomTag.pixelData);
      expect(pixelElem, isNotNull);
      expect(pixelElem!.valueBytes.length, equals(512));
    });

    test('2. Pixel Extraction & Payload Verification (Group B)', () {
      final effectiveBytes = CodecRegistry.extractEffectivePixelBytes(dataset);
      expect(effectiveBytes.length, equals(512));

      // Verify checksum of raw pixel data
      final rawAdler = computeAdler32(effectiveBytes);
      expect(rawAdler, equals(0xb2df822f));

      // Decode into 16-bit integer samples
      final info = PixelDataInfo.fromDataset(dataset);
      const decoder = PixelDataDecoder();
      final rawPixels = decoder.decode(effectiveBytes, info);

      expect(rawPixels.length, equals(256));
      expect(rawPixels.reduce((a, b) => a < b ? a : b), equals(1994));
      expect(rawPixels.reduce((a, b) => a > b ? a : b), equals(2802));
      expect(
        rawPixels.take(5).toList(),
        equals([1994, 2031, 2106, 2083, 2225]),
      );
    });

    test('3. MONOCHROME1 Polarity Inversion & Windowing (Group C)', () {
      final effectiveBytes = CodecRegistry.extractEffectivePixelBytes(dataset);
      final info = PixelDataInfo.fromDataset(dataset);
      const decoder = PixelDataDecoder();
      final rawPixels = decoder.decode(effectiveBytes, info);

      final rgba = DicomRenderer.renderToRgba(dataset);
      expect(rgba.length, equals(16 * 16 * 4));

      // In MONOCHROME1, lower raw values represent brighter pixels (closer to 255)
      // and higher raw values represent darker pixels (closer to 0).
      final minIdx = rawPixels.indexOf(1994);
      final maxIdx = rawPixels.indexOf(2802);
      final minIntensity = rgba[minIdx * 4];
      final maxIntensity = rgba[maxIdx * 4];

      expect(minIntensity, equals(131));
      expect(maxIntensity, equals(80));
      expect(
        minIntensity > maxIntensity,
        isTrue,
        reason:
            'MONOCHROME1 requires lower stored pixel values to render brighter than higher values',
      );
    });

    test('4. RGBA Rendering & ui.Image Generation (Group D)', () async {
      final rgba = DicomRenderer.renderToRgba(dataset);

      // Verify all pixels are grayscale (R == G == B) and alpha is opaque (255)
      for (var i = 0; i < 256; i++) {
        final offset = i * 4;
        final r = rgba[offset];
        final g = rgba[offset + 1];
        final b = rgba[offset + 2];
        final a = rgba[offset + 3];

        expect(g, equals(r), reason: 'Pixel $i green channel must match red');
        expect(b, equals(r), reason: 'Pixel $i blue channel must match red');
        expect(a, equals(255), reason: 'Pixel $i alpha must be 255');
      }

      // Verify first 5 display intensities against reference calculation
      final first5 = [rgba[0], rgba[4], rgba[8], rgba[12], rgba[16]];
      expect(first5, equals([131, 128, 124, 125, 116]));

      // Verify ui.Image rasterization
      final image = await DicomRenderer.renderToImage(dataset);
      expect(image.width, equals(16));
      expect(image.height, equals(16));
    });

    test('5. Quantitative ROI Statistics on Real MONOCHROME1 (Group E)', () {
      final stats = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: const Rect.fromLTWH(0, 0, 16, 16),
        frameIndex: 0,
      );

      expect(stats.pixelCount, equals(256));
      expect(stats.validPixelCount, equals(256));
      expect(stats.excludedPaddingCount, equals(0));
      expect(stats.hasValidPixels, isTrue);

      // Stored min (1994) * 0.684 + 200 = 1563.896
      expect((stats.min - 1563.896).abs() < 0.001, isTrue);
      // Stored max (2802) * 0.684 + 200 = 2116.568
      expect((stats.max - 2116.568).abs() < 0.001, isTrue);
      // Mean rescaled value
      expect((stats.mean - 1926.2744).abs() < 0.001, isTrue);

      // CR modality does not use HU unit
      expect(stats.unit, equals(''));
    });

    test('6. Pixel Probe Examination on Real MONOCHROME1 (Group F)', () {
      final effectiveBytes = CodecRegistry.extractEffectivePixelBytes(dataset);
      final info = PixelDataInfo.fromDataset(dataset);
      const decoder = PixelDataDecoder();
      final rawPixels = decoder.decode(effectiveBytes, info);

      final probe0 = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 0,
        pixelRow: 0,
        rawPixels: rawPixels,
      );

      expect(probe0.isInside, isTrue);
      expect(probe0.pixelColumn, equals(0));
      expect(probe0.pixelRow, equals(0));
      expect(probe0.storedValue, equals(1994));
      expect((probe0.rescaledValue! - 1563.896).abs() < 0.001, isTrue);
      expect(probe0.isHounsfield, isFalse);
      expect(probe0.unit, equals(''));
      expect(probe0.formattedLines, contains('Pixel: (0, 0)'));
      expect(probe0.formattedLines, contains('Stored: 1994'));
    });
  });
}
