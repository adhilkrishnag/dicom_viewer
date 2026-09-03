# dicom_viewer

[![pub package](https://img.shields.io/pub/v/dicom_viewer.svg)](https://pub.dev/packages/dicom_viewer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform Support](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-blue)](https://pub.dev/packages/dicom_viewer)

A **pure-Dart, cross-platform DICOM viewer package for Flutter**. Parses uncompressed, RLE Lossless, and JPEG compressed (Baseline & Lossless SV1) DICOM medical images, applies Hounsfield Unit rescaling, linear VOI windowing (contrast/brightness), and PALETTE COLOR lookup tables, and provides interactive 2D distance measurements, rectangular ROI statistics, and pixel probe inspection — **on Android, iOS, macOS, Windows, Linux, and Web from a single codebase with no native/FFI dependencies**.

---

## ⚕️ Medical Use Disclaimer

`dicom_viewer` is an open-source software library intended for image processing, visualization, and application development. It is not a certified or approved medical device and has not been evaluated or authorized by regulatory authorities for clinical diagnosis, treatment, or other patient-care decisions. It is not intended to replace the judgment of qualified healthcare professionals or to be used as the sole basis for clinical decision-making.

Developers are responsible for determining the suitability, validation, regulatory requirements, and intended use of applications built using this library.

---

## ✨ Features

- ⚡ **100% Pure Dart**: Zero C/C++ or FFI native code dependencies. Completely self-contained.
- 🌐 **True Cross-Platform**: Runs natively on Mobile (Android, iOS), Desktop (Windows, macOS, Linux), and Web (CanvasKit & Skwasm).
- 🩺 **DICOM PS3.10 & PS3.5 Parsing**: Parses `Explicit VR Little Endian`, `Implicit VR Little Endian`, and `Big Endian` file streams. Includes dynamic parser fallback for malformed datasets declaring Explicit VR in File Meta whose dataset body elements are encoded in Implicit VR, while properly encoded Explicit VR datasets retain standard Explicit VR parsing.
- 🖼️ **Pure-Dart JPEG Baseline Decompressor (`1.2.840.10008.1.2.4.50`)**:
  - Full 8-bit lossy DCT decompressor complying with ISO/IEC 10918-1 / ITU-T T.81.
  - Native support for grayscale (`MONOCHROME1`, `MONOCHROME2`), `RGB`, and subsampled `YBR_FULL_422` with accurate ITU-R BT.601 color conversion.
  - Supports restart markers (`RST0`–`RST7`) and DRI markers.
- 🔒 **Pure-Dart JPEG Lossless SV1 Decompressor (`1.2.840.10008.1.2.4.70`)**:
  - Full first-order prediction (Process 14, Selection Value 1) decompressor for medical imaging.
  - Supports 8-bit, 12-bit, and 16-bit sample precision with bit-exact reference oracle validation.
- 📦 **Encapsulated Pixel Data & RLE Lossless (`1.2.840.10008.1.2.5`)**:
  - Full RLE Lossless decompressor for 8-bit, 16-bit MSB/LSB, and 24-bit RGB segments, verified with real-world clinical fixtures.
- 🧩 **Modular Internal Codec Registry Architecture**:
  - Pluggable `CodecRegistry` and `DicomFrameCodec` subsystem isolating transfer syntax decoding from rendering pipelines.
  - Frame-accurate payload extraction via dedicated framing strategies (`JpegFramingStrategy`, `RleFramingStrategy`).
- 🎬 **Multi-Frame Navigation & Cine Playback**:
  - Frame slice extraction and dynamic navigation for multi-frame uncompressed, RLE, and JPEG datasets (`numberOfFrames`, `frameIndex`).
  - Supports Basic Offset Tables (BOT), empty BOT fallback with 1:1 fragment-to-frame mapping, and multi-fragment-per-frame scanning.
- 📐 **Physical Pixel Spacing & Geometry**:
  - Automatic geometric aspect-ratio correction preserving physical pixel geometry from `Pixel Spacing (0028,0030)`.
  - Canonical image geometry with strict fallback hierarchy (Verified Physical Spacing $\to$ Display-Only Pixel Aspect Ratio $\to$ Native Matrix Fallback).
- 📏 **2D Distance Measurement (`DicomTool.measure`)**:
  - Interactive caliper line drawing with draggable endpoints and hit-testing.
  - Euclidean physical distance in millimeters ($mm$) when Pixel Spacing is present, or pixel fallback ($px$).
- 🔲 **Rectangle ROI & Quantitative Statistics (`DicomTool.rectangleRoi`)**:
  - Interactive rectangular ROI creation with corner normalization.
  - Reports physical dimensions ($W \times H$ in $mm$, Area in $mm^2$) or pixel fallback ($px, px^2$).
  - Evaluates enclosed discrete pixels: Mean, Population Standard Deviation ($\sigma_N$), Min, Max, Median, and Pixel Count.
  - Verified Hounsfield Unit ($HU$) statistics on CT datasets (including JPEG Lossless CT) with explicit valid rescale metadata.
  - Unitless intensity statistics on non-CT modalities (MR, CR, DX, US) with pre-rescale Pixel Padding exclusion.
- 🔍 **Pixel Probe Tool (`DicomTool.probe`)**:
  - Real-time hover inspection overlay showing discrete coordinates $(c, r)$, stored scalar intensity, and modality/HU rescaled values.
  - RGB triplet and palette index inspection for PALETTE COLOR, RGB, and YBR datasets.
  - High-performance current-frame caching without full-image re-decoding or render pipeline overhead.
- 🎨 **PALETTE COLOR LUT Rendering**: Direct Palette Color Lookup Table mapping (Red, Green, Blue) supporting 8-bit and 16-bit entries with signed/unsigned descriptor handling.
- 🎛️ **VOI Windowing & Rescale Math**:
  - Rescale Slope & Intercept ($RealWorldValue = StoredPixel \times Slope + Intercept$).
  - DICOM PS3.3 C.11.2.1.2 Linear VOI Window Center ($WC$) & Window Width ($WW$) contrast mapping for grayscale modalities.
  - Automatic `MONOCHROME1` vs `MONOCHROME2` grayscale intensity inversion.
  - *Note: Windowing is not applicable to `PALETTE COLOR`, `RGB`, or `YBR_FULL` color rendering.*
- 📋 **Comprehensive Metadata API**: 25+ strongly-typed convenience getters for Patient, Study, Series, Equipment, Instance, and Acquisition attributes.
- 🖐️ **Interactive UI Widget**: `DicomImageWidget` with touch/pan drag gestures for windowing, pan/zoom, distance measurement, rectangle ROI, and pixel probe inspection.
- 🛡️ **Graceful Error Handling**: Clear, version-neutral `UnsupportedError` notifications for unsupported or deferred transfer syntaxes.

---

## 📊 Authoritative Transfer Syntax Support Matrix

The following table defines the official transfer syntax capabilities in `dicom_viewer v0.5.0`:

| Transfer Syntax UID | Transfer Syntax Name | Compression / Encoding | Status in v0.5.0 |
| :--- | :--- | :--- | :--- |
| **`1.2.840.10008.1.2`** | Implicit VR Little Endian | Default Uncompressed Little Endian | ✅ **Supported** |
| **`1.2.840.10008.1.2.1`** | Explicit VR Little Endian | Uncompressed Little Endian | ✅ **Supported** |
| **`1.2.840.10008.1.2.2`** | Explicit VR Big Endian | Uncompressed Big Endian (Retired) | ✅ **Supported** |
| **`1.2.840.10008.1.2.5`** | RLE Lossless | Run Length Encoding (PS3.5 Annex G) | ✅ **Supported** |
| **`1.2.840.10008.1.2.4.50`** | JPEG Baseline (Process 1) | 8-bit Lossy DCT JPEG | ✅ **Supported** |
| **`1.2.840.10008.1.2.4.70`** | JPEG Lossless, Non-Hierarchical, First-Order Prediction (Process 14 SV1) | 8-bit / 12-bit / 16-bit Lossless Huffman JPEG | ✅ **Supported** |
| `1.2.840.10008.1.2.4.51` | JPEG Extended (Process 2 & 4) | 12-bit Lossy DCT JPEG | ❌ **Unsupported** (`UnsupportedError`) |
| `1.2.840.10008.1.2.4.57` | JPEG Lossless (Process 14) | General Selection Value Lossless JPEG | ⏳ **Deferred** (`UnsupportedError`) |
| `1.2.840.10008.1.2.4.80` | JPEG-LS Lossless Image Compression | Context-based Lossless | ❌ **Unsupported** (`UnsupportedError`) |
| `1.2.840.10008.1.2.4.81` | JPEG-LS Lossy (Near-Lossless) Image Compression | Context-based Near-Lossless | ❌ **Unsupported** (`UnsupportedError`) |
| `1.2.840.10008.1.2.4.90` | JPEG 2000 Image Compression (Lossless Only) | Wavelet Lossless | ❌ **Unsupported** (`UnsupportedError`) |
| `1.2.840.10008.1.2.4.91` | JPEG 2000 Image Compression | Wavelet Lossy | ❌ **Unsupported** (`UnsupportedError`) |

### ⛔ Other Scope Boundaries & Limitations

- ❌ Segmented Palette Color LUT Data (`0028,1221-1223`) and Enhanced Palette Color Sequence (`0028,140B`) — throws clear `UnsupportedError` (only direct Palette Color LUT Data `0028,1201-1203` is supported).
- ❌ 3D spatial geometry (Image Position / Image Orientation Patient slice reconstruction).
- ❌ Multi-Planar Reconstruction (MPR) & 3D volume rendering.
- ❌ DICOM Structured Reporting (SR) & Grayscale Softcopy Presentation State (GSPS).

---

## 🚀 Getting Started

Add `dicom_viewer` to your `pubspec.yaml`:

```bash
flutter pub add dicom_viewer
```

Or import it directly in your Dart code:

```dart
import 'package:dicom_viewer/dicom_viewer.dart';
```

---

## 💡 Usage Examples

### 1. Interactive UI Widget with Tool Selection & Gestures

Use `DicomImageWidget` with tool selection (`DicomTool.pan`, `DicomTool.windowing`, `DicomTool.measure`, `DicomTool.rectangleRoi`, `DicomTool.probe`):

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dicom_viewer/dicom_viewer.dart';

class MedicalViewerScreen extends StatefulWidget {
  final Uint8List dicomBytes;

  const MedicalViewerScreen({super.key, required this.dicomBytes});

  @override
  State<MedicalViewerScreen> createState() => _MedicalViewerScreenState();
}

class _MedicalViewerScreenState extends State<MedicalViewerScreen> {
  DicomTool _selectedTool = DicomTool.pan;

  @override
  Widget build(BuildContext context) {
    final dataset = DicomDataset.fromBytes(widget.dicomBytes);

    return Scaffold(
      appBar: AppBar(
        title: Text('DICOM Viewer - ${dataset.patientName}'),
        actions: [
          SegmentedButton<DicomTool>(
            segments: const [
              ButtonSegment(value: DicomTool.pan, label: Text('Pan')),
              ButtonSegment(value: DicomTool.windowing, label: Text('Window')),
              ButtonSegment(value: DicomTool.measure, label: Text('Measure')),
              ButtonSegment(value: DicomTool.rectangleRoi, label: Text('ROI')),
              ButtonSegment(value: DicomTool.probe, label: Text('Probe')),
            ],
            selected: {_selectedTool},
            onSelectionChanged: (tools) => setState(() => _selectedTool = tools.first),
          ),
        ],
      ),
      body: Center(
        child: DicomImageWidget(
          dataset: dataset,
          enableZoom: true,
          tool: _selectedTool,
          showOverlay: true,
          onWindowChanged: (windowCenter, windowWidth) {
            print('New Windowing: WC=$windowCenter, WW=$windowWidth');
          },
        ),
      ),
    );
  }
}
```

### 2. Programmatic Rendering to `ui.Image` with Multi-Frame Support

Convert a `DicomDataset` frame directly to a Flutter `ui.Image`:

```dart
import 'dart:ui' as ui;
import 'package:dicom_viewer/dicom_viewer.dart';

Future<ui.Image> renderDicomFile(Uint8List fileBytes, {int frameIndex = 0}) async {
  // Parse DICOM dataset
  final dataset = DicomDataset.fromBytes(fileBytes);

  // Render frame to ui.Image with specific Window Center (40) & Window Width (400)
  final ui.Image image = await DicomRenderer.renderToImage(
    dataset,
    frameIndex: frameIndex,
    windowCenter: 40.0,
    windowWidth: 400.0,
  );

  return image;
}
```

### 3. Extracting DICOM Metadata & Presets

Access typed DICOM header attributes and clinical presets:

```dart
final dataset = DicomDataset.fromBytes(dicomBytes);

// Study & Series
print('Study UID: ${dataset.studyInstanceUid}');
print('Series Description: ${dataset.seriesDescription}');
print('Modality: ${dataset.modality}'); // e.g. 'CT', 'MR', 'US'

// Patient
print('Patient Name: ${dataset.patientName}');
print('Patient ID: ${dataset.patientId}');

// Geometry & Multi-Frame
print('Dimensions: ${dataset.columns} x ${dataset.rows}');
print('Number of Frames: ${dataset.numberOfFrames}');
print('Pixel Spacing: ${dataset.pixelSpacing}'); // [rowSpacing, columnSpacing]
print('Window Center Presets: ${dataset.windowCenterPresets}');
print('Window Width Presets: ${dataset.windowWidthPresets}');
```

---

## 📖 API Summary

| Class / Widget | Description |
| :--- | :--- |
| **`DicomDataset`** | Parses and stores DICOM dataset attributes and metadata from raw binary streams. |
| **`DicomRenderer`** | Renders a `DicomDataset` frame to a displayable Flutter `ui.Image` using `ui.decodeImageFromPixels`. |
| **`DicomImageWidget`** | Interactive Flutter `StatefulWidget` supporting interactive tools (`DicomTool`), drag windowing, pan/zoom, distance measurement, rectangular ROI statistics, pixel probe, and medical overlays. |
| **`DicomTool`** | Enum defining active tool mode: `pan`, `windowing`, `measure`, `rectangleRoi`, `probe`. |
| **`PixelDataDecoder`** | Decodes raw pixel bytes (8-bit, 16-bit signed/unsigned 2's complement) into normalized integer arrays. |
| **`Windowing`** | Pure math class for Rescale Slope/Intercept and DICOM PS3.3 C.11.2.1.2 Linear VOI Windowing. |

---

## 🗺️ Roadmap

- [x] **v0.1.0** — Uncompressed single-frame DICOM parsing, linear VOI windowing math, `ui.Image` renderer, interactive `DicomImageWidget`, cross-platform support.
- [x] **v0.2.0** — Pure-Dart RLE Lossless decompressor groundwork, Pixel Padding Value filtering, multi-valued clinical window presets, multi-frame groundwork (`frameIndex`), interactive pan/zoom & double-tap reset.
- [x] **v0.3.0** — Real-world DICOM RLE fixture validation, multi-frame navigation & Cine playback, PALETTE COLOR direct LUT rendering, physical Pixel Spacing display aspect-ratio correction, rich Metadata API, medical disclaimer.
- [x] **v0.5.0** — Pure-Dart JPEG Baseline (`.50`) & JPEG Lossless SV1 (`.70`) decompressors, modular codec registry architecture, multi-frame JPEG framing and navigation, ITU-R BT.601 YBR-to-RGB color pipeline, verified quantitative ROI statistics and Pixel Probe across JPEG datasets.
- [ ] **v0.6.0** — Advanced clinical modalities & future extensions.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for details.
