import 'dart:typed_data';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DicomViewerExampleApp());
}

class DicomViewerExampleApp extends StatelessWidget {
  const DicomViewerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOM Viewer Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: const DicomViewerScreen(),
    );
  }
}

class DicomViewerScreen extends StatefulWidget {
  const DicomViewerScreen({super.key});

  @override
  State<DicomViewerScreen> createState() => _DicomViewerScreenState();
}

class _DicomViewerScreenState extends State<DicomViewerScreen> {
  DicomDataset? _dataset;
  String? _fileName;
  bool _isLoading = false;
  String? _error;
  double? _activeWc;
  double? _activeWw;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final Uint8List? bytes = file.bytes;

        if (bytes == null || bytes.isEmpty) {
          throw Exception('Failed to read file bytes. Selected file is empty.');
        }

        final dataset = DicomDataset.fromBytes(bytes);

        setState(() {
          _dataset = dataset;
          _fileName = file.name;
          _activeWc = dataset.windowCenter;
          _activeWw = dataset.windowWidth;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadSampleDicom() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes = _generateSampleCtDicom();
      final dataset = DicomDataset.fromBytes(bytes);

      setState(() {
        _dataset = dataset;
        _fileName = 'Sample_CT_Head.dcm';
        _activeWc = dataset.windowCenter;
        _activeWw = dataset.windowWidth;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyPreset(double center, double width) {
    setState(() {
      _activeWc = center;
      _activeWw = width;
    });
  }

  void _resetWindowing() {
    if (_dataset != null) {
      setState(() {
        _activeWc = _dataset!.windowCenter;
        _activeWw = _dataset!.windowWidth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dicom_viewer v0.1.0'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Load Sample CT',
            onPressed: _loadSampleDicom,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open DICOM File',
            onPressed: _pickFile,
          ),
        ],
      ),
      body: Column(
        children: [
          // Clinical Preset Buttons Bar
          if (_dataset != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF1A1A1A),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Presets: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    _PresetChip(
                      label: '🧠 Brain (40/80)',
                      onPressed: () => _applyPreset(40, 80),
                    ),
                    const SizedBox(width: 6),
                    _PresetChip(
                      label: '🫁 Lung (-600/1500)',
                      onPressed: () => _applyPreset(-600, 1500),
                    ),
                    const SizedBox(width: 6),
                    _PresetChip(
                      label: '🦴 Bone (400/1800)',
                      onPressed: () => _applyPreset(400, 1800),
                    ),
                    const SizedBox(width: 6),
                    _PresetChip(
                      label: '🩺 Soft Tissue (40/400)',
                      onPressed: () => _applyPreset(40, 400),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.refresh, size: 14),
                      label: const Text('Reset', style: TextStyle(fontSize: 12)),
                      onPressed: _resetWindowing,
                    ),
                  ],
                ),
              ),
            ),

          // Main Display Area
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Parsing DICOM file...'),
                        ],
                      ),
                    )
                    : _error != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading DICOM file:\n$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Try Another File'),
                            ),
                          ],
                        ),
                      ),
                    )
                    : _dataset == null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medical_services_outlined,
                            size: 64,
                            color: Colors.cyan.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No DICOM file loaded',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select a single-frame DICOM file (.dcm) or load sample.',
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _loadSampleDicom,
                                icon: const Icon(Icons.science_outlined),
                                label: const Text('Load Sample CT'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan.shade800,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Select DICOM File'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                    : DicomImageWidget(
                      key: ValueKey('$_activeWc-$_activeWw'),
                      dataset: _dataset!,
                      initialWindowCenter: _activeWc,
                      initialWindowWidth: _activeWw,
                      showOverlay: true,
                    ),
          ),

          // Metadata & Controls Footer
          if (_dataset != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1E1E1E),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'File: ${_fileName ?? "Unsaved"}\nModality: ${_dataset!.modality} | Size: ${_dataset!.columns}x${_dataset!.rows} | Rescale: ${_dataset!.rescaleSlope}x + ${_dataset!.rescaleIntercept}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Uint8List _generateSampleCtDicom() {
    final builder = BytesBuilder();
    // 128 bytes preamble
    builder.add(List.filled(128, 0));
    // Prefix 'DICM'
    builder.add([0x44, 0x49, 0x43, 0x4D]);

    // Group 0002 Meta Header
    _writeTag(builder, 0x0002, 0x0010, 'UI', '1.2.840.10008.1.2.1'); // Explicit VR Little Endian

    // Dataset Metadata
    _writeTag(builder, 0x0008, 0x0060, 'CS', 'CT');
    _writeTag(builder, 0x0010, 0x0010, 'PN', 'Sample^HeadCT');
    _writeTag(builder, 0x0010, 0x0020, 'LO', 'CT-10293');
    _writeTag(builder, 0x0028, 0x0002, 'US', 1); // SamplesPerPixel
    _writeTag(builder, 0x0028, 0x0004, 'CS', 'MONOCHROME2');
    _writeTag(builder, 0x0028, 0x0010, 'US', 256); // Rows
    _writeTag(builder, 0x0028, 0x0011, 'US', 256); // Columns
    _writeTag(builder, 0x0028, 0x0100, 'US', 16); // BitsAllocated
    _writeTag(builder, 0x0028, 0x0101, 'US', 16); // BitsStored
    _writeTag(builder, 0x0028, 0x0102, 'US', 15); // HighBit
    _writeTag(builder, 0x0028, 0x0103, 'US', 1); // PixelRepresentation (Signed 2's complement)
    _writeTag(builder, 0x0028, 0x1050, 'DS', '40'); // WindowCenter
    _writeTag(builder, 0x0028, 0x1051, 'DS', '400'); // WindowWidth
    _writeTag(builder, 0x0028, 0x1052, 'DS', '-1024'); // RescaleIntercept
    _writeTag(builder, 0x0028, 0x1053, 'DS', '1.0'); // RescaleSlope

    // Generate 256x256 synthetic CT head phantom pixel data
    final pixelsBuilder = BytesBuilder();
    const width = 256;
    const height = 256;
    const centerX = 128;
    const centerY = 128;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final dx = x - centerX;
        final dy = y - centerY;
        final distSq = dx * dx + dy * dy;

        int hu = -1000; // Air
        if (distSq < 110 * 110) {
          if (distSq > 95 * 95) {
            hu = 1000; // Skull Bone
          } else if (distSq < 30 * 30) {
            hu = 15; // Ventricles CSF
          } else {
            hu = 40; // Brain Soft Tissue
          }
        }

        final storedPixel = hu + 1024; // Reverse Rescale Intercept (-1024)
        final ByteData bd = ByteData(2)..setInt16(0, storedPixel, Endian.little);
        pixelsBuilder.add(bd.buffer.asUint8List());
      }
    }

    final pixelBytes = pixelsBuilder.toBytes();
    // Pixel Data (7FE0,0010) OB/OW
    builder.add([0xE0, 0x7F, 0x10, 0x00]); // Tag (7FE0,0010)
    builder.add([0x4F, 0x57]); // VR 'OW'
    builder.add([0x00, 0x00]); // Reserved
    final lenBd = ByteData(4)..setUint32(0, pixelBytes.length, Endian.little);
    builder.add(lenBd.buffer.asUint8List());
    builder.add(pixelBytes);

    return builder.toBytes();
  }

  void _writeTag(BytesBuilder bb, int group, int element, String vrStr, dynamic val) {
    bb.add([group & 0xFF, (group >> 8) & 0xFF, element & 0xFF, (element >> 8) & 0xFF]);
    final vrBytes = vrStr.codeUnits;
    bb.add(vrBytes);

    Uint8List valBytes;
    if (vrStr == 'US') {
      valBytes = (ByteData(2)..setUint16(0, val as int, Endian.little)).buffer.asUint8List();
    } else {
      final strVal = val.toString();
      var b = strVal.codeUnits;
      if (b.length % 2 != 0) {
        b = [...b, 0x20]; // Space padding
      }
      valBytes = Uint8List.fromList(b);
    }

    if (vrStr == 'OB' || vrStr == 'OW' || vrStr == 'SQ' || vrStr == 'UN' || vrStr == 'UT') {
      bb.add([0x00, 0x00]);
      final lenBd = ByteData(4)..setUint32(0, valBytes.length, Endian.little);
      bb.add(lenBd.buffer.asUint8List());
    } else {
      final lenBd = ByteData(2)..setUint16(0, valBytes.length, Endian.little);
      bb.add(lenBd.buffer.asUint8List());
    }
    bb.add(valBytes);
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PresetChip({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
      backgroundColor: const Color(0xFF2A2A2A),
    );
  }
}
