import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/rle_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic minimal 64-byte RLE header + PackBits segments for a 2x2 RGB image.
// Each segment encodes [R0,R1,R2,R3], [G0,G1,G2,G3], [B0,B1,B2,B3].

Uint8List _buildRleFrame({
  required List<int> rSamples,
  required List<int> gSamples,
  required List<int> bSamples,
}) {
  // PackBits-encode each segment: literal run header = (n-1), followed by n literal bytes.
  Uint8List packBitsLiteral(List<int> samples) {
    return Uint8List.fromList([samples.length - 1, ...samples]);
  }

  final rSeg = packBitsLiteral(rSamples);
  final gSeg = packBitsLiteral(gSamples);
  final bSeg = packBitsLiteral(bSamples);

  // Build 64-byte header: numSegments=3, then offsets for each segment.
  final header = Uint8List(64);
  final hBd = ByteData.sublistView(header);
  hBd.setUint32(0, 3, Endian.little); // numSegments = 3
  // Segment offsets (relative to start of frame, including the 64-byte header)
  hBd.setUint32(4, 64, Endian.little); // Seg 0 (R) offset
  hBd.setUint32(8, 64 + rSeg.length, Endian.little); // Seg 1 (G) offset
  hBd.setUint32(
    12,
    64 + rSeg.length + gSeg.length,
    Endian.little,
  ); // Seg 2 (B) offset

  return Uint8List.fromList([...header, ...rSeg, ...gSeg, ...bSeg]);
}

void main() {
  // 2x2 image, 4 pixels
  const width = 2;
  const height = 2;
  const totalPixels = width * height;

  // Distinct per-channel values to unambiguously identify correct ordering.
  final rSamples = [10, 20, 30, 40]; // R channel
  final gSamples = [50, 60, 70, 80]; // G channel
  final bSamples = [90, 100, 110, 120]; // B channel

  final rleFrame = _buildRleFrame(
    rSamples: rSamples,
    gSamples: gSamples,
    bSamples: bSamples,
  );

  group('RLE Decoder — PlanarConfiguration = 0 (interleaved)', () {
    test('Decodes 2x2 frame to interleaved [R,G,B, R,G,B, ...] layout', () {
      final decoded = RleDecoder.decodeFrame(
        rleFrameBytes: rleFrame,
        width: width,
        height: height,
        bitsAllocated: 8,
        samplesPerPixel: 3,
        planarConfiguration: 0,
      );

      expect(decoded.length, equals(totalPixels * 3));

      // Check each pixel: decoded[p*3]=R[p], decoded[p*3+1]=G[p], decoded[p*3+2]=B[p]
      for (int p = 0; p < totalPixels; p++) {
        expect(
          decoded[p * 3],
          equals(rSamples[p]),
          reason: 'Pixel $p R expected ${rSamples[p]}',
        );
        expect(
          decoded[p * 3 + 1],
          equals(gSamples[p]),
          reason: 'Pixel $p G expected ${gSamples[p]}',
        );
        expect(
          decoded[p * 3 + 2],
          equals(bSamples[p]),
          reason: 'Pixel $p B expected ${bSamples[p]}',
        );
      }
    });

    test('Default planarConfiguration parameter is 0 (interleaved)', () {
      // Call without specifying planarConfiguration → must produce interleaved output
      final decoded = RleDecoder.decodeFrame(
        rleFrameBytes: rleFrame,
        width: width,
        height: height,
        bitsAllocated: 8,
        samplesPerPixel: 3,
      );

      expect(decoded.length, equals(totalPixels * 3));
      expect(decoded[0], equals(rSamples[0])); // Pixel 0 R
      expect(decoded[1], equals(gSamples[0])); // Pixel 0 G
      expect(decoded[2], equals(bSamples[0])); // Pixel 0 B
    });
  });

  group('RLE Decoder — PlanarConfiguration = 1 (separate planes)', () {
    test('Decodes 2x2 frame to planar [R-plane][G-plane][B-plane] layout', () {
      final decoded = RleDecoder.decodeFrame(
        rleFrameBytes: rleFrame,
        width: width,
        height: height,
        bitsAllocated: 8,
        samplesPerPixel: 3,
        planarConfiguration: 1,
      );

      expect(decoded.length, equals(totalPixels * 3));

      // R plane: decoded[0..totalPixels-1]
      for (int p = 0; p < totalPixels; p++) {
        expect(
          decoded[p],
          equals(rSamples[p]),
          reason: 'R plane pixel $p expected ${rSamples[p]}',
        );
      }

      // G plane: decoded[totalPixels..2*totalPixels-1]
      for (int p = 0; p < totalPixels; p++) {
        expect(
          decoded[totalPixels + p],
          equals(gSamples[p]),
          reason: 'G plane pixel $p expected ${gSamples[p]}',
        );
      }

      // B plane: decoded[2*totalPixels..3*totalPixels-1]
      for (int p = 0; p < totalPixels; p++) {
        expect(
          decoded[2 * totalPixels + p],
          equals(bSamples[p]),
          reason: 'B plane pixel $p expected ${bSamples[p]}',
        );
      }
    });

    test(
      'Planar and interleaved output contain identical channel values (just different layouts)',
      () {
        final interleaved = RleDecoder.decodeFrame(
          rleFrameBytes: rleFrame,
          width: width,
          height: height,
          bitsAllocated: 8,
          samplesPerPixel: 3,
          planarConfiguration: 0,
        );

        final planar = RleDecoder.decodeFrame(
          rleFrameBytes: rleFrame,
          width: width,
          height: height,
          bitsAllocated: 8,
          samplesPerPixel: 3,
          planarConfiguration: 1,
        );

        expect(interleaved.length, equals(planar.length));

        // Both should contain all the same values, just differently arranged
        for (int p = 0; p < totalPixels; p++) {
          expect(interleaved[p * 3], equals(planar[p])); // R
          expect(interleaved[p * 3 + 1], equals(planar[totalPixels + p])); // G
          expect(
            interleaved[p * 3 + 2],
            equals(planar[2 * totalPixels + p]),
          ); // B
        }
      },
    );
  });

  group('RLE Decoder — Regression: PlanarConfiguration=0 unchanged', () {
    test(
      'Existing grayscale 8-bit decode is unaffected by planarConfiguration parameter',
      () {
        // Build a 2x1 grayscale frame: 1 segment with 2 pixels.
        final seg = Uint8List.fromList([1, 100, 200]); // literal run of 2 bytes
        final header = Uint8List(64);
        final hBd = ByteData.sublistView(header);
        hBd.setUint32(0, 1, Endian.little); // numSegments = 1
        hBd.setUint32(4, 64, Endian.little); // Seg 0 offset

        final frame = Uint8List.fromList([...header, ...seg]);
        final decoded = RleDecoder.decodeFrame(
          rleFrameBytes: frame,
          width: 2,
          height: 1,
          bitsAllocated: 8,
          samplesPerPixel: 1,
        );

        expect(decoded.length, equals(2));
        expect(decoded[0], equals(100));
        expect(decoded[1], equals(200));
      },
    );
  });
}
