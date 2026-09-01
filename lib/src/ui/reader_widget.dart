import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../flutter_zxing.dart' as zxing;
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
    this.tryDownscale = false,
    this.maxNumberOfSymbols = 10,
    this.showScannerOverlay = true,
    this.scannerOverlay,
    this.actionButtonsAlignment = Alignment.bottomLeft,
    this.actionButtonsPadding = const EdgeInsets.all(10),
    this.showFlashlight = true,
    this.showToggleCamera = true,
    this.showGallery = true,
    this.flashOnIcon = const Icon(Icons.flash_on),
    this.flashOffIcon = const Icon(Icons.flash_off),
    this.flashAlwaysIcon = const Icon(Icons.flash_on),
    this.flashAutoIcon = const Icon(Icons.flash_auto),
    this.galleryIcon = const Icon(Icons.photo_library),
    this.toggleCameraIcon = const Icon(Icons.switch_camera),
    this.actionButtonsBackgroundColor = Colors.black,
    this.actionButtonsBackgroundBorderRadius,
    this.allowPinchZoom = true,
    this.scanDelay = const Duration(milliseconds: 1000),
    this.scanDelaySuccess = const Duration(milliseconds: 1000),
    this.cropPercent = 0.5, // 50% of the screen
    this.horizontalCropOffset = 0.0,
    this.verticalCropOffset = 0.0,
    this.resolution = ResolutionPreset.high,
    this.lensDirection = CameraLensDirection.back,
    this.loading = const DecoratedBox(
      decoration: BoxDecoration(color: Colors.black),
    ),
    this.onActionSecondButton,
    this.actionSecondButtonIcon,
    this.actionSecondButtonIconBackgroundColor,
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
  final Function(CameraController? controller, Exception? error)?
  onControllerCreated;

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

  /// Try to downscale the image
  final bool tryDownscale;

  /// Maximum number of barcodes to detect
  final int maxNumberOfSymbols;

  /// Show cropping rect
  final bool showScannerOverlay;

  /// Custom scanner overlay
  final ShapeBorder? scannerOverlay;

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

  /// Custom flash_on icon
  final Widget flashOnIcon;

  /// Custom flash_off icon
  final Widget flashOffIcon;

  /// Custom flash_always icon
  final Widget flashAlwaysIcon;

  /// Custom flash_auto icon
  final Widget flashAutoIcon;

  /// Custom gallery icon
  final Widget galleryIcon;

  /// Custom camera toggle icon
  final Widget toggleCameraIcon;

  /// Custom background color for action buttons
  final Color actionButtonsBackgroundColor;

  /// Custom background border radius for action buttons
  final BorderRadius? actionButtonsBackgroundBorderRadius;

  /// Allow pinch zoom
  final bool allowPinchZoom;

  /// Delay between scans when no code is detected
  final Duration scanDelay;

  /// How much of the frame is scanned, as a fraction that is **kept** — not
  /// the fraction cropped away.
  ///
  /// `0.5` (the default) scans a centred square half the size of the shorter
  /// side; `1.0` scans the largest centred square that fits; `0` disables
  /// cropping and scans the whole frame. Smaller values are faster and reject
  /// codes near the edges, larger values are more forgiving.
  ///
  /// Ignored when scanning in multi-scan mode, which always uses the whole
  /// frame.
  final double cropPercent;

  /// Move the crop rect vertically, using a value from -1 (top) to 1 (bottom); ignored if [isMultiScan] is true
  final double verticalCropOffset;

  /// Move the crop rect horizontally, using a value from -1 (left) to 1 (right); ignored if [isMultiScan] is true
  final double horizontalCropOffset;

  /// Camera resolution
  final ResolutionPreset resolution;

  /// Camera lens direction
  final CameraLensDirection lensDirection;

  /// Delay between scans when a code is detected, will be ignored if isMultiScan is true
  final Duration scanDelaySuccess;

  /// Loading widget while camera is initializing. Default is a black screen
  final Widget loading;

  /// Callback for second action button
  final Function()? onActionSecondButton;

  /// Second action icon to be displayed on the right side of the action buttons
  final Widget? actionSecondButtonIcon;

  /// Background color for the second action icon
  final Color? actionSecondButtonIconBackgroundColor;

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
  bool _isInitializing = false;
  String _controllerVersion = '';
  Completer<void>? _initializationCompleter;

  double _zoom = 1.0;
  double _scaleFactor = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;

  Codes results = Codes();

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  /// The multi-scan mode actually in effect: [ReaderWidget.isMultiScan] unless
  /// the built-in mode dropdown has since changed it.
  bool get _multiScanEnabled => _isMultiScan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMultiScan = widget.isMultiScan;
    initStateAsync();
  }

  @override
  void didUpdateWidget(ReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A parent that drives `isMultiScan` (for example from
    // `onMultiScanModeChanged`) must win over the dropdown's local state.
    if (oldWidget.isMultiScan != widget.isMultiScan) {
      _isMultiScan = widget.isMultiScan;
    }

    // These two can only take effect by rebuilding the controller.
    if (oldWidget.lensDirection != widget.lensDirection ||
        oldWidget.resolution != widget.resolution) {
      final CameraDescription? camera = cameras.isEmpty
          ? null
          : cameras.firstWhere(
              (CameraDescription camera) =>
                  camera.lensDirection == widget.lensDirection,
              orElse: () => cameras.first,
            );
      if (camera != null) {
        selectedCamera = camera;
        onNewCameraSelected(camera);
      }
    }
  }

  Future<void> initStateAsync() async {
    // Warm up the decoding isolate, but do not make the camera wait on it: the
    // two are independent, and if spawning the isolate is slow or fails the
    // preview must still come up rather than staying black forever. Frames that
    // arrive before it is ready are skipped and the next one is scanned.
    unawaited(
      zx.startCameraProcessing().catchError((Object e) {
        debugPrint('flutter_zxing: failed to start camera processing: $e');
      }),
    );

    try {
      final List<CameraDescription> cameras = await availableCameras();

      if (!mounted) {
        return;
      }

      this.cameras = cameras;
      if (cameras.isNotEmpty) {
        selectedCamera = cameras.firstWhere(
          (CameraDescription camera) =>
              camera.lensDirection == widget.lensDirection,
          orElse: () => cameras.first,
        );
        await onNewCameraSelected(selectedCamera);
      }
    } catch (e) {
      debugPrint('initStateAsync error: $e');
      if (mounted) {
        widget.onControllerCreated?.call(
          null,
          e is Exception ? e : Exception(e.toString()),
        );
      }
    }
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
          onNewCameraSelected(selectedCamera ?? cameras.first);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _stopCamera();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing initialization
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      _initializationCompleter!.complete();
    }

    // Not awaited: `dispose` is synchronous. `_disposeController` stops the
    // image stream itself, so calling `_stopCamera` here too would only race it.
    _disposeController();
    zx.stopCameraProcessing();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  void rebuildOnMount() {
    if (mounted) {
      _isCameraOn = true;
    }
  }

  /// How long each step of tearing a controller down may take before it is
  /// abandoned. Disposal blocks opening the next camera, so it must not be able
  /// to wait forever on an unresponsive platform.
  static const Duration _teardownTimeout = Duration(seconds: 2);

  /// Tears down the current controller.
  ///
  /// Pass `notify: true` from anywhere except [dispose]: `CameraPreview`
  /// subscribes to the controller through a `ValueListenableBuilder`, and that
  /// subscription has to leave the tree before the controller dies. See the
  /// comment on the `setState` below.
  Future<void> _disposeController({bool notify = false}) async {
    final CameraController? oldController = controller;

    if (oldController != null) {
      // Immediately nullify controller and invalidate version
      controller = null;
      _isCameraOn = false;
      _isProcessing = false;
      _controllerVersion = 'disposed_${DateTime.now().millisecondsSinceEpoch}';

      oldController.removeListener(rebuildOnMount);

      // `CameraPreview` renders through a `ValueListenableBuilder` bound to the
      // controller. `stopImageStream()` below writes to `controller.value`,
      // which marks that builder dirty; the controller is then disposed before
      // the scheduled frame runs, and the rebuild calls `buildPreview()` on a
      // dead controller:
      //
      //   CameraException(Disposed CameraController, buildPreview() was called
      //   on a disposed CameraController.)
      //
      // Rebuilding here fixes that: this element sits above the builder, and a
      // frame flushes dirty elements from the top down, so the preview (and the
      // subscription it holds) is unmounted before the builder's own pending
      // rebuild can run. Without it nothing marks this widget dirty at all,
      // since `controller` is mutated outside of `setState`.
      //
      // During `dispose()` the element is already being torn down, so
      // `setState` is neither needed nor allowed there.
      if (notify && mounted) {
        setState(() {});
      }

      // Stop the image stream, retrying briefly: the platform side may still be
      // delivering a frame and reject the first attempt.
      //
      // Every step is bounded by a timeout. A platform that never answers must
      // not wedge teardown: `onNewCameraSelected` waits for this to finish
      // before opening the next camera, so a hang here leaves the widget with
      // no camera at all and no way to recover.
      const int stopStreamAttempts = 5;
      for (int i = 0; i < stopStreamAttempts; i++) {
        // Re-checked every round: a call that timed out may still have stopped
        // the stream, and retrying then only raises "no camera is streaming".
        if (!oldController.value.isStreamingImages) {
          break;
        }
        try {
          await oldController.stopImageStream().timeout(_teardownTimeout);
          break;
        } catch (e) {
          if (i == stopStreamAttempts - 1) {
            debugPrint('_disposeController stopImageStream error: $e');
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }

      try {
        await oldController.dispose().timeout(_teardownTimeout);
      } catch (e) {
        debugPrint('_disposeController dispose error: $e');
      }
    }
  }

  Future<void> _stopCamera() async {
    if (controller?.value.isStreamingImages ?? false) {
      try {
        await controller?.stopImageStream();
      } catch (e) {
        debugPrint('stopImageStream error: $e');
      }
    }
    _isCameraOn = false;
    _isProcessing = false;
  }

  Future<void> onNewCameraSelected(CameraDescription? cameraDescription) async {
    if (cameraDescription == null) {
      return;
    }

    // Cancel any ongoing initialization
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      _initializationCompleter!.complete();
    }

    if (_isInitializing) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_isInitializing) {
        return;
      }
    }

    _isInitializing = true;
    _initializationCompleter = Completer<void>();

    await _disposeController(notify: true);

    // Reset processing state and create new version
    _isProcessing = false;
    _controllerVersion = DateTime.now().millisecondsSinceEpoch.toString();
    final String currentVersion = _controllerVersion;

    // Small delay to ensure complete disposal
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final CameraController cameraController = CameraController(
      cameraDescription,
      widget.resolution,
      enableAudio: false,
      // Request a specific frame layout rather than letting the platform pick.
      // Left unset, CameraX reports whatever the device happens to produce --
      // on some devices that is NV21 rather than YUV420 -- and the scanner then
      // has to guess how to read the buffer. Both of these give a first plane
      // the decoder can read directly: luminance on Android, interleaved BGRA
      // on iOS.
      imageFormatGroup: _preferredImageFormatGroup(),
    );
    controller = cameraController;

    // True while `cameraController` is still the controller this widget is
    // using, and this call is still the most recent selection.
    bool isCurrent() =>
        mounted &&
        identical(controller, cameraController) &&
        _controllerVersion == currentVersion;

    try {
      await cameraController.initialize();
      // The controller can be disposed or replaced while any of the awaits in
      // this method are in flight -- a lifecycle change, a camera toggle, the
      // widget being rebuilt. Driving one that is no longer current throws
      // "Uninitialized/Disposed CameraController", and because that lands in the
      // catch below it used to abort setup entirely and leave no camera at all.
      if (!isCurrent()) {
        return;
      }

      widget.onControllerCreated?.call(controller, null);
      cameraController.addListener(rebuildOnMount);

      if (cameraController.value.isInitialized &&
          !cameraController.value.isStreamingImages) {
        try {
          await cameraController.startImageStream(
            (CameraImage image) => processImageStream(image, currentVersion),
          );

          // Verify stream is actually running
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (!cameraController.value.isStreamingImages) {
            await cameraController.startImageStream(
              (CameraImage image) => processImageStream(image, currentVersion),
            );
          }
        } catch (e) {
          debugPrint('onNewCameraSelected: failed to start image stream: $e');
        }
      }

      if (!isCurrent()) {
        return;
      }

      try {
        _maxZoomLevel = await cameraController.getMaxZoomLevel();
        _minZoomLevel = await cameraController.getMinZoomLevel();
      } catch (e) {
        // Not worth failing camera setup over: fall back to no zoom.
        debugPrint('onNewCameraSelected: zoom levels unavailable: $e');
        _minZoomLevel = 1.0;
        _maxZoomLevel = 1.0;
      }
      // A new camera has its own zoom range; carrying the previous one over
      // would apply a factor this camera may not support.
      _scaleFactor = _minZoomLevel;

      if (!isCurrent()) {
        return;
      }

      try {
        await cameraController.setFlashMode(FlashMode.off);
        if (!_isFlashAvailable && mounted) {
          setState(() => _isFlashAvailable = true);
        }
      } catch (e) {
        if (e is CameraException && e.code == 'setFlashModeFailed') {
          if (mounted) {
            setState(() {
              _isFlashAvailable = false;
            });
          }
        }
      }

      if (!isCurrent()) {
        return;
      }
      setState(() => _isCameraOn = true);

      // Restart only if interrupted (e.g. by flash mode); unconditional
      // stop-then-start risks silently leaving the stream stopped on some devices.
      if (!cameraController.value.isStreamingImages) {
        try {
          await cameraController.startImageStream(
            (CameraImage image) => processImageStream(image, currentVersion),
          );
        } catch (e) {
          debugPrint('onNewCameraSelected: failed to restart image stream: $e');
        }
      }
    } catch (e) {
      if (e is CameraException && e.code == 'setFlashModeFailed') {
        setState(() {
          _isFlashAvailable = false;
        });
      }
      widget.onControllerCreated?.call(
        null,
        e is Exception ? e : Exception(e.toString()),
      );
    } finally {
      _isInitializing = false;
      if (_initializationCompleter != null &&
          !_initializationCompleter!.isCompleted) {
        _initializationCompleter!.complete();
      }
      _initializationCompleter = null;
    }
  }

  Future<void> processImageStream(CameraImage image, String version) async {
    // Early exit if version doesn't match or widget is disposed
    if (version != _controllerVersion ||
        !mounted ||
        _isInitializing ||
        controller == null ||
        version.startsWith('disposed_') ||
        _initializationCompleter != null) {
      return;
    }

    if (!_isProcessing) {
      _isProcessing = true;
      try {
        final bool isMultiScan = _multiScanEnabled;
        final double cropPercent = isMultiScan ? 0 : widget.cropPercent;
        final int cropSize = (min(image.width, image.height) * cropPercent)
            .round();

        final bool swapAxes =
            isAndroid() &&
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final double horizontalOffset = swapAxes
            ? widget.verticalCropOffset
            : widget.horizontalCropOffset;
        final double verticalOffset = swapAxes
            ? -widget.horizontalCropOffset
            : widget.verticalCropOffset;
        final int cropLeft =
            ((image.width - cropSize) ~/ 2 +
                    (horizontalOffset * (image.width - cropSize) / 2))
                .round()
                .clamp(0, image.width - cropSize);
        final int cropTop =
            ((image.height - cropSize) ~/ 2 +
                    (verticalOffset * (image.height - cropSize) / 2))
                .round()
                .clamp(0, image.height - cropSize);

        final int imageFormat = _imageFormat(image.format.group);
        if (imageFormat == zxing.ImageFormat.none) {
          _reportUnscannableFormat(image.format.group);
          return;
        }

        final DecodeParams params = DecodeParams(
          imageFormat: imageFormat,
          format: widget.codeFormat,
          width: image.width,
          height: image.height,
          cropLeft: cropLeft,
          cropTop: cropTop,
          cropWidth: cropSize,
          cropHeight: cropSize,
          tryHarder: widget.tryHarder,
          tryRotate: widget.tryRotate,
          tryInverted: widget.tryInverted,
          tryDownscale: widget.tryDownscale,
          maxNumberOfSymbols: widget.maxNumberOfSymbols,
          isMultiScan: isMultiScan,
        );
        if (isMultiScan) {
          final Codes result = await zx.processCameraImageMulti(image, params);
          if (result.codes.isNotEmpty) {
            results = result;
            widget.onMultiScan?.call(result);
            if (!mounted) {
              return;
            }
            setState(() {});
          } else {
            results = Codes();
            widget.onMultiScanFailure?.call(result);
          }
        } else {
          final Code result = await zx.processCameraImage(image, params);
          if (result.isValid) {
            results = Codes(codes: <Code>[result]);
            widget.onScan?.call(result);
            if (!mounted) {
              return;
            }
            setState(() {});
            await Future<void>.delayed(widget.scanDelaySuccess);
          } else {
            results = Codes();
            widget.onScanFailure?.call(result);
          }
        }
      } catch (e) {
        debugPrint('processImageStream error: $e');
      } finally {
        // Check if still valid before delay
        if (version == _controllerVersion && mounted) {
          await Future<void>.delayed(widget.scanDelay);
        }
        _isProcessing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sized from this widget's own box, not from the screen: a `ReaderWidget`
    // that is not full screen (inside a `SizedBox`, or a `Scaffold` body under
    // an app bar) would otherwise lay the preview out for the whole display and
    // draw the cut-out overlay somewhere other than where it actually scans.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size media = MediaQuery.sizeOf(context);
        // Fall back to the screen when a constraint is unbounded, for example
        // inside a scrollable, where `biggest` would be infinite.
        final Size size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : media.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : media.height,
        );
        return _buildScanner(context, size);
      },
    );
  }

  Widget _buildScanner(BuildContext context, Size size) {
    final bool isCameraReady =
        cameras.isNotEmpty &&
        _isCameraOn &&
        controller != null &&
        controller!.value.isInitialized;
    final double cameraMaxSize = max(size.width, size.height);
    // Multi-scan always scans the whole frame, so the crop rect (and the cut-out
    // overlay that advertises it) must be suppressed in that mode.
    final double cropPercent = _multiScanEnabled ? 0 : widget.cropPercent;
    final double cropSize = min(size.width, size.height) * cropPercent;
    return Stack(
      children: <Widget>[
        switch (true) {
          _ when !isCameraReady => widget.loading,
          _ when _controllerVersion.startsWith('disposed_') =>
            const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
          _ => SizedBox(
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
                      child:
                          widget.showScannerOverlay &&
                              results.codes.isNotEmpty &&
                              cropPercent == 0
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
        },
        if (widget.showScannerOverlay && cropPercent != 0)
          Container(
            decoration: ShapeDecoration(
              shape:
                  widget.scannerOverlay ??
                  ScannerOverlayBorder(
                    cutOutSize: cropSize,
                    horizontalOffset: widget.horizontalCropOffset,
                    verticalOffset: widget.verticalCropOffset,
                    borderColor: Theme.of(context).primaryColor,
                    overlayColor: Colors.black45,
                    borderRadius: 4,
                    borderLength: 20,
                    borderWidth: 8,
                  ),
            ),
          ),
        if (widget.allowPinchZoom)
          GestureDetector(
            onScaleStart: (ScaleStartDetails details) {
              _zoom = _scaleFactor;
            },
            onScaleUpdate: (ScaleUpdateDetails details) {
              if (!_isCameraOn) {
                return;
              }
              _scaleFactor = (_zoom * details.scale).clamp(
                _minZoomLevel,
                _maxZoomLevel,
              );
              controller?.setZoomLevel(_scaleFactor);
            },
          ),
        SafeArea(
          child: Align(
            alignment: widget.actionButtonsAlignment,
            child: Padding(
              padding: widget.actionButtonsPadding,
              child: ClipRRect(
                borderRadius:
                    widget.actionButtonsBackgroundBorderRadius ??
                    BorderRadius.circular(10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius:
                          widget.actionButtonsBackgroundBorderRadius ??
                          BorderRadius.circular(10.0),
                      child: ColoredBox(
                        color: widget.actionButtonsBackgroundColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (widget.showFlashlight && _isFlashAvailable)
                              IconButton(
                                onPressed: _onFlashButtonTapped,
                                color: Colors.white,
                                icon: _flashIcon(
                                  controller?.value.flashMode ?? FlashMode.off,
                                ),
                              ),
                            if (widget.showGallery)
                              IconButton(
                                onPressed: _onGalleryButtonTapped,
                                color: Colors.white,
                                icon: widget.galleryIcon,
                              ),
                            if (widget.showToggleCamera)
                              IconButton(
                                onPressed: _onCameraButtonTapped,
                                color: Colors.white,
                                icon: widget.toggleCameraIcon,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.onActionSecondButton != null &&
                        widget.actionSecondButtonIcon != null) ...<Widget>[
                      Container(
                        margin: EdgeInsets.only(
                          bottom:
                              (widget.onMultiScanModeChanged != null &&
                                  widget.multiScanModeAlignment ==
                                      Alignment.bottomRight)
                              ? 55.0
                              : 0,
                        ),
                        child: IconButton.filled(
                          padding: widget.actionButtonsPadding,
                          onPressed: widget.onActionSecondButton,
                          icon: widget.actionSecondButtonIcon!,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                widget.actionSecondButtonIconBackgroundColor ??
                                widget.actionButtonsBackgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  widget.actionButtonsBackgroundBorderRadius ??
                                  BorderRadius.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
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
                if (mounted) {
                  setState(() {
                    _isMultiScan = value;
                  });
                }
                widget.onMultiScanModeChanged?.call(value);
              },
            ),
          ),
      ],
    );
  }

  Future<void> _onFlashButtonTapped() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    final FlashMode mode = cameraController.value.flashMode == FlashMode.torch
        ? FlashMode.off
        : FlashMode.torch;
    try {
      await cameraController.setFlashMode(mode);
    } catch (e) {
      // Some devices report a torch they cannot actually drive; hide the button
      // rather than leaving it stuck on a mode that never applies.
      debugPrint('setFlashMode error: $e');
      if (mounted) {
        setState(() => _isFlashAvailable = false);
      }
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onGalleryButtonTapped() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      final bool isMultiScan = _multiScanEnabled;
      // Mirror every decoding option used for the camera stream, so a picture
      // from the gallery is scanned exactly the same way a frame would be.
      final DecodeParams params = DecodeParams(
        imageFormat: zxing.ImageFormat.rgb,
        format: widget.codeFormat,
        tryHarder: widget.tryHarder,
        tryRotate: widget.tryRotate,
        tryInverted: widget.tryInverted,
        tryDownscale: widget.tryDownscale,
        maxNumberOfSymbols: widget.maxNumberOfSymbols,
        isMultiScan: isMultiScan,
      );
      if (isMultiScan) {
        final Codes result = await zx.readBarcodesImagePath(file, params);
        if (result.codes.isNotEmpty) {
          results = result;
          widget.onMultiScan?.call(result);
          if (!mounted) {
            return;
          }
          setState(() {});
        } else {
          results = Codes();
          widget.onMultiScanFailure?.call(result);
        }
      } else {
        final Code result = await zx.readBarcodeImagePath(file, params);
        if (result.isValid) {
          results = Codes(codes: <Code>[result]);
          widget.onScan?.call(result);
          if (!mounted) {
            return;
          }
          setState(() {});
        } else {
          results = Codes();
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

  Widget _flashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.torch:
        return widget.flashOnIcon;
      case FlashMode.off:
        return widget.flashOffIcon;
      case FlashMode.always:
        return widget.flashAlwaysIcon;
      case FlashMode.auto:
        return widget.flashAutoIcon;
    }
  }

  /// The frame layout to ask the camera for, per platform.
  ImageFormatGroup _preferredImageFormatGroup() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return ImageFormatGroup.yuv420;
      case TargetPlatform.iOS:
        return ImageFormatGroup.bgra8888;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return ImageFormatGroup.unknown;
    }
  }

  /// Camera frame layouts already reported as unscannable, so the warning is
  /// logged once per layout instead of once per frame.
  final Set<ImageFormatGroup> _reportedUnscannableFormats =
      <ImageFormatGroup>{};

  /// Reports a camera frame layout the decoder cannot read.
  ///
  /// Without this the scanner just returns nothing, forever, with no error --
  /// the hardest kind of failure to diagnose from a bug report.
  void _reportUnscannableFormat(ImageFormatGroup group) {
    if (_reportedUnscannableFormats.add(group)) {
      debugPrint(
        'flutter_zxing: this camera delivers $group frames, which cannot be '
        'scanned as raw pixels. Pass a CameraController configured with '
        'ImageFormatGroup.yuv420 (Android) or ImageFormatGroup.bgra8888 (iOS).',
      );
    }
    widget.onScanFailure?.call(
      Code(
        error: 'Unsupported camera image format: $group',
        source: CodeSource.camera,
      ),
    );
  }

  /// Maps a camera frame layout onto the pixel format the decoder is handed.
  ///
  /// Only the first plane of the frame is scanned. For YUV420 and NV21 that
  /// plane is the luminance (Y) channel — exactly what a barcode decoder wants —
  /// while BGRA8888 frames are a single interleaved plane. JPEG frames hold
  /// compressed data that cannot be scanned as raw pixels.
  int _imageFormat(ImageFormatGroup group) {
    switch (group) {
      case ImageFormatGroup.bgra8888:
        return zxing.ImageFormat.bgrx;
      case ImageFormatGroup.yuv420:
      case ImageFormatGroup.nv21:
        return zxing.ImageFormat.lum;
      case ImageFormatGroup.jpeg:
      case ImageFormatGroup.unknown:
        return zxing.ImageFormat.none;
    }
  }
}
