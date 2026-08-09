import 'dart:convert';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to generate a byte-accurate Explicit VR Big Endian DICOM file (1.2.840.10008.1.2.2).
Uint8List createExplicitVRBigEndianDicom({int width = 4, int height = 4}) {
  final builder = BytesBuilder();

  // 1. 128-byte Preamble + 4-byte 'DICM' prefix
  builder.add(Uint8List(128));
  builder.add(utf8.encode('DICM'));

  // Group 0002 File Meta Info elements MUST be Explicit VR Little Endian per DICOM PS 3.5
  void writeLittleEndianElement(
    int group,
    int element,
    String vrCode,
    Uint8List value,
  ) {
    final header = ByteData(8);
    header.setUint16(0, group, Endian.little);
    header.setUint16(2, element, Endian.little);
    header.setUint8(4, vrCode.codeUnitAt(0));
    header.setUint8(5, vrCode.codeUnitAt(1));
    header.setUint16(6, value.length, Endian.little);
    builder.add(header.buffer.asUint8List());
    builder.add(value);
  }

  // File Meta Information Transfer Syntax UID: 1.2.840.10008.1.2.2 (Explicit VR Big Endian)
  var tsUidBytes = utf8.encode('1.2.840.10008.1.2.2\x00');
  if (tsUidBytes.length.isOdd) {
    tsUidBytes = Uint8List.fromList([...tsUidBytes, 0x20]);
  }
  writeLittleEndianElement(
    0x0002,
    0x0010,
    'UI',
    Uint8List.fromList(tsUidBytes),
  );

  // Helper for writing Explicit VR Big Endian dataset elements
  void writeBigEndianElement(
    int group,
    int element,
    String vrCode,
    Uint8List value,
  ) {
    final isLong = ['OB', 'OW', 'OF', 'SQ', 'UT', 'UN'].contains(vrCode);
    if (isLong) {
      final header = ByteData(12);
      header.setUint16(0, group, Endian.big);
      header.setUint16(2, element, Endian.big);
      header.setUint8(4, vrCode.codeUnitAt(0));
      header.setUint8(5, vrCode.codeUnitAt(1));
      header.setUint16(6, 0, Endian.big); // Reserved
      header.setUint32(8, value.length, Endian.big);
      builder.add(header.buffer.asUint8List());
    } else {
      final header = ByteData(8);
      header.setUint16(0, group, Endian.big);
      header.setUint16(2, element, Endian.big);
      header.setUint8(4, vrCode.codeUnitAt(0));
      header.setUint8(5, vrCode.codeUnitAt(1));
      header.setUint16(6, value.length, Endian.big);
      builder.add(header.buffer.asUint8List());
    }
    builder.add(value);
  }

  void writeBigEndianUint16(int group, int element, int val) {
    final bd = ByteData(2)..setUint16(0, val, Endian.big);
    writeBigEndianElement(group, element, 'US', bd.buffer.asUint8List());
  }

  void writeBigEndianString(int group, int element, String vr, String text) {
    var strBytes = utf8.encode(text);
    if (strBytes.length.isOdd) {
      strBytes = Uint8List.fromList([...strBytes, 0x20]);
    }
    writeBigEndianElement(group, element, vr, Uint8List.fromList(strBytes));
  }

  // Dataset elements (Group 0008, 0010, 0028, 7FE0 in Big Endian)
  writeBigEndianString(0x0008, 0x0060, 'CS', 'CT');
  writeBigEndianString(0x0010, 0x0010, 'PN', 'DOE^JOHN');

  writeBigEndianUint16(0x0028, 0x0002, 1); // Samples per pixel
  writeBigEndianString(0x0028, 0x0004, 'CS', 'MONOCHROME2');
  writeBigEndianUint16(0x0028, 0x0010, height);
  writeBigEndianUint16(0x0028, 0x0011, width);
  writeBigEndianUint16(0x0028, 0x0100, 16); // Bits Allocated
  writeBigEndianUint16(0x0028, 0x0101, 12); // Bits Stored
  writeBigEndianUint16(0x0028, 0x0102, 11); // High Bit
  writeBigEndianUint16(0x0028, 0x0103, 0); // Unsigned

  writeBigEndianString(0x0028, 0x1050, 'DS', '2048');
  writeBigEndianString(0x0028, 0x1051, 'DS', '4096');

  // Group 7FE0 Pixel Data (16-bit Big Endian values)
  final pixelCount = width * height;
  final pixelBytes = Uint8List(pixelCount * 2);
  final bdPixels = ByteData.sublistView(pixelBytes);

  for (int i = 0; i < pixelCount; i++) {
    // Write Big Endian Uint16 values
    final val = (i * 200).clamp(0, 4095);
    bdPixels.setUint16(i * 2, val, Endian.big);
  }

  writeBigEndianElement(0x7FE0, 0x0010, 'OW', pixelBytes);

  return builder.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explicit VR Big Endian DICOM Tests (1.2.840.10008.1.2.2)', () {
    test('Parses Explicit VR Big Endian DICOM header and tags correctly', () {
      final dicomBytes = createExplicitVRBigEndianDicom(width: 4, height: 4);
      final dataset = DicomDataset.fromBytes(dicomBytes);

      expect(dataset.transferSyntaxUid, TransferSyntax.explicitVRBigEndian);
      expect(dataset.modality, 'CT');
      expect(dataset.patientName, 'DOE^JOHN');
      expect(dataset.rows, 4);
      expect(dataset.columns, 4);
      expect(dataset.bitsAllocated, 16);
      expect(dataset.bitsStored, 12);
      expect(dataset.pixelDataBytes, isNotNull);
      expect(dataset.pixelDataBytes!.length, 4 * 4 * 2);
    });

    test(
      'Decodes 16-bit Big Endian pixel data and renders to RGBA buffer correctly',
      () {
        final dicomBytes = createExplicitVRBigEndianDicom(width: 4, height: 4);
        final dataset = DicomDataset.fromBytes(dicomBytes);

        final rgbaBytes = DicomRenderer.renderToRgba(dataset);
        expect(rgbaBytes, isNotNull);
        expect(rgbaBytes.length, 4 * 4 * 4);
      },
    );

    test(
      'Renders Explicit VR Big Endian DICOM to ui.Image without errors',
      () async {
        final dicomBytes = createExplicitVRBigEndianDicom(width: 4, height: 4);
        final dataset = DicomDataset.fromBytes(dicomBytes);

        final image = await DicomRenderer.renderToImage(dataset);
        expect(image.width, 4);
        expect(image.height, 4);
      },
    );
  });
}
