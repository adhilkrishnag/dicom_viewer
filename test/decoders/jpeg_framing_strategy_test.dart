import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/jpeg_framing_strategy.dart';
import 'package:dicom_viewer/src/pixel_data/encapsulated_pixel_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JpegFramingStrategy Unit Tests', () {
    test('Extracts single-frame single-fragment payload (zero-copy)', () {
      final payload = Uint8List.fromList([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9]);
      final encData = EncapsulatedPixelData(
        botOffsets: const [],
        fragments: [
          InternalFragment(index: 1, relativeTagStart: 0, payload: payload),
        ],
      );

      final result = JpegFramingStrategy.extractFramePayload(
        encData,
        frameIndex: 0,
        numberOfFrames: 1,
      );

      expect(result, equals(payload));
    });

    test('Extracts single-frame multi-fragment payload (concatenated)', () {
      final frag1 = Uint8List.fromList([0xFF, 0xD8, 0xAA]);
      final frag2 = Uint8List.fromList([0xBB, 0xCC, 0xFF, 0xD9]);
      final encData = EncapsulatedPixelData(
        botOffsets: const [],
        fragments: [
          InternalFragment(index: 1, relativeTagStart: 0, payload: frag1),
          InternalFragment(index: 2, relativeTagStart: 11, payload: frag2),
        ],
      );

      final result = JpegFramingStrategy.extractFramePayload(
        encData,
        frameIndex: 0,
        numberOfFrames: 1,
      );

      expect(result, equals([0xFF, 0xD8, 0xAA, 0xBB, 0xCC, 0xFF, 0xD9]));
    });

    test(
      'Extracts multi-frame payload with populated BOT (1 fragment per frame)',
      () {
        final frag1 = Uint8List.fromList([0xFF, 0xD8, 0x11, 0xFF, 0xD9]);
        final frag2 = Uint8List.fromList([0xFF, 0xD8, 0x22, 0xFF, 0xD9]);
        final encData = EncapsulatedPixelData(
          botOffsets: const [0, 20],
          fragments: [
            InternalFragment(index: 1, relativeTagStart: 0, payload: frag1),
            InternalFragment(index: 2, relativeTagStart: 20, payload: frag2),
          ],
        );

        final result0 = JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 0,
          numberOfFrames: 2,
        );
        final result1 = JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 1,
          numberOfFrames: 2,
        );

        expect(result0, equals(frag1));
        expect(result1, equals(frag2));
      },
    );

    test(
      'Extracts multi-frame payload with populated BOT (multiple fragments per frame)',
      () {
        // Frame 0 spans frag1 (offset 0) and frag2 (offset 16)
        // Frame 1 spans frag3 (offset 32) and frag4 (offset 48)
        final frag1 = Uint8List.fromList([0xFF, 0xD8, 0x01]);
        final frag2 = Uint8List.fromList([0x02, 0xFF, 0xD9]);
        final frag3 = Uint8List.fromList([0xFF, 0xD8, 0x03]);
        final frag4 = Uint8List.fromList([0x04, 0xFF, 0xD9]);

        final encData = EncapsulatedPixelData(
          botOffsets: const [0, 32],
          fragments: [
            InternalFragment(index: 1, relativeTagStart: 0, payload: frag1),
            InternalFragment(index: 2, relativeTagStart: 16, payload: frag2),
            InternalFragment(index: 3, relativeTagStart: 32, payload: frag3),
            InternalFragment(index: 4, relativeTagStart: 48, payload: frag4),
          ],
        );

        final result0 = JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 0,
          numberOfFrames: 2,
        );
        final result1 = JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 1,
          numberOfFrames: 2,
        );

        expect(result0, equals([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9]));
        expect(result1, equals([0xFF, 0xD8, 0x03, 0x04, 0xFF, 0xD9]));
      },
    );

    test(
      'Throws FormatException on BOT count mismatch with numberOfFrames',
      () {
        final encData = EncapsulatedPixelData(
          botOffsets: const [0], // 1 entry for 2 frames
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List(4),
            ),
          ],
        );

        expect(
          () => JpegFramingStrategy.extractFramePayload(
            encData,
            frameIndex: 0,
            numberOfFrames: 2,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('does not match numberOfFrames'),
            ),
          ),
        );
      },
    );

    test('Throws FormatException on decreasing non-monotonic BOT offsets', () {
      final encData = EncapsulatedPixelData(
        botOffsets: const [30, 10], // Decreasing offsets
        fragments: [
          InternalFragment(
            index: 1,
            relativeTagStart: 30,
            payload: Uint8List(4),
          ),
          InternalFragment(
            index: 2,
            relativeTagStart: 10,
            payload: Uint8List(4),
          ),
        ],
      );

      expect(
        () => JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 0,
          numberOfFrames: 2,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('offsets are not non-decreasing'),
          ),
        ),
      );
    });

    test(
      'Throws FormatException when BOT offset does not match any fragment start',
      () {
        final encData = EncapsulatedPixelData(
          botOffsets: const [0, 50], // Offset 50 does not exist
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List(4),
            ),
            InternalFragment(
              index: 2,
              relativeTagStart: 20,
              payload: Uint8List(4),
            ),
          ],
        );

        expect(
          () => JpegFramingStrategy.extractFramePayload(
            encData,
            frameIndex: 0,
            numberOfFrames: 2,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('does not match any fragment start position'),
            ),
          ),
        );
      },
    );

    test(
      'Extracts multi-frame payload with empty BOT (1:1 fragment-to-frame mapping)',
      () {
        final frag1 = Uint8List.fromList([0xAA, 0xBB]);
        final frag2 = Uint8List.fromList([0xCC, 0xDD]);
        final encData = EncapsulatedPixelData(
          botOffsets: const [],
          fragments: [
            InternalFragment(index: 1, relativeTagStart: 0, payload: frag1),
            InternalFragment(index: 2, relativeTagStart: 10, payload: frag2),
          ],
        );

        final result0 = JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 0,
          numberOfFrames: 2,
        );
        final result1 = JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 1,
          numberOfFrames: 2,
        );

        expect(result0, equals(frag1));
        expect(result1, equals(frag2));
      },
    );

    test(
      'Throws FormatException when multi-frame with empty BOT has fewer fragments than frames',
      () {
        final encData = EncapsulatedPixelData(
          botOffsets: const [],
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List(4),
            ),
          ],
        );

        expect(
          () => JpegFramingStrategy.extractFramePayload(
            encData,
            frameIndex: 0,
            numberOfFrames: 3,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('fewer fragments'),
            ),
          ),
        );
      },
    );

    test(
      'Throws UnsupportedError when multi-frame with empty BOT has multiple fragments per frame',
      () {
        final encData = EncapsulatedPixelData(
          botOffsets: const [],
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List(4),
            ),
            InternalFragment(
              index: 2,
              relativeTagStart: 10,
              payload: Uint8List(4),
            ),
            InternalFragment(
              index: 3,
              relativeTagStart: 20,
              payload: Uint8List(4),
            ),
          ],
        );

        expect(
          () => JpegFramingStrategy.extractFramePayload(
            encData,
            frameIndex: 0,
            numberOfFrames: 2,
          ),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              contains('requires marker-based stream scanning'),
            ),
          ),
        );
      },
    );

    test('Throws RangeError on invalid frameIndex bounds', () {
      final encData = EncapsulatedPixelData(
        botOffsets: const [],
        fragments: [
          InternalFragment(
            index: 1,
            relativeTagStart: 0,
            payload: Uint8List(4),
          ),
        ],
      );

      expect(
        () => JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: -1,
          numberOfFrames: 1,
        ),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 1,
          numberOfFrames: 1,
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('Throws StateError when fragments list is empty', () {
      final encData = EncapsulatedPixelData(
        botOffsets: const [],
        fragments: const [],
      );

      expect(
        () => JpegFramingStrategy.extractFramePayload(
          encData,
          frameIndex: 0,
          numberOfFrames: 1,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
