import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PixelDataDecoder', () {
    test('Decodes 8-bit unsigned pixel data', () {
      final bytes = Uint8List.fromList([0, 128, 255, 64]);
      const info = PixelDataInfo(
        rows: 2,
        columns: 2,
        samplesPerPixel: 1,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        isSigned: false,
        photometricInterpretation: 'MONOCHROME2',
      );

      const decoder = PixelDataDecoder();
      final pixels = decoder.decode(bytes, info);

      expect(pixels, equals([0, 128, 255, 64]));
    });

    test('Decodes 16-bit unsigned pixel data with bitsStored masking', () {
      final bd = ByteData(8);
      bd.setUint16(0, 1000, Endian.little);
      bd.setUint16(2, 4095, Endian.little);
      bd.setUint16(4, 0, Endian.little);
      bd.setUint16(6, 2048, Endian.little);

      const info = PixelDataInfo(
        rows: 2,
        columns: 2,
        samplesPerPixel: 1,
        bitsAllocated: 16,
        bitsStored: 12, // 12-bit stored
        highBit: 11,
        isSigned: false,
        photometricInterpretation: 'MONOCHROME2',
      );

      const decoder = PixelDataDecoder();
      final pixels = decoder.decode(bd.buffer.asUint8List(), info);

      expect(pixels, equals([1000, 4095, 0, 2048]));
    });

    test('Decodes 16-bit Big Endian pixel data correctly', () {
      final bd = ByteData(4);
      bd.setUint16(0, 0x1234, Endian.big);
      bd.setUint16(2, 0x5678, Endian.big);

      const info = PixelDataInfo(
        rows: 1,
        columns: 2,
        samplesPerPixel: 1,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        isSigned: false,
        photometricInterpretation: 'MONOCHROME2',
        isLittleEndian: false,
      );

      const decoder = PixelDataDecoder();
      final pixels = decoder.decode(bd.buffer.asUint8List(), info);

      expect(pixels, equals([0x1234, 0x5678]));
    });
  });
}
