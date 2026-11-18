// Keeps the last seconds of the camera while it is armed, and the recordings
// saved from them on the device.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:path_provider/path_provider.dart';
// The frames are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

import 'diag_runs.dart' show diagBuild, diagDevice;
import 'diag_settings.dart';
import 'recording.dart';

/// The last seconds of the decoded frames.
final class FrameRecorder extends ChangeNotifier {
  /// The most memory the frames may take.
  static const int maxBytes = 400 * 1024 * 1024;

  final List<RecordedFrame> _frames = <RecordedFrame>[];
  final Stopwatch _clock = Stopwatch()..start();
  StreamSubscription<ScannerFrameSample>? _subscription;
  ScannerController? _controller;
  int _bytes = 0;
  bool _armed = false;
  int _keepSeconds = 5;

  /// Frames kept now.
  int get frameCount => _frames.length;

  /// Memory they take.
  int get bytes => _bytes;

  /// Seconds of frames to keep.
  int get keepSeconds => _keepSeconds;
  set keepSeconds(int value) {
    _keepSeconds = value;
    notifyListeners();
  }

  /// Whether frames are being kept. Copying them costs a little time on
  /// every frame, so it is off unless asked for.
  bool get armed => _armed;
  set armed(bool value) {
    _armed = value;
    if (!value) {
      _clear();
    }
    notifyListeners();
  }

  /// Follows [controller] from now on.
  void attach(ScannerController controller) {
    unawaited(_subscription?.cancel());
    _controller = controller;
    _clear();
    _subscription = controller.frameSamples.listen(_onSample);
  }

  void _clear() {
    _frames.clear();
    _bytes = 0;
  }

  void _onSample(ScannerFrameSample sample) {
    final ScannerController? controller = _controller;
    final (PixelBuffer, Rect?)? last = controller?.lastFrame;
    if (!_armed || controller == null || last == null) {
      return;
    }
    final (PixelBuffer image, Rect? crop) = last;
    final Uint8List pixels = lumaOf(image, crop);
    _frames.add(
      RecordedFrame(
        width: (crop?.width ?? image.width.toDouble()).toInt(),
        height: (crop?.height ?? image.height.toDouble()).toInt(),
        pixels: pixels,
        atMicros: _clock.elapsedMicroseconds,
        engineMicros: sample.engineMicros,
        mirrored: controller.lastFrameMirrored,
        reads: sample.reads.map(RecordedRead.of).toList(),
      ),
    );
    _bytes += pixels.length;
    final int oldest = _clock.elapsedMicroseconds - _keepSeconds * 1000000;
    while (_frames.length > 1 &&
        (_frames.first.atMicros < oldest || _bytes > maxBytes)) {
      _bytes -= _frames.removeAt(0).pixels.length;
    }
    if (_frames.length.isEven) {
      notifyListeners();
    }
  }

  /// The frames kept now, read with [settings]; `null` without frames.
  Recording? take(DiagSettings settings) {
    if (_frames.isEmpty) {
      return null;
    }
    final String name = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return Recording(
      name: name,
      device: diagDevice,
      build: diagBuild,
      engine: zxingCppVersion,
      settings: settings.toJson(),
      frames: List<RecordedFrame>.of(_frames),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

/// A recording on the device.
@immutable
final class RecordingFile {
  /// Creates the entry.
  const RecordingFile(this.file, this.frames, this.size, this.device);

  final File file;
  final int frames;
  final int size;
  final String device;

  /// The name of the recording.
  String get name => file.uri.pathSegments.last.replaceAll('.fzxrec', '');
}

/// The recordings in the app's documents, in `recordings/`: `make diag-pull`
/// copies them from there.
final class RecordingStore extends ChangeNotifier {
  /// The recordings, newest first.
  List<RecordingFile> files = <RecordingFile>[];

  Future<Directory> _directory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/recordings').create(recursive: true);
  }

  /// Lists the recordings.
  Future<void> load() async {
    final List<File> found =
        (await _directory())
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.fzxrec'))
            .toList()
          ..sort((File a, File b) => b.path.compareTo(a.path));
    files = <RecordingFile>[for (final File f in found) await _describe(f)];
    notifyListeners();
  }

  Future<RecordingFile> _describe(File file) async {
    final RandomAccessFile raf = await file.open();
    try {
      final int length = Recording.headerLength(
        await raf.read(Recording.prefixLength),
      );
      final Map<String, dynamic> header = Recording.decodeHeader(
        await raf.read(length),
      );
      return RecordingFile(
        file,
        (header['frames'] as List<Object?>).length,
        await file.length(),
        header['device'] as String,
      );
    } finally {
      await raf.close();
    }
  }

  /// Writes [recording] to a file.
  Future<void> save(Recording recording) async {
    final Directory dir = await _directory();
    final IOSink sink = File(
      '${dir.path}/${recording.name}.fzxrec',
    ).openWrite();
    recording.encode().forEach(sink.add);
    await sink.close();
    await load();
  }

  /// Reads a recording back.
  Future<Recording> open(RecordingFile file) async =>
      Recording.decode(await file.file.readAsBytes());

  /// Deletes a recording.
  Future<void> remove(RecordingFile file) async {
    await file.file.delete();
    await load();
  }
}
