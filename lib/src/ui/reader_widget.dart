import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../flutter_zxing.dart';
import 'scan_mode_dropdown.dart';

/// Widget to scan a code from the camera stream
class ReaderWidget extends StatefulWidget {
  const ReaderWidget({
    super.key,
    this.onScan,
    this.onScanFailure,
    this.onMultiScan,
    this.onMultiScanFailure,
    this.onControllerCreated,
    this.onMultiScanModeChanged,
    this.isMultiScan = false,
    this.multiScanModeAlignment = Alignment.bottomRight,
    this.multiScanModePadding = const EdgeInsets.all(10),
    this.codeFormat = Format.any,
    this.tryHarder = false,
    this.tryInverted = false,
    this.tryRotate = true,
    this.showScannerOverlay = true,
    this.scannerOverlay,
    this.actionButtonsAlignment = Alignment.bottomLeft,
    this.actionButtonsPadding = const EdgeInsets.all(10),
    this.showFlashlight = true,
    this.showToggleCamera = true,
    this.showGallery = true,
    this.allowPinchZoom = true,
    this.scanDelay = const Duration(milliseconds: 1000),
    this.scanDelaySuccess = const Duration(milliseconds: 1000),
    this.cropPercent = 0.5, // 50% of the screen
    this.resolution = ResolutionPreset.high,
    this.lensDirection = CameraLensDirection.back,
    this.loading =
        const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
  });

  /// Called when a code is detected
  final Function(Code)? onScan;

  /// Called when a code is not detected
  final Function(Code)? onScanFailure;

  /// Called when a code is detected
  final Function(Codes)? onMultiScan;

  /// Called when a code is not detected
  final Function(Codes)? onMultiScanFailure;

  /// Called when the camera controller is created
  final Function(CameraController?)? onControllerCreated;

  /// Called when the multi scan mode is changed
  /// When set to null, the multi scan mode button will not be displayed
  final Function(bool)? onMultiScanModeChanged;

  /// Allow multiple scans
  final bool isMultiScan;

  /// Alignment for multi scan mode button
  final AlignmentGeometry multiScanModeAlignment;

  /// Padding for multi scan mode button
  final EdgeInsetsGeometry multiScanModePadding;

  /// Code format to scan
  final int codeFormat;

  /// Try harder to detect a code
  final bool tryHarder;

  /// Try to detect inverted code
  final bool tryInverted;

  /// Try to rotate the image
  final bool tryRotate;

  /// Show cropping rect
  final bool showScannerOverlay;

  /// Custom scanner overlay
  final ScannerOverlay? scannerOverlay;

  /// Align for action buttons
  final AlignmentGeometry actionButtonsAlignment;

  /// Padding for action buttons
  final EdgeInsetsGeometry actionButtonsPadding;

  /// Show flashlight button
  final bool showFlashlight;

  /// Show toggle camera
  final bool showGallery;

  /// Show toggle camera
  final bool showToggleCamera;

  /// Allow pinch zoom
  final bool allowPinchZoom;

  /// Delay between scans when no code is detected
  final Duration scanDelay;

  /// Crop percent of the screen, will be ignored if isMultiScan is true
  final double cropPercent;

  /// Camera resolution
  final ResolutionPreset resolution;

  /// Camera lens direction
  final CameraLensDirection lensDirection;

  /// Delay between scans when a code is detected, will be ignored if isMultiScan is true
  final Duration scanDelaySuccess;

  /// Loading widget while camera is initializing. Default is a black screen
  final Widget loading;

  @override
  State<ReaderWidget> createState() => _ReaderWidgetState();
}

class _ReaderWidgetState extends State<ReaderWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<CameraDescription> cameras = <CameraDescription>[];
  CameraDescription? selectedCamera;
  CameraController? controller;

  // true when code detecting is ongoing
  bool _isProcessing = false;
  bool _isCameraOn = false;
  bool _isFlashAvailable = true;
  bool _isMultiScan = false;

  double _zoom = 1.0;
  double _scaleFactor = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;

  Codes results = Codes();

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMultiScan = widget.isMultiScan;
    initStateAsync();
  }

  Future<void> initStateAsync() async {
    // Spawn a new isolate
    await zx.startCameraProcessing();

    availableCameras().then((List<CameraDescription> cameras) {
      setState(() {
        this.cameras = cameras;
        if (cameras.isNotEmpty) {
          selectedCamera = cameras.firstWhere(
            (CameraDescription camera) =>
                camera.lensDirection == widget.lensDirection,
            orElse: () => cameras.first,
          );
          onNewCameraSelected(selectedCamera);
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        if (cameras.isNotEmpty && !_isCameraOn) {
          onNewCameraSelected(cameras.first);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        controller?.dispose();
        setState(() {
          _isCameraOn = false;
        });
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    zx.stopCameraProcessing();
    controller?.removeListener(rebuildOnMount);
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void rebuildOnMount() {
    if (mounted) {
      setState(() {
        _isCameraOn = true;
      });
    }
  }

  Future<void> onNewCameraSelected(CameraDescription? cameraDescription) async {
    if (cameraDescription == null) {
      return;
    }
    final CameraController? oldController = controller;
    if (oldController != null) {
      // controller?.removeListener(rebuildOnMount);
      controller = null;
      await oldController.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      widget.resolution,
      enableAudio: false,
      imageFormatGroup:
          isAndroid() ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    controller = cameraController;
    try {
      await cameraController.initialize();
      widget.onControllerCreated?.call(controller);
      cameraController.addListener(rebuildOnMount);
      cameraController.startImageStream(processImageStream);
    } on CameraException catch (e) {
      debugPrint('${e.code}: ${e.description}');
    } catch (e) {
      debugPrint('Error: $e');
    }

    try {
      cameraController
          .getMaxZoomLevel()
          .then((double value) => _maxZoomLevel = value);
      cameraController
          .getMinZoomLevel()
          .then((double value) => _minZoomLevel = value);
    } catch (e) {
      debugPrint('Error: $e');
    }

    try {
      await cameraController.setFlashMode(FlashMode.off);
    } catch (e) {
      _isFlashAvailable = false;
      debugPrint('Error: $e');
    }

    rebuildOnMount();
  }

  Future<void> processImageStream(CameraImage image) async {
    if (!_isProcessing) {
      _isProcessing = true;
      try {
        final double cropPercent = widget.isMultiScan ? 0 : widget.cropPercent;
        final int cropSize =
            (min(image.width, image.height) * cropPercent).round();
        final DecodeParams params = DecodeParams(
          format: widget.codeFormat,
          cropWidth: cropSize,
          cropHeight: cropSize,
          tryHarder: widget.tryHarder,
          tryRotate: widget.tryRotate,
          tryInverted: widget.tryInverted,
          isMultiScan: widget.isMultiScan,
        );
        if (widget.isMultiScan) {
          final Codes result = await zx.processCameraImageMulti(
            image,
            params: params,
          );
          if (result.codes.isNotEmpty) {
            results = result;
            widget.onMultiScan?.call(result);
            setState(() {});
            if (!widget.isMultiScan) {
              await Future<void>.delayed(widget.scanDelaySuccess);
            }
          } else {
            results = Codes();
            widget.onMultiScanFailure?.call(result);
          }
        } else {
          final Code result = await zx.processCameraImage(
            image,
            params: params,
          );
          if (result.isValid) {
            widget.onScan?.call(result);
            setState(() {});
            await Future<void>.delayed(widget.scanDelaySuccess);
          } else {
            widget.onScanFailure?.call(result);
          }
        }
      } on FileSystemException catch (e) {
        debugPrint(e.message);
      } catch (e) {
        debugPrint(e.toString());
      }
      await Future<void>.delayed(widget.scanDelay);
      _isProcessing = false;
    }

    return;
  }

  @override
  Widget build(BuildContext context) {
    final bool isCameraReady = cameras.isNotEmpty &&
        _isCameraOn &&
        controller != null &&
        controller!.value.isInitialized;
    final Size size = MediaQuery.of(context).size;
    final double cameraMaxSize = max(size.width, size.height);
    final double cropSize = min(size.width, size.height) * widget.cropPercent;
    return Stack(
      children: <Widget>[
        if (!isCameraReady) widget.loading,
        if (isCameraReady)
          SizedBox(
            width: cameraMaxSize,
            height: cameraMaxSize,
            child: ClipRRect(
              child: OverflowBox(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cameraMaxSize,
                    child: CameraPreview(
                      controller!,
                      child: widget.showScannerOverlay &&
                              widget.isMultiScan &&
                              results.codes.isNotEmpty
                          ? MultiResultOverlay(
                              results: results.codes,
                              onCodeTap: widget.onScan,
                              controller: controller,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.showScannerOverlay && !widget.isMultiScan)
          Container(
            decoration: ShapeDecoration(
              shape: widget.scannerOverlay ??
                  FixedScannerOverlay(
                    borderColor: Theme.of(context).primaryColor,
                    overlayColor: Colors.black45,
                    borderRadius: 1,
                    borderLength: 16,
                    borderWidth: 8,
                    cutOutSize: cropSize,
                  ),
            ),
          ),
        if (widget.allowPinchZoom)
          GestureDetector(
            onScaleStart: (ScaleStartDetails details) {
              _zoom = _scaleFactor;
            },
            onScaleUpdate: (ScaleUpdateDetails details) {
              _scaleFactor =
                  (_zoom * details.scale).clamp(_minZoomLevel, _maxZoomLevel);
              controller?.setZoomLevel(_scaleFactor);
            },
          ),
        SafeArea(
          child: Align(
            alignment: widget.actionButtonsAlignment,
            child: Padding(
              padding: widget.actionButtonsPadding,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.showFlashlight && _isFlashAvailable)
                        IconButton(
                          onPressed: _onFlashButtonTapped,
                          color: Colors.white,
                          icon: Icon(
                            _flashIcon(
                                controller?.value.flashMode ?? FlashMode.off),
                          ),
                        ),
                      if (widget.showGallery)
                        IconButton(
                          onPressed: _onGalleryButtonTapped,
                          color: Colors.white,
                          icon: const Icon(Icons.photo_library),
                        ),
                      if (widget.showToggleCamera)
                        IconButton(
                          onPressed: _onCameraButtonTapped,
                          color: Colors.white,
                          icon: const Icon(Icons.switch_camera),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.onMultiScanModeChanged != null)
          SafeArea(
            child: ScanModeDropdown(
              isMultiScan: _isMultiScan,
              alignment: widget.multiScanModeAlignment,
              padding: widget.multiScanModePadding,
              onChanged: (bool value) {
                setState(() {
                  _isMultiScan = value;
                });
                widget.onMultiScanModeChanged?.call(value);
              },
            ),
          ),
      ],
    );
  }

  void _onFlashButtonTapped() {
    FlashMode mode = controller?.value.flashMode ?? FlashMode.off;
    if (mode == FlashMode.torch) {
      mode = FlashMode.off;
    } else {
      mode = FlashMode.torch;
    }
    controller?.setFlashMode(mode);
    setState(() {});
  }

  Future<void> _onGalleryButtonTapped() async {
    final XFile? file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      final DecodeParams params = DecodeParams(
        format: widget.codeFormat,
        tryHarder: widget.tryHarder,
        tryInverted: widget.tryInverted,
        isMultiScan: widget.isMultiScan,
      );
      if (widget.isMultiScan) {
        final Codes result =
            await zx.readBarcodesImagePath(file, params: params);
        if (result.codes.isNotEmpty) {
          results = result;
          widget.onMultiScan?.call(result);
          setState(() {});
        } else {
          results = Codes();
          widget.onMultiScanFailure?.call(result);
        }
      } else {
        final Code result = await zx.readBarcodeImagePath(file, params: params);
        if (result.isValid) {
          widget.onScan?.call(result);
        } else {
          widget.onScanFailure?.call(result);
        }
      }
    }
  }

  void _onCameraButtonTapped() {
    if (cameras.isEmpty || controller == null) {
      return;
    }
    final int cameraIndex = cameras.indexOf(controller!.description);
    final int nextCameraIndex = (cameraIndex + 1) % cameras.length;
    selectedCamera = cameras[nextCameraIndex];
    onNewCameraSelected(selectedCamera);
  }

  IconData _flashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.torch:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.auto:
        return Icons.flash_auto;
    }
  }
}
