#include "live_audio_bridge.h"

#include <flutter/standard_method_codec.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <deque>
#include <functional>
#include <limits>
#include <mutex>
#include <optional>
#include <utility>
#include <variant>
#include <vector>

#include "utils.h"

namespace {

using Microsoft::WRL::ComPtr;
using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kLiveAudioChannelName[] = "field_notes/live_audio";
constexpr char kOpenEncoderMethod[] = "openEncoder";
constexpr char kAppendPcmMethod[] = "appendPcm";
constexpr char kCloseEncoderMethod[] = "closeEncoder";
constexpr char kCancelEncoderMethod[] = "cancelEncoder";
constexpr char kJoinAudioMethod[] = "joinAudio";
constexpr char kPathArgument[] = "path";
constexpr char kSampleRateArgument[] = "sampleRate";
constexpr char kChannelsArgument[] = "channels";
constexpr char kBitRateArgument[] = "bitRate";
constexpr char kIdArgument[] = "id";
constexpr char kPcmArgument[] = "pcm";
constexpr char kVideoArgument[] = "video";
constexpr char kAudioArgument[] = "audio";
constexpr char kOutputArgument[] = "output";
constexpr char kEncodeFailedCode[] = "encode-failed";
constexpr char kEncodeFailedMessage[] = "The voice could not be encoded.";
constexpr char kOpenBadArgumentsMessage[] =
    "openEncoder expects a string under \"path\" and positive integers under "
    "\"sampleRate\", \"channels\" and \"bitRate\"";
constexpr char kAppendBadArgumentsMessage[] =
    "appendPcm expects an encoder id under \"id\" and bytes under \"pcm\"";
constexpr char kCloseBadArgumentsMessage[] =
    "closeEncoder expects an encoder id under \"id\"";
constexpr char kCancelBadArgumentsMessage[] =
    "cancelEncoder expects an encoder id under \"id\"";
constexpr char kUnknownEncoderMessage[] = "No open encoder has that id.";
constexpr char kJoinFailedCode[] = "join-failed";
constexpr char kJoinFailedMessage[] =
    "The picture and the sound could not be joined.";
constexpr char kJoinBadArgumentsMessage[] =
    "joinAudio expects strings under \"video\", \"audio\" and \"output\", "
    "with the output apart from both inputs";
constexpr wchar_t kRepliedMessageName[] = L"FieldNotes.LiveAudioReplied";
constexpr DWORD kFirstVideoStream =
    static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);
constexpr DWORD kFirstAudioStream =
    static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM);
constexpr DWORD kAllStreams = static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS);
constexpr DWORD kMediaSink = static_cast<DWORD>(MF_SINK_WRITER_MEDIASINK);
constexpr UINT32 kPcmBits = 16;
constexpr UINT32 kPcmBytes = kPcmBits / 8;
constexpr UINT32 kBitsPerByte = 8;
constexpr uint64_t kTicksPerSecond = 10000000;

struct EncoderSettings {
  std::wstring path;
  std::string path_utf8;
  UINT32 sample_rate;
  UINT32 channels;
  UINT32 bit_rate;
};

struct LiveAudioReply {
  Result result;
  std::optional<flutter::EncodableValue> value;
  const char* code;
  const char* message;
  std::optional<int> failed_open;
};

void PostReply(HWND window, UINT message, LiveAudioReply* reply) {
  if (!::PostMessage(window, message, 0, reinterpret_cast<LPARAM>(reply))) {
    delete reply;
  }
}

ComPtr<IMFAttributes> Mpeg4Container() {
  ComPtr<IMFAttributes> attributes;
  if (FAILED(::MFCreateAttributes(&attributes, 1)) ||
      FAILED(attributes->SetGUID(MF_TRANSCODE_CONTAINERTYPE,
                                 MFTranscodeContainerType_MPEG4))) {
    return nullptr;
  }
  return attributes;
}

void ShutDownSink(IMFSinkWriter* writer) {
  ComPtr<IMFMediaSink> sink;
  if (SUCCEEDED(writer->GetServiceForStream(kMediaSink, GUID_NULL,
                                            IID_PPV_ARGS(&sink))) &&
      FAILED(sink->Shutdown())) {
    OutputDebugStringW(L"Field Notes could not stop a media file sink.\n");
  }
}

ComPtr<IMFMediaType> AacType(const EncoderSettings& settings) {
  ComPtr<IMFMediaType> type;
  if (FAILED(::MFCreateMediaType(&type)) ||
      FAILED(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio)) ||
      FAILED(type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, kPcmBits)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                             settings.sample_rate)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, settings.channels)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                             settings.bit_rate / kBitsPerByte))) {
    return nullptr;
  }
  return type;
}

ComPtr<IMFMediaType> PcmType(const EncoderSettings& settings) {
  const UINT32 block_align = settings.channels * kPcmBytes;
  ComPtr<IMFMediaType> type;
  if (FAILED(::MFCreateMediaType(&type)) ||
      FAILED(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio)) ||
      FAILED(type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, kPcmBits)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                             settings.sample_rate)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, settings.channels)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, block_align)) ||
      FAILED(type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                             settings.sample_rate * block_align))) {
    return nullptr;
  }
  return type;
}

class SinkEncoder {
 public:
  explicit SinkEncoder(EncoderSettings settings)
      : settings_(std::move(settings)) {}

  SinkEncoder(const SinkEncoder&) = delete;
  SinkEncoder& operator=(const SinkEncoder&) = delete;

  bool Open() {
    const ComPtr<IMFMediaType> aac = AacType(settings_);
    const ComPtr<IMFMediaType> pcm = PcmType(settings_);
    const ComPtr<IMFAttributes> container = Mpeg4Container();
    ComPtr<IMFSinkWriter> writer;
    DWORD stream = 0;
    if (aac.Get() == nullptr || pcm.Get() == nullptr ||
        container.Get() == nullptr ||
        FAILED(::MFCreateSinkWriterFromURL(settings_.path.c_str(), nullptr,
                                           container.Get(), &writer)) ||
        FAILED(writer->AddStream(aac.Get(), &stream)) ||
        FAILED(writer->SetInputMediaType(stream, pcm.Get(), nullptr)) ||
        FAILED(writer->BeginWriting())) {
      if (writer.Get() != nullptr) {
        ShutDownSink(writer.Get());
      }
      ::DeleteFileW(settings_.path.c_str());
      return false;
    }
    writer_ = writer;
    stream_ = stream;
    return true;
  }

  bool Append(const std::vector<uint8_t>& pcm) {
    const UINT32 block_align = settings_.channels * kPcmBytes;
    std::vector<uint8_t> bytes;
    bytes.reserve(carry_.size() + pcm.size());
    bytes.insert(bytes.end(), carry_.begin(), carry_.end());
    bytes.insert(bytes.end(), pcm.begin(), pcm.end());
    const size_t whole = bytes.size() - bytes.size() % block_align;
    carry_.assign(bytes.begin() + static_cast<std::ptrdiff_t>(whole),
                  bytes.end());
    if (writer_.Get() == nullptr ||
        whole > std::numeric_limits<DWORD>::max()) {
      return false;
    }
    if (whole == 0) {
      return true;
    }
    const DWORD length = static_cast<DWORD>(whole);
    const uint64_t end = frames_ + length / block_align;
    const LONGLONG time = TimeAtFrame(frames_);
    ComPtr<IMFMediaBuffer> buffer;
    ComPtr<IMFSample> sample;
    BYTE* target = nullptr;
    if (FAILED(::MFCreateMemoryBuffer(length, &buffer)) ||
        FAILED(buffer->Lock(&target, nullptr, nullptr))) {
      return false;
    }
    std::memcpy(target, bytes.data(), length);
    if (FAILED(buffer->Unlock()) || FAILED(buffer->SetCurrentLength(length)) ||
        FAILED(::MFCreateSample(&sample)) ||
        FAILED(sample->AddBuffer(buffer.Get())) ||
        FAILED(sample->SetSampleTime(time)) ||
        FAILED(sample->SetSampleDuration(TimeAtFrame(end) - time)) ||
        FAILED(writer_->WriteSample(stream_, sample.Get()))) {
      return false;
    }
    frames_ = end;
    return true;
  }

  bool Close() {
    if (writer_.Get() == nullptr || FAILED(writer_->Finalize())) {
      Cancel();
      return false;
    }
    writer_.Reset();
    return true;
  }

  void Cancel() {
    Abandon();
    ::DeleteFileW(settings_.path.c_str());
  }

  void Abandon() {
    if (writer_.Get() != nullptr) {
      ShutDownSink(writer_.Get());
      writer_.Reset();
    }
  }

  const std::string& path_utf8() const { return settings_.path_utf8; }

 private:
  LONGLONG TimeAtFrame(uint64_t frame) const {
    return static_cast<LONGLONG>(frame * kTicksPerSecond /
                                 settings_.sample_rate);
  }

  EncoderSettings settings_;
  ComPtr<IMFSinkWriter> writer_;
  DWORD stream_ = 0;
  uint64_t frames_ = 0;
  std::vector<uint8_t> carry_;
};

using EncoderWork =
    std::function<std::optional<flutter::EncodableValue>(SinkEncoder&)>;

struct EncoderTask {
  EncoderWork work;
  Result result;
  std::optional<int> opening;
};

}

class EncoderWorker {
 public:
  EncoderWorker(HWND window, UINT message, EncoderSettings settings)
      : window_(window), message_(message), encoder_(std::move(settings)) {}

  EncoderWorker(const EncoderWorker&) = delete;
  EncoderWorker& operator=(const EncoderWorker&) = delete;

  void Enqueue(EncoderWork work, Result result, std::optional<int> opening) {
    {
      const std::lock_guard<std::mutex> lock(mutex_);
      tasks_.push_back(EncoderTask{std::move(work), std::move(result), opening});
    }
    wake_.notify_one();
  }

  void Finish() {
    {
      const std::lock_guard<std::mutex> lock(mutex_);
      finishing_ = true;
    }
    wake_.notify_one();
  }

  void Run(bool ready) {
    while (std::optional<EncoderTask> task = Next()) {
      std::optional<flutter::EncodableValue> value;
      if (ready) {
        value = task->work(encoder_);
      }
      std::optional<int> failed_open;
      if (!value.has_value()) {
        failed_open = task->opening;
      }
      PostReply(window_, message_,
                new LiveAudioReply{std::move(task->result), std::move(value),
                                   kEncodeFailedCode, kEncodeFailedMessage,
                                   failed_open});
    }
    encoder_.Abandon();
  }

 private:
  std::optional<EncoderTask> Next() {
    std::unique_lock<std::mutex> lock(mutex_);
    wake_.wait(lock, [this] { return finishing_ || !tasks_.empty(); });
    if (tasks_.empty()) {
      return std::nullopt;
    }
    std::optional<EncoderTask> task(std::move(tasks_.front()));
    tasks_.pop_front();
    return task;
  }

  HWND window_;
  UINT message_;
  SinkEncoder encoder_;
  std::mutex mutex_;
  std::condition_variable wake_;
  std::deque<EncoderTask> tasks_;
  bool finishing_ = false;
};

namespace {

struct JoinJob {
  HWND window;
  UINT message;
  std::wstring video;
  std::wstring audio;
  std::wstring output;
  std::string output_utf8;
  Result result;
};

DWORD WINAPI EncodeOffThread(LPVOID parameter) {
  const std::unique_ptr<std::shared_ptr<EncoderWorker>> held(
      static_cast<std::shared_ptr<EncoderWorker>*>(parameter));
  const bool com = SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED));
  const bool media = com && SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE));
  (*held)->Run(media);
  if (media && FAILED(::MFShutdown())) {
    OutputDebugStringW(L"Field Notes could not stop Media Foundation.\n");
  }
  if (com) {
    ::CoUninitialize();
  }
  return 0;
}

std::shared_ptr<EncoderWorker> StartEncoderWorker(HWND window,
                                                  UINT message,
                                                  EncoderSettings settings) {
  const std::shared_ptr<EncoderWorker> worker =
      std::make_shared<EncoderWorker>(window, message, std::move(settings));
  std::shared_ptr<EncoderWorker>* held =
      new std::shared_ptr<EncoderWorker>(worker);
  HANDLE thread = ::CreateThread(nullptr, 0, EncodeOffThread, held, 0, nullptr);
  if (thread == nullptr) {
    delete held;
    return nullptr;
  }
  if (!::CloseHandle(thread)) {
    OutputDebugStringW(L"Field Notes could not release a worker thread.\n");
  }
  return worker;
}

ComPtr<IMFMediaType> SelectNativeStream(IMFSourceReader* reader,
                                        DWORD stream) {
  ComPtr<IMFMediaType> native;
  if (FAILED(reader->SetStreamSelection(kAllStreams, FALSE)) ||
      FAILED(reader->GetNativeMediaType(stream, 0, &native)) ||
      FAILED(reader->SetStreamSelection(stream, TRUE)) ||
      FAILED(reader->SetCurrentMediaType(stream, nullptr, native.Get()))) {
    return nullptr;
  }
  return native;
}

ComPtr<IMFMediaType> RotationKeptType(IMFMediaType* native) {
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

class TrackCopy {
 public:
  TrackCopy(IMFSourceReader* reader,
            DWORD source_stream,
            IMFSinkWriter* writer,
            DWORD writer_stream)
      : reader_(reader),
        source_stream_(source_stream),
        writer_(writer),
        writer_stream_(writer_stream) {}

  bool Fill() {
    while (pending_.Get() == nullptr && !ended_) {
      DWORD flags = 0;
      LONGLONG time = 0;
      if (FAILED(reader_->ReadSample(source_stream_, 0, nullptr, &flags, &time,
                                     &pending_)) ||
          (flags & MF_SOURCE_READERF_ERROR) != 0) {
        return false;
      }
      pending_time_ = time;
      ended_ = (flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0;
    }
    return true;
  }

  bool Done() const { return pending_.Get() == nullptr && ended_; }

  LONGLONG PendingTime() const { return pending_time_; }

  bool WritePending() {
    const HRESULT written =
        writer_->WriteSample(writer_stream_, pending_.Get());
    pending_.Reset();
    return SUCCEEDED(written);
  }

 private:
  IMFSourceReader* reader_;
  DWORD source_stream_;
  IMFSinkWriter* writer_;
  DWORD writer_stream_;
  ComPtr<IMFSample> pending_;
  LONGLONG pending_time_ = 0;
  bool ended_ = false;
};

bool CopyInterleaved(TrackCopy& picture, TrackCopy& sound) {
  for (;;) {
    if (!picture.Fill() || !sound.Fill()) {
      return false;
    }
    if (picture.Done() && sound.Done()) {
      return true;
    }
    const bool picture_first =
        sound.Done() ||
        (!picture.Done() && picture.PendingTime() <= sound.PendingTime());
    TrackCopy& next = picture_first ? picture : sound;
    if (!next.WritePending()) {
      return false;
    }
  }
}

bool JoinTracks(const JoinJob& job) {
  const ComPtr<IMFAttributes> container = Mpeg4Container();
  ComPtr<IMFSourceReader> picture_source;
  ComPtr<IMFSourceReader> sound_source;
  if (container.Get() == nullptr ||
      FAILED(::MFCreateSourceReaderFromURL(job.video.c_str(), nullptr,
                                           &picture_source)) ||
      FAILED(::MFCreateSourceReaderFromURL(job.audio.c_str(), nullptr,
                                           &sound_source))) {
    return false;
  }
  const ComPtr<IMFMediaType> picture_type =
      SelectNativeStream(picture_source.Get(), kFirstVideoStream);
  const ComPtr<IMFMediaType> sound_type =
      SelectNativeStream(sound_source.Get(), kFirstAudioStream);
  if (picture_type.Get() == nullptr || sound_type.Get() == nullptr) {
    return false;
  }
  const ComPtr<IMFMediaType> written_picture =
      RotationKeptType(picture_type.Get());
  ComPtr<IMFSinkWriter> writer;
  DWORD picture_stream = 0;
  DWORD sound_stream = 0;
  if (written_picture.Get() == nullptr ||
      FAILED(::MFCreateSinkWriterFromURL(job.output.c_str(), nullptr,
                                         container.Get(), &writer))) {
    return false;
  }
  if (FAILED(writer->AddStream(written_picture.Get(), &picture_stream)) ||
      FAILED(writer->AddStream(sound_type.Get(), &sound_stream)) ||
      FAILED(writer->BeginWriting())) {
    ShutDownSink(writer.Get());
    return false;
  }
  TrackCopy picture(picture_source.Get(), kFirstVideoStream, writer.Get(),
                    picture_stream);
  TrackCopy sound(sound_source.Get(), kFirstAudioStream, writer.Get(),
                  sound_stream);
  if (!CopyInterleaved(picture, sound) || FAILED(writer->Finalize())) {
    ShutDownSink(writer.Get());
    return false;
  }
  return true;
}

DWORD WINAPI JoinOffThread(LPVOID parameter) {
  std::unique_ptr<JoinJob> job(static_cast<JoinJob*>(parameter));
  bool joined = false;
  if (SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {
    if (SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
      joined = JoinTracks(*job);
      if (FAILED(::MFShutdown())) {
        OutputDebugStringW(L"Field Notes could not stop Media Foundation.\n");
      }
    }
    ::CoUninitialize();
  }
  if (!joined) {
    ::DeleteFileW(job->output.c_str());
  }
  std::optional<flutter::EncodableValue> value;
  if (joined) {
    value = flutter::EncodableValue(job->output_utf8);
  }
  PostReply(job->window, job->message,
            new LiveAudioReply{std::move(job->result), std::move(value),
                               kJoinFailedCode, kJoinFailedMessage,
                               std::nullopt});
  return 0;
}

const flutter::EncodableValue* Argument(
    const flutter::EncodableValue* arguments,
    const char* key) {
  const flutter::EncodableMap* map =
      std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) {
    return nullptr;
  }
  const flutter::EncodableMap::const_iterator entry =
      map->find(flutter::EncodableValue(key));
  if (entry == map->end()) {
    return nullptr;
  }
  return &entry->second;
}

std::optional<int32_t> PositiveArgument(
    const flutter::EncodableValue* arguments,
    const char* key) {
  const flutter::EncodableValue* value = Argument(arguments, key);
  if (value == nullptr) {
    return std::nullopt;
  }
  const int32_t* narrow = std::get_if<int32_t>(value);
  const int64_t* wide = std::get_if<int64_t>(value);
  if (narrow != nullptr && *narrow > 0) {
    return *narrow;
  }
  if (wide != nullptr && *wide > 0 &&
      *wide <= std::numeric_limits<int32_t>::max()) {
    return static_cast<int32_t>(*wide);
  }
  return std::nullopt;
}

const std::vector<uint8_t>* BytesArgument(
    const flutter::EncodableValue* arguments,
    const char* key) {
  const flutter::EncodableValue* value = Argument(arguments, key);
  if (value == nullptr) {
    return nullptr;
  }
  return std::get_if<std::vector<uint8_t>>(value);
}

bool IsPath(const std::string* value) {
  return value != nullptr && !value->empty();
}

}

LiveAudioBridge::LiveAudioBridge(flutter::BinaryMessenger* messenger,
                                 HWND window)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kLiveAudioChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      replied_message_(::RegisterWindowMessageW(kRepliedMessageName)) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             Result result) { Handle(call, std::move(result)); });
}

LiveAudioBridge::~LiveAudioBridge() {
  for (const std::pair<const int, std::shared_ptr<EncoderWorker>>& encoder :
       encoders_) {
    encoder.second->Finish();
  }
}

bool LiveAudioBridge::IsRepliedMessage(UINT message) const {
  return replied_message_ != 0 && message == replied_message_;
}

void LiveAudioBridge::CompleteReply(LPARAM reply) {
  const std::unique_ptr<LiveAudioReply> finished(
      reinterpret_cast<LiveAudioReply*>(reply));
  if (finished->failed_open.has_value()) {
    ForgetEncoder(*finished->failed_open);
  }
  if (!finished->value.has_value()) {
    finished->result->Error(finished->code, finished->message);
    return;
  }
  finished->result->Success(*finished->value);
}

void LiveAudioBridge::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    Result result) {
  const flutter::EncodableValue* arguments = call.arguments();
  const std::string& method = call.method_name();
  if (method == kOpenEncoderMethod) {
    OpenEncoder(arguments, std::move(result));
    return;
  }
  if (method == kAppendPcmMethod) {
    AppendPcm(arguments, std::move(result));
    return;
  }
  if (method == kCloseEncoderMethod) {
    CloseEncoder(arguments, std::move(result));
    return;
  }
  if (method == kCancelEncoderMethod) {
    CancelEncoder(arguments, std::move(result));
    return;
  }
  if (method == kJoinAudioMethod) {
    JoinAudio(arguments, std::move(result));
    return;
  }
  result->NotImplemented();
}

void LiveAudioBridge::OpenEncoder(const flutter::EncodableValue* arguments,
                                  Result result) {
  const std::string* path = StringArgument(arguments, kPathArgument);
  const std::optional<int32_t> sample_rate =
      PositiveArgument(arguments, kSampleRateArgument);
  const std::optional<int32_t> channels =
      PositiveArgument(arguments, kChannelsArgument);
  const std::optional<int32_t> bit_rate =
      PositiveArgument(arguments, kBitRateArgument);
  if (!IsPath(path) || !sample_rate.has_value() || !channels.has_value() ||
      !bit_rate.has_value()) {
    result->Error(kEncodeFailedCode, kOpenBadArgumentsMessage);
    return;
  }
  if (replied_message_ == 0) {
    result->Error(kEncodeFailedCode, kEncodeFailedMessage);
    return;
  }
  const std::shared_ptr<EncoderWorker> worker = StartEncoderWorker(
      window_, replied_message_,
      EncoderSettings{Utf16FromUtf8(*path), *path,
                      static_cast<UINT32>(*sample_rate),
                      static_cast<UINT32>(*channels),
                      static_cast<UINT32>(*bit_rate)});
  if (worker == nullptr) {
    result->Error(kEncodeFailedCode, kEncodeFailedMessage);
    return;
  }
  const int id = next_encoder_id_++;
  encoders_.emplace(id, worker);
  worker->Enqueue(
      [id](SinkEncoder& encoder) -> std::optional<flutter::EncodableValue> {
        if (!encoder.Open()) {
          return std::nullopt;
        }
        return flutter::EncodableValue(id);
      },
      std::move(result), id);
}

void LiveAudioBridge::AppendPcm(const flutter::EncodableValue* arguments,
                                Result result) {
  const std::optional<int32_t> id = PositiveArgument(arguments, kIdArgument);
  const std::vector<uint8_t>* pcm = BytesArgument(arguments, kPcmArgument);
  if (!id.has_value() || pcm == nullptr) {
    result->Error(kEncodeFailedCode, kAppendBadArgumentsMessage);
    return;
  }
  const std::map<int, std::shared_ptr<EncoderWorker>>::const_iterator found =
      encoders_.find(*id);
  if (found == encoders_.end()) {
    result->Error(kEncodeFailedCode, kUnknownEncoderMessage);
    return;
  }
  found->second->Enqueue(
      [bytes = *pcm](
          SinkEncoder& encoder) -> std::optional<flutter::EncodableValue> {
        if (!encoder.Append(bytes)) {
          return std::nullopt;
        }
        return flutter::EncodableValue();
      },
      std::move(result), std::nullopt);
}

void LiveAudioBridge::CloseEncoder(const flutter::EncodableValue* arguments,
                                   Result result) {
  const std::optional<int32_t> id = PositiveArgument(arguments, kIdArgument);
  if (!id.has_value()) {
    result->Error(kEncodeFailedCode, kCloseBadArgumentsMessage);
    return;
  }
  const std::shared_ptr<EncoderWorker> worker = TakeEncoder(*id);
  if (worker == nullptr) {
    result->Error(kEncodeFailedCode, kUnknownEncoderMessage);
    return;
  }
  worker->Enqueue(
      [](SinkEncoder& encoder) -> std::optional<flutter::EncodableValue> {
        if (!encoder.Close()) {
          return std::nullopt;
        }
        return flutter::EncodableValue(encoder.path_utf8());
      },
      std::move(result), std::nullopt);
  worker->Finish();
}

void LiveAudioBridge::CancelEncoder(const flutter::EncodableValue* arguments,
                                    Result result) {
  const std::optional<int32_t> id = PositiveArgument(arguments, kIdArgument);
  if (!id.has_value()) {
    result->Error(kEncodeFailedCode, kCancelBadArgumentsMessage);
    return;
  }
  const std::shared_ptr<EncoderWorker> worker = TakeEncoder(*id);
  if (worker == nullptr) {
    result->Error(kEncodeFailedCode, kUnknownEncoderMessage);
    return;
  }
  worker->Enqueue(
      [](SinkEncoder& encoder) -> std::optional<flutter::EncodableValue> {
        encoder.Cancel();
        return flutter::EncodableValue();
      },
      std::move(result), std::nullopt);
  worker->Finish();
}

void LiveAudioBridge::JoinAudio(const flutter::EncodableValue* arguments,
                                Result result) {
  const std::string* video = StringArgument(arguments, kVideoArgument);
  const std::string* audio = StringArgument(arguments, kAudioArgument);
  const std::string* output = StringArgument(arguments, kOutputArgument);
  if (!IsPath(video) || !IsPath(audio) || !IsPath(output) ||
      *output == *video || *output == *audio) {
    result->Error(kJoinFailedCode, kJoinBadArgumentsMessage);
    return;
  }
  if (replied_message_ == 0) {
    result->Error(kJoinFailedCode, kJoinFailedMessage);
    return;
  }
  JoinJob* job = new JoinJob{window_,
                             replied_message_,
                             Utf16FromUtf8(*video),
                             Utf16FromUtf8(*audio),
                             Utf16FromUtf8(*output),
                             *output,
                             std::move(result)};
  HANDLE thread = ::CreateThread(nullptr, 0, JoinOffThread, job, 0, nullptr);
  if (thread == nullptr) {
    const std::unique_ptr<JoinJob> unstarted(job);
    unstarted->result->Error(kJoinFailedCode, kJoinFailedMessage);
    return;
  }
  if (!::CloseHandle(thread)) {
    OutputDebugStringW(L"Field Notes could not release a worker thread.\n");
  }
}

std::shared_ptr<EncoderWorker> LiveAudioBridge::TakeEncoder(int id) {
  const std::map<int, std::shared_ptr<EncoderWorker>>::iterator found =
      encoders_.find(id);
  if (found == encoders_.end()) {
    return nullptr;
  }
  const std::shared_ptr<EncoderWorker> worker = found->second;
  encoders_.erase(found);
  return worker;
}

void LiveAudioBridge::ForgetEncoder(int id) {
  const std::shared_ptr<EncoderWorker> worker = TakeEncoder(id);
  if (worker != nullptr) {
    worker->Finish();
  }
}
