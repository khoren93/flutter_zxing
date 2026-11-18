// How much CPU the app uses, for the developer numbers: the process's user
// and system time from getrusage(2), and on iOS and macOS each thread's from
// the Mach kernel (task_threads, thread_info). Native platforms; the web
// gets cpu_usage_stub.dart.
import 'dart:ffi';
import 'dart:io';

typedef _GetRusage = Int32 Function(Int32 who, Pointer<Uint8> usage);
typedef _GetRusageDart = int Function(int who, Pointer<Uint8> usage);

/// Measures the app's CPU use between calls to [sample].
final class CpuMeter {
  CpuMeter() {
    try {
      final DynamicLibrary libc = DynamicLibrary.process();
      _getrusage = libc.lookupFunction<_GetRusage, _GetRusageDart>('getrusage');
      // One struct rusage for every sample: kept as long as the app runs.
      _usage = libc
          .lookupFunction<
            Pointer<Uint8> Function(IntPtr),
            Pointer<Uint8> Function(int)
          >('malloc')(144);
    } on Object {
      _getrusage = null; // no libc symbol here (the web)
    }
    if (Platform.isIOS || Platform.isMacOS) {
      _threads = _MachThreads.load();
    }
  }

  _MachThreads? _threads;
  Map<int, (String, int)> _lastThreads = <int, (String, int)>{};
  int _lastThreadsWall = 0;

  /// Each thread's CPU time since the previous call, by thread name (threads
  /// without one together as "unnamed"), as a share of one core, busiest
  /// first. iOS and macOS only; `null` on the first call and elsewhere.
  List<(String, double)>? sampleThreads() {
    final _MachThreads? threads = _threads;
    if (threads == null) {
      return null;
    }
    final Map<int, (String, int)> now = threads.read();
    final int wall = _wall.elapsedMicroseconds;
    final Map<int, (String, int)> last = _lastThreads;
    final int span = wall - _lastThreadsWall;
    _lastThreads = now;
    _lastThreadsWall = wall;
    if (last.isEmpty || span <= 0) {
      return null;
    }
    final Map<String, int> byName = <String, int>{};
    for (final MapEntry<int, (String, int)> e in now.entries) {
      final (String name, int micros) = e.value;
      final int before = last[e.key]?.$2 ?? 0;
      byName[name] = (byName[name] ?? 0) + (micros - before);
    }
    return <(String, double)>[
      for (final MapEntry<String, int> e in byName.entries)
        if (e.value > 0) (e.key, e.value / span * 100),
    ]..sort(((String, double) a, (String, double) b) => b.$2.compareTo(a.$2));
  }

  _GetRusageDart? _getrusage;
  Pointer<Uint8> _usage = nullptr;
  final Stopwatch _wall = Stopwatch()..start();
  int? _lastCpuMicros;
  int _lastWallMicros = 0;

  /// The logical cores of the device.
  static int get cores => Platform.numberOfProcessors;

  /// The memory the process occupies, in bytes.
  static int? get residentBytes => ProcessInfo.currentRss;

  /// CPU time since the previous call, as a share of one core (100 = one
  /// core busy the whole time; up to [cores] × 100). `null` on the first
  /// call and where it cannot be measured.
  double? sample() {
    final int? cpu = _cpuMicros();
    final int wall = _wall.elapsedMicroseconds;
    final int? last = _lastCpuMicros;
    final int lastWall = _lastWallMicros;
    _lastCpuMicros = cpu;
    _lastWallMicros = wall;
    if (cpu == null || last == null || wall <= lastWall) {
      return null;
    }
    return (cpu - last) / (wall - lastWall) * 100;
  }

  /// User plus system CPU time of the process, in microseconds.
  int? _cpuMicros() {
    final _GetRusageDart? getrusage = _getrusage;
    // struct rusage: ru_utime and ru_stime first, each a timeval of a 64-bit
    // tv_sec and the microseconds right after (16 bytes on 64-bit Darwin and
    // Linux), then 14 longs: 144 bytes. 0 is RUSAGE_SELF.
    if (getrusage == null || _usage == nullptr || getrusage(0, _usage) != 0) {
      return null;
    }
    final _Rusage data = _Rusage(_usage);
    return data.time(0) + data.time(16);
  }
}

/// Reads timevals out of a struct rusage.
extension type _Rusage(Pointer<Uint8> _p) {
  int time(int offset) {
    final int seconds = (_p + offset).cast<Int64>().value;
    final int micros = (_p + offset + 8).cast<Int32>().value;
    return seconds * 1000000 + micros;
  }
}

/// The threads of this process, from the Mach kernel.
final class _MachThreads {
  _MachThreads._(DynamicLibrary lib)
    : _task = lib.lookup<Uint32>('mach_task_self_').value,
      _taskThreads = lib
          .lookupFunction<
            Int32 Function(Uint32, Pointer<Pointer<Uint32>>, Pointer<Uint32>),
            int Function(int, Pointer<Pointer<Uint32>>, Pointer<Uint32>)
          >('task_threads'),
      _threadInfo = lib
          .lookupFunction<
            Int32 Function(Uint32, Int32, Pointer<Int32>, Pointer<Uint32>),
            int Function(int, int, Pointer<Int32>, Pointer<Uint32>)
          >('thread_info'),
      _portDeallocate = lib
          .lookupFunction<
            Int32 Function(Uint32, Uint32),
            int Function(int, int)
          >('mach_port_deallocate'),
      _vmDeallocate = lib
          .lookupFunction<
            Int32 Function(Uint32, UintPtr, UintPtr),
            int Function(int, int, int)
          >('vm_deallocate'),
      _fromMachThread = lib
          .lookupFunction<
            Pointer<Void> Function(Uint32),
            Pointer<Void> Function(int)
          >('pthread_from_mach_thread_np'),
      _getName = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, IntPtr),
            int Function(Pointer<Void>, Pointer<Uint8>, int)
          >('pthread_getname_np'),
      // Scratch memory for every read, kept as long as the app runs: the
      // thread list pointer and count, thread_basic_info (10 ints) and its
      // count, a name.
      _scratch = lib
          .lookupFunction<
            Pointer<Uint8> Function(IntPtr),
            Pointer<Uint8> Function(int)
          >('malloc')(256);

  static _MachThreads? load() {
    try {
      return _MachThreads._(DynamicLibrary.process());
    } on Object {
      return null;
    }
  }

  final int _task;
  final int Function(int, Pointer<Pointer<Uint32>>, Pointer<Uint32>)
  _taskThreads;
  final int Function(int, int, Pointer<Int32>, Pointer<Uint32>) _threadInfo;
  final int Function(int, int) _portDeallocate;
  final int Function(int, int, int) _vmDeallocate;
  final Pointer<Void> Function(int) _fromMachThread;
  final int Function(Pointer<Void>, Pointer<Uint8>, int) _getName;
  final Pointer<Uint8> _scratch;

  static const int _threadBasicInfo = 3; // THREAD_BASIC_INFO
  static const int _threadBasicInfoCount = 10;
  static const int _nameSize = 64;

  /// Each thread's port, name and user plus system CPU time (µs).
  Map<int, (String, int)> read() {
    final Pointer<Pointer<Uint32>> list = _scratch.cast();
    final Pointer<Uint32> count = (_scratch + 8).cast();
    final Pointer<Int32> info = (_scratch + 16).cast();
    final Pointer<Uint32> infoCount = (_scratch + 64).cast();
    final Pointer<Uint8> name = _scratch + 128;
    final Map<int, (String, int)> threads = <int, (String, int)>{};
    if (_taskThreads(_task, list, count) != 0) {
      return threads;
    }
    final Pointer<Uint32> ports = list.value;
    final int n = count.value;
    for (int i = 0; i < n; i++) {
      final int port = ports[i];
      infoCount.value = _threadBasicInfoCount;
      if (_threadInfo(port, _threadBasicInfo, info, infoCount) == 0) {
        // user_time and system_time: seconds and microseconds each.
        final int micros = (info[0] + info[2]) * 1000000 + info[1] + info[3];
        String label = '';
        final Pointer<Void> thread = _fromMachThread(port);
        if (thread != nullptr && _getName(thread, name, _nameSize) == 0) {
          label = _cString(name);
        }
        threads[port] = (label.isEmpty ? 'unnamed' : label, micros);
      }
      _portDeallocate(_task, port);
    }
    _vmDeallocate(_task, ports.address, n * 4);
    return threads;
  }

  static String _cString(Pointer<Uint8> chars) {
    final List<int> bytes = <int>[];
    for (int i = 0; i < _nameSize; i++) {
      final int b = chars[i];
      if (b == 0) {
        break;
      }
      bytes.add(b);
    }
    return String.fromCharCodes(bytes);
  }
}
