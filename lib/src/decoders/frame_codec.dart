import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';
import '../pixel_data/pixel_data_info.dart';

/// Internal interface for DICOM transfer syntax frame decoders.
///
/// Encapsulates frame payload extraction from [EncapsulatedPixelData] and
/// decompressing frame byte payloads into uncompressed sample byte arrays
/// ready for `PixelDataDecoder`.
abstract class DicomFrameCodec {
  /// Extracts the exact compressed or raw frame byte payload for [frameIndex]
  /// from the encapsulated sequence.
  Uint8List extractFramePayload(
    EncapsulatedPixelData encapsulatedData, {
    required int frameIndex,
    required int numberOfFrames,
  });

  /// Decompresses [frameBytes] into raw uncompressed sample bytes matching
  /// the image dimensions and pixel format in [info].
  Uint8List decodeFrame({
    required Uint8List frameBytes,
    required PixelDataInfo info,
  });
}
