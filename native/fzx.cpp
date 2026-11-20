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
//     i32 rotation, i32 x0 y0 x1 y1 x2 y2 x3 y3 (top-left, top-right, bottom-right, bottom-left)
//     i32 line count, i32 sequence index, i32 sequence size
//     str text, bytes raw, str symbology identifier, str ec level, str version,
//     str sequence id, str error message, str extra (JSON object, may be empty)
//     i32 symbol width, i32 symbol height (in modules; 0 for linear codes)
//     bytes symbol modules (width * height, row by row, 1 = dark, 0 = light):
//       the grid of modules the reader sampled from a 2D code
//     bytes merge: the content as fzx_merge takes it back (see writeMergeData)
//   flags: 1 valid, 2 inverted, 4 mirrored, 8 has ECI, 16 reader init
//
// "merged" (fzx_merge)
//   u32 abi version, u32 kind = 3
//   u8 content type, str text, bytes raw

// "symbol" (fzx_write)
//   u32 abi version, u32 kind = 2
//   u32 format id, i32 width, i32 height (in modules, without quiet zones)
//   i32 quiet zone left, top, right, bottom (in modules)
//   str human readable text, str ec level, str version
//   bytes modules (width * height, row by row, 1 = dark, 0 = light)
//
// Every target we build for is little-endian, so integers are copied verbatim.

#include "fzx.h"

#include "BarcodeData.h"
#include "Content.h"
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

#include <algorithm>
#include <cmath>
#include <cstdint>
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

enum : uint32_t { KIND_BARCODES = 1, KIND_SYMBOL = 2, KIND_MERGED = 3 };

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

// zxing-cpp keeps the Content of a Barcode private, and with it the encoding
// of each segment, which BarcodeReader.merge needs to join a structured
// append sequence the way MergeStructuredAppendSequence does. An explicit
// instantiation may name a private member: this hands out &Barcode::d.
struct BarcodeDataTag
{
	using type = std::shared_ptr<BarcodeData> Barcode::*;
	friend type barcodeDataMember(BarcodeDataTag);
};
template <typename Tag, typename Tag::type M>
struct PrivateMember
{
	friend typename Tag::type barcodeDataMember(Tag) { return M; }
};
template struct PrivateMember<BarcodeDataTag, &Barcode::d>;

const Content& contentOf(const Barcode& bc)
{
	return (bc.*barcodeDataMember(BarcodeDataTag{}))->content;
}

// The "merge" field of a barcode: its symbology identifier, its encodings
// and its bytes, from which fzx_merge rebuilds the Content.
//   u8 code, u8 modifier, i8 ECI modifier offset, u8 AI flag, u8 has ECI,
//   u32 count, count * (i32 ECI, i32 position), the bytes
void writeMergeData(Writer& w, const Content& c)
{
	std::vector<uint8_t> data;
	Writer m{data};
	m.u8(static_cast<uint8_t>(c.symbology.code));
	m.u8(static_cast<uint8_t>(c.symbology.modifier));
	m.u8(static_cast<uint8_t>(c.symbology.eciModifierOffset));
	m.u8(static_cast<uint8_t>(c.symbology.aiFlag));
	m.u8(c.hasECI ? 1 : 0);
	m.u32(static_cast<uint32_t>(c.encodings.size()));
	for (const auto& e : c.encodings) {
		m.i32(static_cast<int32_t>(e.eci));
		m.i32(e.pos);
	}
	data.insert(data.end(), c.bytes.begin(), c.bytes.end());
	w.blob(data.data(), data.size());
}

// The luminance of a pixel of any ImageFormat.
inline int luminance(const ImageView& iv, int x, int y)
{
	const uint8_t* p = iv.data(x, y);
	const ImageFormat f = iv.format();
	if (PixStride(f) < 3)
		return p[0];
	return (p[RedIndex(f)] + 2 * p[GreenIndex(f)] + p[BlueIndex(f)]) / 4;
}

// The outline of a linear barcode as tall as its bars.
//
// zxing-cpp reads a linear code along scan lines, and its outline spans the
// lines that decoded: on a camera frame, tilted or a little out of focus,
// the lines near the ends of the bars decode in some frames and not in
// others, so the outline's height changes from frame to frame. Here the
// bars are followed across the code from the middle of the outline, up and
// down, as long as a line across shows the same bars as the middle one. The
// scan lines run level while the code may be tilted, or narrow away in
// perspective: each step may slide the line a little along the code to stay
// on the bars. The outline only grows: the lines that decoded are certainly
// on the bars.
Position barsOf(const ImageView& iv, const Position& pos)
{
	using P = PointF;
	const P tl(pos[0]), tr(pos[1]), br(pos[2]), bl(pos[3]);
	const P a = (tl + bl) / 2, b = (tr + br) / 2; // ends of the middle line
	const double len = length(b - a);
	if (len < 16)
		return pos;
	const P u = (b - a) / len;
	P n(-u.y, u.x); // across the line
	if (dot(bl - tl, n) < 0 && dot(br - tr, n) < 0)
		n = -n;

	const int samples = static_cast<int>(len);
	std::vector<int> lum(samples);
	// The line [offset] across from the middle one, slid by [slide] along it.
	auto row = [&](double offset, double slide) {
		for (int i = 0; i < samples; i++) {
			// Between pixel centres, weighed.
			const P p = a + (i + 0.5 + slide) * u + offset * n - P(0.5, 0.5);
			const int x = static_cast<int>(std::floor(p.x)), y = static_cast<int>(std::floor(p.y));
			if (x < 0 || y < 0 || x + 1 >= iv.width() || y + 1 >= iv.height())
				return false;
			const double fx = p.x - x, fy = p.y - y;
			lum[i] = static_cast<int>((luminance(iv, x, y) * (1 - fx) + luminance(iv, x + 1, y) * fx) * (1 - fy)
									  + (luminance(iv, x, y + 1) * (1 - fx) + luminance(iv, x + 1, y + 1) * fx) * fy);
		}
		return true;
	};
	// The bars of the middle line, light (false) or dark (true).
	if (!row(0, 0))
		return pos;
	auto [lo, hi] = std::minmax_element(lum.begin(), lum.end());
	if (*hi - *lo < 48)
		return pos;
	std::vector<bool> bars(samples);
	for (int i = 0; i < samples; i++)
		bars[i] = lum[i] < (*lo + *hi) / 2;

	// The share of the line [offset] across, slid by [slide], that shows the
	// same bars, against a threshold of its own (the light may change). An
	// edge a sample off still counts: a code a pixel or two per module wide
	// moves its edges by that much between two lines.
	std::vector<bool> dark(samples);
	auto alike = [&](double offset, double slide) {
		if (!row(offset, slide))
			return 0.0;
		const auto [l, h] = std::minmax_element(lum.begin(), lum.end());
		if (*h - *l < 48)
			return 0.0;
		const int t = (*l + *h) / 2;
		for (int i = 0; i < samples; i++)
			dark[i] = lum[i] < t;
		int same = 0;
		for (int i = 0; i < samples; i++)
			same += dark[i] == bars[i] || (i > 0 && dark[i - 1] == bars[i])
					|| (i + 1 < samples && dark[i + 1] == bars[i]);
		return static_cast<double>(same) / samples;
	};
	// Steps of a pixel; one odd line (a speck, a crease) is stepped over.
	// Bars are rarely much taller than the code is long. Returns how far the
	// bars reach and how far the line slid there.
	auto reach = [&](double sign) {
		double last = 0, slide = 0, lastSlide = 0;
		for (double d = 1; d <= len * 1.5; d += 1) {
			double best = 0, bestSlide = slide;
			for (double s : {slide, slide - 0.5, slide + 0.5}) {
				const double v = alike(sign * d, s);
				if (v > best)
					best = v, bestSlide = s;
			}
			if (best >= 0.92) {
				last = d, slide = lastSlide = bestSlide;
			} else if (d - last > 2) {
				break;
			}
		}
		return std::pair{last, lastSlide};
	};
	const auto [up, upSlide] = reach(-1);
	const auto [down, downSlide] = reach(1);

	auto at = [](const P& p) { return PointI(static_cast<int>(std::lround(p.x)), static_cast<int>(std::lround(p.y))); };
	const Position bars4 = {at(a + upSlide * u - up * n), at(b + upSlide * u - up * n),
							 at(b + downSlide * u + down * n), at(a + downSlide * u + down * n)};
	// Keep the outline that decoded where it reaches further.
	auto height = [](const Position& q) { return length(PointF((q[3] + q[2]) - (q[0] + q[1]))) / 2; };
	return height(bars4) >= height(pos) ? bars4 : pos;
}

void encodeBarcodes(fzx_ctx* ctx, const Barcodes& barcodes, int imageWidth, int imageHeight, int dx, int dy,
					const ImageView* image = nullptr)
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
		w.i32(bc.rotation());
		const Position position =
			image && (bc.format() & BarcodeFormat::AllLinear) ? barsOf(*image, bc.position()) : bc.position();
		for (const auto& p : position) {
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
		// The modules as read: zxing-cpp's symbol() is a luminance image,
		// black (dark) == 0.
		const ZXing::ImageView symbol = bc.symbol();
		const int sw = symbol.data() ? symbol.width() : 0;
		const int sh = symbol.data() ? symbol.height() : 0;
		w.i32(sw);
		w.i32(sh);
		std::vector<uint8_t> modules(static_cast<size_t>(sw) * sh);
		for (int y = 0; y < sh; y++)
			for (int x = 0; x < sw; x++)
				modules[static_cast<size_t>(y) * sw + x] = *symbol.data(x, y) < 128 ? 1 : 0;
		w.blob(modules.data(), modules.size());
		writeMergeData(w, contentOf(bc));
	}
}

int fail(fzx_ctx* ctx, int code, std::string msg)
{
	ctx->error = std::move(msg);
	ctx->out.clear();
	return code;
}

// A pixel of luminance [lum] and straight [alpha] put on white.
inline uint8_t onWhite(int lum, int alpha)
{
	return static_cast<uint8_t>((lum * alpha + 255 * (255 - alpha) + 127) / 255);
}

// zxing-cpp ignores alpha, so a transparent background, (0, 0, 0, 0) in most
// files, would read as black. If any pixel of [iv] (RGBA or BGRA) is not
// opaque, [lum] receives the pixels put on white as luminance, with the
// weights zxing-cpp uses, and the result views it. Opaque pixels (camera
// frames) are read as they are.
ImageView onWhite(const ImageView& iv, std::vector<uint8_t>& lum)
{
	const int w = iv.width(), h = iv.height();
	bool opaque = true;
	for (int y = 0; y < h && opaque; y++) {
		const uint8_t* p = iv.data(0, y);
		for (int x = 0; x < w; x++, p += 4)
			if (p[3] != 255) {
				opaque = false;
				break;
			}
	}
	if (opaque)
		return iv;
	const ImageFormat f = iv.format();
	const int r = RedIndex(f), g = GreenIndex(f), b = BlueIndex(f);
	lum.resize(static_cast<size_t>(w) * h);
	uint8_t* dst = lum.data();
	for (int y = 0; y < h; y++) {
		const uint8_t* p = iv.data(0, y);
		for (int x = 0; x < w; x++, p += 4)
			*dst++ = onWhite(RGBToLum(p[r], p[g], p[b]), p[3]);
	}
	return ImageView(lum.data(), w, h, ImageFormat::Lum);
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
							int minLineCount, int characterSet)
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
	if (characterSet < 0 || characterSet >= static_cast<int>(CharacterSet::CharsetCount))
		throw std::invalid_argument("Unknown character set " + std::to_string(characterSet));
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
		.eanAddOnSymbol(static_cast<EanAddOnSymbol>(eanAddOn))
		.characterSet(static_cast<CharacterSet>(characterSet));
	if (const int factor = static_cast<int>((flags & FZX_DOWNSCALE_FACTOR_MASK) >> FZX_DOWNSCALE_FACTOR_SHIFT))
		o.downscaleFactor(static_cast<uint8_t>(factor + 1));
	if (const int threshold = static_cast<int>((flags & FZX_DOWNSCALE_THRESHOLD_MASK) >> FZX_DOWNSCALE_THRESHOLD_SHIFT))
		o.downscaleThreshold(static_cast<uint16_t>(threshold));
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
		// At least one byte: the data() of an empty vector may be NULL.
		const size_t n = size > 0 ? static_cast<size_t>(size) : 1;
		if (n > ctx->input.size())
			ctx->input.resize(n);
		return ctx->input.data();
	} catch (...) {
		return nullptr;
	}
}

int fzx_read(fzx_ctx* ctx, const uint8_t* data, int size, int width, int height, int row_stride, int pix_format,
			 int crop_l, int crop_t, int crop_w, int crop_h, const char* formats, uint32_t flags, int binarizer,
			 int max_symbols, int min_line_count, int character_set)
{
	return guarded(ctx, FZX_ERR_ARGUMENT, [&] {
		if (!data || width <= 0 || height <= 0)
			throw std::invalid_argument("Empty image");
		auto opts = readerOptions(ctx, formats, flags, binarizer, max_symbols, min_line_count, character_set);
		const ImageFormat format = toImageFormat(pix_format);
		// The last row needs no padding.
		const int64_t rowBytes = static_cast<int64_t>(width) * PixStride(format);
		const int64_t stride = row_stride > 0 ? row_stride : rowBytes;
		if (stride < rowBytes || stride * (height - 1) + rowBytes > size)
			throw std::invalid_argument("The pixel buffer is smaller than its width, height and row stride say");
		ImageView iv(data, width, height, format, static_cast<int>(stride));
		int dx = 0, dy = 0;
		if (crop_w > 0 && crop_h > 0) {
			// ImageView::cropped clamps the rectangle to the image.
			dx = crop_l < 0 ? 0 : (crop_l < width ? crop_l : width - 1);
			dy = crop_t < 0 ? 0 : (crop_t < height ? crop_t : height - 1);
			iv = iv.cropped(crop_l, crop_t, crop_w, crop_h);
		}
		std::vector<uint8_t> lum;
		if (format == ImageFormat::RGBA || format == ImageFormat::BGRA)
			iv = onWhite(iv, lum);
		auto barcodes = ReadBarcodes(iv, opts);
		encodeBarcodes(ctx, barcodes, width, height, dx, dy, &iv);
		return static_cast<int>(barcodes.size());
	});
}

int fzx_read_file(fzx_ctx* ctx, const uint8_t* data, int size, const char* formats, uint32_t flags, int binarizer,
				  int max_symbols, int min_line_count, int character_set)
{
	return guarded(ctx, FZX_ERR_ARGUMENT, [&] {
		auto opts = readerOptions(ctx, formats, flags, binarizer, max_symbols, min_line_count, character_set);
		if (!data || size <= 0)
			return fail(ctx, FZX_ERR_IMAGE, "Cannot decode image: no data");
		int w = 0, h = 0, channels = 0;
		if (!stbi_info_from_memory(data, size, &w, &h, &channels))
			return fail(ctx, FZX_ERR_IMAGE, std::string("Cannot decode image: ") + stbi_failure_reason());
		// With alpha, as gray and alpha to put on white; stb_image would
		// drop the alpha.
		const bool alpha = channels == 2 || channels == 4;
		std::unique_ptr<stbi_uc, void (*)(void*)> pixels(
			stbi_load_from_memory(data, size, &w, &h, &channels, alpha ? 2 : 1), stbi_image_free);
		if (!pixels)
			return fail(ctx, FZX_ERR_IMAGE, std::string("Cannot decode image: ") + stbi_failure_reason());
		if (alpha) {
			// In place: pixel i is read from 2i and 2i + 1 before it is written.
			stbi_uc* p = pixels.get();
			const size_t n = static_cast<size_t>(w) * h;
			for (size_t i = 0; i < n; i++)
				p[i] = onWhite(p[2 * i], p[2 * i + 1]);
		}
		const ImageView iv(pixels.get(), w, h, ImageFormat::Lum);
		auto barcodes = ReadBarcodes(iv, opts);
		encodeBarcodes(ctx, barcodes, w, h, 0, 0, &iv);
		return static_cast<int>(barcodes.size());
	});
}

int fzx_merge(fzx_ctx* ctx, const uint8_t* data, int size, int character_set)
{
	return guarded(ctx, FZX_ERR_ARGUMENT, [&] {
		if (character_set < 0 || character_set >= static_cast<int>(CharacterSet::CharsetCount))
			throw std::invalid_argument("Unknown character set " + std::to_string(character_set));
		Content merged;
		merged.defaultCharset = static_cast<CharacterSet>(character_set);
		const auto bad = [] { return std::invalid_argument("Malformed parts to merge"); };
		const auto i32 = [](const uint8_t* p) {
			int32_t v;
			std::memcpy(&v, p, 4);
			return v;
		};
		size_t i = 0;
		const size_t n = data && size > 0 ? static_cast<size_t>(size) : 0;
		for (bool first = true; i < n; first = false) {
			// u32 length, then a "merge" field, see writeMergeData.
			if (n - i < 4)
				throw bad();
			const uint32_t len = static_cast<uint32_t>(i32(data + i));
			i += 4;
			if (len > n - i || len < 9 || data[i + 3] > static_cast<uint8_t>(AIFlag::AIM))
				throw bad();
			const uint8_t* p = data + i;
			i += len;
			Content part;
			part.symbology.code = static_cast<char>(p[0]);
			part.symbology.modifier = static_cast<char>(p[1]);
			part.symbology.eciModifierOffset = static_cast<signed char>(p[2]);
			part.symbology.aiFlag = static_cast<AIFlag>(p[3]);
			part.hasECI = p[4] != 0;
			const uint32_t count = static_cast<uint32_t>(i32(p + 5));
			if (count > (len - 9) / 8)
				throw bad();
			const size_t at = 9 + static_cast<size_t>(count) * 8;
			const int bytes = static_cast<int>(len - at);
			for (uint32_t k = 0, last = 0; k < count; k++) {
				const int32_t eci = i32(p + 9 + k * 8);
				const int32_t pos = i32(p + 13 + k * 8);
				if (pos < static_cast<int32_t>(last) || pos > bytes)
					throw bad();
				last = static_cast<uint32_t>(pos);
				part.encodings.push_back({static_cast<ECI>(eci), pos});
			}
			part.bytes.assign(p + at, p + len);
			if (first)
				merged.symbology = part.symbology;
			merged.append(part);
		}
		if (merged.empty())
			throw std::invalid_argument("Nothing to merge");

		ctx->out.clear();
		Writer w{ctx->out};
		w.u32(FZX_ABI_VERSION);
		w.u32(KIND_MERGED);
		w.u8(static_cast<uint8_t>(merged.type()));
		w.str(merged.text(TextMode::HRI));
		w.blob(merged.bytes.data(), merged.bytes.size());
		return 0;
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
