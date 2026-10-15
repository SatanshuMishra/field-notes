#include "audio_clean_bridge.h"

#include <flutter/standard_method_codec.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mftransform.h>
#include <wrl/client.h>

#include <cstdint>
#include <cstring>
#include <limits>
#include <optional>
#include <utility>
#include <variant>

#include "audio_pcm_reader.h"
#include "utils.h"

namespace {

using Microsoft::WRL::ComPtr;
using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kAudioCleanChannelName[] = "field_notes/audio_clean";
constexpr char kDecodeAudioMethod[] = "decodeAudio";
constexpr char kReplaceAudioMethod[] = "replaceAudio";
constexpr char kInputArgument[] = "input";
constexpr char kAudioArgument[] = "audio";
constexpr char kOutputArgument[] = "output";
constexpr char kBitRateArgument[] = "bitRate";
constexpr char kSampleRateKey[] = "sampleRate";
constexpr char kChannelsKey[] = "channels";
constexpr char kFramesKey[] = "frames";
constexpr char kBadArgumentsCode[] = "bad_arguments";
constexpr char kDecodeBadArgumentsMessage[] =
    "decodeAudio expects strings under \"input\" and \"output\"";
constexpr char kReplaceBadArgumentsMessage[] =
    "replaceAudio expects strings under \"input\", \"audio\" and \"output\" "
    "and a positive integer under \"bitRate\"";
constexpr char kCleanFailedCode[] = "clean-failed";
constexpr char kCleanFailedMessage[] = "The audio could not be cleaned.";
constexpr wchar_t kCleanedMessageName[] = L"FieldNotes.AudioCleaned";
constexpr DWORD kVideoStream =
    static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);
constexpr DWORD kAllStreams = static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS);
constexpr UINT32 kCleanedSampleRate = 48000;
constexpr UINT32 kCleanedChannels = 1;
constexpr UINT32 kPcmBits = 16;
constexpr UINT32 kPcmBytes = kPcmBits / 8;
constexpr UINT32 kCleanedBlockAlign = kCleanedChannels * kPcmBytes;
constexpr UINT32 kBitsPerByte = 8;
constexpr PcmFormat kCleanedFormat{kCleanedSampleRate, kCleanedChannels,
                                   kPcmBits};
constexpr uint64_t kTicksPerSecond = 10000000;
constexpr uint32_t kWavHeaderBytes = 44;
constexpr uint32_t kWavFmtBytes = 16;
constexpr uint32_t kWavPcmFormat = 1;
constexpr uint64_t kMaxWavDataBytes =
    std::numeric_limits<uint32_t>::max() - (kWavHeaderBytes - 8);

struct CleanJob {
  HWND window;
  UINT message;
  CleanWork work;
  std::wstring input;
  std::wstring audio;
  std::wstring output;
  std::string output_utf8;
  int bit_rate;
  Result result;
  std::optional<flutter::EncodableValue> reply;
};

void PutLittleEndian(std::string& bytes, uint32_t value, int width) {
  for (int index = 0; index < width; ++index) {
    bytes.push_back(static_cast<char>((value >> (8 * index)) & 0xFF));
  }
}

std::string WavHeader(const PcmFormat& format, uint32_t data_bytes) {
  const uint32_t block_align = format.channels * kPcmBytes;
  std::string header;
  header.reserve(kWavHeaderBytes);
  header.append("RIFF");
  PutLittleEndian(header, kWavHeaderBytes - 8 + data_bytes, 4);
  header.append("WAVEfmt ");
  PutLittleEndian(header, kWavFmtBytes, 4);
  PutLittleEndian(header, kWavPcmFormat, 2);
  PutLittleEndian(header, format.channels, 2);
  PutLittleEndian(header, format.sample_rate, 4);
  PutLittleEndian(header, format.sample_rate * block_align, 4);
  PutLittleEndian(header, block_align, 2);
  PutLittleEndian(header, kPcmBits, 2);
  header.append("data");
  PutLittleEndian(header, data_bytes, 4);
  return header;
}

bool WriteBytes(HANDLE file, const void* data, DWORD length) {
  DWORD written = 0;
  return ::WriteFile(file, data, length, &written, nullptr) &&
         written == length;
}

class WavWriter {
 public:
  explicit WavWriter(const std::wstring& path)
      : file_(::CreateFileW(path.c_str(),
                            GENERIC_WRITE,
                            0,
                            nullptr,
                            CREATE_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL,
                            nullptr)) {}

  ~WavWriter() { Close(); }

  WavWriter(const WavWriter&) = delete;
  WavWriter& operator=(const WavWriter&) = delete;

  bool Begin() {
    const std::string placeholder(kWavHeaderBytes, '\0');
    return file_ != INVALID_HANDLE_VALUE &&
           WriteBytes(file_, placeholder.data(), kWavHeaderBytes);
  }

  bool Add(const PcmFormat& format, const BYTE* data, DWORD length) {
    if (!format_.has_value()) {
      format_ = format;
    }
    if (*format_ != format || data_bytes_ + length > kMaxWavDataBytes ||
        !WriteBytes(file_, data, length)) {
      return false;
    }
    data_bytes_ += length;
    return true;
  }

  std::optional<flutter::EncodableValue> Finish() {
    if (!format_.has_value()) {
      return std::nullopt;
    }
    const uint64_t frames = data_bytes_ / (format_->channels * kPcmBytes);
    const std::string header =
        WavHeader(*format_, static_cast<uint32_t>(data_bytes_));
    LARGE_INTEGER start;
    start.QuadPart = 0;
    if (frames == 0 ||
        !::SetFilePointerEx(file_, start, nullptr, FILE_BEGIN) ||
        !WriteBytes(file_, header.data(), static_cast<DWORD>(header.size())) ||
        !Close()) {
      return std::nullopt;
    }
    return flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue(kSampleRateKey),
         flutter::EncodableValue(static_cast<int32_t>(format_->sample_rate))},
        {flutter::EncodableValue(kChannelsKey),
         flutter::EncodableValue(static_cast<int32_t>(format_->channels))},
        {flutter::EncodableValue(kFramesKey),
         flutter::EncodableValue(static_cast<int64_t>(frames))},
    });
  }

 private:
  bool Close() {
    const HANDLE file = file_;
    file_ = INVALID_HANDLE_VALUE;
    return file != INVALID_HANDLE_VALUE && ::CloseHandle(file);
  }

  HANDLE file_;
  std::optional<PcmFormat> format_;
  uint64_t data_bytes_ = 0;
};

std::optional<flutter::EncodableValue> DecodeAudio(const std::wstring& input,
                                                   const std::wstring& output) {
  WavWriter wav(output);
  if (!wav.Begin()) {
    return std::nullopt;
  }
  const bool read = ReadPcm(
      input, PcmEncoding::kInt16,
      [&wav](const PcmFormat& format, const BYTE* data, DWORD length) {
        return wav.Add(format, data, length);
      });
  if (!read) {
    return std::nullopt;
  }
  return wav.Finish();
}

ComPtr<IMFMediaType> NearestOfferedType(IMFTransform* encoder,
                                        UINT32 bytes_per_second) {
  ComPtr<IMFMediaType> nearest;
  uint64_t nearest_distance = std::numeric_limits<uint64_t>::max();
  for (DWORD index = 0;; ++index) {
    ComPtr<IMFMediaType> offered;
    if (FAILED(encoder->GetOutputAvailableType(0, index, &offered))) {
      break;
    }
    UINT32 sample_rate = 0;
    UINT32 channels = 0;
    UINT32 average = 0;
    if (FAILED(offered->GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                                  &sample_rate)) ||
        FAILED(offered->GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, &channels)) ||
        FAILED(offered->GetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                                  &average)) ||
        sample_rate != kCleanedSampleRate || channels != kCleanedChannels) {
      continue;
    }
    const uint64_t distance = average > bytes_per_second
                                  ? average - bytes_per_second
                                  : bytes_per_second - average;
    if (distance < nearest_distance) {
      nearest = offered;
      nearest_distance = distance;
    }
  }
  ComPtr<IMFMediaType> chosen;
  if (nearest.Get() == nullptr || FAILED(::MFCreateMediaType(&chosen)) ||
      FAILED(nearest->CopyAllItems(chosen.Get()))) {
    return nullptr;
  }
  return chosen;
}

ComPtr<IMFMediaType> NearestAacType(UINT32 bytes_per_second) {
  IMFActivate** activates = nullptr;
  UINT32 count = 0;
  MFT_REGISTER_TYPE_INFO output_info = {MFMediaType_Audio, MFAudioFormat_AAC};
  const DWORD flags = (MFT_ENUM_FLAG_ALL & (~MFT_ENUM_FLAG_FIELDOFUSE)) |
                      MFT_ENUM_FLAG_SORTANDFILTER;
  if (FAILED(::MFTEnumEx(MFT_CATEGORY_AUDIO_ENCODER, flags, nullptr,
                         &output_info, &activates, &count))) {
    return nullptr;
  }
  ComPtr<IMFMediaType> nearest;
  if (count > 0) {
    ComPtr<IMFTransform> encoder;
    if (SUCCEEDED(activates[0]->ActivateObject(IID_PPV_ARGS(&encoder)))) {
      nearest = NearestOfferedType(encoder.Get(), bytes_per_second);
      if (FAILED(activates[0]->ShutdownObject())) {
        OutputDebugStringW(L"Field Notes could not release the AAC encoder.\n");
      }
    }
  }
  for (UINT32 index = 0; index < count; ++index) {
    activates[index]->Release();
  }
  ::CoTaskMemFree(activates);
  return nearest;
}

ComPtr<IMFMediaType> CleanedPcmType() {
  ComPtr<IMFMediaType> type;
  if (FAILED(::MFCreateMediaType(&type)) ||
      FAILED(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio)) ||
      FAILED(type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, kPcmBits)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                             kCleanedSampleRate)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, kCleanedChannels)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT,
                             kCleanedBlockAlign)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                             kCleanedSampleRate * kCleanedBlockAlign))) {
    return nullptr;
  }
  return type;
}

ComPtr<IMFMediaType> WrittenVideoType(IMFMediaType* native) {
  ComPtr<IMFMediaType> written;
  if (FAILED(::MFCreateMediaType(&written)) ||
      FAILED(native->CopyAllItems(written.Get()))) {
    return nullptr;
  }
  UINT32 rotation = 0;
  if (SUCCEEDED(native->GetUINT32(MF_MT_VIDEO_ROTATION, &rotation)) &&
      FAILED(written->SetUINT32(MF_MT_VIDEO_ROTATION, rotation))) {
    return nullptr;
  }
  return written;
}

class VideoPassThrough {
 public:
  VideoPassThrough(IMFSourceReader* reader,
                   IMFSinkWriter* writer,
                   DWORD writer_index)
      : reader_(reader), writer_(writer), writer_index_(writer_index) {}

  bool WriteBefore(LONGLONG time) {
    while (Fill()) {
      if (pending_.Get() == nullptr || pending_time_ >= time) {
        return true;
      }
      if (FAILED(writer_->WriteSample(writer_index_, pending_.Get()))) {
        return false;
      }
      pending_.Reset();
    }
    return false;
  }

  bool WriteRest() {
    return WriteBefore(std::numeric_limits<LONGLONG>::max());
  }

 private:
  bool Fill() {
    while (pending_.Get() == nullptr && !ended_) {
      DWORD flags = 0;
      if (FAILED(reader_->ReadSample(kVideoStream, 0, nullptr, &flags,
                                     &pending_time_, &pending_)) ||
          (flags & MF_SOURCE_READERF_ERROR) != 0) {
        return false;
      }
      ended_ = (flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0;
    }
    return true;
  }

  IMFSourceReader* reader_;
  IMFSinkWriter* writer_;
  DWORD writer_index_;
  ComPtr<IMFSample> pending_;
  LONGLONG pending_time_ = 0;
  bool ended_ = false;
};

LONGLONG TimeAtFrame(uint64_t frame) {
  return static_cast<LONGLONG>(frame * kTicksPerSecond / kCleanedSampleRate);
}

class CleanedAudioWriter {
 public:
  CleanedAudioWriter(IMFSinkWriter* writer,
                     DWORD writer_index,
                     VideoPassThrough* video)
      : writer_(writer), writer_index_(writer_index), video_(video) {}

  bool Add(const PcmFormat& format, const BYTE* data, DWORD length) {
    if (format != kCleanedFormat || length % kCleanedBlockAlign != 0) {
      return false;
    }
    const uint64_t end = frames_ + length / kCleanedBlockAlign;
    const LONGLONG time = TimeAtFrame(frames_);
    ComPtr<IMFMediaBuffer> buffer;
    ComPtr<IMFSample> sample;
    BYTE* target = nullptr;
    if ((video_ != nullptr && !video_->WriteBefore(time)) ||
        FAILED(::MFCreateMemoryBuffer(length, &buffer)) ||
        FAILED(buffer->Lock(&target, nullptr, nullptr))) {
      return false;
    }
    std::memcpy(target, data, length);
    if (FAILED(buffer->Unlock()) || FAILED(buffer->SetCurrentLength(length)) ||
        FAILED(::MFCreateSample(&sample)) ||
        FAILED(sample->AddBuffer(buffer.Get())) ||
        FAILED(sample->SetSampleTime(time)) ||
        FAILED(sample->SetSampleDuration(TimeAtFrame(end) - time)) ||
        FAILED(writer_->WriteSample(writer_index_, sample.Get()))) {
      return false;
    }
    frames_ = end;
    return true;
  }

  uint64_t frames() const { return frames_; }

 private:
  IMFSinkWriter* writer_;
  DWORD writer_index_;
  VideoPassThrough* video_;
  uint64_t frames_ = 0;
};

std::optional<flutter::EncodableValue> ReplaceAudio(const CleanJob& job) {
  const ComPtr<IMFMediaType> aac =
      NearestAacType(static_cast<UINT32>(job.bit_rate) / kBitsPerByte);
  const ComPtr<IMFMediaType> pcm = CleanedPcmType();
  ComPtr<IMFSourceReader> source;
  ComPtr<IMFSinkWriter> writer;
  if (aac.Get() == nullptr || pcm.Get() == nullptr ||
      FAILED(::MFCreateSourceReaderFromURL(job.input.c_str(), nullptr,
                                           &source)) ||
      FAILED(source->SetStreamSelection(kAllStreams, FALSE)) ||
      FAILED(::MFCreateSinkWriterFromURL(job.output.c_str(), nullptr, nullptr,
                                         &writer))) {
    return std::nullopt;
  }
  ComPtr<IMFMediaType> native_video;
  const HRESULT video_found =
      source->GetNativeMediaType(kVideoStream, 0, &native_video);
  if (FAILED(video_found) && video_found != MF_E_INVALIDSTREAMNUMBER) {
    return std::nullopt;
  }
  std::optional<VideoPassThrough> video;
  if (SUCCEEDED(video_found)) {
    const ComPtr<IMFMediaType> written = WrittenVideoType(native_video.Get());
    DWORD video_index = 0;
    if (written.Get() == nullptr ||
        FAILED(source->SetStreamSelection(kVideoStream, TRUE)) ||
        FAILED(source->SetCurrentMediaType(kVideoStream, nullptr,
                                           native_video.Get())) ||
        FAILED(writer->AddStream(written.Get(), &video_index))) {
      return std::nullopt;
    }
    video.emplace(source.Get(), writer.Get(), video_index);
  }
  DWORD audio_index = 0;
  if (FAILED(writer->AddStream(aac.Get(), &audio_index)) ||
      FAILED(writer->SetInputMediaType(audio_index, pcm.Get(), nullptr)) ||
      FAILED(writer->BeginWriting())) {
    return std::nullopt;
  }
  CleanedAudioWriter audio(writer.Get(), audio_index,
                           video.has_value() ? &*video : nullptr);
  const bool read = ReadPcm(
      job.audio, PcmEncoding::kInt16,
      [&audio](const PcmFormat& format, const BYTE* data, DWORD length) {
        return audio.Add(format, data, length);
      });
  if (!read || audio.frames() == 0 ||
      (video.has_value() && !video->WriteRest()) ||
      FAILED(writer->Finalize())) {
    return std::nullopt;
  }
  return flutter::EncodableValue(job.output_utf8);
}

DWORD WINAPI CleanOffThread(LPVOID parameter) {
  CleanJob* job = static_cast<CleanJob*>(parameter);
  if (SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {
    if (SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
      job->reply = job->work == CleanWork::kDecode
                       ? DecodeAudio(job->input, job->output)
                       : ReplaceAudio(*job);
      if (FAILED(::MFShutdown())) {
        OutputDebugStringW(L"Field Notes could not stop Media Foundation.\n");
      }
    }
    ::CoUninitialize();
  }
  if (!job->reply.has_value()) {
    ::DeleteFileW(job->output.c_str());
  }
  if (!::PostMessage(job->window, job->message, 0,
                     reinterpret_cast<LPARAM>(job))) {
    delete job;
  }
  return 0;
}

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

bool IsPath(const std::string* value) {
  return value != nullptr && !value->empty();
}

}

AudioCleanBridge::AudioCleanBridge(flutter::BinaryMessenger* messenger,
                                   HWND window)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kAudioCleanChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      cleaned_message_(::RegisterWindowMessageW(kCleanedMessageName)) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             Result result) { Handle(call, std::move(result)); });
}

bool AudioCleanBridge::IsCleanedMessage(UINT message) const {
  return cleaned_message_ != 0 && message == cleaned_message_;
}

void AudioCleanBridge::CompleteClean(LPARAM job) {
  const std::unique_ptr<CleanJob> finished(reinterpret_cast<CleanJob*>(job));
  if (!finished->reply.has_value()) {
    finished->result->Error(kCleanFailedCode, kCleanFailedMessage);
    return;
  }
  finished->result->Success(*finished->reply);
}

void AudioCleanBridge::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    Result result) {
  const flutter::EncodableValue* arguments = call.arguments();
  const std::string* input = StringArgument(arguments, kInputArgument);
  const std::string* output = StringArgument(arguments, kOutputArgument);
  if (call.method_name() == kDecodeAudioMethod) {
    if (!IsPath(input) || !IsPath(output)) {
      result->Error(kBadArgumentsCode, kDecodeBadArgumentsMessage);
      return;
    }
    Start(CleanWork::kDecode, *input, std::string(), *output, 0,
          std::move(result));
    return;
  }
  if (call.method_name() == kReplaceAudioMethod) {
    const std::string* audio = StringArgument(arguments, kAudioArgument);
    const std::optional<int> bit_rate =
        IntArgument(arguments, kBitRateArgument);
    if (!IsPath(input) || !IsPath(audio) || !IsPath(output) ||
        !bit_rate.has_value() || *bit_rate <= 0) {
      result->Error(kBadArgumentsCode, kReplaceBadArgumentsMessage);
      return;
    }
    Start(CleanWork::kReplace, *input, *audio, *output, *bit_rate,
          std::move(result));
    return;
  }
  result->NotImplemented();
}

void AudioCleanBridge::Start(CleanWork work,
                             const std::string& input,
                             const std::string& audio,
                             const std::string& output,
                             int bit_rate,
                             Result result) {
  if (cleaned_message_ == 0) {
    result->Error(kCleanFailedCode, kCleanFailedMessage);
    return;
  }
  CleanJob* job = new CleanJob{window_,
                               cleaned_message_,
                               work,
                               Utf16FromUtf8(input),
                               Utf16FromUtf8(audio),
                               Utf16FromUtf8(output),
                               output,
                               bit_rate,
                               std::move(result),
                               std::nullopt};
  HANDLE thread = ::CreateThread(nullptr, 0, CleanOffThread, job, 0, nullptr);
  if (thread == nullptr) {
    const std::unique_ptr<CleanJob> unstarted(job);
    unstarted->result->Error(kCleanFailedCode, kCleanFailedMessage);
    return;
  }
  if (!::CloseHandle(thread)) {
    OutputDebugStringW(L"Field Notes could not release a worker thread.\n");
  }
}
