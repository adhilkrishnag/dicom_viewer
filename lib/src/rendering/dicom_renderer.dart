import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../decoders/rle_decoder.dart';
import '../decoders/rle_framing_strategy.dart';
import '../parsing/dicom_dataset.dart';
import '../parsing/tag.dart';
import '../parsing/transfer_syntax.dart';
import '../pixel_data/pixel_data_decoder.dart';
import '../pixel_data/pixel_data_info.dart';
import '../windowing/palette_color_lut.dart';
import '../windowing/photometric.dart';
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

  /// Extracts frame payload bytes from DICOM encapsulated Pixel Data (7FE0,0010).
  static Uint8List extractEncapsulatedFrame(
    Uint8List pixelBytes, {
    int frameIndex = 0,
  }) {
    if (pixelBytes.length < 8) return pixelBytes;

    final bd = ByteData.sublistView(pixelBytes);
    final group = bd.getUint16(0, Endian.little);
    final elem = bd.getUint16(2, Endian.little);

    if (group != 0xFFFE || elem != 0xE000) {
      return pixelBytes;
    }

    int offset = 0;
    int currentFrame = 0;

    while (offset + 8 <= pixelBytes.length) {
      final g = bd.getUint16(offset, Endian.little);
      final e = bd.getUint16(offset + 2, Endian.little);
      final itemLen = bd.getUint32(offset + 4, Endian.little);
      offset += 8;

      if (g == 0xFFFE && e == 0xE000) {
        if (offset == 8) {
          // Basic Offset Table (BOT) - skip
          offset += itemLen;
          continue;
        }

        if (currentFrame == frameIndex) {
          final end = (offset + itemLen).clamp(offset, pixelBytes.length);
          return pixelBytes.sublist(offset, end);
        }
        currentFrame++;
        offset += itemLen;
      } else if (g == 0xFFFE && e == 0xE0DD) {
        break;
      } else {
        offset += 2;
      }
    }

    return pixelBytes;
  }

  /// Processes a [DicomDataset] frame into a 32-bit RGBA pixel byte array [Uint8List].
  static Uint8List renderToRgba(
    DicomDataset dataset, {
    int frameIndex = 0,
    double? windowCenter,
    double? windowWidth,
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

    Uint8List effectivePixelBytes;

    if (tsUid == TransferSyntax.rleLossless) {
      if (encData == null) {
        throw const FormatException(
          'Invalid RLE DICOM data: Pixel Data (7FE0,0010) is explicit length. '
          'RLE Lossless requires encapsulated undefined length data per DICOM PS3.5.',
        );
      }
      final framePayload = RleFramingStrategy.extractFramePayload(
        encData,
        frameIndex: frameIndex,
        numberOfFrames: dataset.numberOfFrames,
      );
      effectivePixelBytes = RleDecoder.decodeFrame(
        rleFrameBytes: framePayload,
        width: dataset.columns,
        height: dataset.rows,
        bitsAllocated: dataset.bitsAllocated,
        samplesPerPixel: dataset.samplesPerPixel,
      );
    } else {
      final bytes = rawPixelBytes ?? Uint8List(0);
      if (_isCompressed(bytes, tsUid)) {
        throw UnsupportedError(
          'Unsupported Transfer Syntax: ${tsDetails.name} ($tsUid). v0.2.0 supports uncompressed and RLE Lossless DICOM files.',
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
      effectivePixelBytes =
          (bytesPerFrame > 0 && frameStart < bytes.length)
              ? bytes.sublist(frameStart, frameEnd)
              : bytes;
    }

    final info = PixelDataInfo.fromDataset(dataset);
    const decoder = PixelDataDecoder();
    final rawPixels = decoder.decode(effectivePixelBytes, info);

    final wc = windowCenter ?? dataset.windowCenter ?? 128.0;
    final ww = windowWidth ?? dataset.windowWidth ?? 256.0;

    PaletteColorLut? paletteLut;
    final photo = PhotometricInterpretationX.parse(
      info.photometricInterpretation,
    );
    if (photo == PhotometricInterpretation.paletteColor) {
      paletteLut = PaletteColorLut.fromDataset(dataset);
    }

    return Windowing.processPixelData(
      rawPixels,
      info,
      windowCenter: wc,
      windowWidth: ww,
      rescaleSlope: dataset.rescaleSlope,
      rescaleIntercept: dataset.rescaleIntercept,
      paletteLut: paletteLut,
    );
  }

  /// Converts a [DicomDataset] frame into a displayable Flutter [ui.Image].
  static Future<ui.Image> renderToImage(
    DicomDataset dataset, {
    int frameIndex = 0,
    double? windowCenter,
    double? windowWidth,
  }) async {
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

    final tsUid = dataset.transferSyntaxUid;
    final tsDetails = TransferSyntaxDetails.fromUid(tsUid);

    final bytes = rawPixelBytes ?? Uint8List(0);
    if (tsUid != TransferSyntax.rleLossless && _isCompressed(bytes, tsUid)) {
      throw UnsupportedError(
        'Unsupported Transfer Syntax: ${tsDetails.name} ($tsUid). v0.2.0 supports uncompressed and RLE Lossless DICOM files.',
      );
    }

    final rgbaBytes = renderToRgba(
      dataset,
      frameIndex: frameIndex,
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
