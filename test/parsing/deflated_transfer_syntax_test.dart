import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a minimal valid DICOM with Group 0002 specifying Deflated Explicit VR LE.
Uint8List _buildDeflatedDicom() {
  // Build a minimal DICOM Part 10 file with:
  //   - 128-byte preamble + 'DICM' prefix
  //   - Group 0002 Transfer Syntax UID element (0002,0010) with UI VR
  //   - One non-0002 element to trigger the TS transition check in DicomParser

  const tsUid = '1.2.840.10008.1.2.1.99';
  // UI VR uses 2-byte length field; must be padded to even length with 0x00
  final tsUidBytes = Uint8List.fromList(tsUid.codeUnits);
  final tsUidPadded =
      tsUidBytes.length % 2 == 0
          ? tsUidBytes
          : Uint8List.fromList([...tsUidBytes, 0x00]);

  final buffer = <int>[];

  // 128-byte preamble
  buffer.addAll(List.filled(128, 0));
  // DICM magic
  buffer.addAll([0x44, 0x49, 0x43, 0x4D]);

  // Write uint16 LE
  void writeU16(int v) {
    buffer.add(v & 0xFF);
    buffer.add((v >> 8) & 0xFF);
  }

  // Write an Explicit VR element with 2-byte length (for UI, LO, CS, etc.)
  void writeUIElement(int group, int element, Uint8List value) {
    writeU16(group);
    writeU16(element);
    buffer.addAll('UI'.codeUnits); // VR
    writeU16(value.length); // 2-byte length
    buffer.addAll(value);
  }

  // (0002,0010) Transfer Syntax UID
  writeUIElement(0x0002, 0x0010, tsUidPadded);

  // (0002,0012) Implementation Class UID (to round out a minimally valid Group 0002)
  final implUid = Uint8List.fromList([
    ...List.filled(0, 0),
    ...('1.2.3'.codeUnits),
    0x00, // pad to even
  ]);
  writeUIElement(0x0002, 0x0012, implUid);

  // Non-Group-0002 element: (0008,0016) SOP Class UID (Explicit VR, UI, short)
  // This triggers the TS transition check in DicomParser.
  final sopUid = Uint8List.fromList([...'1.2.3'.codeUnits, 0x00]);
  writeUIElement(0x0008, 0x0016, sopUid);

  return Uint8List.fromList(buffer);
}

void main() {
  group('Deflated Explicit VR Little Endian — Unsupported Status', () {
    test(
      'TransferSyntaxDetails.fromUid recognises UID 1.2.840.10008.1.2.1.99',
      () {
        final details = TransferSyntaxDetails.fromUid(
          TransferSyntax.deflatedExplicitVRLittleEndian,
        );
        expect(
          details.name,
          equals('Deflated Explicit VR Little Endian'),
          reason: 'UID should be explicitly named, not generic',
        );
        expect(details.isExplicitVR, isTrue);
        expect(details.isLittleEndian, isTrue);
        expect(
          details.isEncapsulated,
          isFalse,
          reason:
              'Deflated TS is not encapsulated pixel data — it is whole-stream compressed',
        );
      },
    );

    test('TransferSyntax constant matches the DICOM standard UID', () {
      expect(
        TransferSyntax.deflatedExplicitVRLittleEndian,
        equals('1.2.840.10008.1.2.1.99'),
      );
    });

    test(
      'DicomParser throws UnsupportedError for Deflated Explicit VR LE dataset',
      () {
        final bytes = _buildDeflatedDicom();
        const parser = DicomParser();
        expect(
          () => parser.parse(bytes),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              contains('1.2.840.10008.1.2.1.99'),
            ),
          ),
          reason: 'Parser must throw UnsupportedError for deflated datasets',
        );
      },
    );

    test(
      'DicomDataset.fromBytes throws UnsupportedError for Deflated Explicit VR LE dataset',
      () {
        final bytes = _buildDeflatedDicom();
        expect(
          () => DicomDataset.fromBytes(bytes),
          throwsA(isA<UnsupportedError>()),
          reason:
              'DicomDataset.fromBytes must propagate parser UnsupportedError',
        );
      },
    );

    test('Error message is descriptive and mentions the constraint reason', () {
      final bytes = _buildDeflatedDicom();
      const parser = DicomParser();
      try {
        parser.parse(bytes);
        fail('Should have thrown');
      } on UnsupportedError catch (e) {
        expect(e.message, contains('1.2.840.10008.1.2.1.99'));
        expect(e.message, isNotNull);
        expect(
          e.message!.length,
          greaterThan(20),
          reason: 'Error should be descriptive',
        );
      }
    });
  });
}
