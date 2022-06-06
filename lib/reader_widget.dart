import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'flutter_zxing.dart';

import 'isolate_utils.dart';

class ReaderWidget extends StatefulWidget {
  const ReaderWidget({
    Key? key,
    required this.onScan,
    this.onControllerCreated,
    this.codeFormat = Format.Any,
    this.beep = true,
    this.showCroppingRect = true,
    this.scannerOverlay,
    this.showFlashlight = true,
    this.allowPinchZoom = true,
    this.scanDelay = const Duration(milliseconds: 1000), // 1000ms delay
    this.cropPercent = 0.5, // 50% of the screen
    this.resolution = ResolutionPreset.high,
  }) : super(key: key);

  final Function(CodeResult) onScan;
  final Function(CameraController?)? onControllerCreated;
  final int codeFormat;
  final bool beep;
  final bool showCroppingRect;
  final ScannerOverlay? scannerOverlay;
  final bool showFlashlight;
  final bool allowPinchZoom;
  final Duration scanDelay;
  final double cropPercent;
  final ResolutionPreset resolution;

  @override
  State<ReaderWidget> createState() => _ReaderWidgetState();
}

class _ReaderWidgetState extends State<ReaderWidget>
    with TickerProviderStateMixin {
  List<CameraDescription>? cameras;
  CameraController? controller;
  var _cameraOn = false;

  double _zoom = 1.0;
  double _scaleFactor = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  // true when code detecting is ongoing
  bool _isProcessing = false;

  /// Instance of [IsolateUtils]
  IsolateUtils? isolateUtils;

  @override
  void initState() {
    super.initState();

    initStateAsync();
  }

  void initStateAsync() async {
    // Spawn a new isolate
    await FlutterZxing.startCameraProcessing();

    availableCameras().then((cameras) {
      setState(() {
        this.cameras = cameras;
        if (cameras.isNotEmpty) {
          onNewCameraSelected(cameras.first);
        }
      });
    });

    SystemChannels.lifecycle.setMessageHandler((message) async {
      debugPrint(message);
      final CameraController? cameraController = controller;
      if (cameraController == null || !cameraController.value.isInitialized) {
        return;
      }
      if (mounted) {
        if (message == AppLifecycleState.paused.toString()) {
          _cameraOn = false;
          setState(() {});
        }
        if (message == AppLifecycleState.resumed.toString()) {
          _cameraOn = true;
          onNewCameraSelected(cameraController.description);
        }
      }
      return null;
    });
  }

  @override
  void dispose() {
    FlutterZxing.stopCameraProcessing();
    controller?.dispose();
    super.dispose();
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }

    controller = CameraController(
      cameraDescription,
      widget.resolution,
      enableAudio: false,
      imageFormatGroup:
          isAndroid() ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    final CameraController? cameraController = controller;
    if (cameraController == null) {
      return;
    }
    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(FlashMode.off);
      _maxZoomLevel = await cameraController.getMaxZoomLevel();
      _minZoomLevel = await cameraController.getMinZoomLevel();
      cameraController.startImageStream(processCameraImage);
    } on CameraException catch (e) {
      debugPrint('${e.code}: ${e.description}');
    }

    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    if (mounted) {
      _cameraOn = true;
      setState(() {});
    }

    widget.onControllerCreated?.call(cameraController);
  }

  processCameraImage(CameraImage image) async {
    if (!_isProcessing) {
      _isProcessing = true;
      try {
        CodeResult result = await FlutterZxing.processCameraImage(
          image,
          widget.codeFormat,
          widget.cropPercent,
        );
        if (result.isValidBool) {
          if (widget.beep) {
            FlutterBeep.beep();
          }
          widget.onScan(result);
          setState(() {});
          await Future.delayed(const Duration(seconds: 1));
        }
      } on FileSystemException catch (e) {
        debugPrint(e.message);
      } catch (e) {
        debugPrint(e.toString());
      }
      await Future.delayed(widget.scanDelay);
      _isProcessing = false;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cropSize = min(size.width, size.height) * widget.cropPercent;
    return Stack(
      children: [
        // Camera preview
        Center(child: _cameraPreviewWidget(cropSize)),
      ],
    );
  }

  // Display the preview from the camera.
  Widget _cameraPreviewWidget(double cropSize) {
    final CameraController? cameraController = controller;
    if (cameras != null && cameras?.isEmpty == true) {
      return const Text('No cameras found');
    } else if (cameraController == null ||
        !cameraController.value.isInitialized ||
        !_cameraOn) {
      return const CircularProgressIndicator();
    } else {
      final size = MediaQuery.of(context).size;
      var cameraMaxSize = max(size.width, size.height);
      return Stack(
        children: [
          SizedBox(
            width: cameraMaxSize,
            height: cameraMaxSize,
            child: ClipRRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cameraMaxSize,
                    child: CameraPreview(
                      cameraController,
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
              onScaleStart: (details) {
                _zoom = _scaleFactor;
              },
              onScaleUpdate: (details) {
                _scaleFactor =
                    (_zoom * details.scale).clamp(_minZoomLevel, _maxZoomLevel);
                cameraController.setZoomLevel(_scaleFactor);
              },
            ),
          if (widget.showFlashlight)
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton(
                onPressed: () {
                  FlashMode mode = cameraController.value.flashMode;
                  switch (mode) {
                    case FlashMode.torch:
                      mode = FlashMode.off;
                      break;
                    case FlashMode.off:
                      mode = FlashMode.torch;
                      break;
                    default:
                  }
                  cameraController.setFlashMode(mode);
                  setState(() {});
                },
                backgroundColor: Colors.black26,
                child: Icon(_flashIcon(cameraController)),
              ),
            )
        ],
      );
    }
  }

  IconData _flashIcon(CameraController cameraController) {
    final FlashMode mode = cameraController.value.flashMode;
    switch (mode) {
      case FlashMode.torch:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      default:
        return Icons.flash_off;
    }
  }
}
