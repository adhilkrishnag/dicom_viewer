import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
import 'package:dicom_viewer/src/decoders/jpeg_lossless_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Oracle Reference Comparison (A == B)', () {
    test('bit-exact match for 8-bit SV1 (JPGLosslessP14SV1_1s_1f_8b.dcm)', () {
      final dcmFile = File('test/fixtures/jpeg/JPGLosslessP14SV1_1s_1f_8b.dcm');
      final rawFile = File('test/fixtures/jpeg/jpg_8b_expected.raw');
      expect(dcmFile.existsSync(), isTrue);
      expect(rawFile.existsSync(), isTrue);

      final dataset = DicomDataset.fromBytes(dcmFile.readAsBytesSync());
      final expectedBytes = rawFile.readAsBytesSync();

      final decodedBytes = CodecRegistry.extractEffectivePixelBytes(dataset);

      expect(decodedBytes.length, equals(expectedBytes.length));
      expect(decodedBytes, equals(expectedBytes));
    });

    test(
      'bit-exact match for 16-bit SV1 against libjpeg oracle (synthetic_16b.jpg)',
      () {
        final jpgFile = File('test/fixtures/jpeg/synthetic_16b.jpg');
        final rawFile = File('test/fixtures/jpeg/synthetic_16b_expected.raw');
        expect(jpgFile.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final jpgBytes = jpgFile.readAsBytesSync();
        final expectedBytes = rawFile.readAsBytesSync();

        const decoder = JpegLosslessDecoder();
        const info = PixelDataInfo(
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          isSigned: false,
          samplesPerPixel: 1,
          photometricInterpretation: 'MONOCHROME2',
          rows: 4,
          columns: 4,
        );

        final decodedBytes = decoder.decodeFrame(
          frameBytes: jpgBytes,
          info: info,
        );

        expect(decodedBytes.length, equals(expectedBytes.length));
        expect(decodedBytes, equals(expectedBytes));
      },
    );

    test(
      'bit-exact match for 12-bit SV1 against libjpeg oracle (synthetic_12b.jpg)',
      () {
        final jpgFile = File('test/fixtures/jpeg/synthetic_12b.jpg');
        final rawFile = File('test/fixtures/jpeg/synthetic_12b_expected.raw');
        expect(jpgFile.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final jpgBytes = jpgFile.readAsBytesSync();
        final expectedBytes = rawFile.readAsBytesSync();

        const decoder = JpegLosslessDecoder();
        const info = PixelDataInfo(
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
          info: info,
        );

        expect(decodedBytes.length, equals(expectedBytes.length));
        expect(decodedBytes, equals(expectedBytes));
      },
    );

    test('bit-exact match for real 16-bit CT fixture (JPEG-LL.dcm)', () {
      final dcmFile = File('test/fixtures/jpeg/JPEG-LL.dcm');
      final rawFile = File('test/fixtures/jpeg/jpeg_ll_expected.raw');
      expect(dcmFile.existsSync(), isTrue);
      expect(rawFile.existsSync(), isTrue);

      final dataset = DicomDataset.fromBytes(dcmFile.readAsBytesSync());
      final expectedBytes = rawFile.readAsBytesSync();

      expect(dataset.transferSyntaxUid, equals('1.2.840.10008.1.2.4.70'));
      expect(dataset.rows, equals(1024));
      expect(dataset.columns, equals(256));
      expect(dataset.bitsAllocated, equals(16));

      final decodedBytes = CodecRegistry.extractEffectivePixelBytes(dataset);
      expect(decodedBytes.length, equals(expectedBytes.length));

      // Compare sample by sample
      final decodedBd = ByteData.sublistView(decodedBytes);
      final expectedBd = ByteData.sublistView(expectedBytes);

      int mismatchCount = 0;

      for (int i = 0; i < dataset.rows * dataset.columns; i++) {
        final actual = decodedBd.getUint16(i * 2, Endian.little);
        final expected = expectedBd.getUint16(i * 2, Endian.little);
        if (actual != expected) {
          mismatchCount++;
        }
      }

      expect(
        mismatchCount,
        equals(0),
        reason:
            'Every decoded 16-bit sample must match reference oracle bit-for-bit (A == B)',
      );
      expect(decodedBytes, equals(expectedBytes));
    });
  });
}
