# Changelog

## 0.3.0

- **Real-World DICOM RLE Lossless Fixture Validation**:
  - Full support for encapsulated DICOM RLE Lossless (`1.2.840.10008.1.2.5`) streams with Basic Offset Tables (BOT) and fragmented frames.
  - Validated against real clinical DICOM fixtures (`OBXXXX1A_rle.dcm`, `emri_small_RLE.dcm`, `OBXXXX1A_rle_2frame.dcm`).
- **Multi-Frame Navigation & Cine Playback**:
  - Added `DicomDataset.numberOfFrames` getter and 0-indexed `frameIndex` parameter across `DicomRenderer.renderToImage` and `DicomImageWidget`.
  - Added multi-frame scrub slider and play/pause Cine playback in example application.
- **Physical Pixel Spacing (`0028,0030`) Display Aspect-Ratio Correction**:
  - Automatic geometric display aspect-ratio correction preserving non-square physical pixels: `(columns * columnSpacing) / (rows * rowSpacing)`.
  - Graceful fallback to native matrix aspect ratio when Pixel Spacing is absent or invalid.
- **PALETTE COLOR Direct LUT Rendering**:
  - Support for direct Palette Color Lookup Tables (Red `0028,1201`, Green `0028,1202`, Blue `0028,1203`) and Descriptors (`0028,1101`–`1103`).
  - Supports 8-bit and 16-bit high-byte downsampling, signed/unsigned `firstMappedValue`, and $O(1)$ clamping.
  - Descriptive `UnsupportedError` on Segmented LUTs (`0028,1221-1223`) and Enhanced Sequences (`0028,140B`).
  - Palette color HUD overlay (`Color: Palette LUT`, `Color: RGB`) with windowing drag disabled on color images.
- **Comprehensive DICOM Metadata Accessors API**:
  - Added 25+ strongly-typed convenience getters for Patient, Study, Series, Equipment, Instance, Acquisition, and Image header attributes.
- **Medical Use Disclaimer**:
  - Added formal medical device and regulatory non-certification disclaimer to package documentation and example UI.
- **Interactive Tool Switching Improvements**:
  - Fixed coordinate origin consistency when switching between Pan & Zoom and Windowing tools in `InteractiveViewer`.

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
