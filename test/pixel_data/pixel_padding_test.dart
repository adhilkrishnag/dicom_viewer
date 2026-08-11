import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pixel Padding Value (0028,0120) & Range Tests', () {
    test(
      'calculateAutoWindow excludes single pixelPaddingValue from min/max math',
      () {
        // rescaledValues includes background air (-1024) and image pixels (100 to 500)
        final rescaledValues = [-1024.0, -1024.0, 100.0, 300.0, 500.0];
        final rawPixels = [-1024, -1024, 100, 300, 500];

        // Without padding filtering: min = -1024, max = 500, width = 1524
        final autoWithoutPadding = Windowing.calculateAutoWindow(
          rescaledValues,
        );
        expect(autoWithoutPadding['width'], equals(1524.0));

        // With padding filtering (padding = -1024): min = 100, max = 500, width = 400
        final autoWithPadding = Windowing.calculateAutoWindow(
          rescaledValues,
          rawPixels: rawPixels,
          pixelPaddingValue: -1024,
        );

        expect(autoWithPadding['width'], equals(400.0));
        expect(autoWithPadding['center'], equals(300.0));
      },
    );

    test('calculateAutoWindow excludes pixelPaddingRangeLimit range', () {
      final rescaledValues = [-1000.0, -950.0, -900.0, 200.0, 600.0];
      final rawPixels = [-1000, -950, -900, 200, 600];

      // Padding range: -1000 to -900
      final auto = Windowing.calculateAutoWindow(
        rescaledValues,
        rawPixels: rawPixels,
        pixelPaddingValue: -1000,
        pixelPaddingRangeLimit: -900,
      );

      expect(auto['width'], equals(400.0)); // 600 - 200
      expect(auto['center'], equals(400.0)); // (200 + 600) / 2
    });
  });
}
