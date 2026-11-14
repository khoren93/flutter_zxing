// The flutter_zxing engine on the web: one fzx context in a module Web
// Worker, so decoding never runs on the page's main thread.
//
// The reader-only module (fzx_reader.wasm) loads first. The full module with
// barcode creation (fzx.wasm) is loaded on the first `write` and then serves
// every call. Results go back as the raw fzx result buffer (transferred, not
// copied) and are parsed by the shared Dart codec
// (lib/src/engine/result_codec.dart).
//
// Protocol (see lib/src/engine/engine_web.dart):
//   worker -> page  {type: 'ready', abi, version} | {type: 'failed', error}
//   page -> worker  {id, type, ...}
//   worker -> page  {id, code, buffer?, error?, ms}  code < 0: FZX_ERR_*
//
// The modules are imported dynamically, so that a missing one is reported as
// such: fzx*.js / fzx*.wasm are built by tool/build_wasm.sh and ship in the
// published package, but are not in the git repository.

const FZX_PIX_RGBA = 2;
const FZX_ERR_IMAGE = -2;
const FZX_ERR_INTERNAL = -5;

const encoder = new TextEncoder();

// The active module: {M, ctx, formats: Map<string, ptr>, writer: bool}.
let engine;
let full; // Promise of the full module, once requested

async function importModule(file) {
  try {
    return (await import(`./${file}`)).default;
  } catch (error) {
    throw new Error(`cannot load ${file} (${error?.message ?? error}). `
      + 'Working on flutter_zxing itself? Run `make wasm` to build the WebAssembly engine.');
  }
}

async function load(file) {
  const create = await importModule(file);
  const M = await create();
  const ctx = M._fzx_new();
  if (!ctx) throw new Error('The barcode engine is out of memory');
  return { M, ctx, formats: new Map(), writer: M._fzx_has_writer() === 1 };
}

function cstr(M, s) {
  const bytes = encoder.encode(s ?? '');
  const p = M._malloc(bytes.length + 1);
  M.HEAPU8.set(bytes, p);
  M.HEAPU8[p + bytes.length] = 0;
  return p;
}

function formatsPtr(e, formats) {
  let p = e.formats.get(formats);
  if (p === undefined) {
    if (e.formats.size > 32) {
      for (const q of e.formats.values()) e.M._free(q);
      e.formats.clear();
    }
    p = cstr(e.M, formats);
    e.formats.set(formats, p);
  }
  return p;
}

// Copies `bytes` into the context's reusable input buffer.
function input(e, bytes) {
  const p = e.M._fzx_input(e.ctx, bytes.length);
  if (!p) throw new Error('The barcode engine is out of memory');
  e.M.HEAPU8.set(bytes, p);
  return p;
}

function readRgba(e, rgba, w, h, o, crop) {
  const c = crop ?? [0, 0, 0, 0];
  return e.M._fzx_read(e.ctx, input(e, rgba), w, h, 0, FZX_PIX_RGBA, c[0], c[1], c[2], c[3],
    formatsPtr(e, o.formats), o.flags, o.binarizer, o.maxSymbols, o.minLineCount);
}

let canvas, g;
function bitmapPixels(bitmap) {
  const w = bitmap.width, h = bitmap.height;
  if (!canvas || canvas.width !== w || canvas.height !== h) {
    canvas = new OffscreenCanvas(w, h);
    g = canvas.getContext('2d', { willReadFrequently: true });
  }
  g.drawImage(bitmap, 0, 0);
  bitmap.close();
  return g.getImageData(0, 0, w, h).data;
}

function readBitmap(e, bitmap, o, crop) {
  const w = bitmap.width, h = bitmap.height;
  return readRgba(e, bitmapPixels(bitmap), w, h, o, crop);
}

// JPEG, PNG, GIF and BMP, by their magic bytes.
function stbCanDecode(b) {
  if (b.length < 4) return false;
  if (b[0] === 0xff && b[1] === 0xd8) return true; // JPEG
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return true; // PNG
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return true; // GIF
  if (b[0] === 0x42 && b[1] === 0x4d) return true; // BMP
  return false;
}

async function readImage(e, bytes, o) {
  // Formats stb_image knows are decoded inside wasm, in this worker.
  // createImageBitmap(Blob) is only the fallback for the rest (WebP, AVIF,
  // HEIC...): Firefox runs that decode on the main thread (measured: a 60 ms
  // UI stall on a 12 MP JPEG).
  if (!stbCanDecode(bytes)) {
    let bitmap;
    try {
      bitmap = await createImageBitmap(new Blob([bytes]));
    } catch (_) {
      return { code: FZX_ERR_IMAGE, error: 'Cannot decode image: unknown or corrupt format' };
    }
    return { code: readBitmap(e, bitmap, o) };
  }
  return {
    code: e.M._fzx_read_file(e.ctx, input(e, bytes), bytes.length, formatsPtr(e, o.formats), o.flags,
      o.binarizer, o.maxSymbols, o.minLineCount),
  };
}

function write(e, m) {
  const data = new Uint8Array(m.buffer);
  const fp = cstr(e.M, m.format), op = cstr(e.M, m.options);
  try {
    return { code: e.M._fzx_write(e.ctx, input(e, data), data.length, m.binary ? 1 : 0, fp, op) };
  } finally {
    e.M._free(fp);
    e.M._free(op);
  }
}

function reply(id, e, code, t0, error) {
  if (code < 0) {
    postMessage({ id, code, error: error ?? e.M.UTF8ToString(e.M._fzx_error(e.ctx)) });
    return;
  }
  const p = e.M._fzx_result(e.ctx), size = e.M._fzx_result_size(e.ctx);
  const buffer = e.M.HEAPU8.slice(p, p + size).buffer;
  postMessage({ id, code, buffer, ms: performance.now() - t0 }, [buffer]);
}

async function handle(m) {
  if (m.type === 'write' && !engine.writer) {
    full ??= load('fzx.js');
    try {
      engine = await full;
    } catch (error) {
      full = undefined; // try again on the next write
      throw error;
    }
  }
  const e = engine;
  const t0 = performance.now();
  switch (m.type) {
    case 'readImage': {
      const r = await readImage(e, new Uint8Array(m.buffer), m.options);
      return reply(m.id, e, r.code, t0, r.error);
    }
    case 'readPixels': {
      const o = m.options, c = m.crop ?? [0, 0, 0, 0];
      const code = e.M._fzx_read(e.ctx, input(e, new Uint8Array(m.buffer)), m.width, m.height, m.rowStride,
        m.layout, c[0], c[1], c[2], c[3], formatsPtr(e, o.formats), o.flags, o.binarizer, o.maxSymbols,
        o.minLineCount);
      return reply(m.id, e, code, t0);
    }
    case 'readBitmap':
      return reply(m.id, e, readBitmap(e, m.bitmap, m.options, m.crop), t0);
    case 'write':
      return reply(m.id, e, write(e, m).code, t0);
    default:
      throw new Error(`Unknown request ${m.type}`);
  }
}

// Requests are handled strictly in order, even across the asynchronous
// steps (module loading, createImageBitmap).
let queue;
const started = load('fzx_reader.js').then(
  (e) => {
    engine = e;
    postMessage({ type: 'ready', abi: e.M._fzx_abi_version(), version: e.M.UTF8ToString(e.M._fzx_version()) });
  },
  (error) => postMessage({ type: 'failed', error: String(error?.message ?? error) }),
);
queue = started;

onmessage = ({ data: m }) => {
  queue = queue.then(async () => {
    if (!engine) return; // failed to start: the page already knows
    try {
      await handle(m);
    } catch (error) {
      postMessage({ id: m.id, code: FZX_ERR_INTERNAL, error: String(error?.message ?? error) });
    }
  });
};
