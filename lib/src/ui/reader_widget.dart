import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

// import 'package:flutter_beep/flutter_beep.dart';

import '../../generated_bindings.dart';
import '../logic/zxing.dart';
import '../utils/extentions.dart';
import 'scanner_overlay.dart';

class ReaderWidget extends StatefulWidget {
  const ReaderWidget({
    super.key,
    required this.onScan,
    this.onControllerCreated,
    this.codeFormat = Format.Any,
    this.showCroppingRect = true,
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

  final Function(CodeResult) onScan;
  final Function(CameraController?)? onControllerCreated;
  final int codeFormat;
  final bool showCroppingRect;
  final ScannerOverlay? scannerOverlay;
  final bool showFlashlight;
  final bool allowPinchZoom;
  final Duration scanDelay;
  final double cropPercent;
  final ResolutionPreset resolution;
  final Duration scanDelaySuccess;
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
    await startCameraProcessing();

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
    switch (state) {
      case AppLifecycleState.resumed:
        if (cameras.isNotEmpty && !_cameraOn) {
          onNewCameraSelected(cameras.first);
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        controller?.stopImageStream().then((_) => controller?.dispose());
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
    stopCameraProcessing();
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
    if (controller != null) {
      controller?.removeListener(rebuildOnMount);
      await controller!.dispose();
    }

    controller = CameraController(
      cameraDescription,
      widget.resolution,
      enableAudio: false,
      imageFormatGroup:
          isAndroid() ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    if (controller == null) {
      return;
    }
    try {
      await controller!.initialize();
      await controller!.setFlashMode(FlashMode.off);
      _maxZoomLevel = await controller!.getMaxZoomLevel();
      _minZoomLevel = await controller!.getMinZoomLevel();
      controller!.startImageStream(processImageStream);
    } on CameraException catch (e) {
      debugPrint('${e.code}: ${e.description}');
    } catch (e) {
      debugPrint('Error: $e');
    }

    controller!.addListener(rebuildOnMount);
    rebuildOnMount();
    widget.onControllerCreated?.call(controller);
  }

  Future<void> processImageStream(CameraImage image) async {
    if (!_isProcessing) {
      _isProcessing = true;
      try {
        final CodeResult result = await processCameraImage(
          image,
          format: widget.codeFormat,
          cropPercent: widget.showCroppingRect ? widget.cropPercent : 0,
        );
        if (result.isValidBool) {
          widget.onScan(result);
          setState(() {});
          await Future<void>.delayed(widget.scanDelaySuccess);
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
        if (widget.showCroppingRect)
          Container(
            decoration: ShapeDecoration(
              shape: widget.scannerOverlay ??
                  ScannerOverlay(
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
