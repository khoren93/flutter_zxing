#!/usr/bin/env python3
"""The scanner's load on a phone, against the budgets: `make perf DEVICE=<id>`.

Runs the diagnostics page in a profile build with its per-second log, walks
the load ladder through the VM service in two scenes (A: no code in view,
B: a code in the scan window), measures the paused scanner, and prints each
number with its budget. Budgets are known for the phones they were set on
(iPhone 17 Pro Max, Pixel 4a); other phones get the numbers only.

  python3 tool/perf_run.py DEVICE [SCENES]     SCENES: ABM (default), any of
  A (no code), B (a code in the window), M (memory: SOAK=300 s open, then
  camera open/close cycles)

Keep the phone on a cable (the VM service does not connect over Wi-Fi on
iOS 27), still, on a stand, at a steady light. The log and a JSON summary go
to build/perf/.
"""
import json
import os
import re
import statistics as st
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEPS = 'L0,L2,L3,L8,L9,L11,L12'
WARMUP, MEASURE, REPEATS = 5, 20, 2
PAUSE_SECONDS = 20
# Scene M, the memory: the demo template held open (L13), then the camera
# opened and closed again and again.
SOAK_SECONDS = int(os.environ.get('SOAK', '300'))
# The steps held open, one after another: L13 (the demo template) by
# default; SOAK_STEPS=L3,L7,L13 finds which layer a growth comes from.
SOAK_STEPS = os.environ.get('SOAK_STEPS', 'L13').split(',')
# The first minutes of the engine grow the memory to a plateau (on an
# iPhone 17 Pro Max about 20 MB over 5 minutes, then flat at ~160 MB; the
# camera plugin alone stays flat): the soak waits that out, then measures.
SOAK_WARMUP, HEAP_EVERY, CYCLES = 300, 10, 10

# Memory budgets: no growth beyond noise. First estimates (2026-11-23), to
# tighten with more runs. MB over the soak (last minute against the first),
# MB per minute (the trend of every second), and MB after the cycles. The
# Dart heap is compared by its floor (the lowest point of each minute, after
# a collection), so the collector's saw does not count.
MEMORY_BUDGETS = {
    'rssGrowthMb': 10, 'rssSlopeMbPerMin': 1.5, 'heapFloorGrowthMb': 4,
    'externalFloorGrowthMb': 8, 'cyclesRssGrowthMb': 20,
    'cyclesHeapFloorGrowthMb': 4,
}

# Budgets of R4-05 (2026-11-22), for the worst repeat. For iPhones the energy
# of the process, as the CPU share doubles when iOS moves the work to its
# efficiency cores; for Android, without energy counters, the CPU share.
BUDGETS = {
    'iPhone18,2': {  # iPhone 17 Pro Max
        'A:L11:milliwatts': 95, 'A:L11:instructionsG': 1.9,
        'B:L11:milliwatts': 70, 'B:L11:instructionsG': 1.4,
        # The scan line (2026-11-23): within the template's budgets.
        'A:L12:milliwatts': 95, 'A:L12:instructionsG': 1.9,
        'B:L12:milliwatts': 70, 'B:L12:instructionsG': 1.4,
        'pause:milliwatts': 15, 'pause:instructionsG': 0.35,
        'L11:slowFramesPercent': 0.5, 'L12:slowFramesPercent': 0.5,
        'readP95Ms': 12, 'rssMb': 200,
    },
    'Pixel 4a': {
        'A:L11:cpu': 180, 'B:L11:cpu': 180, 'pause:cpu': 40,
        'A:L12:cpu': 180, 'B:L12:cpu': 180,
        'L11:slowFramesPercent': 1, 'L12:slowFramesPercent': 1,
        'readP95Ms': 25, 'rssMb': 400,
    },
}


def model_of(device):
    """The phone's model: an Android model name or an iOS product type."""
    adb = subprocess.run(['adb', '-s', device, 'shell', 'getprop',
                          'ro.product.model'], capture_output=True, text=True,
                         stdin=subprocess.DEVNULL)
    if adb.returncode == 0 and adb.stdout.strip():
        return adb.stdout.strip()
    info = subprocess.run(['xcrun', 'devicectl', 'device', 'info', 'details',
                           '-d', device], capture_output=True, text=True,
                          stdin=subprocess.DEVNULL)
    m = re.search(r'Product Type:\s*(\S+)', info.stdout)
    return m.group(1) if m else 'unknown'


class App:
    """flutter run of the diagnostics page, its log kept with arrival times."""

    def __init__(self, device, log_path):
        self.lines = []
        self.lock = threading.Lock()
        self.log = open(log_path, 'w')
        self.proc = subprocess.Popen(
            ['flutter', 'run', '-d', device, '-t', 'lib/diagnostics.dart',
             '--profile', '--dart-define=DIAG_LOG=true'],
            cwd=os.path.join(ROOT, 'example'), stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        threading.Thread(target=self._read, daemon=True).start()
        self.url = self._wait_for_vm()

    def _read(self):
        for line in self.proc.stdout:
            t = time.time()
            with self.lock:
                self.lines.append((t, line.rstrip('\n')))
            self.log.write(f'{t:.3f} {line}')
            self.log.flush()

    def _wait_for_vm(self):
        deadline = time.time() + 900
        while time.time() < deadline:
            with self.lock:
                for _, line in self.lines:
                    m = re.search(r'Dart VM Service on .* at: (http://\S+/)', line)
                    if m:
                        return m.group(1)
            if self.proc.poll() is not None:
                sys.exit('flutter run ended; see the log')
            time.sleep(2)
        sys.exit('the app did not start within 15 minutes')

    def call(self, method, **params):
        vm = json.load(urllib.request.urlopen(self.url + 'getVM'))
        iso = next(i['id'] for i in vm['result']['isolates']
                   if i['name'] == 'main')
        q = urllib.parse.urlencode({'isolateId': iso, **params})
        return json.load(urllib.request.urlopen(f'{self.url}{method}?{q}'))

    def since(self, t0):
        with self.lock:
            return [(t, l) for t, l in self.lines if t >= t0]

    def quit(self):
        try:
            self.proc.stdin.write('q')
            self.proc.stdin.flush()
            self.proc.wait(timeout=20)
        except Exception:
            self.proc.kill()


def ladder(app, scene):
    t0 = time.time()
    app.call('ext.diag.ladder', action='run', steps=STEPS, warmup=str(WARMUP),
             measure=str(MEASURE), repeats=str(REPEATS), scene=scene)
    total = len(STEPS.split(',')) * (WARMUP + MEASURE) * REPEATS
    print(f'  ladder {scene}: about {total // 60 + 1} min', flush=True)
    while not any('DIAGLADDER done' in l for _, l in app.since(t0)):
        time.sleep(3)
    return [json.loads(re.search(r'DIAGLADDER (\{.*\})', l).group(1))
            for _, l in app.since(t0) if 'DIAGLADDER {' in l]


def pause(app):
    """The scanner of L9, paused: the median of its CPU and work."""
    app.call('ext.diag.ladder', action='step', step='L9')
    time.sleep(6)
    app.call('ext.diag.ladder', action='pause')
    time.sleep(4)
    t0 = time.time()
    time.sleep(PAUSE_SECONDS)
    t1 = time.time()
    app.call('ext.diag.ladder', action='resume')
    app.call('ext.diag.ladder', action='step', step='L0')
    rows = []
    for t, l in app.since(t0):
        m = re.search(r'DIAGCPU .*cpu=([\d.]+) .*work=(\{.*?\}|null) reads', l)
        if m and t <= t1 + 1.5:
            w = json.loads(m.group(2)) or {}
            rows.append({'cpu': float(m.group(1)), **w})
    return {k: round(st.median(r.get(k, 0) for r in rows), 2)
            for k in ('cpu', 'milliwatts', 'instructionsG')} if rows else {}


def _rss_since(app, t0, t1):
    """(time, RSS MB) of each second between t0 and t1."""
    out = []
    for t, l in app.since(t0):
        m = re.search(r'DIAGCPU .* rss=([\d.]+)', l)
        if m and t <= t1:
            out.append((t, float(m.group(1))))
    return out


def _heap(app):
    """(time, Dart heap MB, external MB) of every isolate together: the
    engine reads frames on an isolate of its own."""
    vm = json.load(urllib.request.urlopen(app.url + 'getVM'))
    heap = external = 0
    for iso in vm['result']['isolates']:
        q = urllib.parse.urlencode({'isolateId': iso['id']})
        try:
            r = json.load(urllib.request.urlopen(
                f'{app.url}getMemoryUsage?{q}')).get('result', {})
        except Exception:
            continue  # an isolate that ended meanwhile
        heap += r.get('heapUsage', 0)
        external += r.get('externalUsage', 0)
    mb = 1 << 20
    return (time.time(), heap / mb, external / mb)


def _slope_per_min(points):
    """Least-squares slope of (seconds, MB) points, in MB per minute."""
    if len(points) < 3:
        return 0.0
    t0 = points[0][0]
    xs = [(t - t0) / 60 for t, _ in points]
    ys = [v for _, v in points]
    mx, my = st.mean(xs), st.mean(ys)
    den = sum((x - mx) ** 2 for x in xs)
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / den if den else 0.0


def _floors(samples, index, t0):
    """The lowest value of each minute since t0."""
    per = {}
    for s in samples:
        per.setdefault(int((s[0] - t0) // 60), []).append(s[index])
    return [min(v) for _, v in sorted(per.items())]


def soak(app, step):
    """The memory while [step] stays open for SOAK_SECONDS."""
    app.call('ext.diag.ladder', action='step', step=step)
    time.sleep(SOAK_WARMUP)
    t0 = time.time()
    heap = []
    while time.time() < t0 + SOAK_SECONDS:
        heap.append(_heap(app))
        time.sleep(HEAP_EVERY)
    t1 = time.time()
    rss = _rss_since(app, t0, t1)
    first = [v for t, v in rss if t < t0 + 60]
    last = [v for t, v in rss if t >= t1 - 60]
    heap_floors = _floors(heap, 1, t0)
    ext_floors = _floors(heap, 2, t0)
    return {
        'soakSeconds': SOAK_SECONDS,
        'rssStartMb': round(st.mean(first), 1) if first else None,
        'rssEndMb': round(st.mean(last), 1) if last else None,
        'rssGrowthMb': round(st.mean(last) - st.mean(first), 1)
        if first and last else None,
        'rssSlopeMbPerMin': round(_slope_per_min(rss), 2),
        'heapFloorGrowthMb': round(heap_floors[-1] - heap_floors[0], 1)
        if len(heap_floors) > 1 else None,
        'externalFloorGrowthMb': round(ext_floors[-1] - ext_floors[0], 1)
        if len(ext_floors) > 1 else None,
    }


def memory(app):
    """Scene M: the template open for SOAK_SECONDS, then CYCLES of opening
    and closing the camera; the memory must not grow."""
    minutes = len(SOAK_STEPS) * (SOAK_WARMUP + SOAK_SECONDS) // 60 + 2
    print(f'  memory: about {minutes} min', flush=True)
    out = {}
    for step in SOAK_STEPS:
        out[step] = soak(app, step)
    def settled(seconds=10):
        t = time.time()
        time.sleep(seconds)
        values = [v for _, v in _rss_since(app, t, time.time())]
        return st.median(values) if values else 0.0, min(
            h[1] for h in [_heap(app), _heap(app)])

    app.call('ext.diag.ladder', action='step', step='L0')
    time.sleep(5)
    rss_before, heap_before = settled()
    for _ in range(CYCLES):
        app.call('ext.diag.ladder', action='step', step='L11')
        time.sleep(4)
        app.call('ext.diag.ladder', action='step', step='L0')
        time.sleep(3)
    time.sleep(10)
    rss_after, heap_after = settled()
    out.update({
        'cycles': CYCLES,
        'cyclesRssGrowthMb': round(rss_after - rss_before, 1),
        'cyclesHeapFloorGrowthMb': round(heap_after - heap_before, 1),
    })
    return out


def summary(results):
    """Per scene and step, the worst repeat of each number."""
    out = {}
    for r in results:
        scene = r['scene']
        w = r.get('work') or {}
        cur = out.setdefault(f"{scene}:{r['step']}", {})
        for k, v in (('cpu', r['cpuMedian']), ('milliwatts', w.get('milliwatts')),
                     ('instructionsG', w.get('instructionsG')),
                     ('slowFramesPercent', r['slowFramesPercent']),
                     ('readP95Ms', r['readP95Ms']), ('rssMb', r['rssMaxMb']),
                     ('readsPerSecond', r['readsPerSecond']),
                     ('cameraFps', r['cameraFps'])):
            if v is not None:
                cur[k] = max(cur.get(k, v), v) if k != 'readsPerSecond' \
                    else min(cur.get(k, v), v)
    return out


def verdict(steps, paused, budgets):
    checks = []

    def check(name, value, limit):
        if value is not None:
            checks.append((name, value, limit, value <= limit))

    for key, limit in budgets.items():
        parts = key.split(':')
        if parts[0] == 'pause':
            check(key, paused.get(parts[1]), limit)
        elif len(parts) == 3:
            check(key, steps.get(f'{parts[0]}:{parts[1]}', {}).get(parts[2]), limit)
        elif len(parts) == 2:  # every scene of a step
            for scene_step, nums in steps.items():
                if scene_step.endswith(':' + parts[0]):
                    check(f'{scene_step}:{parts[1]}', nums.get(parts[1]), limit)
        else:  # every scanning step
            for scene_step, nums in steps.items():
                if scene_step.split(':')[1] in ('L8', 'L9', 'L11', 'L12'):
                    check(f'{scene_step}:{key}', nums.get(key), limit)
    for scene_step, nums in steps.items():
        scene, step = scene_step.split(':')
        # With a code in view (B) a template takes it and pauses under its
        # result sheet, so it reads no frames: by design, not a miss.
        if step in ('L8', 'L9') or (scene != 'B' and step in ('L11', 'L12')):
            reads, fps = nums.get('readsPerSecond', 0), nums.get('cameraFps', 0)
            checks.append((f'{scene_step}:reads per camera frame',
                           round(reads / fps, 2) if fps else 0, 0.95,
                           fps > 0 and reads >= 0.95 * fps))
    return checks


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    device = sys.argv[1]
    scenes = sys.argv[2] if len(sys.argv) > 2 else 'ABM'
    model = model_of(device)
    budgets = BUDGETS.get(model)
    stamp = time.strftime('%Y%m%d-%H%M%S')
    out_dir = os.path.join(ROOT, 'build', 'perf')
    os.makedirs(out_dir, exist_ok=True)
    base = os.path.join(out_dir, f"{model.replace(' ', '_')}-{stamp}")
    print(f'{model}: starting the diagnostics page (profile build)...', flush=True)
    app = App(device, base + '.log')
    results, paused, mem = [], {}, {}
    try:
        for scene in scenes:
            what = 'a code in the middle of the scan window' \
                if scene == 'B' else 'NO code in view'
            try:
                input(f'\nScene {scene}: point the camera at {what}, keep '
                      'the phone still, then press Enter. ')
            except EOFError:
                print()  # not a terminal: the scene is set already
            if scene == 'M':
                mem = memory(app)
                continue
            results += ladder(app, scene)
            if scene == scenes[0]:
                paused = pause(app)
    finally:
        app.quit()
    steps = summary(results)
    print(f"\n{'step':<8}{'CPU %':>7}{'mW':>7}{'Ginstr':>8}{'slow %':>8}"
          f"{'read p95':>9}{'reads/cam':>10}{'RSS MB':>8}")
    for key, n in steps.items():
        reads = f"{n['readsPerSecond']:.0f}/{n['cameraFps']:.0f}" \
            if n.get('cameraFps') else '-'
        print(f"{key:<8}{n['cpu']:>7.1f}{n.get('milliwatts', 0):>7.0f}"
              f"{n.get('instructionsG', 0):>8.2f}{n['slowFramesPercent']:>8.1f}"
              f"{n['readP95Ms']:>9.1f}{reads:>10}{n['rssMb']:>8.0f}")
    if paused:
        print(f"{'pause':<8}{paused['cpu']:>7.1f}{paused.get('milliwatts', 0):>7.0f}"
              f"{paused.get('instructionsG', 0):>8.2f}")
    checks = verdict(steps, paused, budgets) if budgets else []
    if mem:
        print()
        for step in SOAK_STEPS:
            m = mem[step]
            print(f"memory {step}: {m['soakSeconds']} s open, RSS "
                  f"{m['rssStartMb']} → {m['rssEndMb']} MB, "
                  f"{m['rssSlopeMbPerMin']} MB/min, Dart heap floor "
                  f"{m['heapFloorGrowthMb']:+} MB, external floor "
                  f"{m['externalFloorGrowthMb']:+} MB")
        print(f"memory: {mem['cycles']} camera open/close cycles")
        for key, limit in MEMORY_BUDGETS.items():
            for step in [s for s in SOAK_STEPS if key in mem[s]] or [None]:
                value = mem[step].get(key) if step else mem.get(key)
                name = f'M:{step}:{key}' if step else f'M:{key}'
                checks.append((name, value, limit,
                               value is not None and value <= limit))
        # The memory has its own budgets on every phone.
        budgets = budgets or {'memory': None}
    if budgets:
        print('\nBudgets (worst repeat):')
        for name, value, limit, ok in checks:
            print(f"  {'ok  ' if ok else 'OVER'} {name}: {value} (budget {limit})")
        failed = [c for c in checks if not c[3]]
        print(f"\n{'All budgets met.' if not failed else f'{len(failed)} over budget.'}")
    else:
        print(f'\nNo budgets for {model}: numbers only.')
    json.dump({'model': model, 'steps': steps, 'pause': paused, 'memory': mem,
               'checks': checks, 'results': results},
              open(base + '.json', 'w'), indent=1)
    print(f'Log and results: {base}.log, {base}.json')
    if budgets and any(not c[3] for c in checks):
        sys.exit(1)


if __name__ == '__main__':
    main()
