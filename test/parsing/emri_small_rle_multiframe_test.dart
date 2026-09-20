import 'dart:io';
import 'dart:typed_data';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/rle_frame_codec.dart';
import 'package:dicom_viewer/src/geometry/dicom_probe_painter.dart';
import 'package:dicom_viewer/src/geometry/dicom_roi_statistics_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int computeAdler32(Uint8List bytes) {
  var a = 1;
  var b = 0;
  const mod = 65521;
  for (var i = 0; i < bytes.length; i++) {
    a = (a + bytes[i]) % mod;
    b = (b + a) % mod;
  }
  return (b << 16) | a;
}

void main() {
  group('Real 10-Frame RLE Fixture Validation (emri_small_RLE.dcm)', () {
    late File file;
    late Uint8List bytes;
    late DicomDataset dataset;

    setUpAll(() async {
      file = File('test/fixtures/rle/emri_small_RLE.dcm');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'emri_small_RLE.dcm fixture must exist in test/fixtures/rle/',
      );
      bytes = await file.readAsBytes();
      dataset = DicomDataset.fromBytes(bytes);
    });

    test('1. Phase 7: Independent Metadata & Structure Verification', () {
      // Transfer Syntax: RLE Lossless (1.2.840.10008.1.2.5)
      expect(dataset.transferSyntaxUid, equals(TransferSyntax.rleLossless));
      expect(dataset.transferSyntaxUid, equals('1.2.840.10008.1.2.5'));

      // Multi-frame & Dimensions
      expect(dataset.numberOfFrames, equals(10));
      expect(dataset.rows, equals(64));
      expect(dataset.columns, equals(64));

      // Pixel Format
      expect(dataset.samplesPerPixel, equals(1));
      expect(dataset.photometricInterpretation, equals('MONOCHROME2'));
      expect(dataset.bitsAllocated, equals(16));
      expect(dataset.bitsStored, equals(12));
      expect(dataset.highBit, equals(11));
      expect(dataset.pixelRepresentation, equals(0)); // Unsigned

      // Planar Configuration: Not applicable or 0 for 1-sample grayscale
      expect(dataset.planarConfiguration, anyOf(isNull, equals(0)));

      // Encapsulated Pixel Data Structure
      final encData = dataset.encapsulatedData;
      expect(encData, isNotNull);
      expect(
        encData!.botOffsets.length,
        equals(10),
        reason: 'Basic Offset Table contains 10 offsets for 10 frames',
      );
      expect(
        encData.fragments.length,
        equals(10),
        reason: 'Encapsulated stream contains 10 item fragments',
      );

      // Expected Frame Byte Lengths:
      // 64 * 64 * 2 bytes = 8,192 raw bytes per frame
      // 64 * 64 pixels = 4,096 scalar pixel values
      // 64 * 64 * 4 bytes = 16,384 RGBA bytes per rendered frame
      const expectedRawBytes = 64 * 64 * 2;
      expect(expectedRawBytes, equals(8192));
    });

    test('2. Phase 8 & 9: All 10 Frames Decoding, Verification & Isolation', () async {
      final frameRawChecksums = <int>[];
      final frameRgbaChecksums = <int>[];
      final frameRawPixelsList = <List<int>>[];
      final frameStats = <Map<String, dynamic>>[];
      const codec = RleFrameCodec();
      final info = PixelDataInfo.fromDataset(dataset);

      for (var frame = 0; frame < 10; frame++) {
        // Step A: Extract and decode through RLE frame codec directly
        final payload = codec.extractFramePayload(
          dataset.encapsulatedData!,
          frameIndex: frame,
          numberOfFrames: dataset.numberOfFrames,
        );
        expect(payload.isNotEmpty, isTrue);

        final decodedBytes = codec.decodeFrame(frameBytes: payload, info: info);
        expect(
          decodedBytes.length,
          equals(64 * 64 * 2),
          reason: 'Frame $frame decoded raw buffer length must be 8,192 bytes',
        );

        // Step B: Decode via DicomRoiStatisticsEngine.extractFramePixels
        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          frame,
        );
        expect(
          rawPixels.length,
          equals(64 * 64),
          reason: 'Frame $frame extracted scalar pixels must be 4,096 samples',
        );
        frameRawPixelsList.add(rawPixels);

        // Step C: Render to RGBA buffer
        final rgbaBytes = DicomRenderer.renderToRgba(
          dataset,
          frameIndex: frame,
        );
        expect(
          rgbaBytes.length,
          equals(64 * 64 * 4),
          reason: 'Frame $frame RGBA buffer length must be 16,384 bytes',
        );

        // Step D: Render to ui.Image
        final image = await DicomRenderer.renderToImage(
          dataset,
          frameIndex: frame,
        );
        expect(image.width, equals(64));
        expect(image.height, equals(64));

        // Step E: Determinism check (decoding same frame again produces byte-identical output)
        final reDecodedBytes = codec.decodeFrame(
          frameBytes: payload,
          info: info,
        );
        expect(
          reDecodedBytes,
          equals(decodedBytes),
          reason: 'Frame $frame decoding must be 100% deterministic',
        );

        // Calculate Adler-32 checksums and statistical metrics for frame isolation evidence
        final rawChecksum = computeAdler32(decodedBytes);
        final rgbaChecksum = computeAdler32(rgbaBytes);
        frameRawChecksums.add(rawChecksum);
        frameRgbaChecksums.add(rgbaChecksum);

        var minVal = rawPixels.first;
        var maxVal = rawPixels.first;
        var sumVal = 0.0;
        var nonZeroCount = 0;
        for (final px in rawPixels) {
          if (px < minVal) minVal = px;
          if (px > maxVal) maxVal = px;
          sumVal += px;
          if (px > 0) nonZeroCount++;
        }
        final meanVal = sumVal / rawPixels.length;

        frameStats.add({
          'frame': frame,
          'min': minVal,
          'max': maxVal,
          'mean': meanVal,
          'nonZero': nonZeroCount,
          'rawChecksum': '0x${rawChecksum.toRadixString(16).padLeft(8, '0')}',
          'rgbaChecksum': '0x${rgbaChecksum.toRadixString(16).padLeft(8, '0')}',
        });
      }

      // Print evidence summary table for reporting
      for (final s in frameStats) {
        // ignore: avoid_print
        print(
          'FRAME ${s['frame']}: min=${s['min']}, max=${s['max']}, mean=${(s['mean'] as double).toStringAsFixed(2)}, '
          'nonZero=${s['nonZero']}, rawAdler=${s['rawChecksum']}, rgbaAdler=${s['rgbaChecksum']}',
        );
      }

      // Verify Frame Isolation:
      // Every frame must have a UNIQUE checksum (no duplicate or repeated frames)
      final uniqueRawChecksums = frameRawChecksums.toSet();
      expect(
        uniqueRawChecksums.length,
        equals(10),
        reason: 'All 10 frames must have distinct decoded raw pixel buffers',
      );

      final uniqueRgbaChecksums = frameRgbaChecksums.toSet();
      expect(
        uniqueRgbaChecksums.length,
        equals(10),
        reason: 'All 10 frames must have distinct rendered RGBA buffers',
      );

      // Verify pairwise difference count between consecutive frames
      for (var f = 0; f < 9; f++) {
        final currentPixels = frameRawPixelsList[f];
        final nextPixels = frameRawPixelsList[f + 1];
        var diffPixels = 0;
        for (var i = 0; i < currentPixels.length; i++) {
          if (currentPixels[i] != nextPixels[i]) {
            diffPixels++;
          }
        }
        expect(
          diffPixels,
          greaterThan(100),
          reason:
              'Consecutive frames $f and ${f + 1} must have significant anatomical difference',
        );
      }
    });

    test('3. Phase 10: RLE Quantitative ROI Statistics Across Multiple Frames', () {
      // Compute ROI on Frame 0, Frame 4, and Frame 9 in the anatomical region (20,20 to 44,44)
      const testRect = Rect.fromLTRB(20.0, 20.0, 44.0, 44.0);

      final stats0 = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: testRect,
        frameIndex: 0,
      );
      final stats4 = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: testRect,
        frameIndex: 4,
      );
      final stats9 = DicomRoiStatisticsEngine.computeStatistics(
        dataset: dataset,
        normalizedRect: testRect,
        frameIndex: 9,
      );

      expect(stats0.validPixelCount, equals(24 * 24));
      expect(stats4.validPixelCount, equals(24 * 24));
      expect(stats9.validPixelCount, equals(24 * 24));

      expect(stats0.isHounsfield, isFalse);
      expect(stats0.unit, isEmpty);

      // Verify stats differ across different frames
      expect(stats0.mean, isNot(equals(stats4.mean)));
      expect(stats4.mean, isNot(equals(stats9.mean)));
      expect(stats0.mean, isNot(equals(stats9.mean)));

      // ignore: avoid_print
      print(
        'ROI Frame 0 Mean: ${stats0.mean.toStringAsFixed(2)}, Min: ${stats0.min}, Max: ${stats0.max}',
      );
      // ignore: avoid_print
      print(
        'ROI Frame 4 Mean: ${stats4.mean.toStringAsFixed(2)}, Min: ${stats4.min}, Max: ${stats4.max}',
      );
      // ignore: avoid_print
      print(
        'ROI Frame 9 Mean: ${stats9.mean.toStringAsFixed(2)}, Min: ${stats9.min}, Max: ${stats9.max}',
      );
    });

    test(
      '4. Phase 10: Pixel Probe Across Multiple Frames on emri_small_RLE.dcm',
      () {
        // Evaluate probe at center pixel (32, 32) on Frame 0, Frame 4, and Frame 9
        final rawPixels0 = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          0,
        );
        final rawPixels4 = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          4,
        );
        final rawPixels9 = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          9,
        );

        final probe0 = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 32,
          pixelRow: 32,
          rawPixels: rawPixels0,
        );
        final probe4 = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 32,
          pixelRow: 32,
          rawPixels: rawPixels4,
        );
        final probe9 = DicomProbeResult.evaluate(
          dataset: dataset,
          pixelColumn: 32,
          pixelRow: 32,
          rawPixels: rawPixels9,
        );

        expect(probe0.isInside, isTrue);
        expect(probe4.isInside, isTrue);
        expect(probe9.isInside, isTrue);

        expect(probe0.storedValue, isNotNull);
        expect(probe4.storedValue, isNotNull);
        expect(probe9.storedValue, isNotNull);

        // ignore: avoid_print
        print('Probe (32,32) Frame 0 Stored: ${probe0.storedValue}');
        // ignore: avoid_print
        print('Probe (32,32) Frame 4 Stored: ${probe4.storedValue}');
        // ignore: avoid_print
        print('Probe (32,32) Frame 9 Stored: ${probe9.storedValue}');

        // The center pixel across MRI slices differs
        expect(
          probe0.storedValue != probe4.storedValue ||
              probe4.storedValue != probe9.storedValue,
          isTrue,
        );
      },
    );

    test('5. Phase 8: Out-of-Bounds Frame Range Verification', () {
      expect(
        () => DicomRenderer.renderToRgba(dataset, frameIndex: -1),
        throwsRangeError,
      );
      expect(
        () => DicomRenderer.renderToRgba(dataset, frameIndex: 10),
        throwsRangeError,
      );
      expect(
        () => DicomRoiStatisticsEngine.extractFramePixels(dataset, -1),
        throwsRangeError,
      );
      expect(
        () => DicomRoiStatisticsEngine.extractFramePixels(dataset, 10),
        throwsRangeError,
      );
    });
  });
}
