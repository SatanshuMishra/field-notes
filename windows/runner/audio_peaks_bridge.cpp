#include "audio_peaks_bridge.h"

#include <flutter/standard_method_codec.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <optional>
#include <utility>
#include <variant>
#include <vector>

#include "utils.h"

namespace {

using Microsoft::WRL::ComPtr;
using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kAudioPeaksChannelName[] = "field_notes/audio_peaks";
constexpr char kWindowRmsMethod[] = "windowRms";
constexpr char kPathArgument[] = "path";
constexpr char kWindowMsArgument[] = "windowMs";
constexpr char kDecodeFailedCode[] = "decode-failed";
constexpr char kDecodeFailedMessage[] = "The recording could not be decoded.";
constexpr wchar_t kDecodedMessageName[] = L"FieldNotes.AudioPeaksDecoded";
constexpr DWORD kAudioStream =
    static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM);
constexpr DWORD kAllStreams = static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS);
constexpr UINT32 kFloatBits = 32;

struct DecodeJob {
  HWND window;
  UINT message;
  std::wstring path;
  int window_ms;
  Result result;
  std::optional<std::vector<double>> rms;
};

class RmsWindows {
 public:
  explicit RmsWindows(int window_ms) : window_ms_(window_ms) {}

  bool Reformat(IMFMediaType* type) {
    UINT32 sample_rate = 0;
    UINT32 channels = 0;
    UINT32 bits = 0;
    if (type == nullptr ||
        FAILED(type->GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                               &sample_rate)) ||
        FAILED(type->GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, &channels)) ||
        FAILED(type->GetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, &bits)) ||
        sample_rate == 0 || channels == 0 || bits != kFloatBits) {
      return false;
    }
    const double frames =
        static_cast<double>(sample_rate) * window_ms_ / 1000.0;
    channels_ = channels;
    window_frames_ =
        std::max<uint64_t>(1, static_cast<uint64_t>(std::llround(frames)));
    return true;
  }

  void Add(const float* samples, size_t count) {
    const size_t frames = count / channels_;
    for (size_t frame = 0; frame < frames; ++frame) {
      double mono = 0.0;
      for (UINT32 channel = 0; channel < channels_; ++channel) {
        mono += samples[frame * channels_ + channel];
      }
      mono /= channels_;
      sum_ += mono * mono;
      ++filled_;
      if (filled_ >= window_frames_) {
        CompleteWindow();
      }
    }
  }

  std::vector<double> Finish() {
    if (filled_ > 0) {
      CompleteWindow();
    }
    return std::move(values_);
  }

 private:
  void CompleteWindow() {
    values_.push_back(std::sqrt(sum_ / static_cast<double>(filled_)));
    sum_ = 0.0;
    filled_ = 0;
  }

  int window_ms_;
  UINT32 channels_ = 1;
  uint64_t window_frames_ = 1;
  uint64_t filled_ = 0;
  double sum_ = 0.0;
  std::vector<double> values_;
};

std::optional<int> IntArgument(const flutter::EncodableValue* arguments,
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
  const int32_t* value = std::get_if<int32_t>(&entry->second);
  if (value == nullptr) {
    return std::nullopt;
  }
  return *value;
}

bool AddSample(IMFSample* sample, RmsWindows& windows) {
  ComPtr<IMFMediaBuffer> buffer;
  BYTE* data = nullptr;
  DWORD length = 0;
  if (FAILED(sample->ConvertToContiguousBuffer(&buffer)) ||
      FAILED(buffer->Lock(&data, nullptr, &length))) {
    return false;
  }
  windows.Add(reinterpret_cast<const float*>(data), length / sizeof(float));
  return SUCCEEDED(buffer->Unlock());
}

std::optional<std::vector<double>> WindowRms(const std::wstring& path,
                                             int window_ms) {
  ComPtr<IMFSourceReader> reader;
  ComPtr<IMFMediaType> requested;
  ComPtr<IMFMediaType> current;
  if (path.empty() ||
      FAILED(::MFCreateSourceReaderFromURL(path.c_str(), nullptr, &reader)) ||
      FAILED(reader->SetStreamSelection(kAllStreams, FALSE)) ||
      FAILED(reader->SetStreamSelection(kAudioStream, TRUE)) ||
      FAILED(::MFCreateMediaType(&requested)) ||
      FAILED(requested->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio)) ||
      FAILED(requested->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_Float)) ||
      FAILED(reader->SetCurrentMediaType(kAudioStream, nullptr,
                                         requested.Get())) ||
      FAILED(reader->GetCurrentMediaType(kAudioStream, &current))) {
    return std::nullopt;
  }
  RmsWindows windows(window_ms);
  if (!windows.Reformat(current.Get())) {
    return std::nullopt;
  }
  bool ended = false;
  while (!ended) {
    DWORD flags = 0;
    ComPtr<IMFSample> sample;
    if (FAILED(reader->ReadSample(kAudioStream, 0, nullptr, &flags, nullptr,
                                  &sample)) ||
        (flags & MF_SOURCE_READERF_ERROR) != 0) {
      return std::nullopt;
    }
    if ((flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) != 0) {
      ComPtr<IMFMediaType> changed;
      if (FAILED(reader->GetCurrentMediaType(kAudioStream, &changed)) ||
          !windows.Reformat(changed.Get())) {
        return std::nullopt;
      }
    }
    if (sample.Get() != nullptr && !AddSample(sample.Get(), windows)) {
      return std::nullopt;
    }
    ended = (flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0;
  }
  return windows.Finish();
}

DWORD WINAPI DecodeOffThread(LPVOID parameter) {
  DecodeJob* job = static_cast<DecodeJob*>(parameter);
  if (SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {
    if (SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
      job->rms = WindowRms(job->path, job->window_ms);
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

}

AudioPeaksBridge::AudioPeaksBridge(flutter::BinaryMessenger* messenger,
                                   HWND window)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kAudioPeaksChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      decoded_message_(::RegisterWindowMessageW(kDecodedMessageName)) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             Result result) { Handle(call, std::move(result)); });
}

bool AudioPeaksBridge::IsDecodedMessage(UINT message) const {
  return decoded_message_ != 0 && message == decoded_message_;
}

void AudioPeaksBridge::CompleteDecode(LPARAM job) {
  const std::unique_ptr<DecodeJob> finished(reinterpret_cast<DecodeJob*>(job));
  if (!finished->rms.has_value()) {
    finished->result->Error(kDecodeFailedCode, kDecodeFailedMessage);
    return;
  }
  flutter::EncodableList values;
  values.reserve(finished->rms->size());
  for (const double value : *finished->rms) {
    values.push_back(flutter::EncodableValue(value));
  }
  finished->result->Success(flutter::EncodableValue(values));
}

void AudioPeaksBridge::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    Result result) {
  if (call.method_name() != kWindowRmsMethod) {
    result->NotImplemented();
    return;
  }
  const std::string* path = StringArgument(call.arguments(), kPathArgument);
  const std::optional<int> window_ms =
      IntArgument(call.arguments(), kWindowMsArgument);
  if (path == nullptr || !window_ms.has_value() || *window_ms <= 0) {
    result->Error("bad-arguments",
                  "windowRms expects a string under \"path\" and a positive "
                  "integer under \"windowMs\"");
    return;
  }
  Decode(*path, *window_ms, std::move(result));
}

void AudioPeaksBridge::Decode(const std::string& path,
                              int window_ms,
                              Result result) {
  if (decoded_message_ == 0) {
    result->Error(kDecodeFailedCode, kDecodeFailedMessage);
    return;
  }
  DecodeJob* job = new DecodeJob{window_,   decoded_message_,
                                 Utf16FromUtf8(path), window_ms,
                                 std::move(result), std::nullopt};
  HANDLE thread =
      ::CreateThread(nullptr, 0, DecodeOffThread, job, 0, nullptr);
  if (thread == nullptr) {
    const std::unique_ptr<DecodeJob> unstarted(job);
    unstarted->result->Error(kDecodeFailedCode, kDecodeFailedMessage);
    return;
  }
  if (!::CloseHandle(thread)) {
    OutputDebugStringW(L"Field Notes could not release a worker thread.\n");
  }
}
