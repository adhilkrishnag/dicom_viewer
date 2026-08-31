import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/jpeg_framing_strategy.dart';
import 'package:dicom_viewer/src/pixel_data/encapsulated_pixel_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JPEG Multi-Frame Framing Strategy Tests (BOT & Marker Scanning)', () {
    // Helper to generate dummy JPEG frame bytes
    Uint8List makeDummyJpeg(int markerByte) {
      return Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, 0x00, 0x10, // APP0 header length 16
        0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00,
        0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        // Scan data with byte-stuffed 0xFF 0x00 and restart marker 0xFF 0xD0
        markerByte, 0xFF, 0x00, 0x12, 0xFF, 0xD0, 0x34, markerByte,
        0xFF, 0xD9, // EOI
      ]);
    }

    test('Case A: Populated BOT with 1 fragment per frame', () {
      final f0 = makeDummyJpeg(0x11);
      final f1 = makeDummyJpeg(0x22);
      final f2 = makeDummyJpeg(0x33);

      final frags = [
        InternalFragment(index: 1, relativeTagStart: 0, payload: f0),
        InternalFragment(index: 2, relativeTagStart: 100, payload: f1),
        InternalFragment(index: 3, relativeTagStart: 200, payload: f2),
      ];

      final enc = EncapsulatedPixelData(
        botOffsets: [0, 100, 200],
        fragments: frags,
      );

      final p0 = JpegFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 0,
        numberOfFrames: 3,
      );
      final p1 = JpegFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 1,
        numberOfFrames: 3,
      );
      final p2 = JpegFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 2,
        numberOfFrames: 3,
      );

      expect(p0, equals(f0));
      expect(p1, equals(f1));
      expect(p2, equals(f2));
    });

    test('Case B: Single frame with 1 fragment', () {
      final f0 = makeDummyJpeg(0xAA);
      final frags = [
        InternalFragment(index: 1, relativeTagStart: 0, payload: f0),
      ];
      final enc = EncapsulatedPixelData(botOffsets: [], fragments: frags);

      final p0 = JpegFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 0,
        numberOfFrames: 1,
      );
      expect(p0, equals(f0));
    });

    test('Case C: Single frame spanning multiple fragments', () {
      final f0 = makeDummyJpeg(0xBB);
      final split = f0.length ~/ 2;
      final frag0 = Uint8List.sublistView(f0, 0, split);
      final frag1 = Uint8List.sublistView(f0, split);

      final frags = [
        InternalFragment(index: 1, relativeTagStart: 0, payload: frag0),
        InternalFragment(index: 2, relativeTagStart: 50, payload: frag1),
      ];
      final enc = EncapsulatedPixelData(botOffsets: [], fragments: frags);

      final p0 = JpegFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 0,
        numberOfFrames: 1,
      );
      expect(p0, equals(f0));
    });

    test(
      'Case D: Multi-frame with empty BOT and 1:1 fragment-to-frame mapping',
      () {
        final f0 = makeDummyJpeg(0x10);
        final f1 = makeDummyJpeg(0x20);

        final frags = [
          InternalFragment(index: 1, relativeTagStart: 0, payload: f0),
          InternalFragment(index: 2, relativeTagStart: 50, payload: f1),
        ];
        final enc = EncapsulatedPixelData(botOffsets: [], fragments: frags);

        final p0 = JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 0,
          numberOfFrames: 2,
        );
        final p1 = JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 1,
          numberOfFrames: 2,
        );

        expect(p0, equals(f0));
        expect(p1, equals(f1));
      },
    );

    test(
      'Case E: Multi-frame with empty BOT and multiple fragments per frame (marker scanning)',
      () {
        final f0 = makeDummyJpeg(0x55);
        final f1 = makeDummyJpeg(0x66);

        final frag0 = Uint8List.sublistView(f0, 0, 10);
        final frag1 = Uint8List.sublistView(f0, 10);
        final frag2 = Uint8List.sublistView(f1, 0, 15);
        final frag3 = Uint8List.sublistView(f1, 15);

        final frags = [
          InternalFragment(index: 1, relativeTagStart: 0, payload: frag0),
          InternalFragment(index: 2, relativeTagStart: 20, payload: frag1),
          InternalFragment(index: 3, relativeTagStart: 50, payload: frag2),
          InternalFragment(index: 4, relativeTagStart: 80, payload: frag3),
        ];

        final enc = EncapsulatedPixelData(botOffsets: [], fragments: frags);

        // 4 fragments for 2 frames with empty BOT -> triggers _extractFrameByMarkerScan
        final p0 = JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 0,
          numberOfFrames: 2,
        );
        final p1 = JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 1,
          numberOfFrames: 2,
        );

        expect(p0, equals(f0));
        expect(p1, equals(f1));
      },
    );

    test('Case F: Populated BOT with multiple fragments per frame', () {
      final f0 = makeDummyJpeg(0x77);
      final f1 = makeDummyJpeg(0x88);

      final frag0 = Uint8List.sublistView(f0, 0, 12);
      final frag1 = Uint8List.sublistView(f0, 12);
      final frag2 = f1;

      final frags = [
        InternalFragment(index: 1, relativeTagStart: 0, payload: frag0),
        InternalFragment(index: 2, relativeTagStart: 20, payload: frag1),
        InternalFragment(index: 3, relativeTagStart: 60, payload: frag2),
      ];

      final enc = EncapsulatedPixelData(botOffsets: [0, 60], fragments: frags);

      final p0 = JpegFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 0,
        numberOfFrames: 2,
      );
      final p1 = JpegFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 1,
        numberOfFrames: 2,
      );

      expect(p0, equals(f0));
      expect(p1, equals(f1));
    });

    test('Error Handling: Invalid frameIndex out of bounds', () {
      final f0 = makeDummyJpeg(0x99);
      final frags = [
        InternalFragment(index: 1, relativeTagStart: 0, payload: f0),
      ];
      final enc = EncapsulatedPixelData(botOffsets: [], fragments: frags);

      expect(
        () => JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: -1,
          numberOfFrames: 1,
        ),
        throwsRangeError,
      );
      expect(
        () => JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 1,
          numberOfFrames: 1,
        ),
        throwsRangeError,
      );
      expect(
        () => JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 5,
          numberOfFrames: 1,
        ),
        throwsRangeError,
      );
    });

    test('Error Handling: BOT entry count mismatch with numberOfFrames', () {
      final f0 = makeDummyJpeg(0x99);
      final frags = [
        InternalFragment(index: 1, relativeTagStart: 0, payload: f0),
      ];
      final enc = EncapsulatedPixelData(botOffsets: [0, 50], fragments: frags);

      expect(
        () => JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 0,
          numberOfFrames: 1,
        ),
        throwsFormatException,
      );
    });

    test('Error Handling: Non-monotonic BOT offsets', () {
      final f0 = makeDummyJpeg(0x11);
      final frags = [
        InternalFragment(index: 1, relativeTagStart: 0, payload: f0),
        InternalFragment(index: 2, relativeTagStart: 50, payload: f0),
      ];
      final enc = EncapsulatedPixelData(botOffsets: [50, 10], fragments: frags);

      expect(
        () => JpegFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 0,
          numberOfFrames: 2,
        ),
        throwsFormatException,
      );
    });

    test(
      'Error Handling: Fewer fragments than numberOfFrames with empty BOT',
      () {
        final f0 = makeDummyJpeg(0x11);
        final frags = [
          InternalFragment(index: 1, relativeTagStart: 0, payload: f0),
        ];
        final enc = EncapsulatedPixelData(botOffsets: [], fragments: frags);

        expect(
          () => JpegFramingStrategy.extractFramePayload(
            enc,
            frameIndex: 0,
            numberOfFrames: 2,
          ),
          throwsFormatException,
        );
      },
    );
  });
}
