import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
import 'package:flutter/material.dart';
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

  group('Real PlanarConfiguration=1 Fixture Validation (color-pl.dcm)', () {
    late File file;
    late Uint8List fileBytes;
    late DicomDataset dataset;

    setUpAll(() async {
      file = File('test/fixtures/uncompressed/color-pl.dcm');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'color-pl.dcm fixture must exist in test/fixtures/uncompressed/',
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
      expect(dataset.getString(DicomTag.modality), equals('US'));
      expect(
        dataset.getString(DicomTag.sopClassUid),
        equals('1.2.840.10008.5.1.4.1.1.6'), // Ultrasound Image Storage
      );
      expect(
        dataset.getString(DicomTag.studyDescription),
        equals('Echocardiogram'),
      );
      expect(
        dataset.getString(DicomTag.seriesDescription),
        equals('Transesophageal Echocardiogram'),
      );

      // Color and Sample Attributes
      expect(dataset.samplesPerPixel, equals(3));
      expect(dataset.photometricInterpretation, equals('RGB'));
      expect(dataset.planarConfiguration, equals(1));

      // Image Dimensions & Framing
      expect(dataset.rows, equals(120));
      expect(dataset.columns, equals(256));
      expect(dataset.numberOfFrames, equals(1));

      // Bit Depth & Pixel Representation
      expect(dataset.bitsAllocated, equals(8));
      expect(dataset.bitsStored, equals(8));
      expect(dataset.highBit, equals(7));
      expect(dataset.pixelRepresentation, equals(0));
    });

    test('2. Raw Pixel Data Extraction (Group B)', () {
      final rawBytes = CodecRegistry.extractEffectivePixelBytes(
        dataset,
        frameIndex: 0,
      );

      const expectedLength = 120 * 256 * 3; // 92,160 bytes
      expect(rawBytes.length, equals(expectedLength));

      // Verify dataset.pixelDataBytes matches extracted frame bytes
      expect(dataset.pixelDataBytes, isNotNull);
      expect(dataset.pixelDataBytes!.length, equals(expectedLength));

      // Independent oracle checksum verification of raw planar byte stream
      expect(computeAdler32(rawBytes), equals(0xa83e01e5));
    });

    test('3. Physical Planar Layout Verification (Group C)', () {
      final raw = CodecRegistry.extractEffectivePixelBytes(
        dataset,
        frameIndex: 0,
      );

      const pixelsPerPlane = 120 * 256; // 30,720 pixels
      const bytesPerPlane = pixelsPerPlane * 1; // 30,720 bytes for 8-bit

      // PlanarConfiguration = 1 defines contiguous sample planes:
      // Red:   [0 .. 30,719]
      // Green: [30,720 .. 61,439]
      // Blue:  [61,440 .. 92,159]
      final redPlane = raw.sublist(0, bytesPerPlane);
      final greenPlane = raw.sublist(bytesPerPlane, 2 * bytesPerPlane);
      final bluePlane = raw.sublist(2 * bytesPerPlane, 3 * bytesPerPlane);

      expect(redPlane.length, equals(30720));
      expect(greenPlane.length, equals(30720));
      expect(bluePlane.length, equals(30720));

      // Representative pixel (0, 0): index 0
      expect(redPlane[0], equals(40));
      expect(greenPlane[0], equals(40));
      expect(bluePlane[0], equals(40));

      // Representative pixel (128, 60) [center Doppler flow marker]:
      // 1D pixel index = 60 * 256 + 128 = 15,488
      const centerPixelIdx = 60 * 256 + 128;
      expect(redPlane[centerPixelIdx], equals(184));
      expect(greenPlane[centerPixelIdx], equals(16));
      expect(bluePlane[centerPixelIdx], equals(16));

      // Representative pixel (255, 119) [last pixel]:
      // 1D pixel index = 119 * 256 + 255 = 30,719
      const lastPixelIdx = 119 * 256 + 255;
      expect(redPlane[lastPixelIdx], equals(40));
      expect(greenPlane[lastPixelIdx], equals(40));
      expect(bluePlane[lastPixelIdx], equals(40));
    });

    test('4. End-to-End RGBA Color Conversion & Correctness (Group D & E)', () {
      final raw = CodecRegistry.extractEffectivePixelBytes(
        dataset,
        frameIndex: 0,
      );
      final rgba = DicomRenderer.renderToRgba(dataset);

      const pixelCount = 120 * 256;
      expect(rgba.length, equals(pixelCount * 4)); // 122,880 bytes

      // Verify every RGBA pixel matches planar sample mapping:
      // R = raw[i], G = raw[pixelCount + i], B = raw[2 * pixelCount + i], A = 255
      int differingBytes = 0;
      int maxDiff = 0;
      for (int i = 0; i < pixelCount; i++) {
        final expectedR = raw[i];
        final expectedG = raw[pixelCount + i];
        final expectedB = raw[2 * pixelCount + i];

        final actualR = rgba[i * 4];
        final actualG = rgba[i * 4 + 1];
        final actualB = rgba[i * 4 + 2];
        final actualA = rgba[i * 4 + 3];

        if (actualR != expectedR) {
          differingBytes++;
          final d = (actualR - expectedR).abs();
          if (d > maxDiff) maxDiff = d;
        }
        if (actualG != expectedG) {
          differingBytes++;
          final d = (actualG - expectedG).abs();
          if (d > maxDiff) maxDiff = d;
        }
        if (actualB != expectedB) {
          differingBytes++;
          final d = (actualB - expectedB).abs();
          if (d > maxDiff) maxDiff = d;
        }
        if (actualA != 255) {
          differingBytes++;
        }
      }

      expect(differingBytes, equals(0));
      expect(maxDiff, equals(0));

      // Specific representative pixel checks on rendered RGBA:
      // Pixel (0, 0): (40, 40, 40, 255)
      expect(rgba[0], equals(40));
      expect(rgba[1], equals(40));
      expect(rgba[2], equals(40));
      expect(rgba[3], equals(255));

      // Pixel (128, 60): (184, 16, 16, 255)
      const centerRgbaOffset = (60 * 256 + 128) * 4;
      expect(rgba[centerRgbaOffset], equals(184));
      expect(rgba[centerRgbaOffset + 1], equals(16));
      expect(rgba[centerRgbaOffset + 2], equals(16));
      expect(rgba[centerRgbaOffset + 3], equals(255));

      // Pixel (255, 119): (40, 40, 40, 255)
      const lastRgbaOffset = (119 * 256 + 255) * 4;
      expect(rgba[lastRgbaOffset], equals(40));
      expect(rgba[lastRgbaOffset + 1], equals(40));
      expect(rgba[lastRgbaOffset + 2], equals(40));
      expect(rgba[lastRgbaOffset + 3], equals(255));

      // Independent oracle checksum verification of full rendered RGBA buffer
      expect(computeAdler32(rgba), equals(0x053f90de));
    });

    test('5. Image Rasterization (DicomRenderer.renderToImage)', () async {
      final image = await DicomRenderer.renderToImage(dataset);
      expect(image.width, equals(256));
      expect(image.height, equals(120));
    });

    testWidgets('6. Widget Tree Rendering Integration (DicomImageWidget)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 256,
                height: 120,
                child: DicomImageWidget(dataset: dataset),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byType(DicomImageWidget), findsOneWidget);
      expect(find.byType(RawImage), findsOneWidget);

      final rawImage = tester.widget<RawImage>(find.byType(RawImage));
      expect(rawImage.image, isNotNull);
      expect(rawImage.image!.width, equals(256));
      expect(rawImage.image!.height, equals(120));
    });
  });
}
