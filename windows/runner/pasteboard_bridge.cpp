#include "pasteboard_bridge.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <optional>
#include <utility>
#include <vector>

#include "utils.h"

namespace {

using Microsoft::WRL::ComPtr;
using Bytes = std::vector<uint8_t>;
using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kPasteboardChannelName[] = "field_notes/pasteboard";
constexpr char kContentsMethod[] = "contents";
constexpr char kImageMethod[] = "image";
constexpr char kImageFileMethod[] = "imageFile";
constexpr char kPathArgument[] = "path";
constexpr char kPngImageType[] = "png";
constexpr char kBitmapImageType[] = "bitmap";
constexpr char kPngMime[] = "image/png";
constexpr wchar_t kPngClipboardFormat[] = L"PNG";
constexpr wchar_t kImageFileMessageName[] = L"FieldNotes.PasteboardImageFile";
constexpr wchar_t kOrientationQuery[] = L"System.Photo.Orientation";
constexpr USHORT kUprightOrientation = 1;
constexpr UINT kConvertedLongEdge = 2048;
constexpr int kClipboardAttempts = 5;
constexpr DWORD kClipboardRetryMilliseconds = 10;

struct Orientation {
  WICBitmapTransformOptions rotation;
  WICBitmapTransformOptions flip;
};

struct ImageFileJob {
  HWND window;
  UINT message;
  std::wstring path;
  Result result;
  std::optional<Bytes> png;
};

class ClipboardLock {
 public:
  explicit ClipboardLock(HWND owner) : open_(Open(owner)) {}

  ~ClipboardLock() {
    if (open_ && !::CloseClipboard()) {
      OutputDebugStringW(L"Field Notes could not close the clipboard.\n");
    }
  }

  ClipboardLock(const ClipboardLock&) = delete;
  ClipboardLock& operator=(const ClipboardLock&) = delete;

  bool open() const { return open_; }

 private:
  static bool Open(HWND owner) {
    for (int attempt = 0; attempt < kClipboardAttempts; ++attempt) {
      if (::OpenClipboard(owner)) {
        return true;
      }
      ::Sleep(kClipboardRetryMilliseconds);
    }
    return false;
  }

  bool open_;
};

bool FormatAvailable(UINT format) {
  return format != 0 && ::IsClipboardFormatAvailable(format) != FALSE;
}

std::optional<Bytes> GlobalBytes(HANDLE handle) {
  if (handle == nullptr) {
    return std::nullopt;
  }
  const SIZE_T size = ::GlobalSize(handle);
  const void* data = ::GlobalLock(handle);
  if (data == nullptr) {
    return std::nullopt;
  }
  const uint8_t* begin = static_cast<const uint8_t*>(data);
  const Bytes bytes(begin, begin + size);
  ::GlobalUnlock(handle);
  if (bytes.empty()) {
    return std::nullopt;
  }
  return bytes;
}

flutter::EncodableValue ImageAnswer(const Bytes& png) {
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("bytes"), flutter::EncodableValue(png)},
      {flutter::EncodableValue("mime"), flutter::EncodableValue(kPngMime)},
  });
}

ComPtr<IWICImagingFactory> ImagingFactory() {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(::CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&factory)))) {
    return nullptr;
  }
  return factory;
}

Orientation OrientationFor(USHORT exif) {
  switch (exif) {
    case 2:
      return {WICBitmapTransformRotate0, WICBitmapTransformFlipHorizontal};
    case 3:
      return {WICBitmapTransformRotate180, WICBitmapTransformRotate0};
    case 4:
      return {WICBitmapTransformRotate0, WICBitmapTransformFlipVertical};
    case 5:
      return {WICBitmapTransformRotate90, WICBitmapTransformFlipHorizontal};
    case 6:
      return {WICBitmapTransformRotate90, WICBitmapTransformRotate0};
    case 7:
      return {WICBitmapTransformRotate270, WICBitmapTransformFlipHorizontal};
    case 8:
      return {WICBitmapTransformRotate270, WICBitmapTransformRotate0};
    default:
      return {WICBitmapTransformRotate0, WICBitmapTransformRotate0};
  }
}

USHORT PhotoOrientation(IWICBitmapFrameDecode* frame) {
  ComPtr<IWICMetadataQueryReader> reader;
  if (FAILED(frame->GetMetadataQueryReader(&reader))) {
    return kUprightOrientation;
  }
  PROPVARIANT value;
  PropVariantInit(&value);
  const bool found =
      SUCCEEDED(reader->GetMetadataByName(kOrientationQuery, &value)) &&
      value.vt == VT_UI2;
  const USHORT orientation = found ? value.uiVal : kUprightOrientation;
  if (FAILED(::PropVariantClear(&value))) {
    OutputDebugStringW(L"Field Notes could not clear a photo property.\n");
  }
  return orientation;
}

UINT ScaledLength(UINT length, UINT longest) {
  const double scaled = std::round(static_cast<double>(length) *
                                   kConvertedLongEdge / longest);
  return std::max<UINT>(1, static_cast<UINT>(scaled));
}

ComPtr<IWICBitmapSource> Bgra(IWICImagingFactory* factory,
                              IWICBitmapSource* image) {
  ComPtr<IWICFormatConverter> converter;
  if (FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(image, GUID_WICPixelFormat32bppBGRA,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom))) {
    return nullptr;
  }
  return converter;
}

ComPtr<IWICBitmapSource> Fitted(IWICImagingFactory* factory,
                                const ComPtr<IWICBitmapSource>& image) {
  UINT width = 0;
  UINT height = 0;
  if (image.Get() == nullptr ||
      FAILED(image->GetSize(&width, &height)) || width == 0 || height == 0) {
    return nullptr;
  }
  const UINT longest = std::max(width, height);
  if (longest <= kConvertedLongEdge) {
    return image;
  }
  ComPtr<IWICBitmapScaler> scaler;
  if (FAILED(factory->CreateBitmapScaler(&scaler)) ||
      FAILED(scaler->Initialize(image.Get(), ScaledLength(width, longest),
                                ScaledLength(height, longest),
                                WICBitmapInterpolationModeFant))) {
    return nullptr;
  }
  return scaler;
}

ComPtr<IWICBitmapSource> Materialized(IWICImagingFactory* factory,
                                      const ComPtr<IWICBitmapSource>& image) {
  ComPtr<IWICBitmap> bitmap;
  if (image.Get() == nullptr ||
      FAILED(factory->CreateBitmapFromSource(image.Get(), WICBitmapCacheOnLoad,
                                             &bitmap))) {
    return nullptr;
  }
  return bitmap;
}

ComPtr<IWICBitmapSource> Transformed(IWICImagingFactory* factory,
                                     const ComPtr<IWICBitmapSource>& image,
                                     WICBitmapTransformOptions options) {
  if (image.Get() == nullptr || options == WICBitmapTransformRotate0) {
    return image;
  }
  ComPtr<IWICBitmapFlipRotator> rotator;
  if (FAILED(factory->CreateBitmapFlipRotator(&rotator)) ||
      FAILED(rotator->Initialize(image.Get(), options))) {
    return nullptr;
  }
  return Materialized(factory, rotator);
}

std::optional<Bytes> EncodePng(IWICImagingFactory* factory,
                               const ComPtr<IWICBitmapSource>& image) {
  UINT width = 0;
  UINT height = 0;
  if (image.Get() == nullptr || FAILED(image->GetSize(&width, &height))) {
    return std::nullopt;
  }
  ComPtr<IStream> stream;
  ComPtr<IWICBitmapEncoder> encoder;
  ComPtr<IWICBitmapFrameEncode> frame;
  WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
  if (FAILED(::CreateStreamOnHGlobal(nullptr, TRUE, &stream)) ||
      FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder)) ||
      FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache)) ||
      FAILED(encoder->CreateNewFrame(&frame, nullptr)) ||
      FAILED(frame->Initialize(nullptr)) ||
      FAILED(frame->SetSize(width, height)) ||
      FAILED(frame->SetPixelFormat(&format)) ||
      FAILED(frame->WriteSource(image.Get(), nullptr)) ||
      FAILED(frame->Commit()) || FAILED(encoder->Commit())) {
    return std::nullopt;
  }
  STATSTG stat{};
  HGLOBAL global = nullptr;
  if (FAILED(stream->Stat(&stat, STATFLAG_NONAME)) ||
      FAILED(::GetHGlobalFromStream(stream.Get(), &global))) {
    return std::nullopt;
  }
  const void* data = ::GlobalLock(global);
  if (data == nullptr) {
    return std::nullopt;
  }
  const uint8_t* begin = static_cast<const uint8_t*>(data);
  const Bytes png(begin, begin + static_cast<size_t>(stat.cbSize.QuadPart));
  ::GlobalUnlock(global);
  return png;
}

std::optional<Bytes> PngFromImage(IWICImagingFactory* factory,
                                  IWICBitmapSource* image,
                                  const Orientation& orientation) {
  const ComPtr<IWICBitmapSource> pixels =
      Materialized(factory, Fitted(factory, Bgra(factory, image)));
  const ComPtr<IWICBitmapSource> oriented = Transformed(
      factory, Transformed(factory, pixels, orientation.rotation),
      orientation.flip);
  return EncodePng(factory, oriented);
}

std::optional<Bytes> PngFromBitmap(HBITMAP bitmap) {
  const ComPtr<IWICImagingFactory> factory = ImagingFactory();
  ComPtr<IWICBitmap> image;
  if (factory.Get() == nullptr || bitmap == nullptr ||
      FAILED(factory->CreateBitmapFromHBITMAP(bitmap, nullptr,
                                              WICBitmapIgnoreAlpha, &image))) {
    return std::nullopt;
  }
  return PngFromImage(factory.Get(), image.Get(),
                      OrientationFor(kUprightOrientation));
}

std::optional<Bytes> PngFromFile(const std::wstring& path) {
  const ComPtr<IWICImagingFactory> factory = ImagingFactory();
  ComPtr<IWICBitmapDecoder> decoder;
  ComPtr<IWICBitmapFrameDecode> frame;
  if (factory.Get() == nullptr || path.empty() ||
      FAILED(factory->CreateDecoderFromFilename(
          path.c_str(), nullptr, GENERIC_READ, WICDecodeMetadataCacheOnDemand,
          &decoder)) ||
      FAILED(decoder->GetFrame(0, &frame))) {
    return std::nullopt;
  }
  return PngFromImage(factory.Get(), frame.Get(),
                      OrientationFor(PhotoOrientation(frame.Get())));
}

DWORD WINAPI ConvertImageFileOffThread(LPVOID parameter) {
  ImageFileJob* job = static_cast<ImageFileJob*>(parameter);
  if (SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {
    job->png = PngFromFile(job->path);
    ::CoUninitialize();
  }
  if (!::PostMessage(job->window, job->message, 0,
                     reinterpret_cast<LPARAM>(job))) {
    delete job;
  }
  return 0;
}

}

PasteboardBridge::PasteboardBridge(flutter::BinaryMessenger* messenger,
                                   HWND window)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kPasteboardChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      png_format_(::RegisterClipboardFormatW(kPngClipboardFormat)),
      image_file_message_(::RegisterWindowMessageW(kImageFileMessageName)) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             Result result) { Handle(call, std::move(result)); });
}

bool PasteboardBridge::IsImageFileMessage(UINT message) const {
  return image_file_message_ != 0 && message == image_file_message_;
}

void PasteboardBridge::CompleteImageFile(LPARAM job) {
  const std::unique_ptr<ImageFileJob> finished(
      reinterpret_cast<ImageFileJob*>(job));
  if (finished->png.has_value()) {
    finished->result->Success(ImageAnswer(*finished->png));
    return;
  }
  finished->result->Success();
}

void PasteboardBridge::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    Result result) {
  const std::string& method = call.method_name();
  if (method == kContentsMethod) {
    result->Success(Contents());
  } else if (method == kImageMethod) {
    result->Success(Image());
  } else if (method == kImageFileMethod) {
    const std::string* path = StringArgument(call.arguments(), kPathArgument);
    if (path == nullptr) {
      result->Error("bad-arguments",
                    "imageFile expects a string under \"path\"");
      return;
    }
    ConvertImageFile(*path, std::move(result));
  } else {
    result->NotImplemented();
  }
}

flutter::EncodableValue PasteboardBridge::Contents() const {
  flutter::EncodableList paths;
  flutter::EncodableList image_types;
  const ClipboardLock clipboard(window_);
  if (clipboard.open()) {
    if (FormatAvailable(CF_HDROP)) {
      for (const std::string& path :
           PathsFromDrop(static_cast<HDROP>(::GetClipboardData(CF_HDROP)))) {
        paths.push_back(flutter::EncodableValue(path));
      }
    }
    if (FormatAvailable(png_format_)) {
      image_types.push_back(flutter::EncodableValue(kPngImageType));
    }
    if (FormatAvailable(CF_DIBV5) || FormatAvailable(CF_DIB)) {
      image_types.push_back(flutter::EncodableValue(kBitmapImageType));
    }
  }
  const bool has_text = clipboard.open() && FormatAvailable(CF_UNICODETEXT);
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("paths"), flutter::EncodableValue(paths)},
      {flutter::EncodableValue("imageTypes"),
       flutter::EncodableValue(image_types)},
      {flutter::EncodableValue("hasText"), flutter::EncodableValue(has_text)},
  });
}

flutter::EncodableValue PasteboardBridge::Image() const {
  const ClipboardLock clipboard(window_);
  if (!clipboard.open()) {
    return flutter::EncodableValue();
  }
  if (FormatAvailable(png_format_)) {
    const std::optional<Bytes> png =
        GlobalBytes(::GetClipboardData(png_format_));
    if (png.has_value()) {
      return ImageAnswer(*png);
    }
  }
  if (FormatAvailable(CF_DIBV5) || FormatAvailable(CF_DIB) ||
      FormatAvailable(CF_BITMAP)) {
    const std::optional<Bytes> png =
        PngFromBitmap(static_cast<HBITMAP>(::GetClipboardData(CF_BITMAP)));
    if (png.has_value()) {
      return ImageAnswer(*png);
    }
  }
  return flutter::EncodableValue();
}

void PasteboardBridge::ConvertImageFile(const std::string& path,
                                        Result result) {
  if (image_file_message_ == 0) {
    result->Success();
    return;
  }
  ImageFileJob* job = new ImageFileJob{window_, image_file_message_,
                                       Utf16FromUtf8(path), std::move(result),
                                       std::nullopt};
  HANDLE thread =
      ::CreateThread(nullptr, 0, ConvertImageFileOffThread, job, 0, nullptr);
  if (thread == nullptr) {
    const std::unique_ptr<ImageFileJob> unstarted(job);
    unstarted->result->Success();
    return;
  }
  if (!::CloseHandle(thread)) {
    OutputDebugStringW(L"Field Notes could not release a worker thread.\n");
  }
}
