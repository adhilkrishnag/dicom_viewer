import 'dart:typed_data';

import 'jpeg_bit_reader.dart';

/// Canonical JPEG Huffman Table representation and fast decoder per ITU-T T.81 Annex C & F.
class HuffmanTable {
  /// Creates a [HuffmanTable] from [tableClass], [destinationId], 16-byte [bits], and [huffval].
  HuffmanTable({
    required this.tableClass,
    required this.destinationId,
    required List<int> bits,
    required List<int> huffval,
  }) : bits = Uint8List.fromList(bits),
       huffval = Uint8List.fromList(huffval) {
    if (bits.length != 16) {
      throw FormatException(
        'Huffman table bits array must contain exactly 16 lengths (got ${bits.length}).',
      );
    }
    _buildTables();
  }

  /// Table class (0 = DC/Lossless difference, 1 = AC).
  final int tableClass;

  /// Table destination identifier (0..3).
  final int destinationId;

  /// Number of codes of each length 1..16 (index 0 unused, length 17).
  final Uint8List bits;

  /// Symbol values associated with each Huffman code.
  final Uint8List huffval;

  final Int32List _minCode = Int32List(17);
  final Int32List _maxCode = Int32List(17);
  final Int32List _valOffset = Int32List(17);

  // 8-bit fast lookup table: upper 8 bits = symbol, lower 8 bits = code length.
  // Value 0 means code length > 8 or invalid.
  final Int32List _fastTable = Int32List(256);

  /// Builds canonical minCode, maxCode, valOffset, and fast lookup tables.
  void _buildTables() {
    int huffcode = 0;
    int k = 0;

    for (int i = 1; i <= 16; i++) {
      final count = bits[i - 1];
      if (count == 0) {
        _minCode[i] = -1;
        _maxCode[i] = -1;
        _valOffset[i] = 0;
      } else {
        _minCode[i] = huffcode;
        _valOffset[i] = k - huffcode;
        for (int j = 0; j < count; j++) {
          if (k >= huffval.length) {
            throw const FormatException(
              'Huffman table values count is less than sum of bit lengths.',
            );
          }
          final symbol = huffval[k];

          // Populate fast lookup table for codes of length <= 8
          if (i <= 8) {
            final int fillBits = 8 - i;
            final int baseIndex = huffcode << fillBits;
            final int fillCount = 1 << fillBits;
            final int entry = (symbol << 8) | i;
            for (int f = 0; f < fillCount; f++) {
              _fastTable[baseIndex + f] = entry;
            }
          }

          k++;
          huffcode++;
        }
        _maxCode[i] = huffcode - 1;
      }
      huffcode <<= 1;
    }

    if (k != huffval.length) {
      throw FormatException(
        'Huffman table values count ($k) does not match huffval length (${huffval.length}).',
      );
    }
  }

  /// Decodes the next symbol from [reader].
  int decode(JpegBitReader reader) {
    // Canonical bit-by-bit decoding per ITU-T T.81 Section F.2.2.3
    int code = reader.readBit();
    int len = 1;

    while (code > _maxCode[len]) {
      len++;
      if (len > 16) {
        throw const FormatException(
          'Invalid Huffman code: exceeded maximum code length 16.',
        );
      }
      code = (code << 1) | reader.readBit();
    }

    final valIdx = code + _valOffset[len];
    if (valIdx < 0 || valIdx >= huffval.length) {
      throw FormatException(
        'Huffman decoded index $valIdx out of range (0..${huffval.length - 1}).',
      );
    }
    return huffval[valIdx];
  }
}
