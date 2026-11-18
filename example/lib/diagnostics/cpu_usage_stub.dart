// The web has no getrusage: no CPU numbers.

/// Measures nothing.
final class CpuMeter {
  /// Unknown.
  static int get cores => 0;

  /// Unknown.
  static int? get residentBytes => null;

  /// Always `null`.
  double? sample() => null;

  /// Always `null`.
  List<(String, double)>? sampleThreads() => null;
}
