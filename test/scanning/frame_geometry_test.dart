import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';

Matcher _near(Offset expected) => predicate<Offset>(
  (Offset o) => (o - expected).distance < 1e-9,
  'is $expected',
);

void main() {
  group('FrameTransform', () {
    const Size frame = Size(640, 480);

    test('round-trips every rotation, mirrored or not', () {
      const List<Offset> points = <Offset>[
        Offset.zero,
        Offset(640, 480),
        Offset(100, 30),
        Offset(639, 1),
      ];
      for (final int rotation in <int>[0, 90, 180, 270]) {
        for (final bool mirrored in <bool>[false, true]) {
          final FrameTransform t = FrameTransform(
            frame,
            rotation: rotation,
            mirrored: mirrored,
          );
          for (final Offset p in points) {
            expect(t.toFrame(t.toDisplay(p)), _near(p), reason: '$t $p');
          }
        }
      }
    });

    test('turns the frame clockwise', () {
      const FrameTransform t = FrameTransform(frame, rotation: 90);
      expect(t.displaySize, const Size(480, 640));
      // The frame's top-left corner ends up top-right.
      expect(t.toDisplay(Offset.zero), _near(const Offset(480, 0)));
      expect(t.toDisplay(const Offset(640, 0)), _near(const Offset(480, 640)));
      expect(
        const FrameTransform(frame, rotation: 180).toDisplay(Offset.zero),
        _near(const Offset(640, 480)),
      );
      expect(
        const FrameTransform(frame, rotation: 270).toDisplay(Offset.zero),
        _near(const Offset(0, 640)),
      );
    });

    test('mirrors after rotating', () {
      const FrameTransform t = FrameTransform(
        frame,
        rotation: 90,
        mirrored: true,
      );
      expect(t.toDisplay(Offset.zero), _near(Offset.zero));
      expect(
        const FrameTransform(frame, mirrored: true).toDisplay(Offset.zero),
        _near(const Offset(640, 0)),
      );
    });

    test('maps a display rectangle back into the frame', () {
      const FrameTransform t = FrameTransform(frame, rotation: 90);
      // The top-left quarter of the display is the bottom-left of the frame.
      expect(
        t.rectToFrame(const Rect.fromLTWH(0, 0, 240, 320)),
        const Rect.fromLTWH(0, 240, 320, 240),
      );
    });

    test('moves the barcode corners and keeps the rest', () {
      final Barcode barcode = Barcode(
        format: BarcodeFormat.qrCode,
        text: 'x',
        bytes: Uint8List.fromList(<int>[120]),
        position: const BarcodePosition(
          topLeft: Offset(10, 10),
          topRight: Offset(20, 10),
          bottomRight: Offset(20, 20),
          bottomLeft: Offset(10, 20),
        ),
        ecLevel: 'M',
      );
      final Barcode moved = const FrameTransform(
        frame,
        rotation: 90,
      ).barcodeToDisplay(barcode);
      expect(moved.text, 'x');
      expect(moved.ecLevel, 'M');
      expect(moved.position.topLeft, _near(const Offset(470, 10)));
      expect(moved.position.bottomLeft, _near(const Offset(460, 10)));
    });
  });

  group('PreviewFit', () {
    test('cover crops the frame and fills the widget', () {
      final PreviewFit fit = PreviewFit(
        const Size(720, 1280),
        const Size(400, 800),
        BoxFit.cover,
      );
      expect(fit.target, const Rect.fromLTWH(0, 0, 400, 800));
      expect(fit.source, const Rect.fromLTWH(40, 0, 640, 1280));
      expect(fit.toView(const Offset(40, 0)), _near(Offset.zero));
      expect(
        fit.toFrame(const Offset(200, 400)),
        _near(const Offset(360, 640)),
      );
      expect(
        fit.rectToFrame(const Rect.fromLTWH(0, 0, 400, 800)),
        const Rect.fromLTWH(40, 0, 640, 1280),
      );
    });

    test('contain letterboxes; only the frame part of a rectangle counts', () {
      final PreviewFit fit = PreviewFit(
        const Size(1280, 720),
        const Size(400, 400),
        BoxFit.contain,
      );
      expect(fit.target.top, closeTo(87.5, 1e-9));
      final Rect window = fit.rectToFrame(const Rect.fromLTWH(0, 0, 400, 400))!;
      expect(window.top, closeTo(0, 1e-9));
      expect(window.bottom, closeTo(720, 1e-9));
      expect(fit.rectToFrame(const Rect.fromLTWH(0, 0, 400, 50)), isNull);
    });
  });

  test('pixelCrop rounds outwards and clamps', () {
    expect(
      pixelCrop(const Rect.fromLTRB(-3.5, 10.2, 99.1, 500), const Size(80, 60)),
      const Rect.fromLTRB(0, 10, 80, 60),
    );
    expect(
      pixelCrop(const Rect.fromLTRB(90, 0, 120, 10), const Size(80, 60)),
      isNull,
    );
  });

  group('orientation', () {
    test('Android frames turn as the camera plugin turns its preview', () {
      // The rotations flutter_zxing 3.x found by hand for a back camera
      // with the usual 90 degree sensor.
      for (final (DeviceOrientation ui, int rotation)
          in <(DeviceOrientation, int)>[
            (DeviceOrientation.portraitUp, 90),
            (DeviceOrientation.landscapeLeft, 0),
            (DeviceOrientation.portraitDown, 270),
            (DeviceOrientation.landscapeRight, 180),
          ]) {
        expect(
          androidFrameRotation(sensorOrientation: 90, ui: ui, front: false),
          rotation,
          reason: ui.name,
        );
      }
      expect(
        androidFrameRotation(
          sensorOrientation: 270,
          ui: DeviceOrientation.portraitUp,
          front: true,
        ),
        270,
      );
    });

    test('iOS frames are turned only when iOS did not turn them', () {
      const Size portrait = Size(720, 1280);
      const Size landscape = Size(1280, 720);
      expect(iosFrameRotation(portrait, DeviceOrientation.portraitUp), 0);
      expect(iosFrameRotation(landscape, DeviceOrientation.landscapeLeft), 0);
      // The front camera of an iPhone 17 Pro Max turns the wrong way:
      // landscape frames in portrait, portrait ones in landscape.
      expect(iosFrameRotation(landscape, DeviceOrientation.portraitUp), 90);
      expect(iosFrameRotation(landscape, DeviceOrientation.portraitDown), 90);
      expect(iosFrameRotation(portrait, DeviceOrientation.landscapeRight), 270);
      expect(iosFrameRotation(portrait, DeviceOrientation.landscapeLeft), 270);
    });

    test('the UI follows the device unless it is locked', () {
      expect(
        uiOrientation(DeviceOrientation.landscapeLeft, Orientation.landscape),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        uiOrientation(DeviceOrientation.landscapeLeft, Orientation.portrait),
        DeviceOrientation.portraitUp,
      );
      expect(
        uiOrientation(DeviceOrientation.portraitUp, Orientation.landscape),
        DeviceOrientation.landscapeRight,
      );
      for (final DeviceOrientation o in DeviceOrientation.values) {
        expect(orientationOfDegrees(orientationDegrees(o)), o);
      }
    });
  });
}
