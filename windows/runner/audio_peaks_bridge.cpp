#include "audio_peaks_bridge.h"

#include <flutter/standard_method_codec.h>
#include <mfapi.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <optional>
#include <utility>
#include <variant>
#include <vector>

#include "audio_pcm_reader.h"
#include "utils.h"

namespace {

using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kAudioPeaksChannelName[] = "field_notes/audio_peaks";
constexpr char kWindowRmsMethod[] = "windowRms";
constexpr char kPathArgument[] = "path";
constexpr char kWindowMsArgument[] = "windowMs";
constexpr char kDecodeFailedCode[] = "decode-failed";
constexpr char kDecodeFailedMessage[] = "The recording could not be decoded.";
constexpr wchar_t kDecodedMessageName[] = L"FieldNotes.AudioPeaksDecoded";

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

  void Add(const PcmFormat& format, const float* samples, size_t count) {
    if (format != format_) {
      Reformat(format);
    }
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
  void Reformat(const PcmFormat& format) {
    const double frames =
        static_cast<double>(format.sample_rate) * window_ms_ / 1000.0;
    format_ = format;
    channels_ = format.channels;
    window_frames_ =
        std::max<uint64_t>(1, static_cast<uint64_t>(std::llround(frames)));
  }

  void CompleteWindow() {
    values_.push_back(std::sqrt(sum_ / static_cast<double>(filled_)));
    sum_ = 0.0;
    filled_ = 0;
  }

  int window_ms_;
  PcmFormat format_{0, 0, 0};
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

std::optional<std::vector<double>> WindowRms(const std::wstring& path,
                                             int window_ms) {
  RmsWindows windows(window_ms);
  const bool read = ReadPcm(
      path, PcmEncoding::kFloat32,
      [&windows](const PcmFormat& format, const BYTE* data, DWORD length) {
        windows.Add(format, reinterpret_cast<const float*>(data),
                    length / sizeof(float));
        return true;
      });
  if (!read) {
    return std::nullopt;
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
