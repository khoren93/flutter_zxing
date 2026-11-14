// Runs the web scanner end to end in headless Chrome with a video file as
// the camera, and checks that the barcode is read and outlined exactly where
// it shows on screen: portrait, landscape, and a mirrored front camera.
//
//   cd example && flutter build web -t lib/scanner_web.dart [--wasm]
//   node tool/web_scanner_test.mjs example/build/web [label]
//
// The camera picture is a QR code sample of the zxing-cpp submodule, scaled
// into a 1280x720 white frame by ffmpeg (Chrome's fake camera reads y4m);
// where the code lies in the sample comes from the committed corpus results.
// Needs ffmpeg, Chrome ($CHROME_PATH or the usual install locations) and
// puppeteer-core (`npm ci` in tool/).
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.resolve(process.argv[2] ?? 'example/build/web');
const label = process.argv[3] ?? 'web';

// The camera picture: qrcode-2/14.png (429 x 429) scaled to 220 px, so that
// the code fits the default scan window in every case below, and moved 15 px
// right of the centre, so that mirroring moves it.
const sample = path.join(repo, 'third_party/zxing-cpp/test/samples/qrcode-2/14.png');
const sampleSize = 429;
const scaled = 220;
const shift = 15;
const frame = [1280, 720];
const corpus = JSON.parse(fs.readFileSync(path.join(repo, 'example/assets/fixtures/corpus_expected.json'), 'utf8'));
const recorded = corpus.results['qrcode-2__14'][0];
const text = recorded.text;
const cases = [
  { name: 'portrait', viewport: [400, 800] },
  { name: 'landscape', viewport: [1280, 720] },
  { name: 'front camera', viewport: [400, 800], query: '?facing=front' },
];
const tolerance = 8;

/// Where the code shows in a viewport: its bounds in the sample, scaled and
/// centred into the frame, mirrored for the front camera, then fitted the
/// way BoxFit.cover fits the preview.
function expectedBounds(c) {
  const xs = recorded.position.filter((_, i) => i % 2 === 0);
  const ys = recorded.position.filter((_, i) => i % 2 === 1);
  const s = scaled / sampleSize;
  const ox = (frame[0] - scaled) / 2 + shift;
  const oy = (frame[1] - scaled) / 2;
  let [l, r] = [Math.min(...xs) * s + ox, Math.max(...xs) * s + ox];
  const [t, b] = [Math.min(...ys) * s + oy, Math.max(...ys) * s + oy];
  if (c.query?.includes('front')) [l, r] = [frame[0] - r, frame[0] - l];
  const [vw, vh] = c.viewport;
  const k = Math.max(vw / frame[0], vh / frame[1]);
  const dx = (vw - frame[0] * k) / 2;
  const dy = (vh - frame[1] * k) / 2;
  return [l * k + dx, t * k + dy, r * k + dx, b * k + dy];
}

const work = fs.mkdtempSync(path.join(os.tmpdir(), 'fzx-scanner-'));
const video = path.join(work, 'camera.y4m');
execFileSync('ffmpeg', [
  '-y', '-loglevel', 'error', '-loop', '1', '-i', sample,
  '-vf', `scale=${scaled}:${scaled}:flags=neighbor,pad=${frame[0]}:${frame[1]}:(ow-iw)/2+${shift}:(oh-ih)/2:white,format=yuv420p`,
  '-t', '2', '-r', '10', video,
]);

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.json': 'application/json', '.png': 'image/png', '.otf': 'font/otf', '.ttf': 'font/ttf',
};
const server = http.createServer((req, res) => {
  let p = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (p.endsWith('/')) p += 'index.html';
  fs.readFile(p, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end();
    }
    res.writeHead(200, {
      'Content-Type': types[path.extname(p)] ?? 'application/octet-stream',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    res.end(data);
  });
}).listen(0);

const chrome = process.env.CHROME_PATH ?? [
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/google-chrome-stable',
  '/usr/bin/chromium',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
].find((p) => fs.existsSync(p));
if (!chrome) {
  console.error('Chrome not found, set CHROME_PATH');
  process.exit(2);
}

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: true,
  args: [
    '--no-sandbox',
    '--use-fake-ui-for-media-stream',
    '--use-fake-device-for-media-stream',
    `--use-file-for-fake-video-capture=${video}`,
  ],
});

/// Opens the scanner in [c.viewport] and returns the first outline.
async function run(c) {
  const page = await browser.newPage();
  try {
    await page.setViewport({ width: c.viewport[0], height: c.viewport[1] });
    const outline = new Promise((resolve, reject) => {
      page.on('console', (m) => {
        const line = m.text();
        if (line.startsWith('FZX_OUTLINE ')) resolve(JSON.parse(line.slice('FZX_OUTLINE '.length)));
        else if (line.startsWith('FZX_SCANNER ')) {
          const state = JSON.parse(line.slice('FZX_SCANNER '.length));
          if (state.status === 'error') reject(new Error(`scanner error: ${state.error}`));
        } else if (/error|exception/i.test(line)) console.log(`  console: ${line}`);
      });
      page.on('pageerror', reject);
    });
    const timeout = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('no barcode outlined within 60 s')), 60000));
    await page.goto(`http://localhost:${server.address().port}/${c.query ?? ''}`);
    return await Promise.race([outline, timeout]);
  } finally {
    await page.close();
  }
}

const failures = [];
try {
  for (const c of cases) {
    try {
      const found = await run(c);
      const expected = expectedBounds(c);
      const off = Math.max(...found.bounds.map((v, i) => Math.abs(v - expected[i])));
      const fmt = (b) => `[${b.map((v) => v.toFixed(1)).join(', ')}]`;
      console.log(`  ${label}, ${c.name}: outlined at ${fmt(found.bounds)}, expected ${fmt(expected)}, ` +
        `off by ${off.toFixed(1)} px`);
      if (found.text !== text) failures.push(`${c.name}: read "${found.text}", expected "${text}"`);
      else if (off > tolerance) failures.push(`${c.name}: the outline is ${off.toFixed(1)} px off`);
    } catch (e) {
      failures.push(`${c.name}: ${e.message ?? e}`);
    }
  }
} finally {
  await browser.close();
  server.close();
  fs.rmSync(work, { recursive: true, force: true });
}
if (failures.length > 0) {
  for (const f of failures) console.error(`${label}: FAILED: ${f}`);
  process.exit(1);
}
console.log(`${label}: the scanner reads the code and outlines it where it shows (${cases.length} cases)`);
