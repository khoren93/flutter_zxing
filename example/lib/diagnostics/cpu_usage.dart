// How much CPU the app uses, for the developer numbers: the process's user
// and system time from getrusage(2), and on iOS and macOS each thread's from
// the Mach kernel (task_threads, thread_info). Native platforms; the web
// gets cpu_usage_stub.dart.
import 'dart:ffi';
import 'dart:io';

typedef _GetRusage = Int32 Function(Int32 who, Pointer<Uint8> usage);
typedef _GetRusageDart = int Function(int who, Pointer<Uint8> usage);

/// Measures the app's CPU use between calls to [sample].
///
/// One meter for the app: its native buffers are never freed.
final class CpuMeter {
  /// The app's meter.
  factory CpuMeter() => _instance;

  CpuMeter._() {
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
    } else if (Platform.isAndroid || Platform.isLinux) {
      _threads = _ProcThreads();
    }
  }

  static final CpuMeter _instance = CpuMeter._();

  _ThreadReader? _threads;
  Map<int, (String, int)> _lastThreads = <int, (String, int)>{};
  int _lastThreadsWall = 0;

  /// Each thread's CPU time since the previous call, by thread name (the
  /// main thread as "main", the other threads without a name together as
  /// "unnamed"), as a share of one core, busiest
  /// first. iOS, macOS, Android and Linux; `null` on the first call and
  /// elsewhere.
  List<(String, double)>? sampleThreads() {
    final _ThreadReader? threads = _threads;
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

  /// The process's counters from proc_pid_rusage(RUSAGE_INFO_V6), iOS and
  /// macOS: work and energy that do not depend on which cores ran it or at
  /// what clock. `null` elsewhere or where the kernel is older.
  static RusageCounters? get counters => _rusage?.read();

  static final _Rusage6? _rusage = (Platform.isIOS || Platform.isMacOS)
      ? _Rusage6.load()
      : null;

  /// How hot the device is: 0 nominal, 1 fair, 2 serious, 3 critical
  /// (NSProcessInfo.thermalState). iOS and macOS; `null` elsewhere.
  static int? get thermalState => _thermal?.call();

  static final int? Function()? _thermal = _thermalReader();

  static int? Function()? _thermalReader() {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return null;
    }
    try {
      final DynamicLibrary lib = DynamicLibrary.process();
      final Pointer<Uint8> Function(int) malloc = lib
          .lookupFunction<
            Pointer<Uint8> Function(IntPtr),
            Pointer<Uint8> Function(int)
          >('malloc');
      Pointer<Uint8> cString(String s) {
        final Pointer<Uint8> p = malloc(s.length + 1);
        for (int i = 0; i < s.length; i++) {
          p[i] = s.codeUnitAt(i);
        }
        p[s.length] = 0;
        return p;
      }

      final Pointer<Void> Function(Pointer<Uint8>) getClass = lib
          .lookupFunction<
            Pointer<Void> Function(Pointer<Uint8>),
            Pointer<Void> Function(Pointer<Uint8>)
          >('objc_getClass');
      final Pointer<Void> Function(Pointer<Uint8>) selector = lib
          .lookupFunction<
            Pointer<Void> Function(Pointer<Uint8>),
            Pointer<Void> Function(Pointer<Uint8>)
          >('sel_registerName');
      final Pointer<Void> send = lib.lookup<Void>('objc_msgSend');
      final Pointer<Void> Function(Pointer<Void>, Pointer<Void>)
      sendObject = send
          .cast<
            NativeFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>
          >()
          .asFunction();
      final int Function(Pointer<Void>, Pointer<Void>) sendInt = send
          .cast<NativeFunction<IntPtr Function(Pointer<Void>, Pointer<Void>)>>()
          .asFunction();
      // Looked up once, kept as long as the app runs.
      final Pointer<Void> info = sendObject(
        getClass(cString('NSProcessInfo')),
        selector(cString('processInfo')),
      );
      final Pointer<Void> thermal = selector(cString('thermalState'));
      return () => sendInt(info, thermal);
    } on Object {
      return null;
    }
  }

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

  /// User plus system CPU time of the process so far, in microseconds.
  int? get processMicros => _cpuMicros();

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

/// Each thread of the process: its id, name and user plus system CPU time
/// in microseconds.
abstract interface class _ThreadReader {
  Map<int, (String, int)> read();
}

/// The threads of this process from /proc (Android, Linux): the main thread
/// (whose id is the process's) as "main".
final class _ProcThreads implements _ThreadReader {
  /// Clock ticks per second of /proc times (USER_HZ): 100 on Android and
  /// Linux.
  static const int _hz = 100;

  @override
  Map<int, (String, int)> read() {
    final Map<int, (String, int)> threads = <int, (String, int)>{};
    final List<FileSystemEntity> tasks;
    try {
      tasks = Directory('/proc/self/task').listSync();
    } on FileSystemException {
      return threads;
    }
    final int self = pid;
    for (final FileSystemEntity task in tasks) {
      final int? tid = int.tryParse(
        task.uri.pathSegments.lastWhere((String s) => s.isNotEmpty),
      );
      if (tid == null) {
        continue;
      }
      try {
        // "tid (name) state ppid ...": the name may hold spaces and
        // parentheses, so the fields are counted after the last ')'.
        final String stat = File('${task.path}/stat').readAsStringSync();
        final int open = stat.indexOf('(');
        final int close = stat.lastIndexOf(')');
        final List<String> f = stat.substring(close + 2).split(' ');
        // utime and stime are fields 14 and 15, here 11 and 12 (from 0
        // after the state, field 3).
        final int ticks = int.parse(f[11]) + int.parse(f[12]);
        final String name = tid == self
            ? 'main'
            : stat.substring(open + 1, close);
        threads[tid] = (name, ticks * 1000000 ~/ _hz);
      } on Object {
        // The thread ended meanwhile.
      }
    }
    return threads;
  }
}

/// The threads of this process, from the Mach kernel.
final class _MachThreads implements _ThreadReader {
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
      _mainThread = _lookupMain(lib),
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

  /// The main thread's pthread (Darwin's pthread_main_thread_np), `null`
  /// if the symbol is missing.
  static Pointer<Void>? _lookupMain(DynamicLibrary lib) {
    try {
      return lib
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'pthread_main_thread_np',
          )();
    } on Object {
      return null;
    }
  }

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
  final Pointer<Void>? _mainThread;
  final int Function(Pointer<Void>, Pointer<Uint8>, int) _getName;
  final Pointer<Uint8> _scratch;

  static const int _threadBasicInfo = 3; // THREAD_BASIC_INFO
  static const int _threadBasicInfoCount = 10;
  static const int _nameSize = 64;

  /// Each thread's port, name and user plus system CPU time (µs).
  @override
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
        if (thread != nullptr && thread == _mainThread) {
          label = 'main';
        } else if (thread != nullptr &&
            _getName(thread, name, _nameSize) == 0) {
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

/// Counters of the whole process since it started.
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

/// proc_pid_rusage with RUSAGE_INFO_V6 (macOS 13, iOS 16 and later).
final class _Rusage6 {
  _Rusage6._(this._call, this._pid, this._buffer, this._nsPerTick);

  static _Rusage6? load() {
    try {
      final DynamicLibrary lib = DynamicLibrary.process();
      final int Function(int, int, Pointer<Uint8>) call = lib
          .lookupFunction<
            Int32 Function(Int32, Int32, Pointer<Uint8>),
            int Function(int, int, Pointer<Uint8>)
          >('proc_pid_rusage');
      final int pid = lib.lookupFunction<Int32 Function(), int Function()>(
        'getpid',
      )();
      // Kept as long as the app runs.
      final Pointer<Uint8> buffer = lib
          .lookupFunction<
            Pointer<Uint8> Function(IntPtr),
            Pointer<Uint8> Function(int)
          >('malloc')(1024);
      // The times count Mach ticks (24 MHz on Apple silicon).
      lib.lookupFunction<
        Int32 Function(Pointer<Uint32>),
        int Function(Pointer<Uint32>)
      >('mach_timebase_info')(buffer.cast());
      final double nsPerTick =
          buffer.cast<Uint32>()[0] / buffer.cast<Uint32>()[1];
      final _Rusage6 r = _Rusage6._(call, pid, buffer, nsPerTick);
      return r.read() == null ? null : r;
    } on Object {
      return null;
    }
  }

  final int Function(int, int, Pointer<Uint8>) _call;
  final int _pid;
  final Pointer<Uint8> _buffer;
  final double _nsPerTick;

  int _ns(int offset) => (_u64(offset) * _nsPerTick).round();

  int _u64(int offset) => (_buffer + offset).cast<Uint64>().value;

  RusageCounters? read() {
    if (_call(_pid, 6, _buffer) != 0) {
      return null;
    }
    // struct rusage_info_v6, <sys/resource.h>.
    return (
      userNs: _ns(16),
      systemNs: _ns(24),
      userPNs: _ns(304),
      systemPNs: _ns(312),
      instructions: _u64(248),
      cycles: _u64(256),
      pInstructions: _u64(320),
      pCycles: _u64(328),
      energyNj: _u64(336),
      pEnergyNj: _u64(344),
      billedEnergy: _u64(264),
    );
  }
}
