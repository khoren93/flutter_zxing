// The fixed parts of a read QR code, drawn again from the specification.
// Not exported from the package.
import 'dart:typed_data';

import '../barcode/barcode_format.dart';

/// [modules] of a [size] × [size] QR code with its function patterns (the
/// finders and their separators, the timing lines, the alignment patterns
/// and the dark module) set as ISO/IEC 18004 places them.
///
/// The reader samples every module at its centre. A code printed with
/// rounded or circular finders is white there in the corners of the finder
/// rings: it still decodes, as the reader finds the finders by their shape,
/// but the sampled grid has holes where the code has none. These modules
/// never carry data, so drawing them again gives the code as written.
///
/// Returns [modules] unchanged for other formats, sizes that are no QR
/// version, or a grid whose finders do not look like finders.
Uint8List withQrFunctionPatterns(
  BarcodeFormat format,
  int width,
  int height,
  Uint8List modules,
) {
  if (format != BarcodeFormat.qrCode && format != BarcodeFormat.qrCodeModel2) {
    return modules;
  }
  final int size = width;
  if (width != height ||
      size < 21 ||
      size > 177 ||
      (size - 17) % 4 != 0 ||
      modules.length != size * size) {
    return modules;
  }
  final int version = (size - 17) ~/ 4;
  final Map<int, bool> fixed = <int, bool>{};
  void set(int x, int y, bool dark) => fixed[y * size + x] = dark;

  // Finders with their white separators.
  const List<(int, int)> unit = <(int, int)>[(0, 0), (1, 0), (0, 1)];
  int finderCells = 0;
  int finderMatches = 0;
  for (final (int ux, int uy) in unit) {
    final int fx = ux * (size - 7);
    final int fy = uy * (size - 7);
    for (int dy = -1; dy <= 7; dy++) {
      for (int dx = -1; dx <= 7; dx++) {
        final int x = fx + dx;
        final int y = fy + dy;
        if (x < 0 || y < 0 || x >= size || y >= size) {
          continue;
        }
        final int ring = _ring(dx - 3, dy - 3);
        final bool dark = ring != 2 && ring != 4;
        if (ring < 4) {
          finderCells++;
          if ((modules[y * size + x] != 0) == dark) {
            finderMatches++;
          }
        }
        set(x, y, dark);
      }
    }
  }
  // Rounded rings lose their corners, circles about a third of their
  // modules; random modules match half the time. Dark centres and well
  // over half matching: the finders are where the grid claims they are.
  final bool centresDark = unit.every(
    ((int, int) u) =>
        modules[(u.$2 * (size - 7) + 3) * size + u.$1 * (size - 7) + 3] != 0,
  );
  if (!centresDark || finderMatches < finderCells * 0.6) {
    return modules;
  }

  // Timing lines.
  for (int i = 8; i < size - 8; i++) {
    set(i, 6, i.isEven);
    set(6, i, i.isEven);
  }

  // Alignment patterns, except where they would overlap a finder.
  final List<int> centres = _alignmentCentres(version, size);
  for (final int cy in centres) {
    for (final int cx in centres) {
      final bool onFinder =
          (cx == 6 && cy == 6) ||
          (cx == 6 && cy == size - 7) ||
          (cx == size - 7 && cy == 6);
      if (onFinder) {
        continue;
      }
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          set(cx + dx, cy + dy, _ring(dx, dy) != 1);
        }
      }
    }
  }

  // The dark module beside the bottom-left finder.
  set(8, size - 8, true);

  final Uint8List out = Uint8List.fromList(modules);
  fixed.forEach((int i, bool dark) => out[i] = dark ? 1 : 0);
  return out;
}

/// Chebyshev distance of (dx, dy) from a pattern's centre.
int _ring(int dx, int dy) {
  final int ax = dx.abs();
  final int ay = dy.abs();
  return ax > ay ? ax : ay;
}

/// Row and column coordinates of the alignment pattern centres of a QR
/// code [version] (ISO/IEC 18004 Annex E).
List<int> _alignmentCentres(int version, int size) {
  if (version < 2) {
    return const <int>[];
  }
  final int count = version ~/ 7 + 2;
  final int last = size - 7;
  // The spacing is even and, but for version 32, rounded up from an equal
  // split; the first centre takes what is left.
  final int step = version == 32
      ? 26
      : ((last - 6) / (count - 1) / 2).ceil() * 2;
  return <int>[6, for (int i = count - 2; i >= 0; i--) last - i * step];
}
