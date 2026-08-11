import 'dart:convert';
import 'dart:typed_data';

/// Helper to generate synthetic valid DICOM files for unit testing.
class SyntheticDicomGenerator {
  /// Generates a minimal Explicit VR Little Endian DICOM binary byte stream.
  static Uint8List create({
    int width = 32,
    int height = 32,
    int bitsAllocated = 16,
    int bitsStored = 12,
    int highBit = 11,
    int pixelRepresentation = 0,
    String photometricInterpretation = 'MONOCHROME2',
    double rescaleSlope = 1.0,
    double rescaleIntercept = -1024.0,
    double windowCenter = 40.0,
    double windowWidth = 400.0,
    String? windowCenterString,
    String? windowWidthString,
    int? numberOfFrames,
    String patientName = 'TEST^PATIENT',
    String modality = 'CT',
    String transferSyntaxUid = '1.2.840.10008.1.2.1',
    Uint8List? rawEncapsulatedBytes,
    int samplesPerPixel = 1,
    int planarConfiguration = 0,
    Uint8List? customRgbBytes,
  }) {
    final builder = BytesBuilder();

    // 128-byte preamble of 0x00
    builder.add(Uint8List(128));

    // 4-byte prefix 'DICM'
    builder.add(utf8.encode('DICM'));

    // Helper function to write Explicit VR Data Element
    void writeElement(int group, int element, String vrCode, Uint8List value) {
      final header = ByteData(8);
      header.setUint16(0, group, Endian.little);
      header.setUint16(2, element, Endian.little);
      header.setUint8(4, vrCode.codeUnitAt(0));
      header.setUint8(5, vrCode.codeUnitAt(1));

      final isLong = ['OB', 'OW', 'OF', 'SQ', 'UT', 'UN'].contains(vrCode);
      if (isLong) {
        final longHeader = ByteData(12);
        longHeader.setUint16(0, group, Endian.little);
        longHeader.setUint16(2, element, Endian.little);
        longHeader.setUint8(4, vrCode.codeUnitAt(0));
        longHeader.setUint8(5, vrCode.codeUnitAt(1));
        longHeader.setUint16(6, 0, Endian.little); // Reserved
        longHeader.setUint32(8, value.length, Endian.little);
        builder.add(longHeader.buffer.asUint8List());
      } else {
        header.setUint16(6, value.length, Endian.little);
        builder.add(header.buffer.asUint8List());
      }
      builder.add(value);
    }

    void writeString(int group, int element, String vr, String text) {
      var bytes = utf8.encode(text);
      if (bytes.length.isOdd) {
        bytes = Uint8List.fromList([...bytes, 0x20]); // Pad with space
      }
      writeElement(group, element, vr, Uint8List.fromList(bytes));
    }

    void writeUint16(int group, int element, int val) {
      final bd = ByteData(2)..setUint16(0, val, Endian.little);
      writeElement(group, element, 'US', bd.buffer.asUint8List());
    }

    // Group 0002 File Meta Info
    writeString(0x0002, 0x0010, 'UI', '$transferSyntaxUid\x00');

    // Group 0008 General Info
    writeString(0x0008, 0x0060, 'CS', modality);

    // Group 0010 Patient Info
    writeString(0x0010, 0x0010, 'PN', patientName);

    // Group 0028 Image Pixel Module
    if (numberOfFrames != null) {
      writeString(0x0028, 0x0008, 'IS', numberOfFrames.toString());
    }
    writeUint16(0x0028, 0x0002, samplesPerPixel);
    writeString(0x0028, 0x0004, 'CS', photometricInterpretation);
    if (samplesPerPixel > 1) {
      writeUint16(0x0028, 0x0006, planarConfiguration);
    }
    writeUint16(0x0028, 0x0010, height);
    writeUint16(0x0028, 0x0011, width);
    writeUint16(0x0028, 0x0100, bitsAllocated);
    writeUint16(0x0028, 0x0101, bitsStored);
    writeUint16(0x0028, 0x0102, highBit);
    writeUint16(0x0028, 0x0103, pixelRepresentation);

    writeString(0x0028, 0x1052, 'DS', rescaleIntercept.toString());
    writeString(0x0028, 0x1053, 'DS', rescaleSlope.toString());
    writeString(
      0x0028,
      0x1050,
      'DS',
      windowCenterString ?? windowCenter.toString(),
    );
    writeString(
      0x0028,
      0x1051,
      'DS',
      windowWidthString ?? windowWidth.toString(),
    );

    // Group 7FE0 Pixel Data
    if (rawEncapsulatedBytes != null) {
      // Write Encapsulated Pixel Data (OB, undefined length 0xFFFFFFFF)
      final pixelHeader = ByteData(12);
      pixelHeader.setUint16(0, 0x7FE0, Endian.little);
      pixelHeader.setUint16(2, 0x0010, Endian.little);
      pixelHeader.setUint8(4, 'O'.codeUnitAt(0));
      pixelHeader.setUint8(5, 'B'.codeUnitAt(0));
      pixelHeader.setUint16(6, 0, Endian.little);
      pixelHeader.setUint32(8, 0xFFFFFFFF, Endian.little);
      builder.add(pixelHeader.buffer.asUint8List());

      // Item #0: Basic Offset Table (0 bytes)
      final botItem = ByteData(8);
      botItem.setUint16(0, 0xFFFE, Endian.little);
      botItem.setUint16(2, 0xE000, Endian.little);
      botItem.setUint32(4, 0, Endian.little);
      builder.add(botItem.buffer.asUint8List());

      // Item #1: Encapsulated frame bytes
      var frameBytes = rawEncapsulatedBytes;
      if (frameBytes.length.isOdd) {
        frameBytes = Uint8List.fromList([...frameBytes, 0x00]);
      }
      final frameItem = ByteData(8);
      frameItem.setUint16(0, 0xFFFE, Endian.little);
      frameItem.setUint16(2, 0xE000, Endian.little);
      frameItem.setUint32(4, frameBytes.length, Endian.little);
      builder.add(frameItem.buffer.asUint8List());
      builder.add(frameBytes);

      // Sequence Delimitation Item
      final seqDelim = ByteData(8);
      seqDelim.setUint16(0, 0xFFFE, Endian.little);
      seqDelim.setUint16(2, 0xE0DD, Endian.little);
      seqDelim.setUint32(4, 0, Endian.little);
      builder.add(seqDelim.buffer.asUint8List());
    } else if (customRgbBytes != null) {
      writeElement(0x7FE0, 0x0010, 'OB', customRgbBytes);
    } else {
      final pixelCount = width * height;
      final totalSamples = pixelCount * samplesPerPixel;
      final pixelBytes = Uint8List(totalSamples * (bitsAllocated ~/ 8));
      final bdPixels = ByteData.sublistView(pixelBytes);

      for (int i = 0; i < totalSamples; i++) {
        final val = ((i / totalSamples) * 255).round();
        if (bitsAllocated == 8) {
          pixelBytes[i] = val & 0xFF;
        } else if (bitsAllocated == 16) {
          bdPixels.setUint16(i * 2, val & 0xFFFF, Endian.little);
        }
      }

      writeElement(
        0x7FE0,
        0x0010,
        bitsAllocated == 8 ? 'OB' : 'OW',
        pixelBytes,
      );
    }

    return builder.toBytes();
  }
}
