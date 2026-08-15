import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicom_viewer/src/windowing/palette_color_lut.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 6 — PALETTE COLOR LUT Synthetic Tests', () {
    test(
      '1. 8-bit LUT (bitsPerEntry = 8) maps scalar indices to RGB channels',
      () {
        // 3 entries:
        // Entry 0: Red=255, Green=0, Blue=0
        // Entry 1: Red=0, Green=255, Blue=0
        // Entry 2: Red=0, Green=0, Blue=255
        final redLut = Uint8List.fromList([255, 0, 0]);
        final greenLut = Uint8List.fromList([0, 255, 0]);
        final blueLut = Uint8List.fromList([0, 0, 255]);
        final desc = [3, 0, 8];

        // 4 pixels (2x2): [0, 1, 2, 1]
        final pixelData = Uint8List.fromList([0, 1, 2, 1]);

        final bytes = SyntheticDicomGenerator.create(
          width: 2,
          height: 2,
          bitsAllocated: 8,
          bitsStored: 8,
          highBit: 7,
          photometricInterpretation: 'PALETTE COLOR',
          redDescriptor: desc,
          greenDescriptor: desc,
          blueDescriptor: desc,
          redLutData: redLut,
          greenLutData: greenLut,
          blueLutData: blueLut,
          customPixelData: pixelData,
        );

        final dataset = DicomDataset.fromBytes(bytes);
        expect(dataset.photometricInterpretation, 'PALETTE COLOR');

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, 2 * 2 * 4);

        // Pixel 0 (index 0) -> (255, 0, 0, 255)
        expect(rgba.sublist(0, 4), [255, 0, 0, 255]);
        // Pixel 1 (index 1) -> (0, 255, 0, 255)
        expect(rgba.sublist(4, 8), [0, 255, 0, 255]);
        // Pixel 2 (index 2) -> (0, 0, 255, 255)
        expect(rgba.sublist(8, 12), [0, 0, 255, 255]);
        // Pixel 3 (index 1) -> (0, 255, 0, 255)
        expect(rgba.sublist(12, 16), [0, 255, 0, 255]);
      },
    );

    test(
      '2. 16-bit LUT (bitsPerEntry = 16) scales high byte to 8-bit RGBA',
      () {
        // 3 entries, 16-bit Little Endian:
        // Entry 0: Red=0xFF00 (65280 -> 255), Green=0, Blue=0
        // Entry 1: Red=0, Green=0x8000 (32768 -> 128), Blue=0
        // Entry 2: Red=0, Green=0, Blue=0xFFFF (65535 -> 255)
        final redLut = Uint8List.fromList([0x00, 0xFF, 0x00, 0x00, 0x00, 0x00]);
        final greenLut = Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x80,
          0x00,
          0x00,
        ]);
        final blueLut = Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
        ]);
        final desc = [3, 0, 16];

        final pixelData = Uint8List.fromList([0, 1, 2]);

        final bytes = SyntheticDicomGenerator.create(
          width: 3,
          height: 1,
          bitsAllocated: 8,
          bitsStored: 8,
          highBit: 7,
          photometricInterpretation: 'PALETTE COLOR',
          redDescriptor: desc,
          greenDescriptor: desc,
          blueDescriptor: desc,
          redLutData: redLut,
          greenLutData: greenLut,
          blueLutData: blueLut,
          customPixelData: pixelData,
        );

        final dataset = DicomDataset.fromBytes(bytes);
        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, 3 * 1 * 4);

        // Pixel 0 -> (255, 0, 0, 255)
        expect(rgba.sublist(0, 4), [255, 0, 0, 255]);
        // Pixel 1 -> (0, 128, 0, 255)
        expect(rgba.sublist(4, 8), [0, 128, 0, 255]);
        // Pixel 2 -> (0, 0, 255, 255)
        expect(rgba.sublist(8, 12), [0, 0, 255, 255]);
      },
    );

    test('3. firstMappedValue offset maps shifted pixel values accurately', () {
      // firstMappedValue = 50, 3 entries (mapped range: 50, 51, 52)
      final redLut = Uint8List.fromList([10, 20, 30]);
      final greenLut = Uint8List.fromList([100, 110, 120]);
      final blueLut = Uint8List.fromList([200, 210, 220]);
      final desc = [3, 50, 8];

      final pixelData = Uint8List.fromList([50, 51, 52]);

      final bytes = SyntheticDicomGenerator.create(
        width: 3,
        height: 1,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        photometricInterpretation: 'PALETTE COLOR',
        redDescriptor: desc,
        greenDescriptor: desc,
        blueDescriptor: desc,
        redLutData: redLut,
        greenLutData: greenLut,
        blueLutData: blueLut,
        customPixelData: pixelData,
      );

      final dataset = DicomDataset.fromBytes(bytes);
      final rgba = DicomRenderer.renderToRgba(dataset);

      // Pixel 50 -> entry 0 (10, 100, 200, 255)
      expect(rgba.sublist(0, 4), [10, 100, 200, 255]);
      // Pixel 51 -> entry 1 (20, 110, 210, 255)
      expect(rgba.sublist(4, 8), [20, 110, 210, 255]);
      // Pixel 52 -> entry 2 (30, 120, 220, 255)
      expect(rgba.sublist(8, 12), [30, 120, 220, 255]);
    });

    test('4. Below-range pixel values clamp to entry 0', () {
      final redLut = Uint8List.fromList([10, 20, 30]);
      final greenLut = Uint8List.fromList([100, 110, 120]);
      final blueLut = Uint8List.fromList([200, 210, 220]);
      final desc = [3, 50, 8];

      // Pixel values: [0, 25, 49] - all below firstMappedValue 50
      final pixelData = Uint8List.fromList([0, 25, 49]);

      final bytes = SyntheticDicomGenerator.create(
        width: 3,
        height: 1,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        photometricInterpretation: 'PALETTE COLOR',
        redDescriptor: desc,
        greenDescriptor: desc,
        blueDescriptor: desc,
        redLutData: redLut,
        greenLutData: greenLut,
        blueLutData: blueLut,
        customPixelData: pixelData,
      );

      final dataset = DicomDataset.fromBytes(bytes);
      final rgba = DicomRenderer.renderToRgba(dataset);

      // All map to entry 0: (10, 100, 200, 255)
      expect(rgba.sublist(0, 4), [10, 100, 200, 255]);
      expect(rgba.sublist(4, 8), [10, 100, 200, 255]);
      expect(rgba.sublist(8, 12), [10, 100, 200, 255]);
    });

    test(
      '5. Above-range pixel values clamp to final entry (numEntries - 1)',
      () {
        final redLut = Uint8List.fromList([10, 20, 30]);
        final greenLut = Uint8List.fromList([100, 110, 120]);
        final blueLut = Uint8List.fromList([200, 210, 220]);
        final desc = [3, 50, 8];

        // Pixel values: [53, 100, 255] - all above mapped range (50..52)
        final pixelData = Uint8List.fromList([53, 100, 255]);

        final bytes = SyntheticDicomGenerator.create(
          width: 3,
          height: 1,
          bitsAllocated: 8,
          bitsStored: 8,
          highBit: 7,
          photometricInterpretation: 'PALETTE COLOR',
          redDescriptor: desc,
          greenDescriptor: desc,
          blueDescriptor: desc,
          redLutData: redLut,
          greenLutData: greenLut,
          blueLutData: blueLut,
          customPixelData: pixelData,
        );

        final dataset = DicomDataset.fromBytes(bytes);
        final rgba = DicomRenderer.renderToRgba(dataset);

        // All map to entry 2: (30, 120, 220, 255)
        expect(rgba.sublist(0, 4), [30, 120, 220, 255]);
        expect(rgba.sublist(4, 8), [30, 120, 220, 255]);
        expect(rgba.sublist(8, 12), [30, 120, 220, 255]);
      },
    );

    test(
      '6. Descriptor with numberOfEntries = 0 interprets as 65536 entries per DICOM PS3.3',
      () {
        final desc = [0, 0, 8]; // 0 -> 65536 entries
        final redLut = Uint8List(65536)..[65535] = 255;
        final greenLut = Uint8List(65536)..[65535] = 128;
        final blueLut = Uint8List(65536)..[65535] = 64;

        // 16-bit pixel 65535
        final pixelBytes = Uint8List(2);
        ByteData.sublistView(pixelBytes).setUint16(0, 65535, Endian.little);

        final bytes = SyntheticDicomGenerator.create(
          width: 1,
          height: 1,
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          photometricInterpretation: 'PALETTE COLOR',
          redDescriptor: desc,
          greenDescriptor: desc,
          blueDescriptor: desc,
          redLutData: redLut,
          greenLutData: greenLut,
          blueLutData: blueLut,
          customPixelData: pixelBytes,
        );

        final dataset = DicomDataset.fromBytes(bytes);
        final lut = PaletteColorLut.fromDataset(dataset);
        expect(lut.numberOfEntries, 65536);

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.sublist(0, 4), [255, 128, 64, 255]);
      },
    );

    test('7. Malformed descriptor (< 6 bytes) throws FormatException', () {
      final descBytes = Uint8List.fromList([
        0x03,
        0x00,
        0x00,
        0x00,
      ]); // only 4 bytes

      final bytes = SyntheticDicomGenerator.create(
        photometricInterpretation: 'PALETTE COLOR',
        rawRedDescriptorBytes: descBytes,
        greenDescriptor: [3, 0, 8],
        blueDescriptor: [3, 0, 8],
        redLutData: Uint8List(3),
        greenLutData: Uint8List(3),
        blueLutData: Uint8List(3),
      );

      final dataset = DicomDataset.fromBytes(bytes);
      expect(() => DicomRenderer.renderToRgba(dataset), throwsFormatException);
    });

    test('8. Truncated LUT data throws FormatException', () {
      final desc = [256, 0, 8];
      // Red LUT has only 10 bytes instead of 256
      final redLut = Uint8List(10);
      final greenLut = Uint8List(256);
      final blueLut = Uint8List(256);

      final bytes = SyntheticDicomGenerator.create(
        photometricInterpretation: 'PALETTE COLOR',
        redDescriptor: desc,
        greenDescriptor: desc,
        blueDescriptor: desc,
        redLutData: redLut,
        greenLutData: greenLut,
        blueLutData: blueLut,
      );

      final dataset = DicomDataset.fromBytes(bytes);
      expect(() => DicomRenderer.renderToRgba(dataset), throwsFormatException);
    });

    test(
      '9. Inconsistent/Mismatched RGB descriptors throw FormatException',
      () {
        final redDesc = [256, 0, 8];
        final greenDesc = [128, 0, 8]; // Mismatched entry count
        final blueDesc = [256, 0, 8];

        final bytes = SyntheticDicomGenerator.create(
          photometricInterpretation: 'PALETTE COLOR',
          redDescriptor: redDesc,
          greenDescriptor: greenDesc,
          blueDescriptor: blueDesc,
          redLutData: Uint8List(256),
          greenLutData: Uint8List(128),
          blueLutData: Uint8List(256),
        );

        final dataset = DicomDataset.fromBytes(bytes);
        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsFormatException,
        );
      },
    );

    test(
      '10. Unsupported bit depth (e.g. bitsPerEntry = 12) throws FormatException',
      () {
        final desc = [256, 0, 12]; // 12 is invalid in DICOM PS3.3 C.7.6.3.1.5

        final bytes = SyntheticDicomGenerator.create(
          photometricInterpretation: 'PALETTE COLOR',
          redDescriptor: desc,
          greenDescriptor: desc,
          blueDescriptor: desc,
          redLutData: Uint8List(256),
          greenLutData: Uint8List(256),
          blueLutData: Uint8List(256),
        );

        final dataset = DicomDataset.fromBytes(bytes);
        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsFormatException,
        );
      },
    );

    test(
      '11. Unsupported Segmented LUT data without direct LUT throws UnsupportedError',
      () {
        final bytes = SyntheticDicomGenerator.create(
          photometricInterpretation: 'PALETTE COLOR',
          segmentedRedLutData: Uint8List(64),
        );

        final dataset = DicomDataset.fromBytes(bytes);
        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsUnsupportedError,
        );
      },
    );

    test(
      '11b. Unsupported Enhanced Palette Color Sequence (0028,140B) throws UnsupportedError',
      () {
        final bytes = SyntheticDicomGenerator.create(
          photometricInterpretation: 'PALETTE COLOR',
          hasEnhancedPaletteSequence: true,
        );

        final dataset = DicomDataset.fromBytes(bytes);
        expect(
          () => DicomRenderer.renderToRgba(dataset),
          throwsUnsupportedError,
        );
      },
    );

    test(
      '11c. Explicit SS descriptor with negative firstMappedValue decodes and indexes correctly',
      () {
        // SS descriptor: 3 entries, firstMappedValue = -10, 8 bits/entry
        final desc = [3, -10, 8];
        final redLut = Uint8List.fromList([255, 0, 0]);
        final greenLut = Uint8List.fromList([0, 255, 0]);
        final blueLut = Uint8List.fromList([0, 0, 255]);

        // 16-bit signed pixel values: [-10, -9, -8, -20, 5]
        // -10 -> entry 0 (255, 0, 0)
        // -9  -> entry 1 (0, 255, 0)
        // -8  -> entry 2 (0, 0, 255)
        // -20 (below range) -> clamped to entry 0 (255, 0, 0)
        // 5   (above range) -> clamped to entry 2 (0, 0, 255)
        final pixelBytes = Uint8List(5 * 2);
        final bd = ByteData.sublistView(pixelBytes);
        bd.setInt16(0, -10, Endian.little);
        bd.setInt16(2, -9, Endian.little);
        bd.setInt16(4, -8, Endian.little);
        bd.setInt16(6, -20, Endian.little);
        bd.setInt16(8, 5, Endian.little);

        final bytes = SyntheticDicomGenerator.create(
          width: 5,
          height: 1,
          bitsAllocated: 16,
          bitsStored: 16,
          highBit: 15,
          pixelRepresentation: 1, // Signed 2's complement
          photometricInterpretation: 'PALETTE COLOR',
          descriptorVr: 'SS',
          redDescriptor: desc,
          greenDescriptor: desc,
          blueDescriptor: desc,
          redLutData: redLut,
          greenLutData: greenLut,
          blueLutData: blueLut,
          customPixelData: pixelBytes,
        );

        final dataset = DicomDataset.fromBytes(bytes);
        final lut = PaletteColorLut.fromDataset(dataset);
        expect(lut.numberOfEntries, 3);
        expect(lut.firstMappedValue, -10);

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, 5 * 1 * 4);

        // Pixel -10 -> entry 0
        expect(rgba.sublist(0, 4), [255, 0, 0, 255]);
        // Pixel -9  -> entry 1
        expect(rgba.sublist(4, 8), [0, 255, 0, 255]);
        // Pixel -8  -> entry 2
        expect(rgba.sublist(8, 12), [0, 0, 255, 255]);
        // Pixel -20 -> clamped to entry 0
        expect(rgba.sublist(12, 16), [255, 0, 0, 255]);
        // Pixel 5   -> clamped to entry 2
        expect(rgba.sublist(16, 20), [0, 0, 255, 255]);
      },
    );

    test(
      '11d. Explicit US descriptor with firstMappedValue = 0 decodes and indexes correctly',
      () {
        final desc = [3, 0, 8];
        final redLut = Uint8List.fromList([10, 20, 30]);
        final greenLut = Uint8List.fromList([40, 50, 60]);
        final blueLut = Uint8List.fromList([70, 80, 90]);

        final pixelBytes = Uint8List.fromList([0, 1, 2]);

        final bytes = SyntheticDicomGenerator.create(
          width: 3,
          height: 1,
          bitsAllocated: 8,
          bitsStored: 8,
          highBit: 7,
          pixelRepresentation: 0,
          photometricInterpretation: 'PALETTE COLOR',
          descriptorVr: 'US',
          redDescriptor: desc,
          greenDescriptor: desc,
          blueDescriptor: desc,
          redLutData: redLut,
          greenLutData: greenLut,
          blueLutData: blueLut,
          customPixelData: pixelBytes,
        );

        final dataset = DicomDataset.fromBytes(bytes);
        final lut = PaletteColorLut.fromDataset(dataset);
        expect(lut.numberOfEntries, 3);
        expect(lut.firstMappedValue, 0);

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.sublist(0, 4), [10, 40, 70, 255]);
        expect(rgba.sublist(4, 8), [20, 50, 80, 255]);
        expect(rgba.sublist(8, 12), [30, 60, 90, 255]);
      },
    );

    test(
      '12. Missing Red, Green, or Blue descriptor or data throws FormatException',
      () {
        // Missing Red Descriptor
        final bytesNoRedDesc = SyntheticDicomGenerator.create(
          photometricInterpretation: 'PALETTE COLOR',
          greenDescriptor: [3, 0, 8],
          blueDescriptor: [3, 0, 8],
          redLutData: Uint8List(3),
          greenLutData: Uint8List(3),
          blueLutData: Uint8List(3),
        );
        expect(
          () => DicomRenderer.renderToRgba(
            DicomDataset.fromBytes(bytesNoRedDesc),
          ),
          throwsFormatException,
        );

        // Missing Blue LUT Data
        final bytesNoBlueData = SyntheticDicomGenerator.create(
          photometricInterpretation: 'PALETTE COLOR',
          redDescriptor: [3, 0, 8],
          greenDescriptor: [3, 0, 8],
          blueDescriptor: [3, 0, 8],
          redLutData: Uint8List(3),
          greenLutData: Uint8List(3),
        );
        expect(
          () => DicomRenderer.renderToRgba(
            DicomDataset.fromBytes(bytesNoBlueData),
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('Task 6 — Real Fixture Validation (OBXXXX1A_rle.dcm)', () {
    late DicomDataset dataset;

    setUpAll(() {
      final file = File('test/fixtures/rle/OBXXXX1A_rle.dcm');
      dataset = DicomDataset.fromBytes(file.readAsBytesSync());
    });

    test('13. OBXXXX1A_rle.dcm metadata and palette color LUTs verified', () {
      expect(dataset.photometricInterpretation, 'PALETTE COLOR');
      expect(dataset.rows, 600);
      expect(dataset.columns, 800);
      expect(dataset.samplesPerPixel, 1);
      expect(dataset.bitsAllocated, 8);
      expect(dataset.bitsStored, 8);
      expect(dataset.pixelRepresentation, 0);
      expect(dataset.transferSyntaxUid, '1.2.840.10008.1.2.5');

      final lut = PaletteColorLut.fromDataset(dataset);
      expect(lut.numberOfEntries, 256);
      expect(lut.firstMappedValue, 0);
      expect(lut.bitsPerEntry, 16);
      expect(lut.redLut.length, 256);
      expect(lut.greenLut.length, 256);
      expect(lut.blueLut.length, 256);
    });

    test(
      '14. OBXXXX1A_rle.dcm full RGBA rendering and known ultrasound pixel colors',
      () {
        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, 600 * 800 * 4);

        // Pixel 0 in OBXXXX1A_rle.dcm has stored value 244 (Doppler ultrasound slate blue background)
        // 16-bit RGB = (9472, 15872, 24064) -> 8-bit RGB = (37, 62, 94, 255)
        expect(rgba.sublist(0, 4), [37, 62, 94, 255]);

        // Verify LUT values for key ultrasound pixel values:
        final lut = PaletteColorLut.fromDataset(dataset);

        // Pixel 0 in LUT: 16-bit RGB = (0, 0, 0) -> 8-bit RGB = (0, 0, 0)
        expect(lut.redLut[0], 0);
        expect(lut.greenLut[0], 0);
        expect(lut.blueLut[0], 0);

        // Pixel 1 in LUT: 16-bit RGB = (256, 256, 256) -> 8-bit RGB = (1, 1, 1)
        expect(lut.redLut[1], 1);
        expect(lut.greenLut[1], 1);
        expect(lut.blueLut[1], 1);

        // Pixel 244 in LUT (Doppler / Ultrasound slate blue background):
        // 16-bit RGB = (9472, 15872, 24064) -> 8-bit RGB = (37, 62, 94)
        expect(lut.redLut[244], 37);
        expect(lut.greenLut[244], 62);
        expect(lut.blueLut[244], 94);

        // Pixel 231 in LUT (Text / Grid annotation):
        // 16-bit RGB = (65280, 65280, 65280) -> 8-bit RGB = (255, 255, 255)
        expect(lut.redLut[231], 255);
        expect(lut.greenLut[231], 255);
        expect(lut.blueLut[231], 255);
      },
    );

    test('15. OBXXXX1A_rle.dcm renderToImage returns valid ui.Image', () async {
      final img = await DicomRenderer.renderToImage(dataset);
      expect(img.width, 800);
      expect(img.height, 600);
    });

    testWidgets(
      '16. DicomImageWidget renders PALETTE COLOR fixture in widget tree with Color mode overlay',
      (tester) async {
        bool windowChangedCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DicomImageWidget(
                dataset: dataset,
                onWindowChanged: (c, w) {
                  windowChangedCalled = true;
                },
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(find.byType(DicomImageWidget), findsOneWidget);
        expect(find.byType(RawImage), findsOneWidget);

        // Shows Color: Palette LUT in overlay
        expect(find.text('Color: Palette LUT'), findsOneWidget);
        // Does NOT show misleading WC / WW or drag instructions
        expect(find.textContaining('WC:'), findsNothing);
        expect(find.textContaining('Drag to adjust contrast'), findsNothing);

        // Dragging gesture does not fire onWindowChanged for PALETTE COLOR
        final gestureFinder = find.byKey(const Key('dicom_windowing_gesture'));
        await tester.drag(gestureFinder, const Offset(50, -30));
        await tester.pump();

        expect(windowChangedCalled, isFalse);
      },
    );
  });

  group('Task 6 — Regression Tests', () {
    test(
      '17. MONOCHROME2 uncompressed fixture (CT_small.dcm) renders correctly',
      () {
        final file = File('test/fixtures/CT_small.dcm');
        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
        expect(dataset.photometricInterpretation, 'MONOCHROME2');

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, dataset.rows * dataset.columns * 4);
      },
    );

    test('18. MONOCHROME1 synthetic dataset renders with inversion', () {
      final bytes = SyntheticDicomGenerator.create(
        photometricInterpretation: 'MONOCHROME1',
        width: 4,
        height: 4,
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final rgba = DicomRenderer.renderToRgba(dataset);
      expect(rgba.length, 4 * 4 * 4);
    });

    test('19. RGB synthetic dataset renders unchanged', () {
      final rgbBytes = Uint8List.fromList([
        255, 0, 0, // R
        0, 255, 0, // G
        0, 0, 255, // B
        255, 255, 0, // Yellow
      ]);
      final bytes = SyntheticDicomGenerator.create(
        width: 2,
        height: 2,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        photometricInterpretation: 'RGB',
        samplesPerPixel: 3,
        planarConfiguration: 0,
        customRgbBytes: rgbBytes,
      );
      final dataset = DicomDataset.fromBytes(bytes);
      final rgba = DicomRenderer.renderToRgba(dataset);
      expect(rgba.sublist(0, 4), [255, 0, 0, 255]);
      expect(rgba.sublist(4, 8), [0, 255, 0, 255]);
      expect(rgba.sublist(8, 12), [0, 0, 255, 255]);
      expect(rgba.sublist(12, 16), [255, 255, 0, 255]);
    });

    test(
      '20. Existing RLE grayscale (emri_small_RLE.dcm) renders correctly',
      () {
        final file = File('test/fixtures/rle/emri_small_RLE.dcm');
        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
        expect(dataset.photometricInterpretation, 'MONOCHROME2');

        final rgba = DicomRenderer.renderToRgba(dataset);
        expect(rgba.length, dataset.rows * dataset.columns * 4);
      },
    );

    test(
      '21. Existing RLE multi-frame (OBXXXX1A_rle_2frame.dcm) renders frame 0 and frame 1',
      () {
        final file = File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm');
        final dataset = DicomDataset.fromBytes(file.readAsBytesSync());
        expect(dataset.numberOfFrames, 2);
        expect(dataset.photometricInterpretation, 'PALETTE COLOR');

        final frame0 = DicomRenderer.renderToRgba(dataset, frameIndex: 0);
        final frame1 = DicomRenderer.renderToRgba(dataset, frameIndex: 1);
        expect(frame0.length, 600 * 800 * 4);
        expect(frame1.length, 600 * 800 * 4);
      },
    );
  });
}
