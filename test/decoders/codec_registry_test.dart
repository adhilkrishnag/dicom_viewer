import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
import 'package:dicom_viewer/src/decoders/rle_frame_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  group('CodecRegistry Unit Tests', () {
    test('Resolves RleFrameCodec for RLE Lossless transfer syntax', () {
      final codec = CodecRegistry.getCodec(TransferSyntax.rleLossless);
      expect(codec, isNotNull);
      expect(codec, isA<RleFrameCodec>());
      expect(CodecRegistry.hasCodec(TransferSyntax.rleLossless), isTrue);
    });

    test('Returns null for uncompressed native transfer syntaxes', () {
      expect(
        CodecRegistry.getCodec(TransferSyntax.explicitVRLittleEndian),
        isNull,
      );
      expect(
        CodecRegistry.getCodec(TransferSyntax.implicitVRLittleEndian),
        isNull,
      );
      expect(
        CodecRegistry.getCodec(TransferSyntax.explicitVRBigEndian),
        isNull,
      );
      expect(
        CodecRegistry.hasCodec(TransferSyntax.explicitVRLittleEndian),
        isFalse,
      );
    });

    test(
      'Throws UnsupportedError for unregistered compressed transfer syntaxes',
      () {
        final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
        final dataset = DicomDataset.fromBytes(
          SyntheticDicomGenerator.create(
            width: 16,
            height: 16,
            transferSyntaxUid: TransferSyntax.jpegBaseline,
            rawEncapsulatedBytes: dummyBytes,
          ),
        );

        expect(
          () => CodecRegistry.extractEffectivePixelBytes(dataset),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              contains('JPEG Baseline'),
            ),
          ),
        );
      },
    );

    test(
      'Throws StateError if DICOM dataset contains no Pixel Data element',
      () {
        // Create a dataset without pixel data element
        final dataset = DicomDataset([]);
        expect(
          () => CodecRegistry.extractEffectivePixelBytes(dataset),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('Throws RangeError on out-of-bounds frameIndex', () {
      final dataset = DicomDataset.fromBytes(
        SyntheticDicomGenerator.create(
          width: 8,
          height: 8,
          transferSyntaxUid: TransferSyntax.explicitVRLittleEndian,
        ),
      );

      expect(
        () => CodecRegistry.extractEffectivePixelBytes(dataset, frameIndex: -1),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => CodecRegistry.extractEffectivePixelBytes(dataset, frameIndex: 1),
        throwsA(isA<RangeError>()),
      );
    });

    test(
      'Throws FormatException if compressed transfer syntax lacks encapsulated data',
      () {
        // Create synthetic dataset with RLE transfer syntax but unencapsulated native flat bytes
        final dataset = DicomDataset.fromBytes(
          SyntheticDicomGenerator.create(
            width: 8,
            height: 8,
            transferSyntaxUid: TransferSyntax.rleLossless,
            // Passing customPixelData directly produces explicit-length unencapsulated element
            customPixelData: Uint8List(8 * 8 * 2),
          ),
        );

        expect(
          () => CodecRegistry.extractEffectivePixelBytes(dataset),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('requires encapsulated undefined length data'),
            ),
          ),
        );
      },
    );
  });
}
