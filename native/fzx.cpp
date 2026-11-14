// fzx: the C ABI of the flutter_zxing engine. See fzx.h.
//
// Result layouts (little-endian; str/bytes = u32 length + payload):
//
// "barcodes" (fzx_read, fzx_read_file)
//   u32 abi version, u32 kind = 1
//   i32 image width, i32 image height   (of the decoded image, before cropping)
//   i32 count
//   per barcode:
//     u32 format id, u8 content type, u8 error type, u8 flags, u8 reserved
//     i32 orientation, i32 x0 y0 x1 y1 x2 y2 x3 y3 (top-left, top-right, bottom-right, bottom-left)
//     i32 line count, i32 sequence index, i32 sequence size
//     str text, bytes raw, str symbology identifier, str ec level, str version,
//     str sequence id, str error message, str extra (JSON object, may be empty)
//   flags: 1 valid, 2 inverted, 4 mirrored, 8 has ECI, 16 reader init
//
// "symbol" (fzx_write)
//   u32 abi version, u32 kind = 2
//   u32 format id, i32 width, i32 height (in modules, without quiet zones)
//   i32 quiet zone left, top, right, bottom (in modules)
//   str human readable text, str ec level, str version
//   bytes modules (width * height, row by row, 1 = dark, 0 = light)
//
// Every target we build for is little-endian, so integers are copied verbatim.

#include "fzx.h"

#include "ReadBarcode.h"
#include "Version.h"

#ifdef ZXING_USE_ZINT
#include "CreateBarcode.h"
#include "WriteBarcode.h"
#endif

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#define STBI_NO_STDIO
#define STBI_NO_HDR
#define STBI_NO_LINEAR
#define STBI_ONLY_JPEG
#define STBI_ONLY_PNG
#define STBI_ONLY_GIF
#define STBI_ONLY_BMP
#include "stb_image.h"

#include <cstring>
#include <exception>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <vector>

using namespace ZXing;

struct fzx_ctx
{
	std::vector<uint8_t> input;
	std::vector<uint8_t> out;
	std::string error;
	// Parsed `formats` of the last call, keyed by the string it came from.
	std::string formatsKey;
	BarcodeFormats formats;
};

namespace {

enum : uint32_t { KIND_BARCODES = 1, KIND_SYMBOL = 2 };

struct Writer
{
	std::vector<uint8_t>& b;

	void u8(uint8_t v) { b.push_back(v); }
	void u32(uint32_t v)
	{
		auto p = b.size();
		b.resize(p + 4);
		std::memcpy(b.data() + p, &v, 4);
	}
	void i32(int32_t v) { u32(static_cast<uint32_t>(v)); }
	void blob(const void* data, size_t n)
	{
		u32(static_cast<uint32_t>(n));
		auto p = b.size();
		b.resize(p + n);
		if (n)
			std::memcpy(b.data() + p, data, n);
	}
	void str(const std::string& s) { blob(s.data(), s.size()); }
};

void encodeBarcodes(fzx_ctx* ctx, const Barcodes& barcodes, int imageWidth, int imageHeight, int dx, int dy)
{
	ctx->out.clear();
	ctx->out.reserve(256 * (barcodes.size() + 1));
	Writer w{ctx->out};
	w.u32(FZX_ABI_VERSION);
	w.u32(KIND_BARCODES);
	w.i32(imageWidth);
	w.i32(imageHeight);
	w.i32(static_cast<int32_t>(barcodes.size()));
	for (const auto& bc : barcodes) {
		w.u32(static_cast<uint32_t>(bc.format()));
		w.u8(static_cast<uint8_t>(bc.contentType()));
		w.u8(static_cast<uint8_t>(bc.error().type()));
		uint8_t flags = (bc.isValid() ? 1 : 0) | (bc.isInverted() ? 2 : 0) | (bc.isMirrored() ? 4 : 0)
						| (bc.hasECI() ? 8 : 0) | (bc.readerInit() ? 16 : 0);
		w.u8(flags);
		w.u8(0);
		w.i32(bc.orientation());
		for (const auto& p : bc.position()) {
			w.i32(p.x + dx);
			w.i32(p.y + dy);
		}
		w.i32(bc.lineCount());
		w.i32(bc.sequenceIndex());
		w.i32(bc.sequenceSize());
		w.str(bc.text());
		const auto& bytes = bc.bytes();
		w.blob(bytes.data(), bytes.size());
		w.str(bc.symbologyIdentifier());
		w.str(bc.ecLevel());
		w.str(bc.version());
		w.str(bc.sequenceId());
		w.str(bc.error().msg());
		w.str(bc.extra());
	}
}

int fail(fzx_ctx* ctx, int code, std::string msg)
{
	ctx->error = std::move(msg);
	ctx->out.clear();
	return code;
}

ImageFormat toImageFormat(int pix)
{
	switch (pix) {
	case FZX_PIX_LUM: return ImageFormat::Lum;
	case FZX_PIX_RGB: return ImageFormat::RGB;
	case FZX_PIX_RGBA: return ImageFormat::RGBA;
	case FZX_PIX_BGRA: return ImageFormat::BGRA;
	default: throw std::invalid_argument("Unknown pixel format " + std::to_string(pix));
	}
}

ReaderOptions readerOptions(fzx_ctx* ctx, const char* formats, uint32_t flags, int binarizer, int maxSymbols,
							int minLineCount)
{
	const char* key = formats ? formats : "";
	if (ctx->formatsKey != key) {
		ctx->formats = *key ? BarcodeFormatsFromString(key) : BarcodeFormats{};
		ctx->formatsKey = key;
	}
	if (binarizer < FZX_BINARIZER_LOCAL_AVERAGE || binarizer > FZX_BINARIZER_BOOL_CAST)
		throw std::invalid_argument("Unknown binarizer " + std::to_string(binarizer));
	const int textMode = static_cast<int>((flags & FZX_TEXT_MODE_MASK) >> FZX_TEXT_MODE_SHIFT);
	if (textMode > static_cast<int>(TextMode::HexECI) + 1)
		throw std::invalid_argument("Unknown text mode " + std::to_string(textMode - 1));
	const int eanAddOn = static_cast<int>((flags & FZX_EAN_ADD_ON_MASK) >> FZX_EAN_ADD_ON_SHIFT);
	if (eanAddOn > static_cast<int>(EanAddOnSymbol::Require))
		throw std::invalid_argument("Unknown EAN add-on mode " + std::to_string(eanAddOn));
	ReaderOptions o;
	o.formats(ctx->formats)
		.tryHarder(flags & FZX_TRY_HARDER)
		.tryRotate(flags & FZX_TRY_ROTATE)
		.tryInvert(flags & FZX_TRY_INVERT)
		.tryDownscale(flags & FZX_TRY_DOWNSCALE)
		.isPure(flags & FZX_IS_PURE)
		.returnErrors(flags & FZX_RETURN_ERRORS)
		.validateOptionalChecksum(flags & FZX_VALIDATE_OPTIONAL_CHECKSUM)
		.binarizer(static_cast<Binarizer>(binarizer))
		.maxNumberOfSymbols(maxSymbols > 0 && maxSymbols < 0xFF ? maxSymbols : 0xFF)
		.minLineCount(minLineCount > 0 ? (minLineCount < 0xFF ? minLineCount : 0xFF) : 2)
		.textMode(textMode ? static_cast<TextMode>(textMode - 1) : TextMode::HRI)
		.eanAddOnSymbol(static_cast<EanAddOnSymbol>(eanAddOn));
	return o;
}

// Runs `f`, turning exceptions into error codes.
template <typename F>
int guarded(fzx_ctx* ctx, int errorCode, F&& f)
{
	try {
		ctx->error.clear();
		return f();
	} catch (const std::invalid_argument& e) {
		return fail(ctx, errorCode, e.what());
	} catch (const std::bad_alloc&) {
		return fail(ctx, FZX_ERR_INTERNAL, "Out of memory");
	} catch (const std::exception& e) {
		return fail(ctx, FZX_ERR_INTERNAL, e.what());
	} catch (...) {
		return fail(ctx, FZX_ERR_INTERNAL, "Unknown error");
	}
}

#ifdef ZXING_USE_ZINT
// Position of the first dark pixel in row-major order, (-1, -1) if there is none.
void firstDark(const Image& img, int& x, int& y)
{
	for (y = 0; y < img.height(); ++y)
		for (x = 0; x < img.width(); ++x)
			if (*img.data(x, y) < 128)
				return;
	x = y = -1;
}
#endif

} // namespace

extern "C" {

int fzx_abi_version(void)
{
	return FZX_ABI_VERSION;
}

const char* fzx_version(void)
{
	return ZXING_VERSION_STR;
}

int fzx_has_writer(void)
{
#ifdef ZXING_USE_ZINT
	return 1;
#else
	return 0;
#endif
}

fzx_ctx* fzx_new(void)
{
	return new (std::nothrow) fzx_ctx();
}

void fzx_free(fzx_ctx* ctx)
{
	delete ctx;
}

uint8_t* fzx_input(fzx_ctx* ctx, int size)
{
	try {
		if (size > 0 && static_cast<size_t>(size) > ctx->input.size())
			ctx->input.resize(size);
		return ctx->input.data();
	} catch (...) {
		return nullptr;
	}
}

int fzx_read(fzx_ctx* ctx, const uint8_t* data, int width, int height, int row_stride, int pix_format, int crop_l,
			 int crop_t, int crop_w, int crop_h, const char* formats, uint32_t flags, int binarizer, int max_symbols,
			 int min_line_count)
{
	return guarded(ctx, FZX_ERR_ARGUMENT, [&] {
		if (!data || width <= 0 || height <= 0)
			throw std::invalid_argument("Empty image");
		auto opts = readerOptions(ctx, formats, flags, binarizer, max_symbols, min_line_count);
		ImageView iv(data, width, height, toImageFormat(pix_format), row_stride > 0 ? row_stride : 0);
		int dx = 0, dy = 0;
		if (crop_w > 0 && crop_h > 0) {
			// ImageView::cropped clamps the rectangle to the image.
			dx = crop_l < 0 ? 0 : (crop_l < width ? crop_l : width - 1);
			dy = crop_t < 0 ? 0 : (crop_t < height ? crop_t : height - 1);
			iv = iv.cropped(crop_l, crop_t, crop_w, crop_h);
		}
		auto barcodes = ReadBarcodes(iv, opts);
		encodeBarcodes(ctx, barcodes, width, height, dx, dy);
		return static_cast<int>(barcodes.size());
	});
}

int fzx_read_file(fzx_ctx* ctx, const uint8_t* data, int size, const char* formats, uint32_t flags, int binarizer,
				  int max_symbols, int min_line_count)
{
	return guarded(ctx, FZX_ERR_ARGUMENT, [&] {
		auto opts = readerOptions(ctx, formats, flags, binarizer, max_symbols, min_line_count);
		int w = 0, h = 0, channels = 0;
		std::unique_ptr<stbi_uc, void (*)(void*)> pixels(
			data && size > 0 ? stbi_load_from_memory(data, size, &w, &h, &channels, 1) : nullptr, stbi_image_free);
		if (!pixels)
			return fail(ctx, FZX_ERR_IMAGE,
						std::string("Cannot decode image: ") + (data && size > 0 ? stbi_failure_reason() : "no data"));
		auto barcodes = ReadBarcodes(ImageView(pixels.get(), w, h, ImageFormat::Lum), opts);
		encodeBarcodes(ctx, barcodes, w, h, 0, 0);
		return static_cast<int>(barcodes.size());
	});
}

int fzx_write(fzx_ctx* ctx, const uint8_t* data, int size, int binary, const char* format, const char* options)
{
#ifdef ZXING_USE_ZINT
	BarcodeFormat fmt = BarcodeFormat::None;
	try {
		fmt = BarcodeFormatFromString(format ? format : "");
	} catch (...) {
	}
	if (fmt == BarcodeFormat::None)
		return fail(ctx, FZX_ERR_ARGUMENT, std::string("Unknown format: ") + (format ? format : ""));
	return guarded(ctx, FZX_ERR_WRITE, [&] {
		if (!data || size <= 0)
			throw std::invalid_argument("Nothing to encode");
		CreatorOptions copts(fmt, options ? options : "");
		auto bc = binary ? CreateBarcodeFromBytes(data, size, copts)
						 : CreateBarcodeFromText({reinterpret_cast<const char*>(data), static_cast<size_t>(size)}, copts);

		// One pixel per module, no text: the raster is the module matrix, with
		// the EAN/UPC guard bars reaching lower than the data bars. A second
		// render with quiet zones tells how wide they are on each side (zint
		// knows the per-symbology rules; EAN-13 for example is asymmetric).
		auto plain = WriteBarcodeToImage(bc, WriterOptions().scale(1).addHRT(false).addQuietZones(false));
		auto quiet = WriteBarcodeToImage(bc, WriterOptions().scale(1).addHRT(false).addQuietZones(true));
		int x0, y0, x1, y1;
		firstDark(plain, x0, y0);
		firstDark(quiet, x1, y1);
		int qzLeft = 0, qzTop = 0, qzRight = 0, qzBottom = 0;
		if (x0 >= 0 && x1 >= 0) {
			qzLeft = x1 - x0;
			qzTop = y1 - y0;
			qzRight = quiet.width() - plain.width() - qzLeft;
			qzBottom = quiet.height() - plain.height() - qzTop;
		}

		ctx->out.clear();
		Writer w{ctx->out};
		w.u32(FZX_ABI_VERSION);
		w.u32(KIND_SYMBOL);
		w.u32(static_cast<uint32_t>(bc.format()));
		w.i32(plain.width());
		w.i32(plain.height());
		w.i32(qzLeft);
		w.i32(qzTop);
		w.i32(qzRight);
		w.i32(qzBottom);
		w.str(bc.text());
		w.str(bc.ecLevel());
		w.str(bc.version());
		const size_t n = static_cast<size_t>(plain.width()) * plain.height();
		w.u32(static_cast<uint32_t>(n));
		auto p = ctx->out.size();
		ctx->out.resize(p + n);
		uint8_t* dst = ctx->out.data() + p;
		for (int y = 0; y < plain.height(); ++y)
			for (int x = 0; x < plain.width(); ++x)
				*dst++ = *plain.data(x, y) < 128 ? 1 : 0;
		return 0;
	});
#else
	(void)data, (void)size, (void)binary, (void)format, (void)options;
	return fail(ctx, FZX_ERR_NO_WRITER, "This build of the engine cannot create barcodes");
#endif
}

const uint8_t* fzx_result(fzx_ctx* ctx)
{
	return ctx->out.data();
}

int fzx_result_size(fzx_ctx* ctx)
{
	return static_cast<int>(ctx->out.size());
}

const char* fzx_error(fzx_ctx* ctx)
{
	return ctx->error.c_str();
}

} // extern "C"
