import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../geometry/dicom_image_geometry.dart';
import '../geometry/distance_measurement.dart';
import '../geometry/distance_measurement_painter.dart';
import '../geometry/image_coordinate_transform.dart';
import '../parsing/dicom_dataset.dart';
import '../windowing/photometric.dart';
import 'dicom_renderer.dart';

/// Gesture tool mode when [DicomImageWidget.enableZoom] is enabled.
enum DicomTool {
  /// Drag gestures pan the image viewport inside InteractiveViewer.
  pan,

  /// Drag gestures adjust Window Center (brightness) and Window Width (contrast).
  windowing,

  /// Drag gestures draw a 2D two-point distance measurement caliper line across the image.
  measure,
}

/// Interactive Flutter widget that renders a DICOM image and provides real-time
/// windowing (contrast/brightness) drag gestures.
class DicomImageWidget extends StatefulWidget {
  /// Creates an interactive [DicomImageWidget] for viewing DICOM imagery.
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

  /// Stored completed distance measurements per frame index.
  final Map<int, DicomDistanceMeasurement> _measurements = {};

  /// In-progress distance measurement currently being dragged on the active frame.
  DicomDistanceMeasurement? _inProgressMeasurement;

  /// Viewport position where the current measurement drag gesture started.
  Offset? _measureDragStartViewport;

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
    if (oldWidget.dataset != widget.dataset) {
      _initWindowing();
      _transformationController.value = Matrix4.identity();
      _measurements.clear();
      _inProgressMeasurement = null;
      _measureDragStartViewport = null;
      _renderImage();
    } else if (oldWidget.frameIndex != widget.frameIndex) {
      _inProgressMeasurement = null;
      _measureDragStartViewport = null;
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
    if (mounted) {
      setState(() {});
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

  bool get _isMonochrome {
    final photo = PhotometricInterpretationX.parse(
      widget.dataset.photometricInterpretation,
    );
    return photo.isMonochrome;
  }

  String get _colorModeLabel {
    final photo = PhotometricInterpretationX.parse(
      widget.dataset.photometricInterpretation,
    );
    switch (photo) {
      case PhotometricInterpretation.paletteColor:
        return 'Color: Palette LUT';
      case PhotometricInterpretation.rgb:
        return 'Color: RGB';
      case PhotometricInterpretation.ybrFull:
        return 'Color: YBR';
      default:
        return 'Color: ${widget.dataset.photometricInterpretation}';
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isMonochrome) return;

    setState(() {
      _windowWidth += details.delta.dx * widget.sensitivity;
      _windowCenter -= details.delta.dy * widget.sensitivity;

      if (_windowWidth < 1.0) _windowWidth = 1.0;
    });

    widget.onWindowChanged?.call(_windowCenter, _windowWidth);
    unawaited(_renderImage());
  }

  void _onMeasurePanStart(
    DragStartDetails details,
    ImageCoordinateTransform transform,
  ) {
    final startPoint = transform.viewportToImage(details.localPosition);
    _measureDragStartViewport = details.localPosition;

    setState(() {
      _inProgressMeasurement = DicomDistanceMeasurement.fromPoints(
        start: startPoint,
        end: startPoint,
        frameIndex: widget.frameIndex,
        geometry: transform.geometry,
      );
    });
  }

  void _onMeasurePanUpdate(
    DragUpdateDetails details,
    ImageCoordinateTransform transform,
  ) {
    if (_measureDragStartViewport == null) return;

    final startPoint = transform.viewportToImage(_measureDragStartViewport!);
    final currentPoint = transform.viewportToImage(details.localPosition);

    setState(() {
      _inProgressMeasurement = DicomDistanceMeasurement.fromPoints(
        start: startPoint,
        end: currentPoint,
        frameIndex: widget.frameIndex,
        geometry: transform.geometry,
      );
    });
  }

  void _onMeasurePanEnd(
    DragEndDetails details,
    ImageCoordinateTransform transform,
  ) {
    if (_inProgressMeasurement != null && _inProgressMeasurement!.isValid) {
      _measurements[widget.frameIndex] = _inProgressMeasurement!;
    }
    setState(() {
      _inProgressMeasurement = null;
      _measureDragStartViewport = null;
    });
  }

  void _onMeasurePanCancel() {
    setState(() {
      _inProgressMeasurement = null;
      _measureDragStartViewport = null;
    });
  }

  void resetWindowing() {
    if (_isMonochrome) {
      setState(() {
        _initWindowing();
        _transformationController.value = Matrix4.identity();
        _inProgressMeasurement = null;
        _measureDragStartViewport = null;
      });
      unawaited(_renderImage());
    } else {
      setState(() {
        _transformationController.value = Matrix4.identity();
        _inProgressMeasurement = null;
        _measureDragStartViewport = null;
      });
    }
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

  /// Calculates the display aspect ratio (width / height) for physical pixel geometry.
  ///
  /// In DICOM PS3.3 Section 10.7.1.3 and C.7.6.3.1.2, [DicomDataset.pixelSpacing] (0028,0030) specifies:
  /// - Index 0: Row Spacing (vertical distance between adjacent row centers, $S_y$, in mm).
  /// - Index 1: Column Spacing (horizontal distance between adjacent column centers, $S_x$, in mm).
  ///
  /// Physical display aspect ratio is calculated via [DicomImageGeometry]:
  /// `(columns * columnSpacing) / (rows * rowSpacing)`
  ///
  /// If [pixelSpacing] is null, does not contain exactly 2 values, has values <= 0,
  /// contains non-finite numbers, or image dimensions are invalid (rows/cols <= 0),
  /// it safely falls back to native matrix aspect ratio: `columns / rows`.
  double get _displayAspectRatio =>
      DicomImageGeometry.fromDataset(widget.dataset).displayAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0,
        );
        final geometry = DicomImageGeometry.fromDataset(widget.dataset);
        final transform = ImageCoordinateTransform(
          geometry: geometry,
          viewportSize: viewportSize,
          transformMatrix:
              widget.enableZoom ? _transformationController.value : null,
        );

        final activeMeasurement =
            _inProgressMeasurement ?? _measurements[widget.frameIndex];

        Widget imageContent = Center(
          child:
              _renderedImage != null
                  ? AspectRatio(
                    aspectRatio: _displayAspectRatio,
                    child: RawImage(
                      image: _renderedImage,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
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

        final GestureDragStartCallback? panStart;
        final GestureDragUpdateCallback? panUpdate;
        final GestureDragEndCallback? panEnd;
        final GestureDragCancelCallback? panCancel;

        if (widget.tool == DicomTool.measure) {
          panStart = (details) => _onMeasurePanStart(details, transform);
          panUpdate = (details) => _onMeasurePanUpdate(details, transform);
          panEnd = (details) => _onMeasurePanEnd(details, transform);
          panCancel = _onMeasurePanCancel;
        } else if (widget.tool == DicomTool.windowing || !widget.enableZoom) {
          panStart = null;
          panUpdate = _onPanUpdate;
          panEnd = null;
          panCancel = null;
        } else {
          // DicomTool.pan with enableZoom == true -> handled by InteractiveViewer
          panStart = null;
          panUpdate = null;
          panEnd = null;
          panCancel = null;
        }

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // Image canvas with gesture handling
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('dicom_windowing_gesture'),
                  onPanStart: panStart,
                  onPanUpdate: panUpdate,
                  onPanEnd: panEnd,
                  onPanCancel: panCancel,
                  onTapDown: _onTapDown,
                  behavior: HitTestBehavior.opaque,
                  child: imageContent,
                ),
              ),

              // Distance Measurement Overlay
              if (viewportSize.width > 0 && viewportSize.height > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: viewportSize,
                      painter: DistanceMeasurementPainter(
                        measurement: activeMeasurement,
                        transform: transform,
                      ),
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
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              // Medical Overlay
              if (widget.showOverlay &&
                  !_isLoading &&
                  _errorMessage == null) ...[
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
                      if (widget.tool == DicomTool.measure) ...[
                        const Text(
                          'Tool: Measure (Drag across image to measure distance)',
                          style: TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                      ] else if (_isMonochrome) ...[
                        Text(
                          'WC: ${_windowCenter.round()}  WW: ${_windowWidth.round()}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
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
                      ] else ...[
                        Text(
                          _colorModeLabel,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
