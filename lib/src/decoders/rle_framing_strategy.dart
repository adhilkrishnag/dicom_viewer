import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';

/// Transfer Syntax specific framing strategy for DICOM PS3.5 Annex G RLE Lossless.
class RleFramingStrategy {
  /// Extracts the exact frame byte payload for [frameIndex] per DICOM PS3.5 Annex G rules.
  ///
  /// Specification Rules (DICOM PS3.5 Annex G Section G.2):
  /// - For multi-frame images ($numberOfFrames > 1$), each frame shall be contained
  ///   in one and only one Item (Fragment).
  /// - For single-frame images ($numberOfFrames == 1$), the image payload is contained
  ///   in one or more fragments.
  static Uint8List extractFramePayload(
    EncapsulatedPixelData encapsulatedData, {
    required int frameIndex,
    required int numberOfFrames,
  }) {
    if (frameIndex < 0 || frameIndex >= numberOfFrames) {
      throw RangeError(
        'Invalid frameIndex $frameIndex (total frames: $numberOfFrames).',
      );
    }

    final fragments = encapsulatedData.fragments;
    if (fragments.isEmpty) {
      throw StateError(
        'Encapsulated RLE pixel data contains no item fragments.',
      );
    }

    // --- Validate Basic Offset Table if Populated ---
    if (encapsulatedData.botOffsets.isNotEmpty) {
      if (encapsulatedData.botOffsets.length != numberOfFrames) {
        throw FormatException(
          'Basic Offset Table entry count (${encapsulatedData.botOffsets.length}) '
          'does not match numberOfFrames ($numberOfFrames).',
        );
      }

      for (int i = 0; i < encapsulatedData.botOffsets.length - 1; i++) {
        if (encapsulatedData.botOffsets[i] >
            encapsulatedData.botOffsets[i + 1]) {
          throw const FormatException(
            'Invalid Basic Offset Table: offsets are not non-decreasing.',
          );
        }
      }

      for (int i = 0; i < encapsulatedData.botOffsets.length; i++) {
        if (i < fragments.length) {
          if (encapsulatedData.botOffsets[i] != fragments[i].relativeTagStart) {
            throw FormatException(
              'Basic Offset Table entry $i (${encapsulatedData.botOffsets[i]}) '
              'does not match fragment relative offset (${fragments[i].relativeTagStart}).',
            );
          }
        }
      }
    }

    // --- Single-Frame DICOM Image (numberOfFrames == 1) ---
    if (numberOfFrames == 1) {
      if (fragments.length == 1) {
        // Zero-copy slice
        return fragments[0].payload;
      }
      // Single-frame with multiple fragments: concatenate fragments into frame payload
      return encapsulatedData.flatBytes;
    }

    // --- Multi-Frame RLE Image (numberOfFrames > 1) ---
    // DICOM PS3.5 Annex G Section G.2 Rule: Each multi-frame RLE frame must be contained
    // in exactly one Fragment (fragments.length == numberOfFrames).
    if (fragments.length != numberOfFrames) {
      throw FormatException(
        'DICOM PS3.5 Annex G Violation: RLE Lossless multi-frame image has '
        '${fragments.length} fragments for $numberOfFrames frames. '
        'Per Annex G Section G.2, each RLE frame must be contained in exactly one Fragment.',
      );
    }

    // Zero-copy slice for requested frame
    return fragments[frameIndex].payload;
  }
}
