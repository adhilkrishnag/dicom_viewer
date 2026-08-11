import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/rle_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RLE Lossless Decoder Unit Tests (v0.2.0 Scope)', () {
    test(
      'Synthetic RLE Test: Decompresses 8-bit Grayscale 1 segment payload correctly',
      () {
        // Create a 64-byte RLE Header
        // numSegments = 1 (at offset 0), offset[0] = 64 (at offset 4)
        final rleBytes = Uint8List(64 + 6);
        final bd = ByteData.sublistView(rleBytes);
        bd.setUint32(0, 1, Endian.little); // 1 segment
        bd.setUint32(4, 64, Endian.little); // segment 0 offset = 64

        // Segment payload: PackBits stream for [10, 20, 20, 20, 30]
        // n = 0 (literal 1 byte: 10) -> [0x00, 0x0A]
        // n = -2 (repeat 3 times: 20) -> [0xFE, 0x14]
        // n = 0 (literal 1 byte: 30) -> [0x00, 0x1E]
        rleBytes.setAll(64, [0x00, 0x0A, 0xFE, 0x14, 0x00, 0x1E]);

        final decoded = RleDecoder.decodeFrame(
          rleFrameBytes: rleBytes,
          width: 5,
          height: 1,
          bitsAllocated: 8,
          samplesPerPixel: 1,
        );

        expect(decoded, equals([10, 20, 20, 20, 30]));
      },
    );

    test(
      'Synthetic RLE Test: Decompresses 16-bit Grayscale 2 segment payload (MSB/LSB re-interleaving)',
      () {
        final rleBytes = Uint8List(64 + 6 + 6);
        final bd = ByteData.sublistView(rleBytes);
        bd.setUint32(0, 2, Endian.little); // 2 segments
        bd.setUint32(4, 64, Endian.little); // Seg 0 (MSB) offset = 64
        bd.setUint32(8, 70, Endian.little); // Seg 1 (LSB) offset = 70

        // Seg 0 (MSB): 2 pixels with MSB=0x01, 0x02 -> [0x01, 0x01, 0x02] (literal 2 bytes)
        rleBytes.setAll(64, [0x01, 0x01, 0x02]);

        // Seg 1 (LSB): 2 pixels with LSB=0xAA, 0xBB -> [0x01, 0xAA, 0xBB]
        rleBytes.setAll(70, [0x01, 0xAA, 0xBB]);

        final decoded = RleDecoder.decodeFrame(
          rleFrameBytes: rleBytes,
          width: 2,
          height: 1,
          bitsAllocated: 16,
          samplesPerPixel: 1,
        );

        // 16-bit Little Endian output format: [LSB0, MSB0, LSB1, MSB1]
        expect(decoded, equals([0xAA, 0x01, 0xBB, 0x02]));
      },
    );

    test(
      'Synthetic RLE Test: Decompresses 24-bit RGB 3 segment payload (Red, Green, Blue re-interleaving)',
      () {
        final rleBytes = Uint8List(64 + 4 + 4 + 4);
        final bd = ByteData.sublistView(rleBytes);
        bd.setUint32(0, 3, Endian.little); // 3 segments
        bd.setUint32(4, 64, Endian.little); // Seg 0 (Red)
        bd.setUint32(8, 68, Endian.little); // Seg 1 (Green)
        bd.setUint32(12, 72, Endian.little); // Seg 2 (Blue)

        // 2 pixels: Pixel 0 = (255, 0, 0), Pixel 1 = (0, 255, 0)
        rleBytes.setAll(64, [0x01, 255, 0]); // Red
        rleBytes.setAll(68, [0x01, 0, 255]); // Green
        rleBytes.setAll(72, [0x01, 0, 0]); // Blue

        final decoded = RleDecoder.decodeFrame(
          rleFrameBytes: rleBytes,
          width: 2,
          height: 1,
          bitsAllocated: 8,
          samplesPerPixel: 3,
        );

        // Output RGB interleave: [R0, G0, B0, R1, G1, B1]
        expect(decoded, equals([255, 0, 0, 0, 255, 0]));
      },
    );

    test(
      'RLE Decoder throws FormatException on header shorter than 64 bytes',
      () {
        expect(
          () => RleDecoder.decodeFrame(
            rleFrameBytes: Uint8List(32),
            width: 2,
            height: 2,
            bitsAllocated: 8,
            samplesPerPixel: 1,
          ),
          throwsFormatException,
        );
      },
    );
  });
}
