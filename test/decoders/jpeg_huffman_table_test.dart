import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/huffman_table.dart';
import 'package:dicom_viewer/src/decoders/jpeg_bit_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HuffmanTable', () {
    // Standard ITU-T T.81 Annex K Table K.3 (Luminance DC)
    final bitsK3 = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
    final huffvalK3 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

    test('constructs table and decodes standard DC Huffman symbols', () {
      final table = HuffmanTable(
        tableClass: 0,
        destinationId: 0,
        bits: bitsK3,
        huffval: huffvalK3,
      );

      expect(table.tableClass, equals(0));
      expect(table.destinationId, equals(0));
      expect(table.bits.length, equals(16));
      expect(table.huffval.length, equals(12));

      // Test decoding symbol 0 (code: 00 -> 2 bits)
      // Test decoding symbol 1 (code: 010 -> 3 bits)
      // Test decoding symbol 6 (code: 1110 -> 4 bits)
      // Binary stream: 00 010 1110 0 (pad to 10 bits = 0x00, 0x5C...)
      // 00 = 0
      // 010 = 1
      // 1110 = 6
      // Combined: 00 010 1110 = 0001 0111 0000 0000 = 0x17 0x00
      final reader = JpegBitReader(Uint8List.fromList([0x17, 0x00]));

      expect(table.decode(reader), equals(0));
      expect(table.decode(reader), equals(1));
      expect(table.decode(reader), equals(6));
    });

    test(
      'decodes deep codes of length up to 9 bits (canonical loop fallback)',
      () {
        final table = HuffmanTable(
          tableClass: 0,
          destinationId: 0,
          bits: bitsK3,
          huffval: huffvalK3,
        );

        // Symbol 11 has code length 9: 111111110 (9 bits)
        // 11111111 00000000 = 0xFF, 0x00 (with byte stuffing: 0xFF 0x00 0x00)
        final reader = JpegBitReader(Uint8List.fromList([0xFF, 0x00, 0x00]));
        expect(table.decode(reader), equals(11));
      },
    );

    test('validates bits length must be exactly 16', () {
      expect(
        () => HuffmanTable(
          tableClass: 0,
          destinationId: 0,
          bits: [1, 2, 3], // invalid length != 16
          huffval: [0, 1, 2, 3, 4, 5],
        ),
        throwsFormatException,
      );
    });

    test('throws on huffval length mismatch', () {
      expect(
        () => HuffmanTable(
          tableClass: 0,
          destinationId: 0,
          bits: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          huffval: [], // expects 1 symbol, provided 0
        ),
        throwsFormatException,
      );
    });
  });
}
