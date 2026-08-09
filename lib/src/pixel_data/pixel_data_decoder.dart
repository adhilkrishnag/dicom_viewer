import 'dart:typed_data';

import 'pixel_data_info.dart';

/// Raw DICOM Pixel Data decoder for uncompressed explicit/implicit transfer syntaxes.
class PixelDataDecoder {
  const PixelDataDecoder();

  /// Decodes raw DICOM bytes into an array of scalar pixel values.
  List<int> decode(Uint8List rawBytes, PixelDataInfo info) {
    if (rawBytes.isEmpty) {
      return const [];
    }

    final totalPixelCount = info.totalPixels * info.samplesPerPixel;
    final pixels = List<int>.filled(totalPixelCount, 0);
    final bd = ByteData.sublistView(rawBytes);

    final mask = (1 << info.bitsStored) - 1;
    final signBit = 1 << info.highBit;

    final endian = info.isLittleEndian ? Endian.little : Endian.big;

    if (info.bitsAllocated == 8) {
      final count =
          rawBytes.length < totalPixelCount ? rawBytes.length : totalPixelCount;
      for (int i = 0; i < count; i++) {
        var val = rawBytes[i];
        val = val & mask;
        if (info.isSigned && (val & signBit) != 0) {
          // Sign extension for 8-bit signed integer
          val = val | ~mask;
        }
        pixels[i] = val;
      }
    } else if (info.bitsAllocated == 16) {
      final availableWords = rawBytes.length ~/ 2;
      final count =
          availableWords < totalPixelCount ? availableWords : totalPixelCount;

      for (int i = 0; i < count; i++) {
        final rawVal = bd.getUint16(i * 2, endian);
        // Apply bits stored mask
        var val = rawVal & mask;

        // Apply sign extension if 2's complement signed integer
        if (info.isSigned && (val & signBit) != 0) {
          val = val | ~mask;
        }
        pixels[i] = val;
      }
    } else if (info.bitsAllocated == 32) {
      final availableDwords = rawBytes.length ~/ 4;
      final count =
          availableDwords < totalPixelCount ? availableDwords : totalPixelCount;

      for (int i = 0; i < count; i++) {
        final rawVal = bd.getUint32(i * 4, endian);
        var val = rawVal & mask;
        if (info.isSigned && (val & signBit) != 0) {
          val = val | ~mask;
        }
        pixels[i] = val;
      }
    } else {
      throw UnsupportedError(
        'Unsupported bitsAllocated: ${info.bitsAllocated}',
      );
    }

    return pixels;
  }
}
