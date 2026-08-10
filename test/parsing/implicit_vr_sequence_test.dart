import 'dart:convert';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Implicit VR Sequence & Undefined Length Parsing Tests', () {
    test(
      'Parses Implicit VR DICOM file with unknown undefined-length sequence tag (0099,9999) without desyncing parser offset',
      () {
        final builder = BytesBuilder();

        // 1. 128-byte Preamble + 'DICM'
        builder.add(Uint8List(128));
        builder.add(utf8.encode('DICM'));

        // 2. Group 0002 Tag (0002, 0010) Transfer Syntax UID = Implicit VR Little Endian
        // Explicit VR Little Endian header for Group 0002
        const tsUidStr = '${TransferSyntax.implicitVRLittleEndian}\x00';
        final tsBytes = utf8.encode(tsUidStr);

        final metaBd = ByteData(8);
        metaBd.setUint16(0, 0x0002, Endian.little);
        metaBd.setUint16(2, 0x0010, Endian.little);
        metaBd.setUint8(4, 'U'.codeUnitAt(0));
        metaBd.setUint8(5, 'I'.codeUnitAt(0));
        metaBd.setUint16(6, tsBytes.length, Endian.little);
        builder.add(metaBd.buffer.asUint8List());
        builder.add(tsBytes);

        // 3. Implicit VR Dataset starts here!
        // Element A: Patient Name (0010, 0010) -> "TEST^PATIENT "
        final patNameBytes = utf8.encode('TEST^PATIENT ');
        final elem1Bd = ByteData(8);
        elem1Bd.setUint16(0, 0x0010, Endian.little);
        elem1Bd.setUint16(2, 0x0010, Endian.little);
        elem1Bd.setUint32(4, patNameBytes.length, Endian.little);
        builder.add(elem1Bd.buffer.asUint8List());
        builder.add(patNameBytes);

        // Element B: UNKNOWN Sequence Tag (0099, 9999) with Undefined Length (0xFFFFFFFF)
        // NOT in TagDictionary!
        final seqBd = ByteData(8);
        seqBd.setUint16(0, 0x0099, Endian.little);
        seqBd.setUint16(2, 0x9999, Endian.little);
        seqBd.setUint32(4, 0xFFFFFFFF, Endian.little);
        builder.add(seqBd.buffer.asUint8List());

        // Item 1: (FFFE, E000) length 4 -> 0x12345678
        final itemBd = ByteData(12);
        itemBd.setUint16(0, 0xFFFE, Endian.little);
        itemBd.setUint16(2, 0xE000, Endian.little);
        itemBd.setUint32(4, 4, Endian.little);
        itemBd.setUint32(8, 0x12345678, Endian.little);
        builder.add(itemBd.buffer.asUint8List());

        // Sequence Delimitation Item: (FFFE, E0DD) length 0
        final seqDelimBd = ByteData(8);
        seqDelimBd.setUint16(0, 0xFFFE, Endian.little);
        seqDelimBd.setUint16(2, 0xE0DD, Endian.little);
        seqDelimBd.setUint32(4, 0, Endian.little);
        builder.add(seqDelimBd.buffer.asUint8List());

        // Element C: Rows (0028, 0010) -> 64
        // Should parse successfully AFTER the unknown sequence item!
        final rowsBd = ByteData(10);
        rowsBd.setUint16(0, 0x0028, Endian.little);
        rowsBd.setUint16(2, 0x0010, Endian.little);
        rowsBd.setUint32(4, 2, Endian.little);
        rowsBd.setUint16(8, 64, Endian.little);
        builder.add(rowsBd.buffer.asUint8List());

        // Element D: Columns (0028, 0011) -> 64
        final colsBd = ByteData(10);
        colsBd.setUint16(0, 0x0028, Endian.little);
        colsBd.setUint16(2, 0x0011, Endian.little);
        colsBd.setUint32(4, 2, Endian.little);
        colsBd.setUint16(8, 64, Endian.little);
        builder.add(colsBd.buffer.asUint8List());

        final dicomBytes = builder.toBytes();
        final dataset = DicomDataset.fromBytes(dicomBytes);

        // Assertions
        expect(dataset.patientName.trim(), equals('TEST^PATIENT'));
        expect(dataset.rows, equals(64));
        expect(dataset.columns, equals(64));
        expect(dataset.getElement(const DicomTag(0x0099, 0x9999)), isNotNull);
      },
    );
  });
}
