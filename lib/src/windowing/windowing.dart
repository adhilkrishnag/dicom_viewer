import 'dart:math' as math;
import 'dart:typed_data';

import '../pixel_data/pixel_data_info.dart';
import 'photometric.dart';

/// Pure mathematical transformations for DICOM Rescale and Windowing (Contrast/Brightness).
class Windowing {
  /// Transforms raw stored pixel value [storedValue] to real-world units (e.g. Hounsfield Units)
  /// using Rescale Slope [slope] and Rescale Intercept [intercept].
  static double applyRescale(int storedValue, double slope, double intercept) {
    return storedValue * slope + intercept;
  }

  /// Applies standard linear DICOM VOI Windowing mapping input value [value] to an 8-bit [0..255] display value.
  /// Standard DICOM PS3.3 C.11.2.1.2 linear windowing algorithm.
  static int applyWindow(
    double value,
    double windowCenter,
    double windowWidth,
  ) {
    if (windowWidth <= 1.0) windowWidth = 1.0;

    final minVal = windowCenter - 0.5 - (windowWidth - 1.0) / 2.0;
    final maxVal = windowCenter - 0.5 + (windowWidth - 1.0) / 2.0;

    if (value <= minVal) {
      return 0;
    } else if (value > maxVal) {
      return 255;
    } else {
      final norm = ((value - (windowCenter - 0.5)) / (windowWidth - 1.0) + 0.5);
      return (norm * 255.0).clamp(0.0, 255.0).round();
    }
  }

  /// Calculates default Window Center & Window Width from a list of rescaled pixel values,
  /// excluding optional DICOM Pixel Padding Values (0028,0120 / 0028,0121).
  static Map<String, double> calculateAutoWindow(
    List<double> rescaledValues, {
    List<int>? rawPixels,
    double rescaleSlope = 1.0,
    double rescaleIntercept = 0.0,
    int? pixelPaddingValue,
    int? pixelPaddingRangeLimit,
  }) {
    if (rescaledValues.isEmpty) {
      return {'center': 128.0, 'width': 256.0};
    }

    double minVal = double.infinity;
    double maxVal = -double.infinity;

    final hasPadding = pixelPaddingValue != null && rawPixels != null;
    final padMin =
        hasPadding
            ? (pixelPaddingRangeLimit != null
                ? math.min(pixelPaddingValue, pixelPaddingRangeLimit)
                : pixelPaddingValue)
            : null;
    final padMax =
        hasPadding
            ? (pixelPaddingRangeLimit != null
                ? math.max(pixelPaddingValue, pixelPaddingRangeLimit)
                : pixelPaddingValue)
            : null;

    for (int i = 0; i < rescaledValues.length; i++) {
      if (hasPadding && i < rawPixels.length) {
        final raw = rawPixels[i];
        if (raw >= padMin! && raw <= padMax!) {
          continue; // Skip padding pixels
        }
      }

      final v = rescaledValues[i];
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }

    if (minVal == double.infinity || maxVal == -double.infinity) {
      // All pixels were padding or empty
      for (final v in rescaledValues) {
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }

    if (minVal == maxVal) {
      maxVal = minVal + 1.0;
    }

    final width = maxVal - minVal;
    final center = minVal + width / 2.0;

    return {'center': center, 'width': math.max(1.0, width)};
  }

  /// Converts a decoded raw pixel array into a 32-bit RGBA byte array [Uint8List].
  static Uint8List processPixelData(
    List<int> rawPixels,
    PixelDataInfo info, {
    double? windowCenter,
    double? windowWidth,
    double rescaleSlope = 1.0,
    double rescaleIntercept = 0.0,
  }) {
    final photo = PhotometricInterpretationX.parse(
      info.photometricInterpretation,
    );
    final pixelCount = info.totalPixels;
    final rgbaBytes = Uint8List(pixelCount * 4);

    if (photo.isMonochrome || photo == PhotometricInterpretation.unsupported) {
      // Step 1: Rescale all raw pixel values
      final rescaledValues = List<double>.filled(rawPixels.length, 0.0);
      for (int i = 0; i < rawPixels.length; i++) {
        rescaledValues[i] = applyRescale(
          rawPixels[i],
          rescaleSlope,
          rescaleIntercept,
        );
      }

      // Step 2: Auto-compute window parameters if missing
      double wc = windowCenter ?? 0.0;
      double ww = windowWidth ?? 0.0;

      if (windowCenter == null || windowWidth == null || windowWidth <= 0) {
        final auto = calculateAutoWindow(
          rescaledValues,
          rawPixels: rawPixels,
          rescaleSlope: rescaleSlope,
          rescaleIntercept: rescaleIntercept,
          pixelPaddingValue: info.pixelPaddingValue,
          pixelPaddingRangeLimit: info.pixelPaddingRangeLimit,
        );
        wc = windowCenter ?? auto['center']!;
        ww =
            (windowWidth != null && windowWidth > 0)
                ? windowWidth
                : auto['width']!;
      }

      final isInverted = photo.isInverted;

      // Step 3: Apply windowing and write to RGBA buffer
      for (int i = 0; i < pixelCount; i++) {
        final val = i < rescaledValues.length ? rescaledValues[i] : 0.0;
        var intensity = applyWindow(val, wc, ww);

        if (isInverted) {
          intensity = 255 - intensity;
        }

        final offset = i * 4;
        rgbaBytes[offset] = intensity; // R
        rgbaBytes[offset + 1] = intensity; // G
        rgbaBytes[offset + 2] = intensity; // B
        rgbaBytes[offset + 3] = 255; // A (Opaque)
      }
    } else if (photo == PhotometricInterpretation.rgb) {
      // RGB color mode
      final isPlanarSeparate = info.planarConfiguration == 1;
      for (int i = 0; i < pixelCount; i++) {
        final dstOffset = i * 4;
        int r, g, b;
        if (isPlanarSeparate) {
          r = i < rawPixels.length ? rawPixels[i] : 0;
          g =
              (pixelCount + i) < rawPixels.length
                  ? rawPixels[pixelCount + i]
                  : 0;
          b =
              (2 * pixelCount + i) < rawPixels.length
                  ? rawPixels[2 * pixelCount + i]
                  : 0;
        } else {
          final srcOffset = i * 3;
          r = srcOffset < rawPixels.length ? rawPixels[srcOffset] : 0;
          g = (srcOffset + 1) < rawPixels.length ? rawPixels[srcOffset + 1] : 0;
          b = (srcOffset + 2) < rawPixels.length ? rawPixels[srcOffset + 2] : 0;
        }

        rgbaBytes[dstOffset] = r.clamp(0, 255);
        rgbaBytes[dstOffset + 1] = g.clamp(0, 255);
        rgbaBytes[dstOffset + 2] = b.clamp(0, 255);
        rgbaBytes[dstOffset + 3] = 255;
      }
    } else if (photo == PhotometricInterpretation.ybrFull) {
      // YBR to RGB conversion
      final isPlanarSeparate = info.planarConfiguration == 1;
      for (int i = 0; i < pixelCount; i++) {
        final dstOffset = i * 4;
        int yVal, cbVal, crVal;
        if (isPlanarSeparate) {
          yVal = i < rawPixels.length ? rawPixels[i] : 0;
          cbVal =
              (pixelCount + i) < rawPixels.length
                  ? rawPixels[pixelCount + i]
                  : 0;
          crVal =
              (2 * pixelCount + i) < rawPixels.length
                  ? rawPixels[2 * pixelCount + i]
                  : 0;
        } else {
          final srcOffset = i * 3;
          yVal = srcOffset < rawPixels.length ? rawPixels[srcOffset] : 0;
          cbVal =
              (srcOffset + 1) < rawPixels.length ? rawPixels[srcOffset + 1] : 0;
          crVal =
              (srcOffset + 2) < rawPixels.length ? rawPixels[srcOffset + 2] : 0;
        }

        final double y = yVal.toDouble();
        final double cb = cbVal.toDouble() - 128.0;
        final double cr = crVal.toDouble() - 128.0;

        final int r = (y + 1.402 * cr).round().clamp(0, 255);
        final int g = (y - 0.344136 * cb - 0.714136 * cr).round().clamp(0, 255);
        final int b = (y + 1.772 * cb).round().clamp(0, 255);

        rgbaBytes[dstOffset] = r;
        rgbaBytes[dstOffset + 1] = g;
        rgbaBytes[dstOffset + 2] = b;
        rgbaBytes[dstOffset + 3] = 255;
      }
    } else {
      // Default fallback for other color modes
      for (int i = 0; i < pixelCount; i++) {
        final dstOffset = i * 4;
        final val = i < rawPixels.length ? rawPixels[i].clamp(0, 255) : 0;
        rgbaBytes[dstOffset] = val;
        rgbaBytes[dstOffset + 1] = val;
        rgbaBytes[dstOffset + 2] = val;
        rgbaBytes[dstOffset + 3] = 255;
      }
    }

    return rgbaBytes;
  }
}
