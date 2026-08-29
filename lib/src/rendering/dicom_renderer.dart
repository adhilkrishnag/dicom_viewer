import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../decoders/codec_registry.dart';
import '../parsing/dicom_dataset.dart';
import '../pixel_data/pixel_data_decoder.dart';
import '../pixel_data/pixel_data_info.dart';
import '../windowing/palette_color_lut.dart';
import '../windowing/photometric.dart';
import '../windowing/windowing.dart';

/// Renderer converting DICOM Datasets to raw RGBA buffers and Flutter [ui.Image]s.
class DicomRenderer {
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
    final effectivePixelBytes = CodecRegistry.extractEffectivePixelBytes(
      dataset,
      frameIndex: frameIndex,
    );

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
