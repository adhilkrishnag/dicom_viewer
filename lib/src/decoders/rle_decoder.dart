import 'dart:typed_data';

/// Pure-Dart RLE Lossless Decompressor complying with DICOM PS3.5 Annex G.
///
/// Supported Scope:
/// - Bit Depths: 8-bit, 16-bit (signed/unsigned 2's complement).
/// - Samples per Pixel: 1 (Grayscale MONOCHROME1/2), 3 (24-bit RGB).
/// - Planar Configuration: 0 (Color-by-pixel interleaved) and 1 (Separate color planes).
///
/// Uncompressed output bytes are returned ready for [PixelDataDecoder] parsing.
class RleDecoder {
  /// Decompresses an RLE-encoded DICOM frame payload into raw uncompressed pixel bytes.
  ///
  /// Parameters:
  /// - [rleFrameBytes]: Raw encapsulated RLE frame byte array (including 64-byte RLE header).
  /// - [width]: Image width (columns).
  /// - [height]: Image height (rows).
  /// - [bitsAllocated]: Number of bits allocated per pixel sample (8, 16).
  /// - [samplesPerPixel]: Number of samples per pixel (1 for Grayscale, 3 for RGB).
  static Uint8List decodeFrame({
    required Uint8List rleFrameBytes,
    required int width,
    required int height,
    required int bitsAllocated,
    required int samplesPerPixel,
    int planarConfiguration = 0,
  }) {
    if (rleFrameBytes.length < 64) {
      throw FormatException(
        'Invalid RLE frame: Header must be at least 64 bytes (got ${rleFrameBytes.length} bytes).',
      );
    }

    final headerBd = ByteData.sublistView(rleFrameBytes, 0, 64);
    final numSegments = headerBd.getUint32(0, Endian.little);

    if (numSegments < 1 || numSegments > 15) {
      throw FormatException(
        'Invalid RLE header: numSegments must be between 1 and 15 (got $numSegments).',
      );
    }

    // Parse segment byte offsets
    final offsets = List<int>.filled(numSegments, 0);
    for (int i = 0; i < numSegments; i++) {
      offsets[i] = headerBd.getUint32((i + 1) * 4, Endian.little);
    }

    final bytesPerSample = (bitsAllocated + 7) ~/ 8;
    final totalPixels = width * height;
    final bytesPerSegment = totalPixels;

    // Decompress each segment stream via PackBits
    final decompressedSegments = <Uint8List>[];
    for (int i = 0; i < numSegments; i++) {
      final start = offsets[i];
      final end = (i + 1 < numSegments) ? offsets[i + 1] : rleFrameBytes.length;

      if (start >= rleFrameBytes.length || start >= end) {
        throw FormatException('Invalid RLE segment offset at segment $i.');
      }

      final segmentStream = rleFrameBytes.sublist(start, end);
      final decompressed = _unpackPackBits(segmentStream, bytesPerSegment);
      decompressedSegments.add(decompressed);
    }

    // Reinterleave decompressed segments into final raw pixel array
    final outputSizeBytes = totalPixels * bytesPerSample * samplesPerPixel;
    final result = Uint8List(outputSizeBytes);

    if (samplesPerPixel == 1) {
      if (bytesPerSample == 1) {
        // 8-bit Grayscale (1 segment)
        result.setAll(0, decompressedSegments[0]);
      } else if (bytesPerSample == 2) {
        // 16-bit Grayscale (2 segments: Seg 0 = MSB, Seg 1 = LSB)
        if (numSegments < 2) {
          throw FormatException(
            '16-bit RLE grayscale requires 2 segments (got $numSegments).',
          );
        }
        final seg0 = decompressedSegments[0]; // MSB
        final seg1 = decompressedSegments[1]; // LSB
        for (int p = 0; p < totalPixels; p++) {
          final outIdx = p * 2;
          result[outIdx] = seg1[p]; // LSB (Little Endian)
          result[outIdx + 1] = seg0[p]; // MSB
        }
      } else {
        throw UnsupportedError(
          'Unsupported RLE bytesPerSample: $bytesPerSample',
        );
      }
    } else if (samplesPerPixel == 3) {
      // 8-bit 3-channel (e.g. RGB or YBR): 3 segments, one per channel.
      // DICOM PS3.5 Annex G.3: segments are always channel-ordered (R/G/B).
      // Output layout depends on PlanarConfiguration (DICOM 0028,0006):
      //   0 = color-by-pixel interleaved: [R0,G0,B0, R1,G1,B1, ...]
      //   1 = color-by-plane separate:   [R0,R1,...,G0,G1,...,B0,B1,...]
      if (bytesPerSample == 1 && numSegments >= 3) {
        final redSeg = decompressedSegments[0];
        final greenSeg = decompressedSegments[1];
        final blueSeg = decompressedSegments[2];
        if (planarConfiguration == 1) {
          // Planar output: R plane, then G plane, then B plane
          result.setAll(0, redSeg);
          result.setAll(totalPixels, greenSeg);
          result.setAll(2 * totalPixels, blueSeg);
        } else {
          // Interleaved output (default, PlanarConfiguration == 0)
          for (int p = 0; p < totalPixels; p++) {
            final outIdx = p * 3;
            result[outIdx] = redSeg[p];
            result[outIdx + 1] = greenSeg[p];
            result[outIdx + 2] = blueSeg[p];
          }
        }
      } else {
        throw UnsupportedError(
          'Unsupported RLE multi-sample format with $bytesPerSample bytes/sample and $numSegments segments.',
        );
      }
    } else {
      throw UnsupportedError(
        'Unsupported RLE samplesPerPixel: $samplesPerPixel',
      );
    }

    return result;
  }

  /// PackBits run-length decompressor for a single segment stream.
  static Uint8List _unpackPackBits(Uint8List src, int expectedLength) {
    final dest = Uint8List(expectedLength);
    final bd = ByteData.sublistView(src);
    int srcIdx = 0;
    int destIdx = 0;

    while (srcIdx < src.length && destIdx < expectedLength) {
      final n = bd.getInt8(srcIdx);
      srcIdx++;

      if (n >= 0 && n <= 127) {
        // Literal run: Copy next (n + 1) bytes
        final count = n + 1;
        for (
          int i = 0;
          i < count && destIdx < expectedLength && srcIdx < src.length;
          i++
        ) {
          dest[destIdx++] = src[srcIdx++];
        }
      } else if (n >= -127 && n <= -1) {
        // Repeat run: Repeat next byte (-n + 1) times
        if (srcIdx >= src.length) break;
        final repeatByte = src[srcIdx++];
        final count = -n + 1;
        for (int i = 0; i < count && destIdx < expectedLength; i++) {
          dest[destIdx++] = repeatByte;
        }
      } else if (n == -128) {
        // 0x80 No-op: skip
        continue;
      }
    }

    return dest;
  }
}
