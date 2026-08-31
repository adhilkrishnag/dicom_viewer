import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';

/// Transfer Syntax specific framing strategy for DICOM encapsulated JPEG bitstreams.
///
/// Complies with DICOM PS3.5 Section A.4 and Section 8.2 encapsulated sequencing rules.
class JpegFramingStrategy {
  /// Extracts the compressed byte payload for [frameIndex] from [encapsulatedData].
  static Uint8List extractFramePayload(
    EncapsulatedPixelData encapsulatedData, {
    required int frameIndex,
    required int numberOfFrames,
  }) {
    if (frameIndex < 0 ||
        (numberOfFrames > 0 && frameIndex >= numberOfFrames)) {
      throw RangeError(
        'Invalid frameIndex $frameIndex (total frames: $numberOfFrames).',
      );
    }

    final fragments = encapsulatedData.fragments;
    if (fragments.isEmpty) {
      throw StateError(
        'Encapsulated JPEG pixel data contains no item fragments.',
      );
    }

    // --- 1. Basic Offset Table (BOT) Available & Populated ---
    if (encapsulatedData.botOffsets.isNotEmpty) {
      final bot = encapsulatedData.botOffsets;
      if (bot.length != numberOfFrames) {
        throw FormatException(
          'Basic Offset Table entry count (${bot.length}) '
          'does not match numberOfFrames ($numberOfFrames).',
        );
      }

      // Validate non-decreasing monotonic order
      for (int i = 0; i < bot.length - 1; i++) {
        if (bot[i] > bot[i + 1]) {
          throw const FormatException(
            'Invalid Basic Offset Table: offsets are not non-decreasing.',
          );
        }
      }

      // Locate the starting fragment for target frameIndex
      final targetOffset = bot[frameIndex];
      int startFragIdx = -1;
      for (int i = 0; i < fragments.length; i++) {
        if (fragments[i].relativeTagStart == targetOffset) {
          startFragIdx = i;
          break;
        }
      }

      if (startFragIdx == -1) {
        throw FormatException(
          'Basic Offset Table entry for frame $frameIndex (offset $targetOffset) '
          'does not match any fragment start position.',
        );
      }

      // Determine end fragment index (exclusive)
      int endFragIdx;
      if (frameIndex + 1 < numberOfFrames) {
        final nextTargetOffset = bot[frameIndex + 1];
        endFragIdx = -1;
        for (int i = startFragIdx; i < fragments.length; i++) {
          if (fragments[i].relativeTagStart == nextTargetOffset) {
            endFragIdx = i;
            break;
          }
        }
        if (endFragIdx == -1) {
          throw FormatException(
            'Basic Offset Table entry for frame ${frameIndex + 1} (offset $nextTargetOffset) '
            'does not match any fragment start position.',
          );
        }
      } else {
        // Last frame spans up to the final fragment
        endFragIdx = fragments.length;
      }

      final count = endFragIdx - startFragIdx;
      if (count <= 0) {
        throw FormatException(
          'Invalid fragment range [$startFragIdx..$endFragIdx) for frame $frameIndex.',
        );
      }

      if (count == 1) {
        // Zero-copy slice for single-fragment frame
        return fragments[startFragIdx].payload;
      }

      // Multi-fragment frame: assemble fragments
      final builder = BytesBuilder(copy: false);
      for (int i = startFragIdx; i < endFragIdx; i++) {
        builder.add(fragments[i].payload);
      }
      return builder.toBytes();
    }

    // --- 2. Single-Frame DICOM Image (numberOfFrames == 1) ---
    if (numberOfFrames == 1) {
      if (fragments.length == 1) {
        // Zero-copy slice
        return fragments[0].payload;
      }
      // Single frame spanning multiple fragments
      return encapsulatedData.flatBytes;
    }

    // --- 3. Multi-Frame Image without BOT (numberOfFrames > 1, botOffsets.isEmpty) ---
    if (fragments.length == numberOfFrames) {
      // 1:1 fragment-to-frame mapping
      return fragments[frameIndex].payload;
    }

    if (fragments.length < numberOfFrames) {
      throw FormatException(
        'Encapsulated multi-frame JPEG has fewer fragments (${fragments.length}) '
        'than numberOfFrames ($numberOfFrames).',
      );
    }

    // Multi-frame with multiple fragments per frame and empty BOT
    return _extractFrameByMarkerScan(
      encapsulatedData.flatBytes,
      frameIndex: frameIndex,
      numberOfFrames: numberOfFrames,
    );
  }

  /// Extracts a frame by scanning concatenated fragment payloads for standard JPEG
  /// Start of Image (`0xFF 0xD8`) and End of Image (`0xFF 0xD9`) markers.
  static Uint8List _extractFrameByMarkerScan(
    Uint8List flatBytes, {
    required int frameIndex,
    required int numberOfFrames,
  }) {
    final n = flatBytes.length;
    int idx = 0;
    int currentFrame = 0;

    while (idx < n && currentFrame <= frameIndex) {
      // Find SOI marker (0xFF 0xD8)
      int soiIdx = -1;
      while (idx < n - 1) {
        if (flatBytes[idx] == 0xFF && flatBytes[idx + 1] == 0xD8) {
          soiIdx = idx;
          idx += 2;
          break;
        }
        idx++;
      }

      if (soiIdx == -1) {
        throw FormatException(
          'Failed to locate JPEG SOI marker for frame $currentFrame of $numberOfFrames.',
        );
      }

      // Find EOI marker (0xFF 0xD9)
      int eoiEnd = -1;
      while (idx < n - 1) {
        if (flatBytes[idx] == 0xFF) {
          // Skip consecutive 0xFF fill bytes
          int j = idx + 1;
          while (j < n && flatBytes[j] == 0xFF) {
            j++;
          }
          if (j >= n) break;

          final marker = flatBytes[j];
          if (marker == 0x00) {
            // Byte-stuffed 0xFF 0x00 literal byte in entropy-coded scan
            idx = j + 1;
            continue;
          } else if (marker >= 0xD0 && marker <= 0xD7) {
            // RSTm restart marker in scan
            idx = j + 1;
            continue;
          } else if (marker == 0xD9) {
            // EOI (End of Image) terminates current frame
            eoiEnd = j + 1;
            idx = j + 1;
            break;
          } else if (marker == 0xD8) {
            // Next frame SOI encountered without explicit EOI
            eoiEnd = idx;
            break;
          } else {
            // Variable length marker segment (e.g. SOF, DQT, DHT, APP)
            if (j + 2 < n && marker != 0xDA) {
              final segLen = (flatBytes[j + 1] << 8) | flatBytes[j + 2];
              if (segLen >= 2 && j + 1 + segLen <= n) {
                idx = j + 1 + segLen;
                continue;
              }
            }
            idx = j + 1;
          }
        } else {
          idx++;
        }
      }

      final frameEnd = (eoiEnd != -1) ? eoiEnd : n;
      if (currentFrame == frameIndex) {
        return Uint8List.sublistView(flatBytes, soiIdx, frameEnd);
      }

      currentFrame++;
    }

    throw FormatException(
      'Could not extract frame $frameIndex (only found $currentFrame frames in stream).',
    );
  }
}
