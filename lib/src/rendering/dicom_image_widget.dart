import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../parsing/dicom_dataset.dart';
import 'dicom_renderer.dart';

/// Gesture tool mode when [DicomImageWidget.enableZoom] is enabled.
enum DicomTool {
  /// Drag gestures pan the image viewport inside InteractiveViewer.
  pan,

  /// Drag gestures adjust Window Center (brightness) and Window Width (contrast).
  windowing,
}

/// Interactive Flutter widget that renders a DICOM image and provides real-time
/// windowing (contrast/brightness) drag gestures.
class DicomImageWidget extends StatefulWidget {
  const DicomImageWidget({
    super.key,
    required this.dataset,
    this.frameIndex = 0,
    this.initialWindowCenter,
    this.initialWindowWidth,
    this.showOverlay = true,
    this.sensitivity = 2.0,
    this.enableZoom = false,
    this.tool = DicomTool.pan,
    this.onWindowChanged,
    this.onViewChanged,
  });

  /// The parsed DICOM dataset to display.
  final DicomDataset dataset;

  /// Multi-frame image index (0-indexed, default 0).
  final int frameIndex;

  /// Optional initial Window Center override.
  final double? initialWindowCenter;

  /// Optional initial Window Width override.
  final double? initialWindowWidth;

  /// Whether to show the medical overlay text (WC/WW, Patient Info).
  final bool showOverlay;

  /// Drag gesture windowing sensitivity multiplier.
  final double sensitivity;

  /// Whether to enable interactive pan & zoom gestures.
  final bool enableZoom;

  /// Active interaction tool when [enableZoom] is true. Defaults to [DicomTool.pan].
  final DicomTool tool;

  /// Callback emitted when windowing parameters change.
  final void Function(double center, double width)? onWindowChanged;

  /// Callback emitted when view scale/pan offset changes.
  final void Function(double scale, Offset offset)? onViewChanged;

  @override
  State<DicomImageWidget> createState() => _DicomImageWidgetState();
}

class _DicomImageWidgetState extends State<DicomImageWidget> {
  late double _windowCenter;
  late double _windowWidth;
  ui.Image? _renderedImage;
  bool _isLoading = true;
  String? _errorMessage;

  int _renderGeneration = 0;
  bool _isRendering = false;
  bool _renderPending = false;

  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _initWindowing();
    _renderImage();
  }

  @override
  void didUpdateWidget(DicomImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataset != widget.dataset ||
        oldWidget.frameIndex != widget.frameIndex) {
      _initWindowing();
      _renderImage();
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _renderGeneration++;
    _renderedImage?.dispose();
    _renderedImage = null;
    super.dispose();
  }

  void _onTransformationChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = Offset(matrix.storage[12], matrix.storage[13]);
    widget.onViewChanged?.call(scale, translation);
  }

  void _initWindowing() {
    _windowCenter =
        widget.initialWindowCenter ?? widget.dataset.windowCenter ?? 128.0;
    _windowWidth =
        widget.initialWindowWidth ?? widget.dataset.windowWidth ?? 256.0;

    if (_windowWidth <= 0) _windowWidth = 256.0;
  }

  Future<void> _renderImage() async {
    if (_isRendering) {
      _renderPending = true;
      return;
    }

    _isRendering = true;
    final currentGen = ++_renderGeneration;

    if (mounted && _renderedImage == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final img = await DicomRenderer.renderToImage(
        widget.dataset,
        frameIndex: widget.frameIndex,
        windowCenter: _windowCenter,
        windowWidth: _windowWidth,
      );

      if (mounted && currentGen == _renderGeneration) {
        final oldImage = _renderedImage;
        setState(() {
          _renderedImage = img;
          _isLoading = false;
        });
        oldImage?.dispose();
      } else {
        img.dispose();
      }
    } catch (e) {
      if (mounted && currentGen == _renderGeneration) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      _isRendering = false;
      if (_renderPending && mounted) {
        _renderPending = false;
        unawaited(_renderImage());
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
    unawaited(_renderImage());
  }

  void resetWindowing() {
    setState(() {
      _initWindowing();
      _transformationController.value = Matrix4.identity();
    });
    unawaited(_renderImage());
  }

  int _lastTapTime = 0;

  void _onTapDown(TapDownDetails details) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < 300) {
      resetWindowing();
      _lastTapTime = 0;
    } else {
      _lastTapTime = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imageContent = Center(
      child:
          _renderedImage != null
              ? RawImage(
                image: _renderedImage,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              )
              : Container(),
    );

    if (widget.enableZoom) {
      if (widget.tool == DicomTool.pan) {
        imageContent = InteractiveViewer(
          transformationController: _transformationController,
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 5.0,
          child: imageContent,
        );
      } else {
        imageContent = ClipRect(
          child: Transform(
            transform: _transformationController.value,
            child: imageContent,
          ),
        );
      }
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Image canvas with gesture handling
          Positioned.fill(
            child: GestureDetector(
              key: const Key('dicom_windowing_gesture'),
              onPanUpdate:
                  (widget.enableZoom && widget.tool == DicomTool.pan)
                      ? null
                      : _onPanUpdate,
              onTapDown: _onTapDown,
              behavior: HitTestBehavior.opaque,
              child: imageContent,
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
