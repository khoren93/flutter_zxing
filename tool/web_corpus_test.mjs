// Runs the fixture corpus of a web build in headless Chrome and fails if the
// results differ from example/assets/fixtures/corpus_expected.json.
//
//   cd example && flutter build web -t lib/corpus_web.dart [--wasm]
//   node tool/web_corpus_test.mjs example/build/web [label]
//
// Chrome: $CHROME_PATH, or the usual install locations. Needs puppeteer-core
// (`npm ci` in tool/).
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import puppeteer from 'puppeteer-core';

const root = path.resolve(process.argv[2] ?? 'example/build/web');
const label = process.argv[3] ?? root;
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.gif': 'image/gif',
  '.txt': 'text/plain', '.otf': 'font/otf', '.ttf': 'font/ttf',
};
const server = http.createServer((req, res) => {
  let p = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (p.endsWith('/')) p += 'index.html';
  fs.readFile(p, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end();
    }
    // dart2wasm builds need cross-origin isolation for their best renderer;
    // harmless for dart2js.
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

const browser = await puppeteer.launch({ executablePath: chrome, headless: true, args: ['--no-sandbox'] });
let outcome;
try {
  const page = await browser.newPage();
  const done = new Promise((resolve) => {
    page.on('console', (m) => {
      const text = m.text();
      if (text.startsWith('FZX_CORPUS ')) resolve(JSON.parse(text.slice('FZX_CORPUS '.length)));
      else if (/error|exception/i.test(text)) console.log(`  console: ${text}`);
    });
  });
  page.on('pageerror', (e) => console.log(`  page error: ${e.message}`));
  await page.goto(`http://localhost:${server.address().port}/`);
  outcome = await Promise.race([
    done,
    new Promise((resolve) => setTimeout(() => resolve({ ok: false, summary: 'timed out after 180 s', problems: [], diffs: [] }), 180000)),
  ]);
} finally {
  await browser.close();
  server.close();
}

console.log(`${label}: ${outcome.summary}`);
for (const line of [...outcome.problems, ...outcome.diffs]) console.log(`  ${line}`);
process.exit(outcome.ok ? 0 : 1);
