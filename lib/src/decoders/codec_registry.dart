import 'dart:typed_data';

import '../parsing/dicom_dataset.dart';
import '../parsing/tag.dart';
import '../parsing/transfer_syntax.dart';
import '../pixel_data/pixel_data_info.dart';
import 'frame_codec.dart';
import 'jpeg_baseline_decoder.dart';
import 'jpeg_lossless_decoder.dart';
import 'rle_frame_codec.dart';

/// Internal registry and dispatcher for DICOM transfer syntax codecs.
class CodecRegistry {
  static const Map<String, DicomFrameCodec> _codecs = {
    TransferSyntax.rleLossless: RleFrameCodec(),
    TransferSyntax.jpegLosslessSV1: JpegLosslessDecoder(),
    TransferSyntax.jpegBaseline: JpegBaselineDecoder(),
  };

  /// Returns the [DicomFrameCodec] registered for [transferSyntaxUid],
  /// or null if uncompressed or unregistered.
  static DicomFrameCodec? getCodec(String transferSyntaxUid) {
    final cleanUid = transferSyntaxUid.trim().replaceAll('\x00', '');
    return _codecs[cleanUid];
  }

  /// Whether [transferSyntaxUid] corresponds to a registered decompressor.
  static bool hasCodec(String transferSyntaxUid) {
    return getCodec(transferSyntaxUid) != null;
  }

  /// Checks whether pixel data is encapsulated/compressed (e.g. JPEG 2000, JPEG, RLE).
  static bool isCompressed(Uint8List bytes, String transferSyntaxUid) {
    if (bytes.length >= 2) {
      // JPEG 2000 SOC marker: 0xFF4F or JP2 magic 0x0000000C
      if (bytes[0] == 0xFF && bytes[1] == 0x4F) return true;
      if (bytes[0] == 0x00 &&
          bytes.length >= 4 &&
          bytes[1] == 0x00 &&
          bytes[2] == 0x00 &&
          bytes[3] == 0x0C) {
        return true;
      }
      // JPEG SOI marker: 0xFFD8
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    }
    final details = TransferSyntaxDetails.fromUid(transferSyntaxUid);
    return details.isEncapsulated;
  }

  /// Authoritative extraction and decompression of raw pixel bytes for [frameIndex].
  ///
  /// For compressed datasets (e.g. RLE), uses the registered [DicomFrameCodec].
  /// For uncompressed datasets, extracts the native frame slice.
  static Uint8List extractEffectivePixelBytes(
    DicomDataset dataset, {
    int frameIndex = 0,
  }) {
    final pixelElem = dataset.getElement(DicomTag.pixelData);
    if (pixelElem == null) {
      throw StateError('DICOM Dataset contains no Pixel Data (7FE0,0010).');
    }

    final encData = dataset.encapsulatedData;
    final rawPixelBytes = dataset.pixelDataBytes;

    if (encData != null && encData.fragments.isEmpty) {
      throw const FormatException(
        'Encapsulated Pixel Data (7FE0,0010) contains no item fragments.',
      );
    }

    if (encData == null && (rawPixelBytes == null || rawPixelBytes.isEmpty)) {
      throw StateError('DICOM Dataset contains no Pixel Data (7FE0,0010).');
    }

    final totalFrames = dataset.numberOfFrames;
    if (frameIndex < 0 || (totalFrames > 0 && frameIndex >= totalFrames)) {
      throw RangeError(
        'Invalid frameIndex $frameIndex (total frames: $totalFrames).',
      );
    }

    final tsUid = dataset.transferSyntaxUid;
    final tsDetails = TransferSyntaxDetails.fromUid(tsUid);

    final codec = getCodec(tsUid);
    if (codec != null) {
      if (encData == null) {
        throw FormatException(
          'Invalid compressed DICOM data: Pixel Data (7FE0,0010) is explicit length. '
          '${tsDetails.name} requires encapsulated undefined length data per DICOM PS3.5.',
        );
      }
      final framePayload = codec.extractFramePayload(
        encData,
        frameIndex: frameIndex,
        numberOfFrames: dataset.numberOfFrames,
      );
      final info = PixelDataInfo.fromDataset(dataset);
      return codec.decodeFrame(frameBytes: framePayload, info: info);
    }

    final bytes = rawPixelBytes ?? Uint8List(0);
    if (isCompressed(bytes, tsUid)) {
      throw UnsupportedError(
        'Unsupported Transfer Syntax: ${tsDetails.name} ($tsUid).',
      );
    }

    // Uncompressed frame offset calculation:
    // BytesPerFrame = Rows * Columns * SamplesPerPixel * ceil(BitsAllocated / 8)
    final bytesPerSample = (dataset.bitsAllocated + 7) ~/ 8;
    final bytesPerFrame =
        dataset.rows *
        dataset.columns *
        dataset.samplesPerPixel *
        bytesPerSample;
    final frameStart = frameIndex * bytesPerFrame;
    if (frameStart >= bytes.length && totalFrames > 1) {
      throw FormatException(
        'Frame $frameIndex start offset $frameStart exceeds pixel data length (${bytes.length} bytes).',
      );
    }
    final frameEnd = (frameStart + bytesPerFrame).clamp(
      frameStart,
      bytes.length,
    );
    return (bytesPerFrame > 0 && frameStart < bytes.length)
        ? bytes.sublist(frameStart, frameEnd)
        : bytes;
  }
}
