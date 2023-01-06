import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../flutter_zxing.dart';

/// Widget to scan a code from the camera stream
class ReaderWidget extends StatefulWidget {
  const ReaderWidget({
    super.key,
    required this.onScan,
    this.onScanFailure,
    this.onControllerCreated,
    this.codeFormat = Format.any,
    this.tryHarder = false,
    this.tryInverted = false,
    this.showScannerOverlay = true,
    this.scannerOverlay,
    this.showFlashlight = true,
    this.allowPinchZoom = true,
    this.scanDelay = const Duration(milliseconds: 1000), // 1000ms delay
    this.scanDelaySuccess = const Duration(milliseconds: 1000), // 1000ms delay
    this.cropPercent = 0.5, // 50% of the screen
    this.resolution = ResolutionPreset.high,
    this.loading =
        const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
  });

  /// Called when a code is detected
  final Function(Code) onScan;

  /// Called when a code is not detected
  final Function()? onScanFailure;

  /// Called when the camera controller is created
  final Function(CameraController?)? onControllerCreated;

  /// Code format to scan
  final int codeFormat;

  /// Try harder to detect a code
  final bool tryHarder;

  /// Try to detect inverted code
  final bool tryInverted;

  /// Show cropping rect
  final bool showScannerOverlay;

  /// Custom scanner overlay
  final ScannerOverlay? scannerOverlay;

  /// Show flashlight button
  final bool showFlashlight;

  /// Allow pinch zoom
  final bool allowPinchZoom;

  /// Delay between scans when no code is detected
  final Duration scanDelay;

  /// Crop percent of the screen
  final double cropPercent;

  /// Camera resolution
  final ResolutionPreset resolution;

  /// Delay between scans when a code is detected
  final Duration scanDelaySuccess;

  /// Loading widget while camera is initializing. Default is a black screen
  final Widget loading;

  @override
  State<ReaderWidget> createState() => _ReaderWidgetState();
}

class _ReaderWidgetState extends State<ReaderWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<CameraDescription> cameras = <CameraDescription>[];
  CameraController? controller;
  bool _cameraOn = false;

  double _zoom = 1.0;
  double _scaleFactor = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  // true when code detecting is ongoing
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initStateAsync();
  }

  Future<void> initStateAsync() async {
    // Spawn a new isolate
    await zx.startCameraProcessing();

    availableCameras().then((List<CameraDescription> cameras) {
      setState(() {
        this.cameras = cameras;
        if (cameras.isNotEmpty) {
          onNewCameraSelected(cameras.first);
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
        if (cameras.isNotEmpty && !_cameraOn) {
          onNewCameraSelected(cameras.first);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        controller?.dispose();
        setState(() {
          _cameraOn = false;
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
        _cameraOn = true;
      });
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
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
    cameraController.addListener(rebuildOnMount);
    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(FlashMode.off);
      cameraController
          .getMaxZoomLevel()
          .then((double value) => _maxZoomLevel = value);
      cameraController
          .getMinZoomLevel()
          .then((double value) => _minZoomLevel = value);
      cameraController.startImageStream(processImageStream);
    } on CameraException catch (e) {
      debugPrint('${e.code}: ${e.description}');
    } catch (e) {
      debugPrint('Error: $e');
    }
    rebuildOnMount();
    widget.onControllerCreated?.call(controller);
  }

  Future<void> processImageStream(CameraImage image) async {
    if (!_isProcessing) {
      _isProcessing = true;
      try {
        final double cropPercent =
            widget.showScannerOverlay ? widget.cropPercent : 0;
        final int cropSize =
            (min(image.width, image.height) * cropPercent).round();
        final Params params = Params(
          format: widget.codeFormat,
          cropWidth: cropSize,
          cropHeight: cropSize,
          tryHarder: widget.tryHarder,
          tryInverted: widget.tryInverted,
        );
        final Code result = await zx.processCameraImage(
          image,
          params: params,
        );
        if (result.isValid) {
          widget.onScan(result);
          setState(() {});
          await Future<void>.delayed(widget.scanDelaySuccess);
        } else {
          widget.onScanFailure?.call();
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
        _cameraOn &&
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.showScannerOverlay)
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
        if (widget.showFlashlight && isCameraReady)
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
                onPressed: () {
                  FlashMode mode = controller!.value.flashMode;
                  if (mode == FlashMode.torch) {
                    mode = FlashMode.off;
                  } else {
                    mode = FlashMode.torch;
                  }
                  controller?.setFlashMode(mode);
                  setState(() {});
                },
                backgroundColor: Colors.black26,
                child: _FlashIcon(
                    flashMode: controller?.value.flashMode ?? FlashMode.off)),
          ),
      ],
    );
  }
}

class _FlashIcon extends StatelessWidget {
  const _FlashIcon({required this.flashMode});
  final FlashMode flashMode;

  @override
  Widget build(BuildContext context) {
    switch (flashMode) {
      case FlashMode.torch:
        return const Icon(Icons.flash_on);
      case FlashMode.off:
        return const Icon(Icons.flash_off);
      case FlashMode.always:
        return const Icon(Icons.flash_on);
      case FlashMode.auto:
        return const Icon(Icons.flash_auto);
    }
  }
}
