import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';
import '../pixel_data/pixel_data_info.dart';
import 'frame_codec.dart';
import 'rle_decoder.dart';
import 'rle_framing_strategy.dart';

/// Internal [DicomFrameCodec] implementation for DICOM PS3.5 Annex G RLE Lossless.
class RleFrameCodec implements DicomFrameCodec {
  /// Creates a const [RleFrameCodec] instance.
  const RleFrameCodec();

  @override
  Uint8List extractFramePayload(
    EncapsulatedPixelData encapsulatedData, {
    required int frameIndex,
    required int numberOfFrames,
  }) {
    return RleFramingStrategy.extractFramePayload(
      encapsulatedData,
      frameIndex: frameIndex,
      numberOfFrames: numberOfFrames,
    );
  }

  @override
  Uint8List decodeFrame({
    required Uint8List frameBytes,
    required PixelDataInfo info,
  }) {
    return RleDecoder.decodeFrame(
      rleFrameBytes: frameBytes,
      width: info.columns,
      height: info.rows,
      bitsAllocated: info.bitsAllocated,
      samplesPerPixel: info.samplesPerPixel,
    );
  }
}
