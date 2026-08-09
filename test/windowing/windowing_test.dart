import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windowing Math', () {
    test('Rescale Slope and Intercept calculation', () {
      // Hounsfield Unit CT conversion: HU = raw * 1.0 - 1024
      expect(Windowing.applyRescale(1024, 1.0, -1024.0), 0.0);
      expect(Windowing.applyRescale(0, 1.0, -1024.0), -1024.0);
      expect(Windowing.applyRescale(2048, 1.0, -1024.0), 1024.0);
    });

    test('Linear VOI Windowing mapping to 0..255', () {
      // Window Center = 40, Window Width = 400 (Soft Tissue CT preset)
      // Range: [40 - 0.5 - 199.5, 40 - 0.5 + 199.5] -> [-160, 239]

      // Below min -> 0
      expect(Windowing.applyWindow(-200.0, 40.0, 400.0), 0);

      // Above max -> 255
      expect(Windowing.applyWindow(300.0, 40.0, 400.0), 255);

      // Midpoint -> ~128
      expect(Windowing.applyWindow(40.0, 40.0, 400.0), 128);
    });

    test('Photometric MONOCHROME1 vs MONOCHROME2 inversion', () {
      const infoMono2 = PixelDataInfo(
        rows: 1,
        columns: 2,
        samplesPerPixel: 1,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        isSigned: false,
        photometricInterpretation: 'MONOCHROME2',
      );

      const infoMono1 = PixelDataInfo(
        rows: 1,
        columns: 2,
        samplesPerPixel: 1,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        isSigned: false,
        photometricInterpretation: 'MONOCHROME1',
      );

      final rawPixels = [0, 255]; // Black, White

      final rgba2 = Windowing.processPixelData(
        rawPixels,
        infoMono2,
        windowCenter: 128,
        windowWidth: 256,
      );

      final rgba1 = Windowing.processPixelData(
        rawPixels,
        infoMono1,
        windowCenter: 128,
        windowWidth: 256,
      );

      // MONOCHROME2: 0 -> black (0,0,0,255), 255 -> white (255,255,255,255)
      expect(rgba2.sublist(0, 4), equals([0, 0, 0, 255]));
      expect(rgba2.sublist(4, 8), equals([255, 255, 255, 255]));

      // MONOCHROME1: 0 -> white (255,255,255,255), 255 -> black (0,0,0,255)
      expect(rgba1.sublist(0, 4), equals([255, 255, 255, 255]));
      expect(rgba1.sublist(4, 8), equals([0, 0, 0, 255]));
    });
  });
}
