import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../parsing/dicom_dataset.dart';
import '../parsing/transfer_syntax.dart';
import '../pixel_data/pixel_data_decoder.dart';
import '../pixel_data/pixel_data_info.dart';
import '../windowing/windowing.dart';

/// Renderer converting DICOM Datasets to raw RGBA buffers and Flutter [ui.Image]s.
class DicomRenderer {
  /// Checks whether pixel data is encapsulated/compressed (e.g. JPEG 2000, JPEG, RLE).
  static bool _isCompressed(Uint8List bytes, String transferSyntaxUid) {
    if (bytes.length >= 2) {
      // JPEG 2000 SOC marker: 0xFF4F or JP2 magic 0x0000000C
      if (bytes[0] == 0xFF && bytes[1] == 0x4F) return true;
      if (bytes[0] == 0x00 &&
          bytes[1] == 0x00 &&
          bytes.length >= 4 &&
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

  /// Processes a [DicomDataset] into a 32-bit RGBA pixel byte array [Uint8List].
  static Uint8List renderToRgba(
    DicomDataset dataset, {
    double? windowCenter,
    double? windowWidth,
  }) {
    final rawPixelBytes = dataset.pixelDataBytes;
    if (rawPixelBytes == null || rawPixelBytes.isEmpty) {
      throw StateError('DICOM Dataset contains no Pixel Data (7FE0,0010).');
    }

    final tsDetails = TransferSyntaxDetails.fromUid(dataset.transferSyntaxUid);
    if (_isCompressed(rawPixelBytes, dataset.transferSyntaxUid)) {
      throw UnsupportedError(
        'Unsupported Transfer Syntax: ${tsDetails.name} (${dataset.transferSyntaxUid}). v1 of dicom_viewer supports uncompressed DICOM files (Explicit & Implicit VR Little Endian). Compressed pixel data is planned for v2.',
      );
    }

    final info = PixelDataInfo.fromDataset(dataset);
    const decoder = PixelDataDecoder();
    final rawPixels = decoder.decode(rawPixelBytes, info);

    final wc = windowCenter ?? dataset.windowCenter;
    final ww = windowWidth ?? dataset.windowWidth;

    return Windowing.processPixelData(
      rawPixels,
      info,
      windowCenter: wc,
      windowWidth: ww,
      rescaleSlope: dataset.rescaleSlope,
      rescaleIntercept: dataset.rescaleIntercept,
    );
  }

  /// Converts a [DicomDataset] into a displayable Flutter [ui.Image].
  static Future<ui.Image> renderToImage(
    DicomDataset dataset, {
    double? windowCenter,
    double? windowWidth,
  }) async {
    final rawPixelBytes = dataset.pixelDataBytes;
    if (rawPixelBytes == null || rawPixelBytes.isEmpty) {
      throw StateError('DICOM Dataset contains no Pixel Data (7FE0,0010).');
    }

    final tsDetails = TransferSyntaxDetails.fromUid(dataset.transferSyntaxUid);

    if (_isCompressed(rawPixelBytes, dataset.transferSyntaxUid)) {
      // Check for JPEG 2000 specifically (SOC marker 0xFF4F or JP2 header 0x0000000C)
      final isJpeg2000 =
          (rawPixelBytes.length >= 2 &&
              rawPixelBytes[0] == 0xFF &&
              rawPixelBytes[1] == 0x4F) ||
          (dataset.transferSyntaxUid == TransferSyntax.jpeg2000 ||
              dataset.transferSyntaxUid == TransferSyntax.jpeg2000Lossless);

      if (isJpeg2000) {
        throw UnsupportedError(
          'Unsupported Transfer Syntax: JPEG 2000 (${dataset.transferSyntaxUid}). v1 of dicom_viewer supports uncompressed DICOM files. Compressed pixel data is planned for v2.',
        );
      }

      try {
        final codec = await ui.instantiateImageCodec(rawPixelBytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      } catch (e) {
        throw UnsupportedError(
          'Unsupported Transfer Syntax: ${tsDetails.name} (${dataset.transferSyntaxUid}). v1 of dicom_viewer supports uncompressed DICOM files (Explicit & Implicit VR Little Endian). Compressed pixel data is planned for v2.',
        );
      }
    }

    final rgbaBytes = renderToRgba(
      dataset,
      windowCenter: windowCenter,
      windowWidth: windowWidth,
    );

    final width = dataset.columns;
    final height = dataset.rows;

    if (width <= 0 || height <= 0) {
      throw StateError('Invalid image dimensions: ${width}x$height');
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaBytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    return completer.future;
  }
}
