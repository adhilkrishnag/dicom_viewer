import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
import 'package:dicom_viewer/src/decoders/jpeg_lossless_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JPEG Lossless SV1 Pipeline & Interoperability Integration Tests', () {
    test(
      '16-bit CT (JPEG-LL.dcm) complete pipeline and reference sample equality',
      () async {
        final file = File('test/fixtures/jpeg/JPEG-LL.dcm');
        final rawFile = File('test/fixtures/jpeg/jpeg_ll_expected.raw');
        expect(file.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final bytes = file.readAsBytesSync();
        final expectedBytes = rawFile.readAsBytesSync();
        final dataset = DicomDataset.fromBytes(bytes);

        // 1. Metadata Verification from actual file
        expect(
          dataset.transferSyntaxUid,
          equals(TransferSyntax.jpegLosslessSV1),
        );
        expect(dataset.rows, equals(1024));
        expect(dataset.columns, equals(256));
        expect(dataset.samplesPerPixel, equals(1));
        expect(dataset.bitsAllocated, equals(16));
        expect(dataset.bitsStored, equals(16));
        expect(dataset.highBit, equals(15));
        expect(dataset.pixelRepresentation, equals(1)); // signed
        expect(dataset.photometricInterpretation, equals('MONOCHROME2'));
        expect(dataset.numberOfFrames, equals(1));

        // 2. CodecRegistry & JpegLosslessDecoder extraction
        expect(CodecRegistry.hasCodec(dataset.transferSyntaxUid), isTrue);
        final rawDecodedBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
        );
        expect(rawDecodedBytes.length, equals(1024 * 256 * 2));
        expect(
          rawDecodedBytes,
          equals(expectedBytes),
          reason:
              'Raw decoded byte array must match independent reference oracle bit-for-bit',
        );

        // 3. PixelDataDecoder semantic decoding
        const pixelDecoder = PixelDataDecoder();
        final pixelInfo = PixelDataInfo.fromDataset(dataset);
        final decodedPixels = pixelDecoder.decode(rawDecodedBytes, pixelInfo);
        expect(decodedPixels.length, equals(1024 * 256));

        // 4. Sample-by-sample exact match against reference oracle ByteData
        final refByteData = ByteData.sublistView(expectedBytes);
        int mismatches = 0;
        int minVal = decodedPixels[0];
        int maxVal = decodedPixels[0];
        for (int i = 0; i < decodedPixels.length; i++) {
          final expectedSample = refByteData.getInt16(i * 2, Endian.little);
          if (decodedPixels[i] != expectedSample) {
            mismatches++;
          }
          if (decodedPixels[i] < minVal) minVal = decodedPixels[i];
          if (decodedPixels[i] > maxVal) maxVal = decodedPixels[i];
        }
        expect(mismatches, equals(0));
        expect(minVal, equals(0));
        expect(maxVal, equals(278));

        // 5. Verification of 10 known pixel positions
        final knownPositions =
            <(int row, int col, int expectedStored, double expectedHu)>[
              (0, 0, 0, 0.0),
              (0, 100, 0, 0.0),
              (46, 13, 1, 1.0),
              (512, 128, 13, 13.0),
              (100, 50, 0, 0.0),
              (200, 100, 30, 30.0),
              (300, 150, 57, 57.0),
              (500, 200, 14, 14.0),
              (700, 100, 24, 24.0),
              (1023, 255, 0, 0.0),
            ];

        for (final (row, col, expectedStored, expectedHu) in knownPositions) {
          final index = (row * dataset.columns) + col;
          final stored = decodedPixels[index];
          final hu = (stored * dataset.rescaleSlope) + dataset.rescaleIntercept;
          expect(
            stored,
            equals(expectedStored),
            reason: 'Stored value mismatch at row $row, col $col',
          );
          expect(
            hu,
            equals(expectedHu),
            reason: 'HU mismatch at row $row, col $col',
          );
        }

        // 6. DicomRenderer rendering & windowing
        final defaultRgba = DicomRenderer.renderToRgba(dataset);
        expect(defaultRgba.length, equals(1024 * 256 * 4));

        final customRgba = DicomRenderer.renderToRgba(
          dataset,
          windowCenter: 50.0,
          windowWidth: 100.0,
        );
        expect(customRgba.length, equals(1024 * 256 * 4));
        expect(customRgba, isNot(equals(defaultRgba)));

        // Render to ui.Image asynchronously
        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(256));
        expect(image.height, equals(1024));
      },
    );

    test(
      '8-bit fixture (JPGLosslessP14SV1_1s_1f_8b.dcm) reference sample equality',
      () async {
        final file = File('test/fixtures/jpeg/JPGLosslessP14SV1_1s_1f_8b.dcm');
        final rawFile = File('test/fixtures/jpeg/jpg_8b_expected.raw');
        expect(file.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final bytes = file.readAsBytesSync();
        final expectedBytes = rawFile.readAsBytesSync();
        final dataset = DicomDataset.fromBytes(bytes);

        expect(
          dataset.transferSyntaxUid,
          equals(TransferSyntax.jpegLosslessSV1),
        );
        expect(dataset.rows, equals(768));
        expect(dataset.columns, equals(1024));
        expect(dataset.bitsAllocated, equals(8));
        expect(dataset.bitsStored, equals(8));
        expect(dataset.highBit, equals(7));
        expect(dataset.pixelRepresentation, equals(0));
        expect(dataset.photometricInterpretation, equals('MONOCHROME2'));

        final rawDecodedBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
        );
        expect(rawDecodedBytes.length, equals(768 * 1024));
        expect(rawDecodedBytes, equals(expectedBytes));

        const pixelDecoder = PixelDataDecoder();
        final pixelInfo = PixelDataInfo.fromDataset(dataset);
        final decodedPixels = pixelDecoder.decode(rawDecodedBytes, pixelInfo);
        expect(decodedPixels.length, equals(768 * 1024));

        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, equals(1024));
        expect(image.height, equals(768));
      },
    );

    test(
      '12-bit integration validation (synthetic_12b.jpg) against libjpeg oracle',
      () {
        final jpgFile = File('test/fixtures/jpeg/synthetic_12b.jpg');
        final rawFile = File('test/fixtures/jpeg/synthetic_12b_expected.raw');
        expect(jpgFile.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final jpgBytes = jpgFile.readAsBytesSync();
        final expectedBytes = rawFile.readAsBytesSync();

        const decoder = JpegLosslessDecoder();
        const info12 = PixelDataInfo(
          bitsAllocated: 16,
          bitsStored: 12,
          highBit: 11,
          isSigned: false,
          samplesPerPixel: 1,
          photometricInterpretation: 'MONOCHROME2',
          rows: 4,
          columns: 4,
        );

        final decodedBytes = decoder.decodeFrame(
          frameBytes: jpgBytes,
          info: info12,
        );

        expect(decodedBytes.length, equals(expectedBytes.length));
        expect(decodedBytes, equals(expectedBytes));

        const pixelDecoder = PixelDataDecoder();
        final pixels = pixelDecoder.decode(decodedBytes, info12);
        expect(pixels.length, equals(16));
        expect(pixels[0], equals(2048));
        expect(pixels[1], equals(2049));
        expect(pixels[15], equals(2050));
      },
    );

    test('windowing adjustments do not re-decode or alter stored pixels', () {
      final file = File('test/fixtures/jpeg/JPEG-LL.dcm');
      final bytes = file.readAsBytesSync();
      final dataset = DicomDataset.fromBytes(bytes);

      final storedPixelsBefore = const PixelDataDecoder().decode(
        CodecRegistry.extractEffectivePixelBytes(dataset),
        PixelDataInfo.fromDataset(dataset),
      );

      // Perform multiple render passes with distinct windows
      final rgbaDefault = DicomRenderer.renderToRgba(dataset);
      final rgbaNarrow = DicomRenderer.renderToRgba(
        dataset,
        windowCenter: 30.0,
        windowWidth: 20.0,
      );
      final rgbaWide = DicomRenderer.renderToRgba(
        dataset,
        windowCenter: 100.0,
        windowWidth: 500.0,
      );

      final storedPixelsAfter = const PixelDataDecoder().decode(
        CodecRegistry.extractEffectivePixelBytes(dataset),
        PixelDataInfo.fromDataset(dataset),
      );

      expect(
        storedPixelsBefore,
        equals(storedPixelsAfter),
        reason:
            'Windowing adjustments must never modify decoded stored pixel values',
      );
      expect(rgbaNarrow, isNot(equals(rgbaDefault)));
      expect(rgbaWide, isNot(equals(rgbaDefault)));
    });

    test(
      'malformed JPEG frame payloads fail explicitly with FormatException',
      () {
        const decoder = JpegLosslessDecoder();
        const info = PixelDataInfo(
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          isSigned: false,
          samplesPerPixel: 1,
          rows: 2,
          columns: 2,
          photometricInterpretation: 'MONOCHROME2',
        );

        // Missing SOI
        expect(
          () => decoder.decodeFrame(
            frameBytes: Uint8List.fromList([0x00, 0x00, 0x00]),
            info: info,
          ),
          throwsFormatException,
        );

        // Truncated SOI only
        expect(
          () => decoder.decodeFrame(
            frameBytes: Uint8List.fromList([0xFF, 0xD8]),
            info: info,
          ),
          throwsFormatException,
        );

        // Corrupted segment header
        expect(
          () => decoder.decodeFrame(
            frameBytes: Uint8List.fromList([
              0xFF,
              0xD8,
              0xFF,
              0xC3,
              0x00,
              0x01,
            ]),
            info: info,
          ),
          throwsFormatException,
        );
      },
    );

    test(
      'error recovery and dataset switching preserves zero state contamination',
      () {
        final jpegFile = File('test/fixtures/jpeg/JPEG-LL.dcm');
        final nativeFile = File('test/fixtures/CT_small.dcm');
        expect(jpegFile.existsSync(), isTrue);
        expect(nativeFile.existsSync(), isTrue);

        final jpegDataset = DicomDataset.fromBytes(jpegFile.readAsBytesSync());
        final nativeDataset = DicomDataset.fromBytes(
          nativeFile.readAsBytesSync(),
        );

        // 1. Attempt malformed frame decode
        const decoder = JpegLosslessDecoder();
        const dummyInfo = PixelDataInfo(
          bitsAllocated: 8,
          bitsStored: 8,
          highBit: 7,
          isSigned: false,
          samplesPerPixel: 1,
          rows: 2,
          columns: 2,
          photometricInterpretation: 'MONOCHROME2',
        );
        expect(
          () => decoder.decodeFrame(
            frameBytes: Uint8List.fromList([0x00, 0x01, 0x02]),
            info: dummyInfo,
          ),
          throwsFormatException,
        );

        // 2. Immediate decode of valid JPEG dataset succeeds
        final jpegRgba1 = DicomRenderer.renderToRgba(jpegDataset);
        expect(jpegRgba1.length, equals(1024 * 256 * 4));

        // 3. Switch to native uncompressed CT dataset succeeds
        final nativeRgba = DicomRenderer.renderToRgba(nativeDataset);
        expect(nativeRgba.length, equals(128 * 128 * 4));

        // 4. Switch back to JPEG dataset produces identical output with zero leakage
        final jpegRgba2 = DicomRenderer.renderToRgba(jpegDataset);
        expect(jpegRgba2, equals(jpegRgba1));
      },
    );
  });
}
