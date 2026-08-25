import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import '../decoders/rle_decoder.dart';
import '../decoders/rle_framing_strategy.dart';
import '../parsing/dicom_dataset.dart';
import '../parsing/tag.dart';
import '../parsing/transfer_syntax.dart';
import '../pixel_data/pixel_data_decoder.dart';
import '../pixel_data/pixel_data_info.dart';
import '../windowing/photometric.dart';

/// Immutable quantitative statistics result for a rectangular Region of Interest (ROI).
///
/// Internal to `dicom_viewer`.
class DicomRoiStatistics {
  /// Creates a [DicomRoiStatistics] result instance.
  const DicomRoiStatistics({
    required this.pixelCount,
    required this.validPixelCount,
    required this.excludedPaddingCount,
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.standardDeviation,
    required this.unit,
    required this.isHounsfield,
    required this.hasValidPixels,
  });

  /// Total number of discrete pixel positions enclosed by the ROI boundary.
  final int pixelCount;

  /// Number of non-padded valid pixel values included in statistics.
  final int validPixelCount;

  /// Number of padding pixels excluded from statistics.
  final int excludedPaddingCount;

  /// Minimum rescaled pixel value among valid pixels.
  final double min;

  /// Maximum rescaled pixel value among valid pixels.
  final double max;

  /// Arithmetic mean of valid rescaled pixels.
  final double mean;

  /// Median (50th percentile) of valid rescaled pixels.
  final double median;

  /// Population standard deviation ($\sigma_N$, denominator $N$) of valid rescaled pixels.
  final double standardDeviation;

  /// Unit string: `'HU'` for explicitly verified CT images, or empty string `''` for non-CT modalities.
  final String unit;

  /// Whether the statistics represent verified Hounsfield Units.
  final bool isHounsfield;

  /// Whether at least one non-padded pixel was present and evaluated.
  final bool hasValidPixels;

  /// Suffix string formatted with a leading space if [unit] is non-empty.
  String get _unitSuffix => unit.isNotEmpty ? ' $unit' : '';

  /// Formatted statistics summary for rendering on ROI measurement overlays.
  List<String> get formattedLines {
    if (!hasValidPixels) {
      return const ['Pixels: 0 valid (All padding)'];
    }

    final meanStr = mean.toStringAsFixed(1);
    final stdDevStr = standardDeviation.toStringAsFixed(1);
    final minStr = min.toStringAsFixed(1);
    final maxStr = max.toStringAsFixed(1);
    final medianStr = median.toStringAsFixed(1);

    return [
      'Mean: $meanStr$_unitSuffix \u00B1 $stdDevStr$_unitSuffix  Min: $minStr$_unitSuffix  Max: $maxStr$_unitSuffix',
      'Median: $medianStr$_unitSuffix  ($validPixelCount px)',
    ];
  }

  /// Accessibility-friendly label for screen readers.
  String get semanticsSummary {
    if (!hasValidPixels) {
      return 'No valid pixels, all pixels are padding';
    }
    final unitLabel = isHounsfield ? ' Hounsfield Units' : '';
    return 'Mean ${mean.toStringAsFixed(1)}$unitLabel, '
        'Standard Deviation ${standardDeviation.toStringAsFixed(1)}$unitLabel, '
        'Minimum ${min.toStringAsFixed(1)}$unitLabel, '
        'Maximum ${max.toStringAsFixed(1)}$unitLabel, '
        'Median ${median.toStringAsFixed(1)}$unitLabel across $validPixelCount pixels';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomRoiStatistics &&
          runtimeType == other.runtimeType &&
          pixelCount == other.pixelCount &&
          validPixelCount == other.validPixelCount &&
          excludedPaddingCount == other.excludedPaddingCount &&
          min == other.min &&
          max == other.max &&
          mean == other.mean &&
          median == other.median &&
          standardDeviation == other.standardDeviation &&
          unit == other.unit &&
          isHounsfield == other.isHounsfield &&
          hasValidPixels == other.hasValidPixels;

  @override
  int get hashCode =>
      pixelCount.hashCode ^
      validPixelCount.hashCode ^
      excludedPaddingCount.hashCode ^
      min.hashCode ^
      max.hashCode ^
      mean.hashCode ^
      median.hashCode ^
      standardDeviation.hashCode ^
      unit.hashCode ^
      isHounsfield.hashCode ^
      hasValidPixels.hashCode;

  @override
  String toString() =>
      'DicomRoiStatistics(pixels: $validPixelCount/$pixelCount, '
      'mean: ${mean.toStringAsFixed(1)}$_unitSuffix, '
      'stdDev: ${standardDeviation.toStringAsFixed(1)}$_unitSuffix, '
      'min: ${min.toStringAsFixed(1)}$_unitSuffix, '
      'max: ${max.toStringAsFixed(1)}$_unitSuffix, '
      'median: ${median.toStringAsFixed(1)}$_unitSuffix, '
      'isHU: $isHounsfield)';
}

/// Internal engine that extracts per-frame stored pixels and calculates quantitative
/// ROI pixel statistics.
///
/// Internal to `dicom_viewer`.
class DicomRoiStatisticsEngine {
  /// Extracts and decodes the mathematical stored pixel values for [frameIndex]
  /// reusing existing package decoders.
  static List<int> extractFramePixels(DicomDataset dataset, int frameIndex) {
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
      if (tsDetails.isEncapsulated) {
        throw UnsupportedError(
          'Unsupported Transfer Syntax: ${tsDetails.name} ($tsUid). v0.2.0 supports uncompressed and RLE Lossless DICOM files.',
        );
      }
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
    return decoder.decode(effectivePixelBytes, info);
  }

  /// Calculates quantitative ROI pixel statistics from the provided [dataset]
  /// and continuous [normalizedRect].
  ///
  /// If [rawPixels] is omitted, decodes the requested [frameIndex] on-demand.
  static DicomRoiStatistics computeStatistics({
    required DicomDataset dataset,
    required Rect normalizedRect,
    required int frameIndex,
    List<int>? rawPixels,
  }) {
    final columns = dataset.columns;
    final rows = dataset.rows;

    if (columns <= 0 || rows <= 0) {
      return const DicomRoiStatistics(
        pixelCount: 0,
        validPixelCount: 0,
        excludedPaddingCount: 0,
        min: 0.0,
        max: 0.0,
        mean: 0.0,
        median: 0.0,
        standardDeviation: 0.0,
        unit: '',
        isHounsfield: false,
        hasValidPixels: false,
      );
    }

    // Deterministic Pixel-Center Inclusion Rule
    final minCol = (normalizedRect.left - 0.5).ceil().clamp(0, columns - 1);
    final maxCol = (normalizedRect.right - 0.5).floor().clamp(0, columns - 1);
    final minRow = (normalizedRect.top - 0.5).ceil().clamp(0, rows - 1);
    final maxRow = (normalizedRect.bottom - 0.5).floor().clamp(0, rows - 1);

    if (minCol > maxCol || minRow > maxRow) {
      return const DicomRoiStatistics(
        pixelCount: 0,
        validPixelCount: 0,
        excludedPaddingCount: 0,
        min: 0.0,
        max: 0.0,
        mean: 0.0,
        median: 0.0,
        standardDeviation: 0.0,
        unit: '',
        isHounsfield: false,
        hasValidPixels: false,
      );
    }

    // Decode frame stored pixels if not already provided
    final pixels = rawPixels ?? extractFramePixels(dataset, frameIndex);

    // Explicit Rescale & HU Eligibility Evaluation
    final slopeElem = dataset.getElement(DicomTag.rescaleSlope);
    final interceptElem = dataset.getElement(DicomTag.rescaleIntercept);
    final explicitSlope = slopeElem?.asDouble;
    final explicitIntercept = interceptElem?.asDouble;

    final hasExplicitSlope =
        explicitSlope != null && explicitSlope.isFinite && explicitSlope > 0.0;
    final hasExplicitIntercept =
        explicitIntercept != null && explicitIntercept.isFinite;
    final isExplicitRescaleValid = hasExplicitSlope && hasExplicitIntercept;

    final photo = PhotometricInterpretationX.parse(
      dataset.photometricInterpretation,
    );
    final isMonochrome = photo.isMonochrome;
    final isCT = dataset.modality.toUpperCase() == 'CT';
    final isHounsfield =
        isCT &&
        isMonochrome &&
        isExplicitRescaleValid &&
        dataset.samplesPerPixel == 1;

    final unit = isHounsfield ? 'HU' : '';

    // Active slope and intercept for numeric transformation
    final double slope = hasExplicitSlope ? explicitSlope : 1.0;
    final double intercept = hasExplicitIntercept ? explicitIntercept : 0.0;

    // Pixel Padding Evaluation
    final padVal = dataset.pixelPaddingValue;
    final padLimit = dataset.pixelPaddingRangeLimit;
    final hasPadding = padVal != null;
    final padMin =
        hasPadding
            ? (padLimit != null ? math.min(padVal, padLimit) : padVal)
            : null;
    final padMax =
        hasPadding
            ? (padLimit != null ? math.max(padVal, padLimit) : padVal)
            : null;

    int totalPixelCount = 0;
    int validCount = 0;
    int excludedPaddingCount = 0;

    double minVal = double.infinity;
    double maxVal = -double.infinity;

    // Welford accumulators for Population Mean & Variance
    double mean = 0.0;
    double m2 = 0.0;

    final validValues = <double>[];

    for (int r = minRow; r <= maxRow; r++) {
      final rowOffset = r * columns;
      for (int c = minCol; c <= maxCol; c++) {
        totalPixelCount++;
        final idx = rowOffset + c;
        if (idx >= pixels.length) continue;

        final stored = pixels[idx];

        // Pixel padding exclusion in stored-pixel space
        if (hasPadding && stored >= padMin! && stored <= padMax!) {
          excludedPaddingCount++;
          continue;
        }

        // Modality Rescale calculation
        final rescaled = stored * slope + intercept;
        validValues.add(rescaled);

        if (rescaled < minVal) minVal = rescaled;
        if (rescaled > maxVal) maxVal = rescaled;

        validCount++;
        final delta = rescaled - mean;
        mean += delta / validCount;
        final delta2 = rescaled - mean;
        m2 += delta * delta2;
      }
    }

    if (validCount == 0) {
      return DicomRoiStatistics(
        pixelCount: totalPixelCount,
        validPixelCount: 0,
        excludedPaddingCount: excludedPaddingCount,
        min: 0.0,
        max: 0.0,
        mean: 0.0,
        median: 0.0,
        standardDeviation: 0.0,
        unit: unit,
        isHounsfield: isHounsfield,
        hasValidPixels: false,
      );
    }

    // Population Standard Deviation (denominator N)
    final populationVariance = m2 / validCount;
    final populationStdDev = math.sqrt(populationVariance);

    // Median calculation via sorting
    validValues.sort();
    double median;
    final mid = validCount ~/ 2;
    if (validCount % 2 == 1) {
      median = validValues[mid];
    } else {
      median = (validValues[mid - 1] + validValues[mid]) / 2.0;
    }

    return DicomRoiStatistics(
      pixelCount: totalPixelCount,
      validPixelCount: validCount,
      excludedPaddingCount: excludedPaddingCount,
      min: minVal,
      max: maxVal,
      mean: mean,
      median: median,
      standardDeviation: populationStdDev,
      unit: unit,
      isHounsfield: isHounsfield,
      hasValidPixels: true,
    );
  }
}
