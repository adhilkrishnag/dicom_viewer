import 'dart:typed_data';

/// Internal-only descriptor for an encapsulated sequence item fragment.
class InternalFragment {
  /// Creates an [InternalFragment] descriptor.
  const InternalFragment({
    required this.index,
    required this.relativeTagStart,
    required this.payload,
  });

  /// 1-indexed item number (1..M).
  final int index;

  /// Byte offset T_k relative to the start of Item #1 tag.
  final int relativeTagStart;

  /// Raw fragment byte payload.
  final Uint8List payload;
}

/// Internal-only container for DICOM PS3.5 Annex A.4 encapsulated structures.
///
/// Stores Basic Offset Table uint32 offsets and sequence item fragments.
/// NOT exported in `lib/dicom_viewer.dart`.
class EncapsulatedPixelData {
  /// Creates an [EncapsulatedPixelData] container with [botOffsets] and [fragments].
  EncapsulatedPixelData({required this.botOffsets, required this.fragments});

  /// uint32 offsets extracted from Basic Offset Table (Item #0).
  /// Empty if BOT length is 0.
  final List<int> botOffsets;

  /// Ordered fragment item payloads (Item #1..M).
  final List<InternalFragment> fragments;

  Uint8List? _cachedFlatBytes;

  /// Single source of truth for lazy flat byte generation.
  /// Allocated ONLY when explicitly accessed by legacy/external code.
  Uint8List get flatBytes {
    if (_cachedFlatBytes != null) return _cachedFlatBytes!;
    if (fragments.isEmpty) return Uint8List(0);
    if (fragments.length == 1) {
      _cachedFlatBytes = fragments[0].payload;
      return _cachedFlatBytes!;
    }
    final builder = BytesBuilder(copy: false);
    for (final frag in fragments) {
      builder.add(frag.payload);
    }
    _cachedFlatBytes = builder.toBytes();
    return _cachedFlatBytes!;
  }
}
