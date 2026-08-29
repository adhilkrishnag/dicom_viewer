import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/jpeg_bit_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JpegBitReader', () {
    test('reads individual bits accurately', () {
      // 0xA5 = 10100101 in binary
      final reader = JpegBitReader(Uint8List.fromList([0xA5]));
      expect(reader.readBit(), equals(1));
      expect(reader.readBit(), equals(0));
      expect(reader.readBit(), equals(1));
      expect(reader.readBit(), equals(0));
      expect(reader.readBit(), equals(0));
      expect(reader.readBit(), equals(1));
      expect(reader.readBit(), equals(0));
      expect(reader.readBit(), equals(1));
    });

    test('reads arbitrary bit lengths up to 16 bits', () {
      // 0x12, 0x34, 0x56 = 00010010 00110100 01010110
      final reader = JpegBitReader(Uint8List.fromList([0x12, 0x34, 0x56]));
      expect(reader.readBits(4), equals(0x1)); // 0001
      expect(reader.readBits(12), equals(0x234)); // 0010 00110100
      expect(reader.readBits(8), equals(0x56)); // 01010110
    });

    test('correctly unescapes 0xFF00 byte stuffing to literal 0xFF', () {
      // Stream: 0xFF 0x00 0x12 (stuffed 0xFF, followed by 0x12)
      final reader = JpegBitReader(Uint8List.fromList([0xFF, 0x00, 0x12]));
      expect(reader.readBits(8), equals(0xFF));
      expect(reader.readBits(8), equals(0x12));
      expect(reader.unreadMarker, isNull);
    });

    test('handles consecutive stuffed 0xFF00 bytes', () {
      // Stream: 0xFF 0x00 0xFF 0x00
      final reader = JpegBitReader(
        Uint8List.fromList([0xFF, 0x00, 0xFF, 0x00]),
      );
      expect(reader.readBits(16), equals(0xFFFF));
      expect(reader.unreadMarker, isNull);
    });

    test('handles fill bytes 0xFF 0xFF 0x00', () {
      // Stream: 0xFF 0xFF 0x00 (fill byte followed by stuffed FF)
      final reader = JpegBitReader(Uint8List.fromList([0xFF, 0xFF, 0x00]));
      expect(reader.readBits(8), equals(0xFF));
    });

    test('detects marker boundaries (0xFF followed by non-zero)', () {
      // Stream: 0x12 0xFF 0xD9 (data 0x12, EOI marker 0xFFD9)
      final reader = JpegBitReader(Uint8List.fromList([0x12, 0xFF, 0xD9]));
      expect(reader.readBits(8), equals(0x12));
      // Bit buffer fills when more bits requested and detects 0xD9 marker
      expect(reader.readBit(), equals(0)); // Padded with dummy 0-bits at marker
      expect(reader.unreadMarker, equals(0xD9));
      expect(reader.consumeMarker(), equals(0xD9));
      expect(reader.unreadMarker, isNull);
    });

    test('alignToByte discards fractional remaining bits', () {
      // 0b10110000 0x42
      final reader = JpegBitReader(Uint8List.fromList([0xB0, 0x42]));
      expect(reader.readBits(3), equals(0x5)); // 101
      reader.alignToByte();
      expect(reader.readBits(8), equals(0x42));
    });

    test('validates offset bounds on construction', () {
      expect(() => JpegBitReader(Uint8List(5), offset: -1), throwsRangeError);
      expect(() => JpegBitReader(Uint8List(5), offset: 6), throwsRangeError);
    });
  });
}
