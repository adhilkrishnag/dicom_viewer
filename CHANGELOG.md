# Changelog

## 0.4.0

- **2D Distance Measurement Caliper Tool (`DicomTool.measure`)**:
  - Interactive distance caliper measurement on the 2D DICOM image plane.
  - Computes Euclidean physical distance in millimeters ($mm$) when `Pixel Spacing (0028,0030)` is present.
  - Safe fallback to pixel distance ($px$) when physical spacing is absent or invalid.
  - Interactive endpoint adjustment, endpoint hit-testing, zoom/pan invariance, and screen-reader accessibility semantics.
- **2D Rectangle Region of Interest (ROI) (`DicomTool.rectangleRoi`)**:
  - Interactive rectangular ROI creation with automatic corner normalization.
  - Reports physical dimensions ($W \times H$ in $mm$, Area in $mm^2$) or pixel fallback ($W \times H$ in $px$, Area in $px^2$).
  - Strict image boundary validation without silent clamping.
- **Quantitative ROI Pixel Statistics & Hounsfield Units (HU)**:
  - Quantitative statistics engine evaluating discrete pixels enclosed by ROI boundaries.
  - Calculates Mean, Population Standard Deviation ($\sigma_N$, denominator $N$), Min, Max, Median, and Pixel Count.
  - Verified Hounsfield Unit ($HU$) statistics on CT datasets with explicit valid Rescale Slope ($>0$) and Intercept.
  - Unitless intensity statistics on non-CT modalities (MR, CR, DX, US) with zero invented units or false `px` intensity suffixes.
  - Pre-rescale Pixel Padding Value (`0028,0120`) and Range Limit (`0028,0121`) exclusion in stored pixel space.
  - Per-frame statistics caching computed strictly on pointer release without background rendering overhead.
- **Pixel Probe Tool (`DicomTool.probe`)**:
  - Real-time hover inspection overlay showing discrete pixel coordinate $(c, r)$, stored scalar intensity, and modality/HU rescaled values.
  - Multi-channel RGB triplet and palette index inspection for PALETTE COLOR and RGB datasets.
  - Ephemeral current-frame buffer caching ($O(1)$ lookup per hover event) without full-image re-decoding.
- **Internal 2D Image Geometry & Safe Fallback Architecture**:
  - Canonical `DicomImageGeometry` and `ImageCoordinateTransform` models.
  - Strict geometry fallback classification: Verified Physical Spacing $\to$ Display-Only Pixel Aspect Ratio (`0028,0034`) $\to$ Native Matrix Fallback.
  - Enforces that Pixel Aspect Ratio corrects display aspect ratio only and is strictly prohibited from inventing physical distance scales.
- **Frame-Aware Measurement State & Isolation**:
  - Strict per-frame isolation across Distance Measurements, ROIs, Statistics, and Probe buffers.
  - Frame navigation and tool switching preserve per-frame state without cross-frame leakage.
  - Dataset changes cleanly invalidate and reset all measurement and probe caches.
- **100% Public API DartDoc Coverage**:
  - Complete DartDoc documentation with standard citations and mathematical formulas across all public symbols.
- **Important Semantics & Limitations**:
  - Physical measurements ($mm, mm^2$) strictly require verified, finite, positive `Pixel Spacing (0028,0030)`.
  - `Pixel Aspect Ratio (0028,0034)` provides display aspect ratio correction only and never establishes physical scale.
  - Native matrix fallback operates in pure pixel space ($px, px^2$).
  - Hounsfield Units ($HU$) require valid explicit CT rescale metadata; missing or non-positive rescale slopes cleanly fall back to stored unitless scalar values.
  - Pixel Padding is excluded in stored-pixel space before modality rescale calculation.
  - Intensity statistics for MR, CR, DX, and other non-CT modalities remain unitless without invented units or $px$ suffixes.
  - 3D spatial geometry (Image Position / Image Orientation Patient slice reconstruction), MPR, 3D volume rendering, DICOM Structured Reporting (SR), and Grayscale Softcopy Presentation State (GSPS) are out of scope.

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
