// fzx: the C ABI of the flutter_zxing engine, shared by every platform.
//
// The same source is compiled to a native library (called through dart:ffi)
// and to WebAssembly (called from a Web Worker). Every call returns its result
// as one flat little-endian buffer instead of dozens of getter calls, because
// crossing the Dart/JS boundary is expensive and FFI calls are not free
// either. One Dart parser reads the buffer on all platforms
// (lib/src/engine/result_codec.dart); the layout is described in fzx.cpp.
//
// A context is not thread-safe. Create one per isolate / worker.
//
// Bump FZX_ABI_VERSION on every change of a signature or of the result
// layout: the Dart side refuses to work with a library of another version,
// which catches a stale WebAssembly asset or a stale native build.

#ifndef FZX_H
#define FZX_H

#include <stdint.h>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#define FZX_KEEP EMSCRIPTEN_KEEPALIVE
#else
#define FZX_KEEP
#endif

#ifdef _WIN32
#define FZX_API __declspec(dllexport)
#else
#define FZX_API __attribute__((visibility("default"))) FZX_KEEP
#endif

#define FZX_ABI_VERSION 1

#ifdef __cplusplus
extern "C" {
#endif

typedef struct fzx_ctx fzx_ctx;

// Reader option flags (`flags` of fzx_read / fzx_read_file).
enum {
	FZX_TRY_HARDER = 1 << 0,
	FZX_TRY_ROTATE = 1 << 1,
	FZX_TRY_INVERT = 1 << 2,
	FZX_TRY_DOWNSCALE = 1 << 3,
	FZX_IS_PURE = 1 << 4,
	FZX_RETURN_ERRORS = 1 << 5,
	FZX_VALIDATE_OPTIONAL_CHECKSUM = 1 << 6,
	// Bits 8-11: zxing-cpp TextMode + 1 for the barcode text; 0 is the
	// default, TextMode::HRI. The corpus tests use TextMode::Plain to compare
	// with zxing-cpp's expected results the way its own blackbox tests do.
	FZX_TEXT_MODE_SHIFT = 8,
	FZX_TEXT_MODE_MASK = 0xF << 8,
};

// Binarizers, in zxing-cpp's order.
enum {
	FZX_BINARIZER_LOCAL_AVERAGE = 0,
	FZX_BINARIZER_GLOBAL_HISTOGRAM = 1,
	FZX_BINARIZER_FIXED_THRESHOLD = 2,
	FZX_BINARIZER_BOOL_CAST = 3,
};

// Pixel layouts accepted by fzx_read.
enum {
	FZX_PIX_LUM = 0,
	FZX_PIX_RGB = 1,
	FZX_PIX_RGBA = 2,
	FZX_PIX_BGRA = 3,
};

// Error codes. Every call that can fail returns one of these (< 0), and
// fzx_error() describes the failure.
enum {
	FZX_ERR_ARGUMENT = -1, // invalid argument (unknown format name, bad pixel geometry...)
	FZX_ERR_IMAGE = -2,    // fzx_read_file: the bytes are not an image stb_image can decode
	FZX_ERR_WRITE = -3,    // fzx_write: the data cannot be encoded in the requested format
	FZX_ERR_NO_WRITER = -4, // fzx_write: this build has no writer (the reader-only WebAssembly module)
	FZX_ERR_INTERNAL = -5, // anything else
};

FZX_API int fzx_abi_version(void);

// The zxing-cpp version, e.g. "3.1.1".
FZX_API const char* fzx_version(void);

// Whether this build can create barcodes (1) or only read them (0).
FZX_API int fzx_has_writer(void);

FZX_API fzx_ctx* fzx_new(void);
FZX_API void fzx_free(fzx_ctx* ctx);

// A buffer owned by the context, at least `size` bytes, reused across calls.
// Callers write pixels or file bytes here to avoid an allocation per frame.
// NULL if the allocation failed.
FZX_API uint8_t* fzx_input(fzx_ctx* ctx, int size);

// Reader options, passed with every call so that one context can serve
// readers with different settings:
//   formats         comma separated zxing-cpp format names ("QRCode,EAN13");
//                   NULL or "" means all formats. The parsed list is cached,
//                   so passing the same string again costs a strcmp.
//   flags           FZX_TRY_* / FZX_IS_PURE / ... bits
//   binarizer       FZX_BINARIZER_*
//   max_symbols     stop after this many barcodes; 0 means no limit.
//                   1 stops at the first barcode, which on large photos is
//                   often ten times faster than an exhaustive search.
//   min_line_count  linear barcodes: scan lines that must agree (>= 1)

// Decodes raw pixels. `row_stride` <= 0 means tightly packed rows.
// `crop_w`/`crop_h` <= 0 means the whole image. Positions in the result are
// in the coordinates of the full (uncropped) image.
// Returns the number of barcodes (result layout "barcodes"), or an FZX_ERR_*.
FZX_API int fzx_read(fzx_ctx* ctx, const uint8_t* data, int width, int height, int row_stride, int pix_format,
					 int crop_l, int crop_t, int crop_w, int crop_h, const char* formats, uint32_t flags,
					 int binarizer, int max_symbols, int min_line_count);

// Decodes an encoded image (JPEG, PNG, GIF, BMP via stb_image) at full
// resolution, without lossy pre-scaling: zxing-cpp's tryDownscale handles
// big images. Returns the number of barcodes or an FZX_ERR_*.
FZX_API int fzx_read_file(fzx_ctx* ctx, const uint8_t* data, int size, const char* formats, uint32_t flags,
						  int binarizer, int max_symbols, int min_line_count);

// Encodes `data` into a barcode symbol (result layout "symbol").
//   binary   0: `data` is UTF-8 text, 1: raw bytes (byte mode)
//   format   a writable zxing-cpp format name ("QRCode")
//   options  zxing-cpp creator options ("ecLevel=H, version=4, gs1"), may be NULL
// Returns 0 or an FZX_ERR_*.
FZX_API int fzx_write(fzx_ctx* ctx, const uint8_t* data, int size, int binary, const char* format,
					  const char* options);

// Result of the last successful call. Valid until the next call on the same context.
FZX_API const uint8_t* fzx_result(fzx_ctx* ctx);
FZX_API int fzx_result_size(fzx_ctx* ctx);

// Message of the last failed call, "" if there was none.
FZX_API const char* fzx_error(fzx_ctx* ctx);

#ifdef __cplusplus
}
#endif

#endif
