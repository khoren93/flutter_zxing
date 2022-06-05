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
    this.scanDelay = const Duration(milliseconds: 500), // 500ms delay
    this.cropPercent = 0.5, // 50% of the screen
    this.resolution = ResolutionPreset.high,
  }) : super(key: key);

  final Function(CodeResult) onScan;
  final Function(CameraController?)? onControllerCreated;
  final int codeFormat;
  final bool beep;
  final bool showCroppingRect;
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

    try {
      await controller?.initialize();
      controller?.startImageStream(processCameraImage);
    } on CameraException catch (e) {
      debugPrint('${e.code}: ${e.description}');
    }

    controller?.addListener(() {
      if (mounted) setState(() {});
    });

    if (mounted) {
      _cameraOn = true;
      setState(() {});
    }

    widget.onControllerCreated?.call(controller);
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
          widget.showCroppingRect
              ? Container(
                  decoration: ShapeDecoration(
                    shape: ScannerOverlay(
                      borderColor: Theme.of(context).primaryColor,
                      overlayColor: const Color.fromRGBO(0, 0, 0, 0.5),
                      borderRadius: 1,
                      borderLength: 16,
                      borderWidth: 8,
                      cutOutSize: cropSize,
                    ),
                  ),
                )
              : Container()
        ],
      );
    }
  }
}
