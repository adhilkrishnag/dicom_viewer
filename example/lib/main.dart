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
  final GlobalKey<State<DicomImageWidget>> _widgetKey = GlobalKey();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dicom_viewer v0.1.0'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open DICOM File',
            onPressed: _pickFile,
          ),
        ],
      ),
      body: Column(
        children: [
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
                            'Select a single-frame DICOM file (.dcm) to view.',
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.file_open),
                            label: const Text('Select DICOM File'),
                          ),
                        ],
                      ),
                    )
                    : DicomImageWidget(key: _widgetKey, dataset: _dataset!),
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
                      'File: ${_fileName ?? "Unsaved"}\nModality: ${_dataset!.modality} | Size: ${_dataset!.columns}x${_dataset!.rows}',
                      style: const TextStyle(
                        fontSize: 12,
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
}
