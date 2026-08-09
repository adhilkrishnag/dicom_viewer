# dicom_viewer

[![pub package](https://img.shields.io/pub/v/dicom_viewer.svg)](https://pub.dev/packages/dicom_viewer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform Support](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-blue)](https://pub.dev/packages/dicom_viewer)

A **pure-Dart, cross-platform DICOM viewer package for Flutter**. Parses single-frame uncompressed DICOM medical images, applies Hounsfield Unit rescaling and linear VOI windowing (contrast/brightness), and renders displayable images — **on Android, iOS, macOS, Windows, Linux, and Web from a single codebase with no native/FFI dependencies**.

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

### 1. Interactive UI Widget with Drag Gestures

Use `DicomImageWidget` to render a DICOM dataset with real-time drag gestures (horizontal = window width, vertical = window center):

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
          showOverlay: true,
          onWindowingChanged: (windowCenter, windowWidth) {
            print('New Windowing: WC=$windowCenter, WW=$windowWidth');
          },
        ),
      ),
    );
  }
}
```

### 2. Programmatic Rendering to `ui.Image`

Convert a `DicomDataset` directly to a Flutter `ui.Image` for custom canvas drawing or image processing:

```dart
import 'dart:ui' as ui;
import 'package:dicom_viewer/dicom_viewer.dart';

Future<ui.Image> renderDicomFile(Uint8List fileBytes) async {
  // Parse DICOM dataset
  final dataset = DicomDataset.fromBytes(fileBytes);

  // Render to ui.Image with specific Window Center (40) & Window Width (400) for Soft Tissue
  final ui.Image image = await DicomRenderer.renderToImage(
    dataset,
    windowCenter: 40.0,
    windowWidth: 400.0,
  );

  return image;
}
```

### 3. Extracting DICOM Metadata

Access typed DICOM header attributes directly:

```dart
final dataset = DicomDataset.fromBytes(dicomBytes);

print('Patient Name: ${dataset.patientName}');
print('Patient ID: ${dataset.patientId}');
print('Modality: ${dataset.modality}'); // e.g. 'CT', 'MR'
print('Dimensions: ${dataset.columns} x ${dataset.rows}');
print('Bits Allocated/Stored: ${dataset.bitsAllocated} / ${dataset.bitsStored}');
print('Rescale Slope / Intercept: ${dataset.rescaleSlope} / ${dataset.rescaleIntercept}');
print('Window Center / Width: ${dataset.windowCenter} / ${dataset.windowWidth}');
```

---

## 📖 API Summary

| Class / Widget | Description |
| :--- | :--- |
| **`DicomDataset`** | Parses and stores DICOM dataset attributes from raw binary streams. |
| **`DicomRenderer`** | Renders a `DicomDataset` to a displayable Flutter `ui.Image` using `ui.decodeImageFromPixels`. |
| **`DicomImageWidget`** | Interactive Flutter `StatefulWidget` supporting touch/drag gestures for dynamic windowing and medical overlays. |
| **`PixelDataDecoder`** | Decodes raw pixel bytes (8-bit, 16-bit signed/unsigned 2's complement) into normalized integer arrays. |
| **`Windowing`** | Pure math class for Rescale Slope/Intercept and DICOM PS3.3 C.11.2.1.2 Linear VOI Windowing. |

---

## 🗺️ Roadmap

- [x] **v0.1.0** — Uncompressed single-frame DICOM parsing, linear VOI windowing math, `ui.Image` renderer, interactive `DicomImageWidget`, cross-platform support.
- [ ] **v0.2.0** — Native Dart decompressors for JPEG 2000 (`1.2.840.10008.1.2.4.90`/`.91`) and RLE Lossless (`1.2.840.10008.1.2.5`).
- [ ] **v0.3.0** — Multi-frame DICOM support & slice index scrolling control.
- [ ] **v0.4.0** — Measurement tools (Distance in mm, Area, Hounsfield Unit ROI statistics).

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for details.
