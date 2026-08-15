import 'dart:typed_data';

import '../parsing/data_element.dart';
import '../parsing/dicom_dataset.dart';
import '../parsing/tag.dart';
import '../parsing/value_representation.dart';

/// Descriptor fields for a single Palette Color Lookup Table channel.
class _LutDescriptor {
  const _LutDescriptor({
    required this.numberOfEntries,
    required this.firstMappedValue,
    required this.bitsPerEntry,
  });

  final int numberOfEntries;
  final int firstMappedValue;
  final int bitsPerEntry;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LutDescriptor &&
          numberOfEntries == other.numberOfEntries &&
          firstMappedValue == other.firstMappedValue &&
          bitsPerEntry == other.bitsPerEntry;

  @override
  int get hashCode =>
      numberOfEntries.hashCode ^
      firstMappedValue.hashCode ^
      bitsPerEntry.hashCode;

  @override
  String toString() =>
      'entries: $numberOfEntries, firstMapped: $firstMappedValue, bits: $bitsPerEntry';
}

/// Internal helper for decoding and indexing DICOM PALETTE COLOR Lookup Tables (PS3.3 C.7.6.3.1.5).
class PaletteColorLut {
  PaletteColorLut({
    required this.numberOfEntries,
    required this.firstMappedValue,
    required this.bitsPerEntry,
    required this.redLut,
    required this.greenLut,
    required this.blueLut,
  });

  /// Parses and decodes Palette Color Lookup Tables from a [DicomDataset].
  ///
  /// Throws [FormatException] if descriptors or data elements are missing, incomplete,
  /// mismatched, truncated, or have invalid parameters.
  /// Throws [UnsupportedError] if segmented LUT data is encountered without direct LUT data.
  factory PaletteColorLut.fromDataset(DicomDataset dataset) {
    // 1. Check for segmented LUT data or enhanced palette sequence
    final hasSegmented =
        dataset.getElement(DicomTag.segmentedRedPaletteColorLookupTableData) !=
            null ||
        dataset.getElement(
              DicomTag.segmentedGreenPaletteColorLookupTableData,
            ) !=
            null ||
        dataset.getElement(DicomTag.segmentedBluePaletteColorLookupTableData) !=
            null;

    final hasEnhancedSequence =
        dataset.getElement(DicomTag.enhancedPaletteColorLookupTableSequence) !=
        null;

    final redDescElem = dataset.getElement(
      DicomTag.redPaletteColorLookupTableDescriptor,
    );
    final greenDescElem = dataset.getElement(
      DicomTag.greenPaletteColorLookupTableDescriptor,
    );
    final blueDescElem = dataset.getElement(
      DicomTag.bluePaletteColorLookupTableDescriptor,
    );

    final redDataElem = dataset.getElement(
      DicomTag.redPaletteColorLookupTableData,
    );
    final greenDataElem = dataset.getElement(
      DicomTag.greenPaletteColorLookupTableData,
    );
    final blueDataElem = dataset.getElement(
      DicomTag.bluePaletteColorLookupTableData,
    );

    if (hasSegmented &&
        (redDataElem == null ||
            greenDataElem == null ||
            blueDataElem == null)) {
      throw UnsupportedError(
        'Segmented Palette Color Lookup Table Data (0028,1221-1223) is unsupported in v0.3.0. '
        'Only direct Palette Color LUT Data (0028,1201-1203) is supported.',
      );
    }

    if (hasEnhancedSequence &&
        (redDataElem == null ||
            greenDataElem == null ||
            blueDataElem == null)) {
      throw UnsupportedError(
        'Enhanced Palette Color Lookup Table Sequence (0028,140B) is unsupported in v0.3.0. '
        'Only direct Palette Color LUT Data (0028,1201-1203) is supported.',
      );
    }

    // 2. Validate descriptor presence
    if (redDescElem == null) {
      throw const FormatException(
        'PALETTE COLOR dataset missing Red Palette Color Lookup Table Descriptor (0028,1101).',
      );
    }
    if (greenDescElem == null) {
      throw const FormatException(
        'PALETTE COLOR dataset missing Green Palette Color Lookup Table Descriptor (0028,1102).',
      );
    }
    if (blueDescElem == null) {
      throw const FormatException(
        'PALETTE COLOR dataset missing Blue Palette Color Lookup Table Descriptor (0028,1103).',
      );
    }

    // 3. Validate data presence
    if (redDataElem == null) {
      throw const FormatException(
        'PALETTE COLOR dataset missing Red Palette Color Lookup Table Data (0028,1201).',
      );
    }
    if (greenDataElem == null) {
      throw const FormatException(
        'PALETTE COLOR dataset missing Green Palette Color Lookup Table Data (0028,1202).',
      );
    }
    if (blueDataElem == null) {
      throw const FormatException(
        'PALETTE COLOR dataset missing Blue Palette Color Lookup Table Data (0028,1203).',
      );
    }

    // 4. Parse descriptors
    final isSignedPixel = dataset.pixelRepresentation == 1;
    final redDesc = _parseDescriptor(redDescElem, isSignedPixel);
    final greenDesc = _parseDescriptor(greenDescElem, isSignedPixel);
    final blueDesc = _parseDescriptor(blueDescElem, isSignedPixel);

    // 5. Verify descriptor consistency across RGB channels
    if (redDesc != greenDesc || redDesc != blueDesc) {
      throw FormatException(
        'Inconsistent Palette Color LUT descriptors: '
        'Red($redDesc), Green($greenDesc), Blue($blueDesc).',
      );
    }

    final numEntries = redDesc.numberOfEntries;
    final bitsPerEntry = redDesc.bitsPerEntry;
    final firstMapped = redDesc.firstMappedValue;

    // 6. Decode LUT data
    final redLut = _decodeLutData(
      redDataElem,
      numEntries,
      bitsPerEntry,
      channel: 'Red',
    );
    final greenLut = _decodeLutData(
      greenDataElem,
      numEntries,
      bitsPerEntry,
      channel: 'Green',
    );
    final blueLut = _decodeLutData(
      blueDataElem,
      numEntries,
      bitsPerEntry,
      channel: 'Blue',
    );

    return PaletteColorLut(
      numberOfEntries: numEntries,
      firstMappedValue: firstMapped,
      bitsPerEntry: bitsPerEntry,
      redLut: redLut,
      greenLut: greenLut,
      blueLut: blueLut,
    );
  }

  /// Number of entries in the lookup table (1..65536).
  final int numberOfEntries;

  /// Stored pixel value that maps to index 0.
  final int firstMappedValue;

  /// Bit depth of each LUT entry (8 or 16).
  final int bitsPerEntry;

  /// 8-bit precomputed Red channel lookup table.
  final Uint8List redLut;

  /// 8-bit precomputed Green channel lookup table.
  final Uint8List greenLut;

  /// 8-bit precomputed Blue channel lookup table.
  final Uint8List blueLut;

  static _LutDescriptor _parseDescriptor(
    DicomDataElement element,
    bool isSignedPixel,
  ) {
    final bytes = element.valueBytes;
    if (bytes.length < 6) {
      throw FormatException(
        'Incomplete Palette Color LUT descriptor (${element.tag}): '
        'expected at least 6 bytes, found ${bytes.length}.',
      );
    }

    final endian = element.isLittleEndian ? Endian.little : Endian.big;
    final bd = ByteData.sublistView(bytes);

    final rawNum = bd.getUint16(0, endian);
    // DICOM PS3.3 C.7.6.3.1.5: A value of 0 indicates 65536 entries.
    final numberOfEntries = rawNum == 0 ? 65536 : rawNum;

    final isSigned = isSignedPixel || element.vr == ValueRepresentation.ss;
    final firstMappedValue =
        isSigned ? bd.getInt16(2, endian) : bd.getUint16(2, endian);

    final bitsPerEntry = bd.getUint16(4, endian);
    if (bitsPerEntry != 8 && bitsPerEntry != 16) {
      throw FormatException(
        'Invalid Palette Color LUT bitsPerEntry: $bitsPerEntry. Must be 8 or 16.',
      );
    }

    return _LutDescriptor(
      numberOfEntries: numberOfEntries,
      firstMappedValue: firstMappedValue,
      bitsPerEntry: bitsPerEntry,
    );
  }

  static Uint8List _decodeLutData(
    DicomDataElement element,
    int numberOfEntries,
    int bitsPerEntry, {
    required String channel,
  }) {
    final bytes = element.valueBytes;

    if (bitsPerEntry == 8) {
      if (bytes.length < numberOfEntries) {
        throw FormatException(
          'Truncated $channel Palette Color LUT data: '
          'expected at least $numberOfEntries bytes, found ${bytes.length}.',
        );
      }
      final lut = Uint8List(numberOfEntries);
      lut.setRange(0, numberOfEntries, bytes);
      return lut;
    } else {
      // 16-bit entries: 2 bytes per entry
      final requiredBytes = numberOfEntries * 2;
      if (bytes.length < requiredBytes) {
        throw FormatException(
          'Truncated $channel Palette Color LUT data: '
          'expected at least $requiredBytes bytes, found ${bytes.length}.',
        );
      }

      final lut = Uint8List(numberOfEntries);
      final isLittleEndian = element.isLittleEndian;

      for (int i = 0; i < numberOfEntries; i++) {
        final offset = i * 2;
        final val16 =
            isLittleEndian
                ? (bytes[offset] | (bytes[offset + 1] << 8))
                : ((bytes[offset] << 8) | bytes[offset + 1]);
        // DICOM Standard: 16-bit full range / high byte scaled to 8-bit RGBA channel
        lut[i] = (val16 >> 8) & 0xFF;
      }

      return lut;
    }
  }

  /// Maps an array of stored scalar pixel values into a 32-bit RGBA buffer.
  ///
  /// For stored pixel value V:
  ///   index = V - firstMappedValue
  /// Clamped to:
  ///   0 .. numberOfEntries - 1
  void mapPixelsToRgba(
    List<int> rawPixels,
    Uint8List rgbaBytes,
    int pixelCount,
  ) {
    for (int i = 0; i < pixelCount; i++) {
      final p = i < rawPixels.length ? rawPixels[i] : 0;
      int idx = p - firstMappedValue;
      if (idx < 0) {
        idx = 0;
      } else if (idx >= numberOfEntries) {
        idx = numberOfEntries - 1;
      }

      final offset = i * 4;
      rgbaBytes[offset] = redLut[idx]; // R
      rgbaBytes[offset + 1] = greenLut[idx]; // G
      rgbaBytes[offset + 2] = blueLut[idx]; // B
      rgbaBytes[offset + 3] = 255; // A (Opaque)
    }
  }
}
