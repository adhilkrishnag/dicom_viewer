import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: build a PixelDataInfo for YBR tests.
PixelDataInfo _ybrInfo({
  required String photometric,
  int planarConfiguration = 0,
}) {
  return PixelDataInfo(
    rows: 1,
    columns: 1,
    samplesPerPixel: 3,
    bitsAllocated: 8,
    bitsStored: 8,
    highBit: 7,
    isSigned: false,
    photometricInterpretation: photometric,
    planarConfiguration: planarConfiguration,
  );
}

/// Apply Windowing.processPixelData with 3-sample pixel [y, cb, cr].
List<int> _renderPixel(String photometric, int y, int cb, int cr) {
  final info = _ybrInfo(photometric: photometric);
  final rgba = Windowing.processPixelData([y, cb, cr], info);
  return [rgba[0], rgba[1], rgba[2]]; // R, G, B
}

void main() {
  group('YBR_PARTIAL_422 — BT.601 Limited-Range Conversion', () {
    // CCIR 601-2 Reference triplets verified against the BT.601 standard:
    //   R = 1.1644*(Y-16) + 1.5960*(Cr-128)
    //   G = 1.1644*(Y-16) - 0.3918*(Cb-128) - 0.8130*(Cr-128)
    //   B = 1.1644*(Y-16) + 2.0172*(Cb-128)

    test('Reference black (Y=16, Cb=128, Cr=128) → RGB (0,0,0)', () {
      final rgb = _renderPixel('YBR_PARTIAL_422', 16, 128, 128);
      expect(rgb[0], equals(0), reason: 'R should be 0');
      expect(rgb[1], equals(0), reason: 'G should be 0');
      expect(rgb[2], equals(0), reason: 'B should be 0');
    });

    test('Reference white (Y=235, Cb=128, Cr=128) → RGB (255,255,255)', () {
      final rgb = _renderPixel('YBR_PARTIAL_422', 235, 128, 128);
      expect(rgb[0], equals(255), reason: 'R should be 255');
      expect(rgb[1], equals(255), reason: 'G should be 255');
      expect(rgb[2], equals(255), reason: 'B should be 255');
    });

    test('Mid-grey (Y=126, Cb=128, Cr=128) → approximately (128,128,128)', () {
      final rgb = _renderPixel('YBR_PARTIAL_422', 126, 128, 128);
      // 1.1644*(126-16) = 1.1644*110 = 128.08 → 128
      expect(rgb[0], closeTo(128, 1));
      expect(rgb[1], closeTo(128, 1));
      expect(rgb[2], closeTo(128, 1));
    });

    test(
      'Y=81, Cb=90, Cr=240 → red-shifted output (R significantly > G,B)',
      () {
        // High Cr → high R
        final rgb = _renderPixel('YBR_PARTIAL_422', 81, 90, 240);
        expect(rgb[0], greaterThan(rgb[1]), reason: 'R > G for high Cr');
        expect(rgb[0], greaterThan(rgb[2]), reason: 'R > B for high Cr');
      },
    );

    test(
      'Y=41, Cb=240, Cr=110 → blue-shifted output (B significantly > R,G)',
      () {
        // High Cb → high B
        final rgb = _renderPixel('YBR_PARTIAL_422', 41, 240, 110);
        expect(rgb[2], greaterThan(rgb[0]), reason: 'B > R for high Cb');
      },
    );

    test('Clamp: Y=0 (below legal range) → R,G,B all 0', () {
      // Y=0 < 16 → (Y-16)=-16 → negative before chroma → clamp to 0
      final rgb = _renderPixel('YBR_PARTIAL_422', 0, 128, 128);
      expect(rgb[0], equals(0));
      expect(rgb[1], equals(0));
      expect(rgb[2], equals(0));
    });

    test('Clamp: Y=255 (above legal range) → R,G,B all 255', () {
      // Y=255 → 1.1644*(255-16)=278.2 → clamp to 255
      final rgb = _renderPixel('YBR_PARTIAL_422', 255, 128, 128);
      expect(rgb[0], equals(255));
      expect(rgb[1], equals(255));
      expect(rgb[2], equals(255));
    });

    test(
      'Photometric parse: YBR_PARTIAL_422 maps to ybrPartial422 (not ybrFull)',
      () {
        final parsed = PhotometricInterpretationX.parse('YBR_PARTIAL_422');
        expect(parsed, equals(PhotometricInterpretation.ybrPartial422));
        expect(parsed, isNot(equals(PhotometricInterpretation.ybrFull)));
      },
    );

    test('YBR_PARTIAL_422 is not monochrome', () {
      final parsed = PhotometricInterpretationX.parse('YBR_PARTIAL_422');
      expect(parsed.isMonochrome, isFalse);
    });

    group('PlanarConfiguration=1 (YBR_PARTIAL_422)', () {
      test(
        'Planar black (Y-plane=[16], Cb-plane=[128], Cr-plane=[128]) → (0,0,0)',
        () {
          // Planar: [Y0, Cb0, Cr0] as separate planes of 1 pixel each
          final info = _ybrInfo(
            photometric: 'YBR_PARTIAL_422',
            planarConfiguration: 1,
          );
          final rgba = Windowing.processPixelData([16, 128, 128], info);
          expect(rgba[0], equals(0));
          expect(rgba[1], equals(0));
          expect(rgba[2], equals(0));
          expect(rgba[3], equals(255));
        },
      );

      test(
        'Planar white (Y-plane=[235], Cb-plane=[128], Cr-plane=[128]) → (255,255,255)',
        () {
          final info = _ybrInfo(
            photometric: 'YBR_PARTIAL_422',
            planarConfiguration: 1,
          );
          final rgba = Windowing.processPixelData([235, 128, 128], info);
          expect(rgba[0], equals(255));
          expect(rgba[1], equals(255));
          expect(rgba[2], equals(255));
        },
      );
    });
  });

  group('YBR_FULL / YBR_FULL_422 Regression (full-range must be unchanged)', () {
    test('YBR_FULL parse → ybrFull', () {
      expect(
        PhotometricInterpretationX.parse('YBR_FULL'),
        equals(PhotometricInterpretation.ybrFull),
      );
    });

    test('YBR_FULL_422 parse → ybrFull', () {
      expect(
        PhotometricInterpretationX.parse('YBR_FULL_422'),
        equals(PhotometricInterpretation.ybrFull),
      );
    });

    test(
      'YBR_FULL neutral grey (Y=128, Cb=128, Cr=128) → approximately (128,128,128)',
      () {
        // Full-range: R = 128 + 0 = 128, G = 128 - 0 - 0 = 128, B = 128 + 0 = 128
        final rgb = _renderPixel('YBR_FULL', 128, 128, 128);
        expect(rgb[0], equals(128));
        expect(rgb[1], equals(128));
        expect(rgb[2], equals(128));
      },
    );

    test('YBR_FULL black (Y=0, Cb=128, Cr=128) → (0,0,0)', () {
      final rgb = _renderPixel('YBR_FULL', 0, 128, 128);
      expect(rgb[0], equals(0));
      expect(rgb[1], equals(0));
      expect(rgb[2], equals(0));
    });

    test('YBR_FULL white (Y=255, Cb=128, Cr=128) → (255,255,255)', () {
      final rgb = _renderPixel('YBR_FULL', 255, 128, 128);
      expect(rgb[0], equals(255));
      expect(rgb[1], equals(255));
      expect(rgb[2], equals(255));
    });

    test(
      'YBR_FULL and YBR_PARTIAL_422 produce DIFFERENT output for same triplet (Y=16,Cb=128,Cr=128)',
      () {
        // Full-range: Y=16 → R=16,G=16,B=16 (not black)
        // Partial-range: Y=16 → R=0,G=0,B=0 (true black for BT.601)
        final fullRgb = _renderPixel('YBR_FULL', 16, 128, 128);
        final partialRgb = _renderPixel('YBR_PARTIAL_422', 16, 128, 128);
        expect(fullRgb, isNot(equals(partialRgb)));
        expect(fullRgb[0], equals(16)); // Full-range preserves Y as brightness
        expect(
          partialRgb[0],
          equals(0),
        ); // Partial correctly maps Y=16 to black
      },
    );
  });
}
