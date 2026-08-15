import 'dart:async';
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

  // v0.2.0 Interactive Viewer State
  bool _enableZoom = true;
  DicomTool _selectedTool = DicomTool.pan;
  double _currentScale = 1.0;
  Offset _currentOffset = Offset.zero;

  // v0.3.0 Multi-Frame Navigation & Cine Playback State
  int _currentFrame = 0;
  Timer? _playTimer;
  bool get _isPlaying => _playTimer != null && _playTimer!.isActive;

  /// Incremented only on explicit preset selection, reset, or new-file load.
  /// Changing this key forces DicomImageWidget to recreate with the intended
  /// initialWindowCenter/Width. Tool switching and frame scrubbing do NOT
  /// increment this — the build() method handles structural changes without
  /// recreating state.
  int _presetGeneration = 0;

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  void _stopPlayback() {
    _playTimer?.cancel();
    _playTimer = null;
  }

  void _setFrame(int frame) {
    if (_dataset == null) return;
    final total = _dataset!.numberOfFrames;
    if (total <= 1) return;
    setState(() {
      _currentFrame = frame.clamp(0, total - 1);
    });
  }

  void _togglePlayback() {
    if (_isPlaying) {
      setState(() {
        _stopPlayback();
      });
    } else {
      if (_dataset == null || _dataset!.numberOfFrames <= 1) return;
      setState(() {
        _playTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (!mounted || _dataset == null || _dataset!.numberOfFrames <= 1) {
            _stopPlayback();
            return;
          }
          setState(() {
            _currentFrame = (_currentFrame + 1) % _dataset!.numberOfFrames;
          });
        });
      });
    }
  }

  Future<void> _pickFile() async {
    _stopPlayback();
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
          _currentScale = 1.0;
          _currentOffset = Offset.zero;
          _currentFrame = 0;
          _isLoading = false;
          _presetGeneration++; // new file → fresh initial values
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
    _stopPlayback();
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
        _currentScale = 1.0;
        _currentOffset = Offset.zero;
        _currentFrame = 0;
        _isLoading = false;
        _presetGeneration++; // new sample → fresh initial values
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
      _presetGeneration++; // explicit preset → recreate widget with preset initial values
    });
  }

  void _resetWindowing() {
    if (_dataset != null) {
      setState(() {
        _activeWc = _dataset!.windowCenter;
        _activeWw = _dataset!.windowWidth;
        _currentScale = 1.0;
        _currentOffset = Offset.zero;
        _presetGeneration++; // explicit reset → recreate widget with original initial values
      });
    }
  }

  void _showDisclaimerDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  color: Colors.cyanAccent,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Medical Use Disclaimer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Text(
                'Medical Use Disclaimer: This example is for software development, research, testing, and visualization purposes. It is not a certified or approved medical device and is not intended for primary clinical diagnosis, treatment, or patient-care decisions.\n\nDevelopers are responsible for determining the suitability, validation, regulatory requirements, and intended use of applications built using this library.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DICOM Viewer Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Medical Use Disclaimer',
            onPressed: () => _showDisclaimerDialog(context),
          ),
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
          // Clinical Preset Buttons & Interactive Mode Toggle Bar
          if (_dataset != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF1A1A1A),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Mode Toggle: Interactive Pan & Zoom (v0.2.0) vs Legacy Windowing (v0.1.0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.cyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _enableZoom ? Icons.zoom_in : Icons.contrast,
                            size: 16,
                            color: Colors.cyanAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _enableZoom ? 'Interactive Mode' : 'Legacy Mode',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                            ),
                          ),
                          Switch(
                            value: _enableZoom,
                            activeThumbColor: Colors.cyanAccent,
                            onChanged: (val) {
                              setState(() {
                                _enableZoom = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_enableZoom) ...[
                      const SizedBox(width: 8),
                      SegmentedButton<DicomTool>(
                        segments: const [
                          ButtonSegment<DicomTool>(
                            value: DicomTool.pan,
                            icon: Icon(Icons.pan_tool_outlined, size: 14),
                            label: Text(
                              'Pan & Zoom',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          ButtonSegment<DicomTool>(
                            value: DicomTool.windowing,
                            icon: Icon(Icons.contrast, size: 14),
                            label: Text(
                              'Windowing',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                        selected: {_selectedTool},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedTool = newSelection.first;
                          });
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
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
                      label: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 12),
                      ),
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
                            'Select a DICOM file (.dcm) or load sample.',
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
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Text(
                              'Medical Use Disclaimer: This example is for software development, research, testing, and visualization purposes. It is not a certified or approved medical device and is not intended for primary clinical diagnosis, treatment, or patient-care decisions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.38),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : Stack(
                      children: [
                        Positioned.fill(
                          child: DicomImageWidget(
                            // Key only changes on: explicit preset, reset, or new-file
                            // load (via _presetGeneration). Tool switching and frame scrubbing
                            // do NOT recreate the widget — the build() method
                            // handles those structurally, preserving internal WC/WW state.
                            key: ValueKey(
                              '${_fileName ?? ""}-$_presetGeneration',
                            ),
                            dataset: _dataset!,
                            frameIndex: _currentFrame,
                            initialWindowCenter: _activeWc,
                            initialWindowWidth: _activeWw,
                            enableZoom: _enableZoom,
                            tool: _selectedTool,
                            showOverlay: true,
                            onWindowChanged: (center, width) {
                              // Track silently — no setState to avoid unnecessary
                              // rebuilds during drag. Values are up-to-date whenever
                              // _presetGeneration increments and the widget recreates.
                              _activeWc = center;
                              _activeWw = width;
                            },
                            onViewChanged: (scale, offset) {
                              setState(() {
                                _currentScale = scale;
                                _currentOffset = offset;
                              });
                            },
                          ),
                        ),

                        // Gesture Legend / Guidance Card
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  !_enableZoom
                                      ? 'Legacy Windowing Mode:'
                                      : _selectedTool == DicomTool.pan
                                      ? 'Interactive Pan & Zoom Tool:'
                                      : 'Interactive Windowing Tool:',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.cyanAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_enableZoom) ...[
                                  if (_selectedTool == DicomTool.pan)
                                    const Text(
                                      '🖐️ Drag: Pan Image Viewport',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    )
                                  else
                                    const Text(
                                      '🖐️ Drag: Adjust Contrast / Brightness',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  const Text(
                                    '🔍 Pinch / Wheel: Zoom Image (0.5x - 5.0x)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ] else ...[
                                  const Text(
                                    '🖐️ Drag: Adjust Contrast / Brightness',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                                const Text(
                                  '👆 Double-Tap: Reset Scale & Windowing',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
          ),

          // Multi-Frame Navigation Bar (Only visible when numberOfFrames > 1)
          if (_dataset != null && _dataset!.numberOfFrames > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFF161616),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    color: Colors.cyanAccent,
                    iconSize: 28,
                    tooltip:
                        _isPlaying
                            ? 'Pause Cine Playback'
                            : 'Start Cine Playback',
                    onPressed: _togglePlayback,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 20),
                    tooltip: 'Previous Frame',
                    onPressed:
                        _currentFrame > 0
                            ? () {
                              _stopPlayback();
                              _setFrame(_currentFrame - 1);
                            }
                            : null,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.cyanAccent,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.cyanAccent,
                        overlayColor: Colors.cyanAccent.withValues(alpha: 0.2),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value: _currentFrame.toDouble().clamp(
                          0.0,
                          (_dataset!.numberOfFrames - 1).toDouble(),
                        ),
                        min: 0.0,
                        max: (_dataset!.numberOfFrames - 1).toDouble(),
                        divisions: _dataset!.numberOfFrames - 1,
                        onChanged: (val) {
                          _stopPlayback();
                          _setFrame(val.round());
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 20),
                    tooltip: 'Next Frame',
                    onPressed:
                        _currentFrame < _dataset!.numberOfFrames - 1
                            ? () {
                              _stopPlayback();
                              _setFrame(_currentFrame + 1);
                            }
                            : null,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'Frame ${_currentFrame + 1} / ${_dataset!.numberOfFrames}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                ],
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
                      'File: ${_fileName ?? "Unsaved"} | Modality: ${_dataset!.modality} | Size: ${_dataset!.columns}x${_dataset!.rows}${_dataset!.numberOfFrames > 1 ? " | Frame: ${_currentFrame + 1}/${_dataset!.numberOfFrames}" : ""}\nRescale: ${_dataset!.rescaleSlope}x + ${_dataset!.rescaleIntercept} | Zoom: ${_currentScale.toStringAsFixed(2)}x | Offset: (${_currentOffset.dx.toStringAsFixed(0)}, ${_currentOffset.dy.toStringAsFixed(0)})',
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
    _writeTag(
      builder,
      0x0002,
      0x0010,
      'UI',
      '1.2.840.10008.1.2.1',
    ); // Explicit VR Little Endian

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
    _writeTag(
      builder,
      0x0028,
      0x0103,
      'US',
      1,
    ); // PixelRepresentation (Signed 2's complement)
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
        final ByteData bd = ByteData(2)
          ..setInt16(0, storedPixel, Endian.little);
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

  void _writeTag(
    BytesBuilder bb,
    int group,
    int element,
    String vrStr,
    dynamic val,
  ) {
    bb.add([
      group & 0xFF,
      (group >> 8) & 0xFF,
      element & 0xFF,
      (element >> 8) & 0xFF,
    ]);
    final vrBytes = vrStr.codeUnits;
    bb.add(vrBytes);

    Uint8List valBytes;
    if (vrStr == 'US') {
      valBytes =
          (ByteData(2)
            ..setUint16(0, val as int, Endian.little)).buffer.asUint8List();
    } else {
      final strVal = val.toString();
      var b = strVal.codeUnits;
      if (b.length % 2 != 0) {
        b = [...b, 0x20]; // Space padding
      }
      valBytes = Uint8List.fromList(b);
    }

    if (vrStr == 'OB' ||
        vrStr == 'OW' ||
        vrStr == 'SQ' ||
        vrStr == 'UN' ||
        vrStr == 'UT') {
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
