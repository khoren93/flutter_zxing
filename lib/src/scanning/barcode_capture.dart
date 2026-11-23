part of 'scanner_controller.dart';

/// Barcodes found in one camera frame.
@immutable
final class BarcodeCapture {
  /// Creates a capture. [barcodes] must not be empty.
  const BarcodeCapture({
    required this.barcodes,
    required this.imageSize,
    required this.time,
    this.source = CaptureSource.camera,
  }) : _cut = null,
       _positions = null,
       _encoded = null,
       _mirrored = false,
       assert(barcodes.length > 0, 'A capture has at least one barcode');

  const BarcodeCapture._({
    required this.barcodes,
    required this.imageSize,
    required this.time,
    required this.source,
    required List<BarcodePosition> positions,
    FrameCut? cut,
    Uint8List? encoded,
    bool mirrored = false,
  }) : _cut = cut,
       _positions = positions,
       _encoded = encoded,
       _mirrored = mirrored;

  /// The frame around the barcodes, kept for [snapshot].
  final FrameCut? _cut;

  /// The barcodes' positions in [_cut]'s frame (or in [_encoded]).
  final List<BarcodePosition>? _positions;

  /// The image file given to [ScannerController.readImage].
  final Uint8List? _encoded;

  /// Whether [_cut] is a mirror image of the scene.
  final bool _mirrored;

  /// The barcodes in the frame, at least one.
  final List<Barcode> barcodes;

  /// The first barcode: the one to use when you expect a single code.
  Barcode get barcode => barcodes.first;

  /// Size of the camera frame, in its display orientation. Barcode positions
  /// are in this coordinate space.
  final Size imageSize;

  /// When the frame was decoded.
  final DateTime time;

  /// Where the barcodes came from: a camera frame, or an image given to
  /// [ScannerController.readImage]. Positions of an image's barcodes are
  /// not on screen.
  final CaptureSource source;

  /// [barcode] (default [this.barcode]) cut out of the camera frame or the
  /// photo it was found in and straightened: a flat grayscale image with a
  /// little margin, its contrast stretched. Each call makes a new image,
  /// which the caller disposes.
  ///
  /// ```dart
  /// onDetect: (capture) async {
  ///   final ui.Image? image = await capture.snapshot();
  ///   history.add(capture.barcode, image);
  /// }
  /// ```
  ///
  /// `null` for captures not made by a [ScannerController], and for a
  /// barcode not in [barcodes].
  Future<ui.Image?> snapshot([Barcode? barcode]) async =>
      (await _straightened(barcode))?.toImage();

  /// The pixels of [snapshot].
  Future<GrayImage?> _straightened([Barcode? barcode]) async {
    final int index = barcode == null ? 0 : barcodes.indexOf(barcode);
    final List<BarcodePosition>? positions = _positions;
    if (index < 0 || positions == null) {
      return null;
    }
    FrameCut? cut = _cut;
    BarcodePosition position = positions[index];
    final Uint8List? encoded = _encoded;
    if (cut == null && encoded != null) {
      // The reader sees the file's pixels, the decoder here turns them.
      final int orientation = exifOrientation(encoded);
      final List<BarcodePosition> shown = <BarcodePosition>[
        for (final BarcodePosition p in positions)
          orientedPosition(p, imageSize, orientation),
      ];
      final (FrameCut, double)? decoded = await cutEncoded(
        encoded,
        orientedSize(imageSize, orientation),
        shown,
        linear: <bool>[for (final Barcode b in barcodes) b.format.isLinear],
      );
      if (decoded == null) {
        return null;
      }
      cut = decoded.$1;
      position = scalePosition(shown[index], decoded.$2);
    }
    if (cut == null) {
      return null;
    }
    return _straightenCode(
      cut,
      position,
      linear: barcodes[index].format.isLinear,
      mirrored: _mirrored,
    );
  }
}

/// The code at [position] in [cut], straightened (see
/// [BarcodeCapture.snapshot]).
GrayImage? _straightenCode(
  FrameCut cut,
  BarcodePosition position, {
  required bool linear,
  required bool mirrored,
}) {
  List<Offset> corners = snapshotCorners(
    position,
    linear: linear,
    mirrored: mirrored,
  );
  if (linear) {
    corners = fitBarHeight(cut, alignToBars(cut, corners, mirrored: mirrored));
  }
  return straighten(cut, corners);
}

/// The code at the position in the cut of [job], straightened, then
/// sharpened, and how sharp it was before.
(GrayImage, double)? _sharpenedCode(
  (FrameCut, BarcodePosition, {bool linear, bool mirrored}) job,
) {
  final GrayImage? gray = _straightenCode(
    job.$1,
    job.$2,
    linear: job.linear,
    mirrored: job.mirrored,
  );
  return gray == null ? null : (unsharpMask(gray), sharpness(gray));
}

/// The longest side of a photo decoded to show on screen.
const int _photoSide = 2048;

/// For the scanner's templates. Not exported.
extension BarcodeCapturePhoto on BarcodeCapture {
  /// The pixels of [BarcodeCapture.snapshot] of [barcode], before they
  /// become an image: for the scanner's window, which scores and sharpens
  /// them.
  Future<GrayImage?> straightened([Barcode? barcode]) => _straightened(barcode);

  /// [straightened] of the first barcode of a camera capture, lightly
  /// sharpened ([unsharpMask]), and how sharp it was before
  /// ([sharpness]): worked out on another isolate, as the window compares
  /// several frames while its picture flies. `null` for a photo.
  Future<(GrayImage, double)?> sharpenedApart() async {
    final FrameCut? cut = _cut;
    final List<BarcodePosition>? positions = _positions;
    if (cut == null || positions == null) {
      return null;
    }
    return compute(_sharpenedCode, (
      cut,
      positions.first,
      linear: barcode.format.isLinear,
      mirrored: _mirrored,
    ));
  }

  /// The photo given to [ScannerController.readImage], turned the way it
  /// shows, and the corners of each of [BarcodeCapture.barcodes] in its
  /// pixels. The caller disposes the image. `null` for a capture of the
  /// camera, or when the photo cannot be shown the way the reader saw it.
  Future<(ui.Image, List<List<Offset>>)?> decodePhoto() async {
    final Uint8List? encoded = _encoded;
    final List<BarcodePosition>? positions = _positions;
    if (encoded == null || positions == null) {
      return null;
    }
    final ui.Image image;
    try {
      final ui.Codec codec = await ui.instantiateImageCodecWithSize(
        await ui.ImmutableBuffer.fromUint8List(encoded),
        getTargetSize: (int width, int height) {
          final double scale = math.min(
            1,
            _photoSide / math.max(width, height),
          );
          return ui.TargetImageSize(
            width: (width * scale).round(),
            height: (height * scale).round(),
          );
        },
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      image = frame.image;
    } on Object {
      return null;
    }
    final int orientation = exifOrientation(encoded);
    final Size shown = orientedSize(imageSize, orientation);
    if ((image.width / image.height - shown.width / shown.height).abs() >
        0.02) {
      image.dispose();
      return null;
    }
    final double scale = image.width / shown.width;
    return (
      image,
      <List<Offset>>[
        for (final BarcodePosition p in positions)
          <Offset>[
            for (final Offset c in p.corners)
              orientedPoint(c, imageSize, orientation) * scale,
          ],
      ],
    );
  }
}

/// Where the barcodes of a [BarcodeCapture] came from.
enum CaptureSource {
  /// A camera frame.
  camera,

  /// An image given to [ScannerController.readImage].
  image,
}
