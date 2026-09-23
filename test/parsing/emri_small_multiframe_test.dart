import 'dart:io';
import 'dart:typed_data';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
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
  group('Real 10-Frame Uncompressed Fixture Validation (emri_small.dcm)', () {
    late File file;
    late Uint8List bytes;
    late DicomDataset dataset;

    late File rleFile;
    late Uint8List rleBytes;
    late DicomDataset rleDataset;

    setUpAll(() async {
      file = File('test/fixtures/uncompressed/emri_small.dcm');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'emri_small.dcm fixture must exist in test/fixtures/uncompressed/',
      );
      bytes = await file.readAsBytes();
      dataset = DicomDataset.fromBytes(bytes);

      rleFile = File('test/fixtures/rle/emri_small_RLE.dcm');
      expect(
        rleFile.existsSync(),
        isTrue,
        reason: 'emri_small_RLE.dcm fixture must exist in test/fixtures/rle/',
      );
      rleBytes = await rleFile.readAsBytes();
      rleDataset = DicomDataset.fromBytes(rleBytes);
    });

    test('1. Test Group A: Metadata & Structure Verification', () {
      // Transfer Syntax: Explicit VR Little Endian (1.2.840.10008.1.2.1)
      expect(
        dataset.transferSyntaxUid,
        equals(TransferSyntax.explicitVRLittleEndian),
      );
      expect(dataset.transferSyntaxUid, equals('1.2.840.10008.1.2.1'));

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

      // Uncompressed Native Pixel Data Presence
      expect(dataset.encapsulatedData, isNull);
      expect(dataset.pixelDataBytes, isNotNull);

      // Expected Byte Lengths derived independently from DICOM metadata:
      // Frame byte size: 64 cols * 64 rows * 1 sample * 2 bytes = 8,192 bytes
      // Total pixel data size: 8,192 * 10 frames = 81,920 bytes
      const expectedFrameBytes = 64 * 64 * 1 * 2;
      const expectedTotalPixelBytes = expectedFrameBytes * 10;
      expect(expectedFrameBytes, equals(8192));
      expect(expectedTotalPixelBytes, equals(81920));
      expect(dataset.pixelDataBytes!.length, equals(expectedTotalPixelBytes));
    });

    test('2. Test Group B: All 10 Frames Native Extraction', () {
      for (var frame = 0; frame < 10; frame++) {
        final frameBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
          frameIndex: frame,
        );
        expect(
          frameBytes.length,
          equals(8192),
          reason: 'Frame $frame native byte length must be exactly 8,192 bytes',
        );

        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          frame,
        );
        expect(
          rawPixels.length,
          equals(4096),
          reason: 'Frame $frame scalar pixel count must be exactly 4,096',
        );
      }
    });

    test('3. Test Group C: Frame Isolation Evidence Across All 10 Frames', () {
      final frameRawChecksums = <int>[];
      final frameRgbaChecksums = <int>[];
      final frameRawPixelsList = <List<int>>[];
      final frameStats = <Map<String, dynamic>>[];

      for (var frame = 0; frame < 10; frame++) {
        final frameBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
          frameIndex: frame,
        );
        final rawPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          frame,
        );
        final rgbaBytes = DicomRenderer.renderToRgba(
          dataset,
          frameIndex: frame,
        );

        frameRawPixelsList.add(rawPixels);

        final rawChecksum = computeAdler32(frameBytes);
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

      for (final s in frameStats) {
        // ignore: avoid_print
        print(
          'UNCOMPRESSED FRAME ${s['frame']}: min=${s['min']}, max=${s['max']}, '
          'mean=${(s['mean'] as double).toStringAsFixed(2)}, nonZero=${s['nonZero']}, '
          'rawAdler=${s['rawChecksum']}, rgbaAdler=${s['rgbaChecksum']}',
        );
      }

      // Frame Isolation: all 10 frames have unique native buffers and unique rendered buffers
      final uniqueRaw = frameRawChecksums.toSet();
      expect(
        uniqueRaw.length,
        equals(10),
        reason: 'All 10 frames must produce distinct native pixel buffers',
      );

      final uniqueRgba = frameRgbaChecksums.toSet();
      expect(
        uniqueRgba.length,
        equals(10),
        reason: 'All 10 frames must produce distinct rendered RGBA buffers',
      );

      // Pairwise difference between adjacent frames
      for (var f = 0; f < 9; f++) {
        final curr = frameRawPixelsList[f];
        final next = frameRawPixelsList[f + 1];
        var diffCount = 0;
        for (var i = 0; i < curr.length; i++) {
          if (curr[i] != next[i]) diffCount++;
        }
        expect(
          diffCount,
          greaterThan(100),
          reason:
              'Consecutive frames $f and ${f + 1} must exhibit meaningful anatomical differences',
        );
      }
    });

    test('4. Test Group D: Deterministic Frame Extraction', () {
      for (var frame = 0; frame < 10; frame++) {
        final firstBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
          frameIndex: frame,
        );
        final secondBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
          frameIndex: frame,
        );
        expect(
          firstBytes,
          equals(secondBytes),
          reason: 'Frame $frame native extraction must be 100% deterministic',
        );

        final firstPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          frame,
        );
        final secondPixels = DicomRoiStatisticsEngine.extractFramePixels(
          dataset,
          frame,
        );
        expect(
          firstPixels,
          equals(secondPixels),
          reason: 'Frame $frame scalar extraction must be 100% deterministic',
        );
      }
    });

    test('5. Test Group E: Out-of-Bounds Frame Range Verification', () {
      expect(
        () => CodecRegistry.extractEffectivePixelBytes(dataset, frameIndex: -1),
        throwsRangeError,
      );
      expect(
        () => CodecRegistry.extractEffectivePixelBytes(dataset, frameIndex: 10),
        throwsRangeError,
      );
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

    test(
      '6. Test Group F: Real Fixture Rendering (RGBA and ui.Image)',
      () async {
        for (var frame = 0; frame < 10; frame++) {
          final rgba = DicomRenderer.renderToRgba(dataset, frameIndex: frame);
          expect(
            rgba.length,
            equals(16384),
            reason:
                'Frame $frame RGBA byte length must be 16,384 bytes (64x64x4)',
          );

          final img = await DicomRenderer.renderToImage(
            dataset,
            frameIndex: frame,
          );
          expect(img.width, equals(64));
          expect(img.height, equals(64));
        }
      },
    );

    test('7. Test Group G: Quantitative ROI Statistics Across Multiple Frames', () {
      // Test anatomical region (20,20 to 44,44) - 24x24 = 576 pixels
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

      // Verify independently from raw pixels for Frame 0
      final raw0 = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);
      var manualSum0 = 0.0;
      var manualMin0 = 65535;
      var manualMax0 = 0;
      var count0 = 0;
      for (var y = 20; y < 44; y++) {
        for (var x = 20; x < 44; x++) {
          final val = raw0[y * 64 + x];
          manualSum0 += val;
          if (val < manualMin0) manualMin0 = val;
          if (val > manualMax0) manualMax0 = val;
          count0++;
        }
      }
      expect(stats0.min, equals(manualMin0.toDouble()));
      expect(stats0.max, equals(manualMax0.toDouble()));
      expect(stats0.mean, closeTo(manualSum0 / count0, 1e-4));

      // Stats differ across anatomical slices
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

    test('8. Test Group H: Pixel Probe Across Multiple Frames', () {
      final raw0 = DicomRoiStatisticsEngine.extractFramePixels(dataset, 0);
      final raw4 = DicomRoiStatisticsEngine.extractFramePixels(dataset, 4);
      final raw9 = DicomRoiStatisticsEngine.extractFramePixels(dataset, 9);

      final probe0 = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 32,
        pixelRow: 32,
        rawPixels: raw0,
      );
      final probe4 = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 32,
        pixelRow: 32,
        rawPixels: raw4,
      );
      final probe9 = DicomProbeResult.evaluate(
        dataset: dataset,
        pixelColumn: 32,
        pixelRow: 32,
        rawPixels: raw9,
      );

      expect(probe0.isInside, isTrue);
      expect(probe4.isInside, isTrue);
      expect(probe9.isInside, isTrue);

      // Verify probe stored value matches raw pixel at (32, 32)
      expect(probe0.storedValue, equals(raw0[32 * 64 + 32]));
      expect(probe4.storedValue, equals(raw4[32 * 64 + 32]));
      expect(probe9.storedValue, equals(raw9[32 * 64 + 32]));

      // Verify probe values differ across slices
      expect(
        probe0.storedValue != probe4.storedValue ||
            probe4.storedValue != probe9.storedValue,
        isTrue,
      );

      // ignore: avoid_print
      print('Probe (32,32) Frame 0 Stored: ${probe0.storedValue}');
      // ignore: avoid_print
      print('Probe (32,32) Frame 4 Stored: ${probe4.storedValue}');
      // ignore: avoid_print
      print('Probe (32,32) Frame 9 Stored: ${probe9.storedValue}');
    });

    test(
      '9. Test Group I: Cross-Transfer-Syntax Pixel Equivalence (emri_small.dcm vs emri_small_RLE.dcm)',
      () {
        // EVIDENCE CLASSIFICATION: CROSS-TRANSFER-SYNTAX CONSISTENCY
        // (NOT an independent oracle, as both fixtures represent the same underlying image data).
        var matchingFrames = 0;

        for (var frame = 0; frame < 10; frame++) {
          final nativeBytes = CodecRegistry.extractEffectivePixelBytes(
            dataset,
            frameIndex: frame,
          );
          final rleBytes = CodecRegistry.extractEffectivePixelBytes(
            rleDataset,
            frameIndex: frame,
          );

          expect(
            nativeBytes,
            equals(rleBytes),
            reason:
                'Frame $frame native uncompressed bytes must match RLE-decoded bytes bit-for-bit',
          );

          final nativePixels = DicomRoiStatisticsEngine.extractFramePixels(
            dataset,
            frame,
          );
          final rlePixels = DicomRoiStatisticsEngine.extractFramePixels(
            rleDataset,
            frame,
          );

          expect(
            nativePixels,
            equals(rlePixels),
            reason:
                'Frame $frame scalar pixels must match between uncompressed and RLE fixtures',
          );

          matchingFrames++;
        }

        expect(matchingFrames, equals(10));
        // ignore: avoid_print
        print(
          'Cross-Transfer-Syntax pixel equivalence verified for 10/10 frames.',
        );
      },
    );

    test('10. Test Group J: Cross-Transfer-Syntax Rendered RGBA Equivalence', () {
      // EVIDENCE CLASSIFICATION: CROSS-TRANSFER-SYNTAX RENDERING CONSISTENCY
      for (var frame = 0; frame < 10; frame++) {
        final nativeRgba = DicomRenderer.renderToRgba(
          dataset,
          frameIndex: frame,
        );
        final rleRgba = DicomRenderer.renderToRgba(
          rleDataset,
          frameIndex: frame,
        );

        expect(
          nativeRgba,
          equals(rleRgba),
          reason:
              'Frame $frame rendered RGBA buffers must match bit-for-bit between uncompressed and RLE fixtures',
        );
      }
    });
  });
}
