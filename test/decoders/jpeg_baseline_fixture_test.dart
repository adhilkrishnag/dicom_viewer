import 'dart:io';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/decoders/codec_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JPEG Baseline DICOM Fixture Pipeline Tests', () {
    test(
      'Decodes real RGB DICOM fixture SC_rgb_dcmtk_+eb+cr.dcm (100x100 RGB)',
      () {
        final file = File('test/fixtures/jpeg/SC_rgb_dcmtk_+eb+cr.dcm');
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.rows, equals(100));
        expect(dataset.columns, equals(100));
        expect(dataset.samplesPerPixel, equals(3));
        expect(dataset.bitsAllocated, equals(8));
        expect(dataset.bitsStored, equals(8));
        expect(dataset.photometricInterpretation, equals('RGB'));

        // Extract effective pixel bytes through CodecRegistry
        final pixelBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
          frameIndex: 0,
        );
        expect(pixelBytes.length, equals(100 * 100 * 3));

        // Render to RGBA buffer
        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, equals(100 * 100 * 4));
      },
    );

    test(
      'Decodes synthetic grayscale DICOM fixture synthetic_baseline_grayscale.dcm (32x32 MONOCHROME2)',
      () {
        final file = File(
          'test/fixtures/jpeg/synthetic_baseline_grayscale.dcm',
        );
        expect(file.existsSync(), isTrue);

        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());

        expect(dataset.transferSyntaxUid, equals(TransferSyntax.jpegBaseline));
        expect(dataset.rows, equals(32));
        expect(dataset.columns, equals(32));
        expect(dataset.samplesPerPixel, equals(1));
        expect(dataset.bitsAllocated, equals(8));
        expect(dataset.bitsStored, equals(8));
        expect(dataset.photometricInterpretation, equals('MONOCHROME2'));

        final pixelBytes = CodecRegistry.extractEffectivePixelBytes(
          dataset,
          frameIndex: 0,
        );
        expect(pixelBytes.length, equals(32 * 32));

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, equals(32 * 32 * 4));
      },
    );
  });
}
