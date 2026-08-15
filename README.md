# dicom_viewer

[![pub package](https://img.shields.io/pub/v/dicom_viewer.svg)](https://pub.dev/packages/dicom_viewer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform Support](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-blue)](https://pub.dev/packages/dicom_viewer)

A **pure-Dart, cross-platform DICOM viewer package for Flutter**. Parses single-frame uncompressed DICOM medical images, applies Hounsfield Unit rescaling and linear VOI windowing (contrast/brightness), and renders displayable images — **on Android, iOS, macOS, Windows, Linux, and Web from a single codebase with no native/FFI dependencies**.

---

## ⚕️ Medical Use Disclaimer

`dicom_viewer` is an open-source software library intended for image processing, visualization, and application development. It is not a certified or approved medical device and has not been evaluated or authorized by regulatory authorities for clinical diagnosis, treatment, or other patient-care decisions. It is not intended to replace the judgment of qualified healthcare professionals or to be used as the sole basis for clinical decision-making.

Developers are responsible for determining the suitability, validation, regulatory requirements, and intended use of applications built using this library.

---

## ✨ Features

- ⚡ **100% Pure Dart**: Zero C/C++ or FFI native code dependencies. Completely self-contained.
- 🌐 **True Cross-Platform**: Runs natively on Mobile (Android, iOS), Desktop (Windows, macOS, Linux), and Web (CanvasKit & Skwasm).
- 🩺 **DICOM PS3.10 & PS3.5 Parsing**: Parses `Explicit VR Little Endian`, `Implicit VR Little Endian`, and `Big Endian` file streams.
- 🎨 **Pixel Decoding**: Decodes 8-bit unsigned, 16-bit (unsigned & 2's complement signed Hounsfield Units for CT scans), and 32-bit pixel data.
- 🎛️ **VOI Windowing & Rescale Math**:
  - Rescale Slope & Intercept ($RealWorldValue = StoredPixel \times Slope + Intercept$).
  - DICOM PS3.3 C.11.2.1.2 Linear VOI Window Center ($WC$) & Window Width ($WW$) contrast mapping.
  - Automatic `MONOCHROME1` vs `MONOCHROME2` grayscale intensity inversion.
- 🖐️ **Interactive UI Widget**: `DicomImageWidget` with touch/pan drag gestures for adjusting Window Center (brightness) and Window Width (contrast) in real time + medical text overlays.
- 🛡️ **Graceful Error Handling**: Clear, descriptive `UnsupportedError` notifications for compressed transfer syntaxes (e.g. JPEG 2000, JPEG Lossless, RLE).

### 📋 Supported in v0.2.0

- ✅ **Explicit VR Little Endian** (`1.2.840.10008.1.2.1`)
- ✅ **Implicit VR Little Endian** (`1.2.840.10008.1.2`)
- ✅ **Explicit VR Big Endian** (`1.2.840.10008.1.2.2`)
- ✅ **Uncompressed Pixel Data** (8-bit, 16-bit signed/unsigned, 32-bit)
- ✅ **RLE Lossless** (`1.2.840.10008.1.2.5`) — RLE Lossless is implemented and unit-tested, but real-world DICOM RLE compatibility has not yet been validated against a real RLE DICOM fixture.
- ✅ **Pixel Padding Value Filtering** (`0028, 0120` & `0028, 0121`)
- ✅ **Multi-Valued Clinical Window Presets** (`windowCenterPresets`, `windowWidthPresets`)
- ✅ **Multi-Frame Groundwork** (`numberOfFrames`, 0-indexed `frameIndex`)
- ✅ **Interactive Pan & Pinch-Zoom** (`DicomImageWidget` with double-tap reset & `onViewChanged`)

### ⛔ Planned for Future Releases

- ❌ JPEG Compressed Transfer Syntaxes (JPEG Baseline, JPEG 2000) — throws clear `UnsupportedError`
- ❌ Measurement tools (distance, area, ROI statistics)

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

### 1. Interactive UI Widget with Drag & Zoom Gestures

Use `DicomImageWidget` to render a DICOM dataset with real-time drag gestures (horizontal = window width, vertical = window center) and optional interactive zoom:

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dicom_viewer/dicom_viewer.dart';

class MedicalViewerScreen extends StatelessWidget {
  final Uint8List dicomBytes;

  const MedicalViewerScreen({super.key, required this.dicomBytes});

  @override
  Widget build(BuildContext context) {
    final dataset = DicomDataset.fromBytes(dicomBytes);

    return Scaffold(
      appBar: AppBar(title: Text('DICOM Viewer - ${dataset.patientName}')),
      body: Center(
        child: DicomImageWidget(
          dataset: dataset,
          enableZoom: true,
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

print('Patient Name: ${dataset.patientName}');
print('Patient ID: ${dataset.patientId}');
print('Modality: ${dataset.modality}'); // e.g. 'CT', 'MR'
print('Number of Frames: ${dataset.numberOfFrames}');
print('Dimensions: ${dataset.columns} x ${dataset.rows}');
print('Window Center Presets: ${dataset.windowCenterPresets}');
print('Window Width Presets: ${dataset.windowWidthPresets}');
```

---

## 📖 API Summary

| Class / Widget | Description |
| :--- | :--- |
| **`DicomDataset`** | Parses and stores DICOM dataset attributes from raw binary streams. |
| **`DicomRenderer`** | Renders a `DicomDataset` frame to a displayable Flutter `ui.Image` using `ui.decodeImageFromPixels`. |
| **`DicomImageWidget`** | Interactive Flutter `StatefulWidget` supporting drag windowing, pan/zoom, double-tap reset, and medical overlays. |
| **`PixelDataDecoder`** | Decodes raw pixel bytes (8-bit, 16-bit signed/unsigned 2's complement) into normalized integer arrays. |
| **`Windowing`** | Pure math class for Rescale Slope/Intercept and DICOM PS3.3 C.11.2.1.2 Linear VOI Windowing. |

---

## 🗺️ Roadmap

- [x] **v0.1.0** — Uncompressed single-frame DICOM parsing, linear VOI windowing math, `ui.Image` renderer, interactive `DicomImageWidget`, cross-platform support.
- [x] **v0.2.0** — Pure-Dart RLE Lossless decompressor, Pixel Padding Value filtering, multi-valued clinical window presets, multi-frame groundwork (`frameIndex`), interactive pan/zoom & double-tap reset.
- [ ] **v0.3.0** — Real-world RLE fixture validation, JPEG 2000 / JPEG Baseline decompressors, multi-frame slice player toolbar.
- [ ] **v0.4.0** — Measurement tools (Distance in mm, Area, Hounsfield Unit ROI statistics).

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for details.
