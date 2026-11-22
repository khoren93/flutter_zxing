// The web has no getrusage: no CPU numbers.

/// Measures nothing.
final class CpuMeter {
  /// Unknown.
  static int get cores => 0;

  /// Unknown.
  static int? get residentBytes => null;

  /// Unknown.
  static int? get thermalState => null;

  /// Unknown.
  static RusageCounters? get counters => null;

  /// Always `null`.
  int? get processMicros => null;

  /// Always `null`.
  double? sample() => null;

  /// Always `null`.
  List<(String, double)>? sampleThreads() => null;
}

/// Counters of the whole process since it started (none on the web).
typedef RusageCounters = ({
  int userNs,
  int systemNs,
  int userPNs,
  int systemPNs,
  int instructions,
  int cycles,
  int pInstructions,
  int pCycles,
  int energyNj,
  int pEnergyNj,
  int billedEnergy,
});
