#include "video_frames_bridge.h"

#include <flutter/standard_method_codec.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propidl.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <optional>
#include <string>
#include <utility>
#include <variant>
#include <vector>

#include "utils.h"

namespace {

using Microsoft::WRL::ComPtr;
using Bytes = std::vector<uint8_t>;
using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kVideoFramesChannelName[] = "field_notes/video_frames";
constexpr char kFrameAtMethod[] = "frameAt";
constexpr char kPathArgument[] = "path";
constexpr char kPositionMsArgument[] = "positionMs";
constexpr char kWidthArgument[] = "width";
constexpr char kBadArgumentsCode[] = "bad_arguments";
constexpr char kBadArgumentsMessage[] =
    "frameAt expects a string under \"path\", a position of at least zero "
    "under \"positionMs\" and a positive integer under \"width\"";
constexpr wchar_t kFrameMessageName[] = L"FieldNotes.VideoFrame";
constexpr DWORD kVideoStream =
    static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);
constexpr DWORD kAllStreams = static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS);
constexpr LONGLONG kTicksPerMillisecond = 10000;
constexpr int kMostSamplesRead = 120;
constexpr UINT32 kBytesPerPixel = 4;
constexpr int64_t kWidestFrame = 4096;

struct FrameJob {
  HWND window;
  UINT message;
  std::wstring path;
  LONGLONG position;
  UINT width;
  Result result;
  std::optional<Bytes> jpeg;
};

struct FramePixels {
  Bytes bgrx;
  UINT32 width;
  UINT32 height;
  WICBitmapTransformOptions upright;
};

ComPtr<IMFSourceReader> OpenRgbReader(const std::wstring& path) {
  ComPtr<IMFAttributes> attributes;
  ComPtr<IMFSourceReader> reader;
  ComPtr<IMFMediaType> type;
  if (FAILED(::MFCreateAttributes(&attributes, 1)) ||
      FAILED(attributes->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING,
                                   TRUE)) ||
      FAILED(::MFCreateSourceReaderFromURL(path.c_str(), attributes.Get(),
                                           &reader)) ||
      FAILED(reader->SetStreamSelection(kAllStreams, FALSE)) ||
      FAILED(reader->SetStreamSelection(kVideoStream, TRUE)) ||
      FAILED(::MFCreateMediaType(&type)) ||
      FAILED(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video)) ||
      FAILED(type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32)) ||
      FAILED(reader->SetCurrentMediaType(kVideoStream, nullptr, type.Get()))) {
    return nullptr;
  }
  return reader;
}

bool SeekTo(IMFSourceReader* reader, LONGLONG position) {
  PROPVARIANT value;
  PropVariantInit(&value);
  value.vt = VT_I8;
  value.hVal.QuadPart = position;
  const HRESULT sought = reader->SetCurrentPosition(GUID_NULL, value);
  if (FAILED(::PropVariantClear(&value))) {
    OutputDebugStringW(L"Field Notes could not clear a seek position.\n");
  }
  return SUCCEEDED(sought);
}

ComPtr<IMFSample> SampleNear(IMFSourceReader* reader, LONGLONG position) {
  ComPtr<IMFSample> earlier;
  LONGLONG earlier_timestamp = 0;
  for (int read = 0; read < kMostSamplesRead; ++read) {
    DWORD flags = 0;
    LONGLONG timestamp = 0;
    ComPtr<IMFSample> sample;
    if (FAILED(reader->ReadSample(kVideoStream, 0, nullptr, &flags, &timestamp,
                                  &sample)) ||
        (flags & MF_SOURCE_READERF_ERROR) != 0) {
      return nullptr;
    }
    if (sample.Get() != nullptr) {
      if (timestamp >= position) {
        const bool earlier_is_nearer =
            earlier.Get() != nullptr &&
            position - earlier_timestamp < timestamp - position;
        return earlier_is_nearer ? earlier : sample;
      }
      earlier = sample;
      earlier_timestamp = timestamp;
    }
    if ((flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0) {
      return earlier;
    }
  }
  return earlier;
}

WICBitmapTransformOptions UprightTransform(IMFSourceReader* reader) {
  ComPtr<IMFMediaType> native;
  if (FAILED(reader->GetNativeMediaType(kVideoStream, 0, &native))) {
    return WICBitmapTransformRotate0;
  }
  switch (MFGetAttributeUINT32(native.Get(), MF_MT_VIDEO_ROTATION,
                               MFVideoRotationFormat_0)) {
    case MFVideoRotationFormat_90:
      return WICBitmapTransformRotate90;
    case MFVideoRotationFormat_180:
      return WICBitmapTransformRotate180;
    case MFVideoRotationFormat_270:
      return WICBitmapTransformRotate270;
    default:
      return WICBitmapTransformRotate0;
  }
}

bool CopyLines(IMF2DBuffer* lines, Bytes* target, LONG row, UINT32 height) {
  BYTE* first_line = nullptr;
  LONG stride = 0;
  if (FAILED(lines->Lock2D(&first_line, &stride))) {
    return false;
  }
  const HRESULT copied = ::MFCopyImage(target->data(), row, first_line, stride,
                                       static_cast<DWORD>(row), height);
  if (FAILED(lines->Unlock2D())) {
    OutputDebugStringW(L"Field Notes could not unlock a video frame.\n");
  }
  return SUCCEEDED(copied);
}

bool CopyContiguous(IMFMediaBuffer* buffer,
                    LONG stride,
                    Bytes* target,
                    LONG row,
                    UINT32 height) {
  BYTE* data = nullptr;
  DWORD length = 0;
  if (FAILED(buffer->Lock(&data, nullptr, &length))) {
    return false;
  }
  const LONGLONG line_bytes = stride < 0 ? -static_cast<LONGLONG>(stride)
                                         : static_cast<LONGLONG>(stride);
  const bool fits = line_bytes >= row &&
                    static_cast<LONGLONG>(length) >= line_bytes * height;
  const BYTE* first_line = stride < 0 && fits
                               ? data + line_bytes * (height - 1)
                               : data;
  const HRESULT copied =
      fits ? ::MFCopyImage(target->data(), row, first_line, stride,
                           static_cast<DWORD>(row), height)
           : E_UNEXPECTED;
  if (FAILED(buffer->Unlock())) {
    OutputDebugStringW(L"Field Notes could not unlock a video frame.\n");
  }
  return SUCCEEDED(copied);
}

std::optional<FramePixels> PixelsOf(IMFSourceReader* reader,
                                    IMFSample* sample) {
  ComPtr<IMFMediaType> type;
  ComPtr<IMFMediaBuffer> buffer;
  UINT32 stored_width = 0;
  UINT32 stored_height = 0;
  if (FAILED(reader->GetCurrentMediaType(kVideoStream, &type)) ||
      FAILED(::MFGetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, &stored_width,
                                  &stored_height)) ||
      stored_width == 0 || stored_height == 0 ||
      FAILED(sample->ConvertToContiguousBuffer(&buffer))) {
    return std::nullopt;
  }
  MFVideoArea visible{};
  const bool has_aperture = SUCCEEDED(
      type->GetBlob(MF_MT_MINIMUM_DISPLAY_APERTURE,
                    reinterpret_cast<UINT8*>(&visible), sizeof(visible),
                    nullptr));
  const UINT32 width =
      has_aperture && visible.Area.cx > 0
          ? std::min(stored_width, static_cast<UINT32>(visible.Area.cx))
          : stored_width;
  const UINT32 height =
      has_aperture && visible.Area.cy > 0
          ? std::min(stored_height, static_cast<UINT32>(visible.Area.cy))
          : stored_height;
  const LONG row = static_cast<LONG>(width * kBytesPerPixel);
  Bytes bgrx(static_cast<size_t>(row) * height);
  ComPtr<IMF2DBuffer> lines;
  const bool copied =
      SUCCEEDED(buffer->QueryInterface(IID_PPV_ARGS(&lines)))
          ? CopyLines(lines.Get(), &bgrx, row, height)
          : CopyContiguous(
                buffer.Get(),
                static_cast<LONG>(MFGetAttributeUINT32(
                    type.Get(), MF_MT_DEFAULT_STRIDE,
                    stored_width * kBytesPerPixel)),
                &bgrx, row, height);
  if (!copied) {
    return std::nullopt;
  }
  return FramePixels{std::move(bgrx), width, height, UprightTransform(reader)};
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

ComPtr<IWICBitmapSource> BitmapOf(IWICImagingFactory* factory,
                                  FramePixels* pixels) {
  ComPtr<IWICBitmap> bitmap;
  if (FAILED(factory->CreateBitmapFromMemory(
          pixels->width, pixels->height, GUID_WICPixelFormat32bppBGR,
          pixels->width * kBytesPerPixel,
          static_cast<UINT>(pixels->bgrx.size()), pixels->bgrx.data(),
          &bitmap))) {
    return nullptr;
  }
  return bitmap;
}

UINT ScaledLength(UINT32 length, UINT32 target_width, UINT32 upright_width) {
  const double scaled = std::round(static_cast<double>(length) * target_width /
                                   upright_width);
  return std::max<UINT>(1, static_cast<UINT>(scaled));
}

ComPtr<IWICBitmapSource> ScaledToWidth(IWICImagingFactory* factory,
                                       const ComPtr<IWICBitmapSource>& image,
                                       const FramePixels& pixels,
                                       UINT requested_width) {
  const bool sideways = pixels.upright == WICBitmapTransformRotate90 ||
                        pixels.upright == WICBitmapTransformRotate270;
  const UINT32 upright_width = sideways ? pixels.height : pixels.width;
  if (image.Get() == nullptr || upright_width <= requested_width) {
    return image;
  }
  ComPtr<IWICBitmapScaler> scaler;
  if (FAILED(factory->CreateBitmapScaler(&scaler)) ||
      FAILED(scaler->Initialize(
          image.Get(),
          ScaledLength(pixels.width, requested_width, upright_width),
          ScaledLength(pixels.height, requested_width, upright_width),
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

ComPtr<IWICBitmapSource> Upright(IWICImagingFactory* factory,
                                 const ComPtr<IWICBitmapSource>& image,
                                 WICBitmapTransformOptions transform) {
  if (image.Get() == nullptr || transform == WICBitmapTransformRotate0) {
    return image;
  }
  ComPtr<IWICBitmapFlipRotator> rotator;
  if (FAILED(factory->CreateBitmapFlipRotator(&rotator)) ||
      FAILED(rotator->Initialize(image.Get(), transform))) {
    return nullptr;
  }
  return rotator;
}

ComPtr<IWICBitmapSource> Bgr24(IWICImagingFactory* factory,
                               const ComPtr<IWICBitmapSource>& image) {
  ComPtr<IWICFormatConverter> converter;
  if (image.Get() == nullptr ||
      FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(image.Get(), GUID_WICPixelFormat24bppBGR,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom))) {
    return nullptr;
  }
  return converter;
}

std::optional<Bytes> EncodeJpeg(IWICImagingFactory* factory,
                                const ComPtr<IWICBitmapSource>& image) {
  UINT width = 0;
  UINT height = 0;
  if (image.Get() == nullptr || FAILED(image->GetSize(&width, &height))) {
    return std::nullopt;
  }
  ComPtr<IStream> stream;
  ComPtr<IWICBitmapEncoder> encoder;
  ComPtr<IWICBitmapFrameEncode> frame;
  WICPixelFormatGUID format = GUID_WICPixelFormat24bppBGR;
  if (FAILED(::CreateStreamOnHGlobal(nullptr, TRUE, &stream)) ||
      FAILED(factory->CreateEncoder(GUID_ContainerFormatJpeg, nullptr,
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
  const Bytes jpeg(begin, begin + static_cast<size_t>(stat.cbSize.QuadPart));
  ::GlobalUnlock(global);
  return jpeg;
}

std::optional<Bytes> ExtractJpeg(const std::wstring& path,
                                 LONGLONG position,
                                 UINT width) {
  const ComPtr<IMFSourceReader> reader = OpenRgbReader(path);
  if (reader.Get() == nullptr || !SeekTo(reader.Get(), position)) {
    return std::nullopt;
  }
  const ComPtr<IMFSample> sample = SampleNear(reader.Get(), position);
  if (sample.Get() == nullptr) {
    return std::nullopt;
  }
  std::optional<FramePixels> pixels = PixelsOf(reader.Get(), sample.Get());
  const ComPtr<IWICImagingFactory> factory = ImagingFactory();
  if (!pixels.has_value() || factory.Get() == nullptr) {
    return std::nullopt;
  }
  const ComPtr<IWICBitmapSource> scaled = Materialized(
      factory.Get(), ScaledToWidth(factory.Get(),
                                   BitmapOf(factory.Get(), &*pixels), *pixels,
                                   width));
  return EncodeJpeg(
      factory.Get(),
      Bgr24(factory.Get(), Upright(factory.Get(), scaled, pixels->upright)));
}

DWORD WINAPI ExtractOffThread(LPVOID parameter) {
  FrameJob* job = static_cast<FrameJob*>(parameter);
  if (SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {
    if (SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
      job->jpeg = ExtractJpeg(job->path, job->position, job->width);
      if (FAILED(::MFShutdown())) {
        OutputDebugStringW(L"Field Notes could not stop Media Foundation.\n");
      }
    }
    ::CoUninitialize();
  }
  if (!::PostMessage(job->window, job->message, 0,
                     reinterpret_cast<LPARAM>(job))) {
    delete job;
  }
  return 0;
}

std::optional<int64_t> IntegerArgument(
    const flutter::EncodableValue* arguments,
    const char* key) {
  const flutter::EncodableMap* map =
      std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) {
    return std::nullopt;
  }
  const flutter::EncodableMap::const_iterator entry =
      map->find(flutter::EncodableValue(key));
  if (entry == map->end()) {
    return std::nullopt;
  }
  const int32_t* narrow = std::get_if<int32_t>(&entry->second);
  if (narrow != nullptr) {
    return *narrow;
  }
  const int64_t* wide = std::get_if<int64_t>(&entry->second);
  if (wide != nullptr) {
    return *wide;
  }
  return std::nullopt;
}

}

VideoFramesBridge::VideoFramesBridge(flutter::BinaryMessenger* messenger,
                                     HWND window)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kVideoFramesChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      frame_message_(::RegisterWindowMessageW(kFrameMessageName)) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             Result result) { Handle(call, std::move(result)); });
}

bool VideoFramesBridge::IsFrameMessage(UINT message) const {
  return frame_message_ != 0 && message == frame_message_;
}

void VideoFramesBridge::CompleteFrame(LPARAM job) {
  const std::unique_ptr<FrameJob> finished(reinterpret_cast<FrameJob*>(job));
  if (!finished->jpeg.has_value()) {
    finished->result->Success();
    return;
  }
  finished->result->Success(flutter::EncodableValue(*finished->jpeg));
}

void VideoFramesBridge::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    Result result) {
  if (call.method_name() != kFrameAtMethod) {
    result->NotImplemented();
    return;
  }
  const std::string* path = StringArgument(call.arguments(), kPathArgument);
  const std::optional<int64_t> position_ms =
      IntegerArgument(call.arguments(), kPositionMsArgument);
  const std::optional<int64_t> width =
      IntegerArgument(call.arguments(), kWidthArgument);
  if (path == nullptr || path->empty() || !position_ms.has_value() ||
      *position_ms < 0 || !width.has_value() || *width <= 0 ||
      *width > kWidestFrame) {
    result->Error(kBadArgumentsCode, kBadArgumentsMessage);
    return;
  }
  if (frame_message_ == 0) {
    result->Success();
    return;
  }
  FrameJob* job = new FrameJob{window_,
                               frame_message_,
                               Utf16FromUtf8(*path),
                               *position_ms * kTicksPerMillisecond,
                               static_cast<UINT>(*width),
                               std::move(result),
                               std::nullopt};
  HANDLE thread = ::CreateThread(nullptr, 0, ExtractOffThread, job, 0, nullptr);
  if (thread == nullptr) {
    const std::unique_ptr<FrameJob> unstarted(job);
    unstarted->result->Success();
    return;
  }
  if (!::CloseHandle(thread)) {
    OutputDebugStringW(L"Field Notes could not release a worker thread.\n");
  }
}
