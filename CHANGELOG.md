# Changelog

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
