// The web has no getrusage: no CPU numbers.

/// Measures nothing.
final class CpuMeter {
  /// Unknown.
  static int get cores => 0;

  /// Always `null`.
  double? sample() => null;

  /// Always `null`.
  List<(String, double)>? sampleThreads() => null;
}
