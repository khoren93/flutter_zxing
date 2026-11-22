#!/usr/bin/env python3
"""The scanner's load on a phone, against the budgets: `make perf DEVICE=<id>`.

Runs the diagnostics page in a profile build with its per-second log, walks
the load ladder through the VM service in two scenes (A: no code in view,
B: a code in the scan window), measures the paused scanner, and prints each
number with its budget. Budgets are known for the phones they were set on
(iPhone 17 Pro Max, Pixel 4a); other phones get the numbers only.

  python3 tool/perf_run.py DEVICE [SCENES]     SCENES: AB (default), A or B

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
STEPS = 'L0,L2,L3,L8,L9,L11'
WARMUP, MEASURE, REPEATS = 5, 20, 2
PAUSE_SECONDS = 20

# Budgets of R4-05 (2026-11-22), for the worst repeat. For iPhones the energy
# of the process, as the CPU share doubles when iOS moves the work to its
# efficiency cores; for Android, without energy counters, the CPU share.
BUDGETS = {
    'iPhone18,2': {  # iPhone 17 Pro Max
        'A:L11:milliwatts': 95, 'A:L11:instructionsG': 1.9,
        'B:L11:milliwatts': 70, 'B:L11:instructionsG': 1.4,
        'pause:milliwatts': 15, 'pause:instructionsG': 0.35,
        'L11:slowFramesPercent': 0.5, 'readP95Ms': 12, 'rssMb': 200,
    },
    'Pixel 4a': {
        'A:L11:cpu': 180, 'B:L11:cpu': 180, 'pause:cpu': 40,
        'L11:slowFramesPercent': 0.5, 'readP95Ms': 25, 'rssMb': 400,
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
                if scene_step.split(':')[1] in ('L8', 'L9', 'L11'):
                    check(f'{scene_step}:{key}', nums.get(key), limit)
    for scene_step, nums in steps.items():
        if scene_step.split(':')[1] in ('L8', 'L9', 'L11'):
            reads, fps = nums.get('readsPerSecond', 0), nums.get('cameraFps', 0)
            checks.append((f'{scene_step}:reads per camera frame',
                           round(reads / fps, 2) if fps else 0, 0.95,
                           fps > 0 and reads >= 0.95 * fps))
    return checks


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    device = sys.argv[1]
    scenes = sys.argv[2] if len(sys.argv) > 2 else 'AB'
    model = model_of(device)
    budgets = BUDGETS.get(model)
    stamp = time.strftime('%Y%m%d-%H%M%S')
    out_dir = os.path.join(ROOT, 'build', 'perf')
    os.makedirs(out_dir, exist_ok=True)
    base = os.path.join(out_dir, f"{model.replace(' ', '_')}-{stamp}")
    print(f'{model}: starting the diagnostics page (profile build)...', flush=True)
    app = App(device, base + '.log')
    results, paused = [], {}
    try:
        for scene in scenes:
            what = 'NO code in view' if scene == 'A' else \
                'a code in the middle of the scan window'
            try:
                input(f'\nScene {scene}: point the camera at {what}, keep '
                      'the phone still, then press Enter. ')
            except EOFError:
                print()  # not a terminal: the scene is set already
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
    if budgets:
        print('\nBudgets (worst repeat):')
        for name, value, limit, ok in checks:
            print(f"  {'ok  ' if ok else 'OVER'} {name}: {value} (budget {limit})")
        failed = [c for c in checks if not c[3]]
        print(f"\n{'All budgets met.' if not failed else f'{len(failed)} over budget.'}")
    else:
        print(f'\nNo budgets for {model}: numbers only.')
    json.dump({'model': model, 'steps': steps, 'pause': paused,
               'checks': checks, 'results': results},
              open(base + '.json', 'w'), indent=1)
    print(f'Log and results: {base}.log, {base}.json')
    if budgets and any(not c[3] for c in checks):
        sys.exit(1)


if __name__ == '__main__':
    main()
