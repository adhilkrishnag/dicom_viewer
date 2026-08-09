/// Common DICOM Transfer Syntax UIDs.
class TransferSyntax {
  /// Implicit VR Little Endian (Default DICOM Transfer Syntax)
  static const String implicitVRLittleEndian = '1.2.840.10008.1.2';

  /// Explicit VR Little Endian
  static const String explicitVRLittleEndian = '1.2.840.10008.1.2.1';

  /// Deflated Explicit VR Little Endian
  static const String deflatedExplicitVRLittleEndian = '1.2.840.10008.1.2.1.99';

  /// Explicit VR Big Endian (Retired)
  static const String explicitVRBigEndian = '1.2.840.10008.1.2.2';

  /// RLE Lossless
  static const String rleLossless = '1.2.840.10008.1.2.5';

  /// JPEG Baseline (Process 1)
  static const String jpegBaseline = '1.2.840.10008.1.2.4.50';

  /// JPEG Extended (Process 2 & 4)
  static const String jpegExtended = '1.2.840.10008.1.2.4.51';

  /// JPEG Lossless (Process 14)
  static const String jpegLossless = '1.2.840.10008.1.2.4.57';

  /// JPEG Lossless, Non-Hierarchical, First-Order Prediction (Process 14 Selection Value 1)
  static const String jpegLosslessSV1 = '1.2.840.10008.1.2.4.70';

  /// JPEG 2000 Image Compression (Lossless Only)
  static const String jpeg2000Lossless = '1.2.840.10008.1.2.4.90';

  /// JPEG 2000 Image Compression
  static const String jpeg2000 = '1.2.840.10008.1.2.4.91';
}

/// Metadata about a Transfer Syntax configuration.
class TransferSyntaxDetails {
  const TransferSyntaxDetails({
    required this.uid,
    required this.name,
    required this.isExplicitVR,
    required this.isLittleEndian,
    required this.isEncapsulated,
  });

  final String uid;
  final String name;
  final bool isExplicitVR;
  final bool isLittleEndian;
  final bool isEncapsulated;

  static TransferSyntaxDetails fromUid(String uid) {
    final cleanUid = uid.trim().replaceAll('\x00', '');
    switch (cleanUid) {
      case TransferSyntax.implicitVRLittleEndian:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'Implicit VR Little Endian',
          isExplicitVR: false,
          isLittleEndian: true,
          isEncapsulated: false,
        );
      case TransferSyntax.explicitVRLittleEndian:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'Explicit VR Little Endian',
          isExplicitVR: true,
          isLittleEndian: true,
          isEncapsulated: false,
        );
      case TransferSyntax.explicitVRBigEndian:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'Explicit VR Big Endian',
          isExplicitVR: true,
          isLittleEndian: false,
          isEncapsulated: false,
        );
      case TransferSyntax.jpegBaseline:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'JPEG Baseline (8-bit)',
          isExplicitVR: true,
          isLittleEndian: true,
          isEncapsulated: true,
        );
      case TransferSyntax.jpegExtended:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'JPEG Extended (12-bit)',
          isExplicitVR: true,
          isLittleEndian: true,
          isEncapsulated: true,
        );
      case TransferSyntax.jpegLossless:
      case TransferSyntax.jpegLosslessSV1:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'JPEG Lossless',
          isExplicitVR: true,
          isLittleEndian: true,
          isEncapsulated: true,
        );
      case TransferSyntax.jpeg2000Lossless:
      case TransferSyntax.jpeg2000:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'JPEG 2000',
          isExplicitVR: true,
          isLittleEndian: true,
          isEncapsulated: true,
        );
      case TransferSyntax.rleLossless:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'RLE Lossless',
          isExplicitVR: true,
          isLittleEndian: true,
          isEncapsulated: true,
        );
      default:
        return TransferSyntaxDetails(
          uid: cleanUid,
          name: 'Transfer Syntax $cleanUid',
          isExplicitVR: true,
          isLittleEndian: true,
          isEncapsulated:
              cleanUid != TransferSyntax.implicitVRLittleEndian &&
              cleanUid != TransferSyntax.explicitVRLittleEndian &&
              cleanUid != TransferSyntax.explicitVRBigEndian,
        );
    }
  }
}
