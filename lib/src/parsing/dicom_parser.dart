import 'dart:convert';
import 'dart:typed_data';

import 'data_element.dart';
import 'tag.dart';
import 'tag_dictionary.dart';
import 'transfer_syntax.dart';
import 'value_representation.dart';

/// Robust Pure-Dart DICOM File & Dataset Parser adhering to DICOM Part 10 (PS3.10) & Part 5 (PS3.5).
class DicomParser {
  const DicomParser();

  /// Parse binary DICOM bytes into a list of [DicomDataElement].
  List<DicomDataElement> parse(Uint8List bytes) {
    if (bytes.length < 8) {
      throw const FormatException(
        'Invalid DICOM file: Data length is less than 8 bytes.',
      );
    }

    final bd = ByteData.sublistView(bytes);

    // 1. Check for 128-byte preamble + 4-byte 'DICM' prefix
    bool hasHeader = false;
    if (bytes.length >= 132) {
      final prefix = utf8.decode(bytes.sublist(128, 132), allowMalformed: true);
      hasHeader = prefix == 'DICM';
    }

    if (!hasHeader && bytes.length < 132) {
      throw FormatException(
        'Invalid DICOM file: Truncated or missing DICM header (${bytes.length} bytes).',
      );
    }

    int offset = hasHeader ? 132 : 0;
    final elements = <DicomDataElement>[];

    // Default syntax before reading File Meta Info is Explicit VR Little Endian for Group 0002
    TransferSyntaxDetails datasetSyntax = const TransferSyntaxDetails(
      uid: TransferSyntax.explicitVRLittleEndian,
      name: 'Explicit VR Little Endian',
      isExplicitVR: true,
      isLittleEndian: true,
      isEncapsulated: false,
    );

    // Parse elements sequentially
    while (offset + 4 <= bytes.length) {
      // Read Tag (Group, Element)
      final group = bd.getUint16(
        offset,
        datasetSyntax.isLittleEndian ? Endian.little : Endian.big,
      );
      final element = bd.getUint16(
        offset + 2,
        datasetSyntax.isLittleEndian ? Endian.little : Endian.big,
      );
      final tag = DicomTag(group, element);

      // Group 0002 File Meta Info elements are ALWAYS Explicit VR Little Endian per DICOM standard
      final isGroup0002 = group == 0x0002;

      // DICOM PS3.5 Section 7.5: Group 0xFFFE items (Item, Item Delimitation, Sequence Delimitation)
      // NEVER have VR fields even in Explicit VR mode!
      final isDelimitationOrItem = group == 0xFFFE;

      final currentExplicitVR =
          isDelimitationOrItem
              ? false
              : (isGroup0002 ? true : datasetSyntax.isExplicitVR);

      final currentLittleEndian =
          isGroup0002 ? true : datasetSyntax.isLittleEndian;

      offset += 4;

      ValueRepresentation vr;
      int valueLength;

      if (isDelimitationOrItem) {
        // Item / Delimitation tags have 4-byte uint32 length field and no VR
        if (offset + 4 > bytes.length) break;
        vr = ValueRepresentation.unknown;
        valueLength = bd.getUint32(
          offset,
          currentLittleEndian ? Endian.little : Endian.big,
        );
        offset += 4;
      } else if (currentExplicitVR) {
        if (offset + 2 > bytes.length) break;
        final vrCode = utf8.decode(
          bytes.sublist(offset, offset + 2),
          allowMalformed: true,
        );
        offset += 2;
        vr = ValueRepresentationX.parse(vrCode);

        if (vr.isLongHeader) {
          // 2 reserved bytes + 4 bytes length
          offset += 2;
          if (offset + 4 > bytes.length) break;
          valueLength = bd.getUint32(
            offset,
            currentLittleEndian ? Endian.little : Endian.big,
          );
          offset += 4;
        } else {
          // 2 bytes length
          if (offset + 2 > bytes.length) break;
          valueLength = bd.getUint16(
            offset,
            currentLittleEndian ? Endian.little : Endian.big,
          );
          offset += 2;
        }
      } else {
        // Implicit VR: 4 bytes length, VR looked up from dictionary
        if (offset + 4 > bytes.length) break;
        vr = TagDictionary.getVR(tag);
        valueLength = bd.getUint32(
          offset,
          currentLittleEndian ? Endian.little : Endian.big,
        );
        offset += 4;
      }

      // Handle Undefined Length (0xFFFFFFFF)
      if (valueLength == 0xFFFFFFFF) {
        if (tag == DicomTag.pixelData) {
          // Encapsulated / Undefined length Pixel Data (7FE0, 0010)
          // Scan forward for Sequence Delimitation Tag (FFFE, E0DD)
          final fragmentBytes = BytesBuilder();
          bool isFirstItem = true;
          while (offset + 8 <= bytes.length) {
            final fGroup = bd.getUint16(
              offset,
              currentLittleEndian ? Endian.little : Endian.big,
            );
            final fElem = bd.getUint16(
              offset + 2,
              currentLittleEndian ? Endian.little : Endian.big,
            );
            final fLen = bd.getUint32(
              offset + 4,
              currentLittleEndian ? Endian.little : Endian.big,
            );
            offset += 8;

            if (fGroup == 0xFFFE && fElem == 0xE0DD) {
              // Sequence Delimitation Item found
              break;
            }

            if (fGroup == 0xFFFE && fElem == 0xE000) {
              if (isFirstItem) {
                // Item #0 is the Basic Offset Table (BOT). Skip BOT payload!
                isFirstItem = false;
                if (fLen > 0 &&
                    fLen != 0xFFFFFFFF &&
                    offset + fLen <= bytes.length) {
                  offset += fLen;
                }
              } else {
                if (fLen > 0 &&
                    fLen != 0xFFFFFFFF &&
                    offset + fLen <= bytes.length) {
                  fragmentBytes.add(bytes.sublist(offset, offset + fLen));
                  offset += fLen;
                }
              }
            } else if (fLen > 0 &&
                fLen != 0xFFFFFFFF &&
                offset + fLen <= bytes.length) {
              offset += fLen;
            }
          }

          final valueData = fragmentBytes.toBytes();
          elements.add(
            DicomDataElement(
              tag: tag,
              vr: vr,
              valueLength: valueData.length,
              valueBytes: valueData,
              isLittleEndian: currentLittleEndian,
            ),
          );
          continue;
        } else if (vr == ValueRepresentation.sq ||
            !currentExplicitVR ||
            vr == ValueRepresentation.un ||
            vr == ValueRepresentation.unknown) {
          // Undefined length Sequence or Implicit VR element: scan forward until Sequence Delimitation (FFFE, E0DD).
          // Per DICOM PS3.5 §7.1.2, in Implicit VR, only SQ elements can have undefined length (0xFFFFFFFF).
          final effectiveVR =
              (vr == ValueRepresentation.un ||
                      vr == ValueRepresentation.unknown)
                  ? ValueRepresentation.sq
                  : vr;
          int depth = 1;
          final sqStartOffset = offset;
          while (offset + 8 <= bytes.length) {
            final sGroup = bd.getUint16(
              offset,
              currentLittleEndian ? Endian.little : Endian.big,
            );
            final sElem = bd.getUint16(
              offset + 2,
              currentLittleEndian ? Endian.little : Endian.big,
            );

            if (sGroup == 0xFFFE && sElem == 0xE0DD) {
              // Sequence Delimitation Item
              offset += 8;
              depth--;
              if (depth <= 0) break;
            } else if (sGroup == 0xFFFE && sElem == 0xE000) {
              // Item
              offset += 8;
            } else {
              offset += 2; // Move forward scanning
            }
          }

          final sqData = bytes.sublist(
            sqStartOffset,
            offset.clamp(0, bytes.length),
          );
          elements.add(
            DicomDataElement(
              tag: tag,
              vr: effectiveVR,
              valueLength: sqData.length,
              valueBytes: sqData,
              isLittleEndian: currentLittleEndian,
            ),
          );
          continue;
        } else {
          // Other undefined length item: fallback to empty
          valueLength = 0;
        }
      }

      // Extract Value Bytes for standard defined-length elements
      Uint8List valueBytes;
      if (valueLength > 0) {
        final end = (offset + valueLength).clamp(0, bytes.length);
        valueBytes = bytes.sublist(offset, end);
        offset = end;
      } else {
        valueBytes = Uint8List(0);
      }

      final dataElem = DicomDataElement(
        tag: tag,
        vr: vr,
        valueLength: valueLength,
        valueBytes: valueBytes,
        isLittleEndian: currentLittleEndian,
      );

      elements.add(dataElem);

      // Check if Transfer Syntax UID tag was read to update syntax for main dataset
      if (tag == DicomTag.transferSyntaxUid) {
        final tsUid = dataElem.asString;
        datasetSyntax = TransferSyntaxDetails.fromUid(tsUid);
      }
    }

    return elements;
  }
}
