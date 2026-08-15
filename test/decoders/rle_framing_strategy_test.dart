import 'dart:typed_data';

import 'package:dicom_viewer/src/decoders/rle_framing_strategy.dart';
import 'package:dicom_viewer/src/pixel_data/encapsulated_pixel_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RleFramingStrategy Unit Tests (DICOM PS3.5 Annex G Compliance)', () {
    test('Single-frame RLE with 1 fragment returns fragment payload slice', () {
      final enc = EncapsulatedPixelData(
        botOffsets: const [],
        fragments: [
          InternalFragment(
            index: 1,
            relativeTagStart: 0,
            payload: Uint8List.fromList([10, 20, 30]),
          ),
        ],
      );

      final framePayload = RleFramingStrategy.extractFramePayload(
        enc,
        frameIndex: 0,
        numberOfFrames: 1,
      );

      expect(framePayload, equals([10, 20, 30]));
    });

    test(
      'Single-frame RLE with multiple fragments concatenates fragment payloads',
      () {
        final enc = EncapsulatedPixelData(
          botOffsets: const [],
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List.fromList([10, 20]),
            ),
            InternalFragment(
              index: 2,
              relativeTagStart: 10,
              payload: Uint8List.fromList([30, 40]),
            ),
          ],
        );

        final framePayload = RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 0,
          numberOfFrames: 1,
        );

        expect(framePayload, equals([10, 20, 30, 40]));
      },
    );

    test('Multi-frame RLE with 1 fragment per frame extracts exact frame', () {
      final enc = EncapsulatedPixelData(
        botOffsets: const [],
        fragments: [
          InternalFragment(
            index: 1,
            relativeTagStart: 0,
            payload: Uint8List.fromList([10]),
          ),
          InternalFragment(
            index: 2,
            relativeTagStart: 10,
            payload: Uint8List.fromList([20]),
          ),
          InternalFragment(
            index: 3,
            relativeTagStart: 20,
            payload: Uint8List.fromList([30]),
          ),
        ],
      );

      expect(
        RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 0,
          numberOfFrames: 3,
        ),
        equals([10]),
      );

      expect(
        RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 1,
          numberOfFrames: 3,
        ),
        equals([20]),
      );

      expect(
        RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 2,
          numberOfFrames: 3,
        ),
        equals([30]),
      );
    });

    test(
      'Populated BOT + valid RLE validates offsets and extracts frame payload',
      () {
        final enc = EncapsulatedPixelData(
          botOffsets: const [0, 20, 40],
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List.fromList([10]),
            ),
            InternalFragment(
              index: 2,
              relativeTagStart: 20,
              payload: Uint8List.fromList([20]),
            ),
            InternalFragment(
              index: 3,
              relativeTagStart: 40,
              payload: Uint8List.fromList([30]),
            ),
          ],
        );

        final frame1 = RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 1,
          numberOfFrames: 3,
        );

        expect(frame1, equals([20]));
      },
    );

    test(
      'Throws FormatException on misaligned BOT offset relative to fragment start',
      () {
        final enc = EncapsulatedPixelData(
          botOffsets: const [
            0,
            999,
          ], // 999 does not match fragment relativeTagStart (10)
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List(10),
            ),
            InternalFragment(
              index: 2,
              relativeTagStart: 10,
              payload: Uint8List(10),
            ),
          ],
        );

        expect(
          () => RleFramingStrategy.extractFramePayload(
            enc,
            frameIndex: 0,
            numberOfFrames: 2,
          ),
          throwsFormatException,
        );
      },
    );

    test('Throws FormatException on invalid decreasing BOT offsets', () {
      final enc = EncapsulatedPixelData(
        botOffsets: const [100, 50, 200], // Decreasing!
        fragments: [
          InternalFragment(
            index: 1,
            relativeTagStart: 0,
            payload: Uint8List(10),
          ),
          InternalFragment(
            index: 2,
            relativeTagStart: 10,
            payload: Uint8List(10),
          ),
          InternalFragment(
            index: 3,
            relativeTagStart: 20,
            payload: Uint8List(10),
          ),
        ],
      );

      expect(
        () => RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 0,
          numberOfFrames: 3,
        ),
        throwsFormatException,
      );
    });

    test('Throws RangeError on out-of-bounds frameIndex', () {
      final enc = EncapsulatedPixelData(
        botOffsets: const [],
        fragments: [
          InternalFragment(
            index: 1,
            relativeTagStart: 0,
            payload: Uint8List(10),
          ),
        ],
      );

      expect(
        () => RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: -1,
          numberOfFrames: 1,
        ),
        throwsRangeError,
      );

      expect(
        () => RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: 1,
          numberOfFrames: 1,
        ),
        throwsRangeError,
      );
    });

    test(
      'Throws FormatException on DICOM Annex G violation (multi-frame RLE where fragment count != numberOfFrames)',
      () {
        final enc = EncapsulatedPixelData(
          botOffsets: const [],
          fragments: [
            InternalFragment(
              index: 1,
              relativeTagStart: 0,
              payload: Uint8List(10),
            ),
            InternalFragment(
              index: 2,
              relativeTagStart: 10,
              payload: Uint8List(10),
            ),
          ],
        );

        // 3 frames requested, but only 2 fragments provided
        expect(
          () => RleFramingStrategy.extractFramePayload(
            enc,
            frameIndex: 0,
            numberOfFrames: 3,
          ),
          throwsFormatException,
        );
      },
    );
  });
}
