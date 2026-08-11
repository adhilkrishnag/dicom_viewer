# Changelog

## 0.2.0

- Pure-Dart RLE Lossless decompressor (`1.2.840.10008.1.2.5`) supporting 8-bit, 16-bit MSB/LSB, and 24-bit RGB segment unpacking. RLE Lossless is implemented and unit-tested, but real-world DICOM RLE compatibility has not yet been validated against a real RLE DICOM fixture.
- Pixel Padding Value (`0028, 0120`) & Range Limit (`0028, 0121`) filtering in auto-windowing calculation.
- Multi-valued clinical window presets support (`windowCenterPresets`, `windowWidthPresets`).
- Multi-frame groundwork with 0-indexed `frameIndex` parameter in `DicomRenderer` and `DicomImageWidget`.
- Interactive pan & pinch-to-zoom support (`enableZoom`), double-tap gesture reset, and `onViewChanged` callback in `DicomImageWidget`.

## 0.1.0

- Initial release
- Parse single-frame uncompressed DICOM files (Explicit VR Little Endian)
- Support for Implicit VR Little Endian parsing
- Pixel data decoding: 8-bit and 16-bit (signed/unsigned)
- Windowing: rescale slope/intercept, window center/width
- Photometric interpretation: MONOCHROME1, MONOCHROME2
- Interactive windowing widget with drag gestures
- Cross-platform: Android, iOS, macOS, Windows, Linux, Web
- No native/FFI dependencies — 100% pure Dart
