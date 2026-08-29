import 'dart:typed_data';

/// Bit reader for JPEG entropy-coded streams compliant with ITU-T T.81 Annex F.
///
/// Correctly handles byte stuffing (`0xFF00` -> `0xFF`), fill bytes (`0xFF 0xFF`),
/// and marker boundaries (`0xFF [non-zero]`).
class JpegBitReader {
  /// Creates a [JpegBitReader] starting at [offset] in [bytes].
  JpegBitReader(this._bytes, {int offset = 0, int? length})
    : _offset = offset,
      _end = (length != null) ? offset + length : _bytes.length {
    if (_offset < 0 || _offset > _bytes.length) {
      throw RangeError.value(_offset, 'offset', 'Offset out of bounds');
    }
  }

  final Uint8List _bytes;
  int _offset;
  final int _end;

  int _bitBuffer = 0;
  int _bitsLeft = 0;
  int? _unreadMarker;
  int _eofPadCount = 0;

  /// Current byte offset in the underlying buffer.
  int get offset => _offset;

  /// Returns the marker code if the reader encountered a marker boundary (e.g. 0xD0..0xD7 or 0xD9).
  int? get unreadMarker => _unreadMarker;

  /// Returns true if there are more bits available to read before an unread marker or stream end.
  bool get hasMoreBits =>
      _bitsLeft > 0 || (_offset < _end && _unreadMarker == null);

  /// Reads a single bit (0 or 1).
  int readBit() {
    if (_bitsLeft == 0) {
      _fillBuffer(1);
    }
    _bitsLeft--;
    return (_bitBuffer >> _bitsLeft) & 1;
  }

  /// Reads [count] bits as an unsigned integer ($1 \le count \le 16$).
  int readBits(int count) {
    if (count == 0) return 0;
    if (_bitsLeft < count) {
      _fillBuffer(count);
    }
    _bitsLeft -= count;
    final mask = (1 << count) - 1;
    return (_bitBuffer >> _bitsLeft) & mask;
  }

  /// Discards any remaining unread bits in the current byte, byte-aligning the reader.
  void alignToByte() {
    _bitsLeft = 0;
    _bitBuffer = 0;
  }

  /// Fills the bit buffer with at least [needed] bits.
  void _fillBuffer(int needed) {
    while (_bitsLeft < needed) {
      if (_unreadMarker != null) {
        _eofPadCount++;
        if (_eofPadCount > 16) {
          throw const FormatException(
            'Unexpected marker boundary or truncated entropy stream.',
          );
        }
        // At marker boundary: pad with dummy 0-bits per IJG/libjpeg standard
        _bitBuffer = (_bitBuffer << 1) | 0;
        _bitsLeft++;
        continue;
      }

      if (_offset >= _end) {
        _eofPadCount++;
        if (_eofPadCount > 16) {
          throw const FormatException('Unexpected end of JPEG entropy stream.');
        }
        // Stream ended: pad with dummy 0-bits
        _bitBuffer = (_bitBuffer << 1) | 0;
        _bitsLeft++;
        continue;
      }

      var b = _bytes[_offset++];
      if (b == 0xFF) {
        // Check for byte stuffing or markers
        while (_offset < _end && _bytes[_offset] == 0xFF) {
          _offset++; // Skip fill bytes 0xFF
        }

        if (_offset >= _end) {
          // Truncated trailing 0xFF
          _bitBuffer = (_bitBuffer << 8) | 0xFF;
          _bitsLeft += 8;
          break;
        }

        final next = _bytes[_offset++];
        if (next == 0x00) {
          // Stuffed 0xFF byte
          b = 0xFF;
        } else {
          // Real JPEG marker encountered in entropy stream
          _unreadMarker = next;
          // When a marker is hit, we don't insert marker bytes into entropy buffer.
          // Pad with 1-bits if still needed
          continue;
        }
      }

      _bitBuffer = (_bitBuffer << 8) | b;
      _bitsLeft += 8;
    }
  }

  /// Consumes and clears the current [_unreadMarker].
  int? consumeMarker() {
    final m = _unreadMarker;
    _unreadMarker = null;
    return m;
  }

  /// Aligns to byte boundary and reads the next restart marker from the stream.
  int readRestartMarker() {
    alignToByte();
    if (_unreadMarker != null) {
      final m = _unreadMarker!;
      _unreadMarker = null;
      return m;
    }
    while (_offset < _end && _bytes[_offset] != 0xFF) {
      _offset++;
    }
    while (_offset < _end && _bytes[_offset] == 0xFF) {
      _offset++;
    }
    if (_offset < _end) {
      return _bytes[_offset++];
    }
    return -1;
  }
}
