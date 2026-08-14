import 'dart:convert';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Encapsulated Pixel Data Parser Integration Tests', () {
    test(
      'DicomParser preserves BOT uint32 offsets and sequence item fragment boundaries',
      () {
        final builder = BytesBuilder();

        // 128-byte Preamble + 'DICM'
        builder.add(Uint8List(128));
        builder.add(utf8.encode('DICM'));

        // Group 0002 Transfer Syntax UID = RLE Lossless (1.2.840.10008.1.2.5)
        const tsUidStr = '${TransferSyntax.rleLossless}\x00';
        final tsBytes = utf8.encode(tsUidStr);

        final metaBd = ByteData(8);
        metaBd.setUint16(0, 0x0002, Endian.little);
        metaBd.setUint16(2, 0x0010, Endian.little);
        metaBd.setUint8(4, 'U'.codeUnitAt(0));
        metaBd.setUint8(5, 'I'.codeUnitAt(0));
        metaBd.setUint16(6, tsBytes.length, Endian.little);
        builder.add(metaBd.buffer.asUint8List());
        builder.add(tsBytes);

        // Group 7FE0 Pixel Data (7FE0, 0010) OB, Undefined Length 0xFFFFFFFF
        final pixelHeader = ByteData(12);
        pixelHeader.setUint16(0, 0x7FE0, Endian.little);
        pixelHeader.setUint16(2, 0x0010, Endian.little);
        pixelHeader.setUint8(4, 'O'.codeUnitAt(0));
        pixelHeader.setUint8(5, 'B'.codeUnitAt(0));
        pixelHeader.setUint16(6, 0, Endian.little);
        pixelHeader.setUint32(8, 0xFFFFFFFF, Endian.little);
        builder.add(pixelHeader.buffer.asUint8List());

        // Item #0: Basic Offset Table (BOT) containing 2 uint32 offsets: [0, 64]
        final botPayload = ByteData(8);
        botPayload.setUint32(0, 0, Endian.little);
        botPayload.setUint32(4, 64, Endian.little);

        final botItem = ByteData(8);
        botItem.setUint16(0, 0xFFFE, Endian.little);
        botItem.setUint16(2, 0xE000, Endian.little);
        botItem.setUint32(4, 8, Endian.little);
        builder.add(botItem.buffer.asUint8List());
        builder.add(botPayload.buffer.asUint8List());

        // Item #1: Fragment 1 payload (e.g. [1, 2, 3, 4])
        final frag1Bytes = Uint8List.fromList([1, 2, 3, 4]);
        final frag1Item = ByteData(8);
        frag1Item.setUint16(0, 0xFFFE, Endian.little);
        frag1Item.setUint16(2, 0xE000, Endian.little);
        frag1Item.setUint32(4, 4, Endian.little);
        builder.add(frag1Item.buffer.asUint8List());
        builder.add(frag1Bytes);

        // Item #2: Fragment 2 payload (e.g. [5, 6, 7, 8])
        final frag2Bytes = Uint8List.fromList([5, 6, 7, 8]);
        final frag2Item = ByteData(8);
        frag2Item.setUint16(0, 0xFFFE, Endian.little);
        frag2Item.setUint16(2, 0xE000, Endian.little);
        frag2Item.setUint32(4, 4, Endian.little);
        builder.add(frag2Item.buffer.asUint8List());
        builder.add(frag2Bytes);

        // Sequence Delimitation Item (FFFE, E0DD)
        final seqDelim = ByteData(8);
        seqDelim.setUint16(0, 0xFFFE, Endian.little);
        seqDelim.setUint16(2, 0xE0DD, Endian.little);
        seqDelim.setUint32(4, 0, Endian.little);
        builder.add(seqDelim.buffer.asUint8List());

        final dicomBytes = builder.toBytes();
        final dataset = DicomDataset.fromBytes(dicomBytes);

        final encData = dataset.encapsulatedData;
        expect(encData, isNotNull);
        expect(encData!.botOffsets, equals([0, 64]));
        expect(encData.fragments.length, equals(2));
        expect(encData.fragments[0].payload, equals([1, 2, 3, 4]));
        expect(encData.fragments[1].payload, equals([5, 6, 7, 8]));

        // Check backward-compatible lazy pixelDataBytes getter
        expect(dataset.pixelDataBytes, equals([1, 2, 3, 4, 5, 6, 7, 8]));
      },
    );
  });
}
