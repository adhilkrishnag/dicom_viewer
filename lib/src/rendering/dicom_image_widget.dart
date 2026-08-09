import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../parsing/dicom_dataset.dart';
import 'dicom_renderer.dart';

/// Interactive Flutter widget that renders a DICOM image and provides real-time
/// windowing (contrast/brightness) drag gestures.
class DicomImageWidget extends StatefulWidget {
  const DicomImageWidget({
    super.key,
    required this.dataset,
    this.initialWindowCenter,
    this.initialWindowWidth,
    this.showOverlay = true,
    this.sensitivity = 2.0,
    this.onWindowChanged,
  });

  /// The parsed DICOM dataset to display.
  final DicomDataset dataset;

  /// Optional initial Window Center override.
  final double? initialWindowCenter;

  /// Optional initial Window Width override.
  final double? initialWindowWidth;

  /// Whether to show the medical overlay text (WC/WW, Patient Info).
  final bool showOverlay;

  /// Drag gesture windowing sensitivity multiplier.
  final double sensitivity;

  /// Callback emitted when windowing parameters change.
  final void Function(double center, double width)? onWindowChanged;

  @override
  State<DicomImageWidget> createState() => _DicomImageWidgetState();
}

class _DicomImageWidgetState extends State<DicomImageWidget> {
  late double _windowCenter;
  late double _windowWidth;
  ui.Image? _renderedImage;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWindowing();
    _renderImage();
  }

  @override
  void didUpdateWidget(DicomImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataset != widget.dataset) {
      _initWindowing();
      _renderImage();
    }
  }

  void _initWindowing() {
    _windowCenter =
        widget.initialWindowCenter ?? widget.dataset.windowCenter ?? 128.0;
    _windowWidth =
        widget.initialWindowWidth ?? widget.dataset.windowWidth ?? 256.0;

    if (_windowWidth <= 0) _windowWidth = 256.0;
  }

  Future<void> _renderImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final img = await DicomRenderer.renderToImage(
        widget.dataset,
        windowCenter: _windowCenter,
        windowWidth: _windowWidth,
      );

      if (mounted) {
        setState(() {
          _renderedImage = img;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _windowWidth += details.delta.dx * widget.sensitivity;
      _windowCenter -= details.delta.dy * widget.sensitivity;

      if (_windowWidth < 1.0) _windowWidth = 1.0;
    });

    widget.onWindowChanged?.call(_windowCenter, _windowWidth);
    _renderImage();
  }

  void resetWindowing() {
    setState(() {
      _initWindowing();
    });
    _renderImage();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Image canvas with windowing drag gesture
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child:
                    _renderedImage != null
                        ? RawImage(
                          image: _renderedImage,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        )
                        : Container(),
              ),
            ),
          ),

          // Loading Indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),

          // Error Display
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error rendering image:\n$_errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),
            ),

          // Medical Overlay
          if (widget.showOverlay && !_isLoading && _errorMessage == null) ...[
            // Top-left: Patient & Study Info
            Positioned(
              top: 12,
              left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.dataset.patientName,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  Text(
                    'ID: ${widget.dataset.patientId}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  Text(
                    'Modality: ${widget.dataset.modality}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom-left: Image dimensions & Windowing state
            Positioned(
              bottom: 12,
              left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Size: ${widget.dataset.columns} x ${widget.dataset.rows}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  Text(
                    'WC: ${_windowCenter.round()}  WW: ${_windowWidth.round()}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  const Text(
                    'Drag to adjust contrast / brightness',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
