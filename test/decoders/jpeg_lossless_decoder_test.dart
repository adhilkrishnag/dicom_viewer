import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/jpeg_lossless_decoder.dart';
import 'package:dicom_viewer/src/pixel_data/pixel_data_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JpegLosslessDecoder', () {
    const decoder = JpegLosslessDecoder();

    const defaultInfo8 = PixelDataInfo(
      bitsAllocated: 8,
      bitsStored: 8,
      highBit: 7,
      isSigned: false,
      samplesPerPixel: 1,
      rows: 2,
      columns: 2,
      photometricInterpretation: 'MONOCHROME2',
      isLittleEndian: true,
    );

    const defaultInfo16 = PixelDataInfo(
      bitsAllocated: 16,
      bitsStored: 16,
      highBit: 15,
      isSigned: false,
      samplesPerPixel: 1,
      rows: 2,
      columns: 2,
      photometricInterpretation: 'MONOCHROME2',
      isLittleEndian: true,
    );

    /// Builds a minimal valid SOF3 JPEG Lossless byte stream.
    Uint8List buildJpegStream({
      required int precision,
      required int rows,
      required int columns,
      int predictor = 1,
      int pointTransform = 0,
      int numComponents = 1,
      int restartInterval = 0,
      required List<int> entropyBytes,
    }) {
      final builder = BytesBuilder();

      // SOI
      builder.add([0xFF, 0xD8]);

      // SOF3
      final sofLength = 8 + (numComponents * 3);
      builder.add([0xFF, 0xC3, (sofLength >> 8) & 0xFF, sofLength & 0xFF]);
      builder.addByte(precision);
      builder.add([(rows >> 8) & 0xFF, rows & 0xFF]);
      builder.add([(columns >> 8) & 0xFF, columns & 0xFF]);
      builder.addByte(numComponents);
      for (int i = 0; i < numComponents; i++) {
        builder.add([i + 1, 0x11, 0x00]);
      }

      // DHT (DC Table 0: simple 16 symbols)
      // bits: length 1: 0, length 2: 1 (code 00=sym 0), length 3: 5 (codes 010..110 = syms 1..5), etc.
      final bits = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
      final huffval = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
      final dhtLength = 2 + 1 + 16 + huffval.length;
      builder.add([0xFF, 0xC4, (dhtLength >> 8) & 0xFF, dhtLength & 0xFF]);
      builder.addByte(0x00); // DC table 0
      builder.add(bits);
      builder.add(huffval);

      // DRI if restartInterval > 0
      if (restartInterval > 0) {
        builder.add([
          0xFF,
          0xDD,
          0x00,
          0x04,
          (restartInterval >> 8) & 0xFF,
          restartInterval & 0xFF,
        ]);
      }

      // SOS
      final sosLength = 6 + (numComponents * 2);
      builder.add([0xFF, 0xDA, (sosLength >> 8) & 0xFF, sosLength & 0xFF]);
      builder.addByte(numComponents);
      for (int i = 0; i < numComponents; i++) {
        builder.add([i + 1, 0x00]); // component i+1, DC table 0
      }
      builder.addByte(predictor); // Ss
      builder.addByte(0x00); // Se
      builder.addByte(pointTransform & 0x0F); // Ah/Al

      // Entropy coded data
      builder.add(entropyBytes);

      // EOI
      builder.add([0xFF, 0xD9]);

      return builder.toBytes();
    }

    test('decodes 8-bit synthetic 2x2 image with zero differences', () {
      // In 8-bit, initial predictor = 2^(8-0-1) = 128.
      // 4 pixels with 0 difference: all pixels should be 128.
      // Symbol 0 (diff 0) has Huffman code '00' (2 bits).
      // 4 zeros in binary: '00 00 00 00' = 0x00.
      final stream = buildJpegStream(
        precision: 8,
        rows: 2,
        columns: 2,
        entropyBytes: [0x00],
      );

      final decoded = decoder.decodeFrame(
        frameBytes: stream,
        info: defaultInfo8,
      );

      expect(decoded.length, equals(4));
      expect(decoded, equals(Uint8List.fromList([128, 128, 128, 128])));
    });

    test('decodes 16-bit synthetic 2x2 image with known DPCM steps', () {
      // In 16-bit, initial predictor = 2^(16-0-1) = 32768 (0x8000).
      // Pixel (0,0): diff = 0 -> 32768 (code: 00)
      // Pixel (0,1): diff = +1 -> left (32768) + 1 = 32769.
      //   sym 1 has code '010' + 1 bit '1' for +1 -> '0101' (4 bits).
      // Pixel (1,0): diff = 0 -> above (32768) + 0 = 32768 (code: 00).
      // Pixel (1,1): diff = -1 -> left (32768) - 1 = 32767.
      //   sym 1 has code '010' + 1 bit '0' for -1 -> '0100' (4 bits).
      // Binary sequence:
      // P(0,0): 00
      // P(0,1): 0101
      // P(1,0): 00
      // P(1,1): 0100
      // Combined: 00 0101 00 0100 (12 bits) = 0001 0100 0100 [0000 pad] = 0x14 0x40.
      final stream = buildJpegStream(
        precision: 16,
        rows: 2,
        columns: 2,
        entropyBytes: [0x14, 0x40],
      );

      final decoded = decoder.decodeFrame(
        frameBytes: stream,
        info: defaultInfo16,
      );

      expect(decoded.length, equals(8)); // 4 samples * 2 bytes
      final bd = ByteData.sublistView(decoded);
      expect(bd.getUint16(0, Endian.little), equals(32768));
      expect(bd.getUint16(2, Endian.little), equals(32769));
      expect(bd.getUint16(4, Endian.little), equals(32768));
      expect(bd.getUint16(6, Endian.little), equals(32767));
    });

    test('handles modulo 2^16 boundary wrapping', () {
      // In 16-bit, diff of +1023 (category 10).
      // Code for symbol 10 (8 bits): '11111110' + 10 bits value '1111111111' (+1023)
      // (32768 + 1023) = 33791.
      // All other pixels diff 0 (code 00).
      // Binary: 11111110 11111111 11 00 00 00
      // Note: Byte 1 is 0xFF, which must be followed by stuffed 0x00 in JPEG entropy stream!
      final stream = buildJpegStream(
        precision: 16,
        rows: 2,
        columns: 2,
        entropyBytes: [0xFE, 0xFF, 0x00, 0xC0],
      );

      final decoded = decoder.decodeFrame(
        frameBytes: stream,
        info: defaultInfo16,
      );

      final bd = ByteData.sublistView(decoded);
      expect(bd.getUint16(0, Endian.little), equals(33791));
      expect(bd.getUint16(2, Endian.little), equals(33791));
      expect(bd.getUint16(4, Endian.little), equals(33791));
      expect(bd.getUint16(6, Endian.little), equals(33791));
    });

    test('applies point transform Pt correctly', () {
      // In 8-bit with Pt = 1: initial predictor = 2^(8-1-1) = 64.
      // 4 pixels with diff 0: reconstructed rx = 64.
      // Final sample = (64 << 1) = 128.
      final stream = buildJpegStream(
        precision: 8,
        rows: 2,
        columns: 2,
        pointTransform: 1,
        entropyBytes: [0x00],
      );

      final decoded = decoder.decodeFrame(
        frameBytes: stream,
        info: defaultInfo8,
      );

      expect(decoded, equals(Uint8List.fromList([128, 128, 128, 128])));
    });

    test('handles restart markers in entropy stream', () {
      // 2x2 image with restartInterval = 2 (restarts after 2 pixels).
      // Pixels (0,0), (0,1): diff 0 (code: 00 00 = 0x00).
      // Restart marker RST0 (0xFF 0xD0) byte-aligned.
      // Pixels (1,0), (1,1): diff 0 (code: 00 00 = 0x00).
      final stream = buildJpegStream(
        precision: 8,
        rows: 2,
        columns: 2,
        restartInterval: 2,
        entropyBytes: [0x00, 0xFF, 0xD0, 0x00],
      );

      final decoded = decoder.decodeFrame(
        frameBytes: stream,
        info: defaultInfo8,
      );

      expect(decoded, equals(Uint8List.fromList([128, 128, 128, 128])));
    });

    test('throws FormatException on truncated SOI', () {
      expect(
        () => decoder.decodeFrame(
          frameBytes: Uint8List.fromList([0xFF]),
          info: defaultInfo8,
        ),
        throwsFormatException,
      );
      expect(
        () => decoder.decodeFrame(
          frameBytes: Uint8List.fromList([0x00, 0x00, 0x00, 0x00]),
          info: defaultInfo8,
        ),
        throwsFormatException,
      );
    });

    test('throws UnsupportedError on multi-component stream', () {
      final stream = buildJpegStream(
        precision: 8,
        rows: 2,
        columns: 2,
        numComponents: 3,
        entropyBytes: [0x00],
      );

      expect(
        () => decoder.decodeFrame(frameBytes: stream, info: defaultInfo8),
        throwsUnsupportedError,
      );
    });

    test('throws UnsupportedError on predictor selection != 1', () {
      final stream = buildJpegStream(
        precision: 8,
        rows: 2,
        columns: 2,
        predictor: 2, // Predictor 2 is out of scope for SV1
        entropyBytes: [0x00],
      );

      expect(
        () => decoder.decodeFrame(frameBytes: stream, info: defaultInfo8),
        throwsUnsupportedError,
      );
    });

    test('throws FormatException on truncated entropy stream', () {
      // 10x10 image expects 100 samples, but entropy stream contains only 1 byte
      final stream = buildJpegStream(
        precision: 8,
        rows: 10,
        columns: 10,
        entropyBytes: [0x00],
      );

      const info100 = PixelDataInfo(
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        isSigned: false,
        samplesPerPixel: 1,
        rows: 10,
        columns: 10,
        photometricInterpretation: 'MONOCHROME2',
        isLittleEndian: true,
      );

      expect(
        () => decoder.decodeFrame(frameBytes: stream, info: info100),
        throwsFormatException,
      );
    });

    test('throws FormatException on premature EOI in entropy stream', () {
      // 10x10 image expecting 100 samples, but hit with EOI after 1 byte
      final stream = buildJpegStream(
        precision: 8,
        rows: 10,
        columns: 10,
        entropyBytes: [0x00, 0xFF, 0xD9],
      );

      const info100 = PixelDataInfo(
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        isSigned: false,
        samplesPerPixel: 1,
        rows: 10,
        columns: 10,
        photometricInterpretation: 'MONOCHROME2',
        isLittleEndian: true,
      );

      expect(
        () => decoder.decodeFrame(frameBytes: stream, info: info100),
        throwsFormatException,
      );
    });

    test('throws FormatException on invalid unescaped marker in scan data', () {
      // 0xFF followed by invalid non-marker byte or out-of-sequence byte
      final stream = buildJpegStream(
        precision: 8,
        rows: 10,
        columns: 10,
        entropyBytes: [0xFF, 0x01],
      );

      const info100 = PixelDataInfo(
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        isSigned: false,
        samplesPerPixel: 1,
        rows: 10,
        columns: 10,
        photometricInterpretation: 'MONOCHROME2',
        isLittleEndian: true,
      );

      expect(
        () => decoder.decodeFrame(frameBytes: stream, info: info100),
        throwsFormatException,
      );
    });

    test('decodes 12-bit synthetic stream correctly', () {
      const defaultInfo12 = PixelDataInfo(
        bitsAllocated: 16,
        bitsStored: 12,
        highBit: 11,
        isSigned: false,
        samplesPerPixel: 1,
        rows: 2,
        columns: 2,
        photometricInterpretation: 'MONOCHROME2',
        isLittleEndian: true,
      );

      // In 12-bit precision, initial predictor is 2^(12-1) = 2048.
      // 4 samples with diff 0 -> all 2048.
      final stream = buildJpegStream(
        precision: 12,
        rows: 2,
        columns: 2,
        entropyBytes: [0x00],
      );

      final decoded = decoder.decodeFrame(
        frameBytes: stream,
        info: defaultInfo12,
      );

      expect(decoded.length, equals(8));
      final bd = ByteData.sublistView(decoded);
      expect(bd.getUint16(0, Endian.little), equals(2048));
      expect(bd.getUint16(2, Endian.little), equals(2048));
      expect(bd.getUint16(4, Endian.little), equals(2048));
      expect(bd.getUint16(6, Endian.little), equals(2048));
    });
  });
}
