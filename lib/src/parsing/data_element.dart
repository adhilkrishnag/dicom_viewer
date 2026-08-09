import 'dart:convert';
import 'dart:typed_data';

import 'tag.dart';
import 'value_representation.dart';

/// Represents a single DICOM Data Element containing tag, VR, length, and raw bytes.
class DicomDataElement {
  const DicomDataElement({
    required this.tag,
    required this.vr,
    required this.valueLength,
    required this.valueBytes,
    this.isLittleEndian = true,
  });

  final DicomTag tag;
  final ValueRepresentation vr;
  final int valueLength;
  final Uint8List valueBytes;
  final bool isLittleEndian;

  /// Interpret value as string.
  String get asString {
    if (valueBytes.isEmpty) return '';
    final str = utf8.decode(valueBytes, allowMalformed: true).trim();
    // DICOM strings are padded with null or space
    return str.replaceAll('\x00', '').trim();
  }

  /// Interpret value as list of strings (separated by '\\').
  List<String> get asStringList {
    final raw = asString;
    if (raw.isEmpty) return const [];
    return raw.split('\\').map((e) => e.trim()).toList();
  }

  /// Interpret value as integer (from IS, US, UL, SS, SL, or string IS).
  int? get asInt {
    if (valueBytes.isEmpty) return null;
    switch (vr) {
      case ValueRepresentation.us:
        if (valueBytes.length < 2) return null;
        final bd = ByteData.sublistView(valueBytes);
        return bd.getUint16(0, isLittleEndian ? Endian.little : Endian.big);
      case ValueRepresentation.ul:
        if (valueBytes.length < 4) return null;
        final bd = ByteData.sublistView(valueBytes);
        return bd.getUint32(0, isLittleEndian ? Endian.little : Endian.big);
      case ValueRepresentation.ss:
        if (valueBytes.length < 2) return null;
        final bd = ByteData.sublistView(valueBytes);
        return bd.getInt16(0, isLittleEndian ? Endian.little : Endian.big);
      case ValueRepresentation.sl:
        if (valueBytes.length < 4) return null;
        final bd = ByteData.sublistView(valueBytes);
        return bd.getInt32(0, isLittleEndian ? Endian.little : Endian.big);
      case ValueRepresentation.isVR:
      case ValueRepresentation.ds:
      case ValueRepresentation.cs:
      case ValueRepresentation.sh:
      case ValueRepresentation.lo:
        final str = asString;
        if (str.isEmpty) return null;
        final firstPart = str.contains('\\') ? str.split('\\').first : str;
        return int.tryParse(firstPart) ?? double.tryParse(firstPart)?.toInt();
      default:
        final str = asString;
        return int.tryParse(str);
    }
  }

  /// Interpret value as double (from DS, FL, FD, or string DS).
  double? get asDouble {
    if (valueBytes.isEmpty) return null;
    switch (vr) {
      case ValueRepresentation.fl:
        if (valueBytes.length < 4) return null;
        final bd = ByteData.sublistView(valueBytes);
        return bd.getFloat32(0, isLittleEndian ? Endian.little : Endian.big);
      case ValueRepresentation.fd:
        if (valueBytes.length < 8) return null;
        final bd = ByteData.sublistView(valueBytes);
        return bd.getFloat64(0, isLittleEndian ? Endian.little : Endian.big);
      case ValueRepresentation.ds:
      case ValueRepresentation.isVR:
        final str = asString;
        if (str.isEmpty) return null;
        final firstPart = str.contains('\\') ? str.split('\\').first : str;
        return double.tryParse(firstPart);
      default:
        final str = asString;
        return double.tryParse(str);
    }
  }

  /// Interpret value as list of doubles (multi-valued DS).
  List<double> get asDoubleList {
    final list = asStringList;
    return list.map((s) => double.tryParse(s)).whereType<double>().toList();
  }

  @override
  String toString() => '$tag ${vr.code} [$valueLength bytes] -> $asString';
}
