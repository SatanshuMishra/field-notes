#include "video_join_bridge.h"

#include <flutter/standard_method_codec.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propidl.h>
#include <wrl/client.h>

#include <optional>
#include <utility>
#include <variant>
#include <vector>

#include "utils.h"

namespace {

using Microsoft::WRL::ComPtr;
using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kVideoJoinChannelName[] = "field_notes/video_join";
constexpr char kJoinMethod[] = "join";
constexpr char kSegmentsArgument[] = "segments";
constexpr char kOutputArgument[] = "output";
constexpr char kBadArgumentsCode[] = "bad_arguments";
constexpr char kBadArgumentsMessage[] =
    "join expects at least two strings under \"segments\" and a string under "
    "\"output\"";
constexpr char kJoinFailedCode[] = "join-failed";
constexpr char kJoinFailedMessage[] = "The video parts could not be joined.";
constexpr char kNoSegmentMessage[] = "No video part could be read.";
constexpr char kMissingStreamMessage[] =
    "A video part lacks a stream the first part has.";
constexpr wchar_t kJoinedMessageName[] = L"FieldNotes.VideoJoined";
constexpr DWORD kAnyStream = static_cast<DWORD>(MF_SOURCE_READER_ANY_STREAM);
constexpr DWORD kAllStreams = static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS);
constexpr DWORD kMediaSource = static_cast<DWORD>(MF_SOURCE_READER_MEDIASOURCE);
constexpr size_t kMinimumSegments = 2;

struct JoinJob {
  HWND window;
  UINT message;
  std::vector<std::wstring> segments;
  std::wstring output;
  std::string output_utf8;
  Result result;
  std::optional<std::string> failure;
};

struct Segment {
  ComPtr<IMFSourceReader> reader;
  LONGLONG duration;
};

struct JoinedStream {
  DWORD source_index;
  GUID major_type;
  DWORD writer_index;
};

std::optional<LONGLONG> SegmentDuration(IMFSourceReader* reader) {
  PROPVARIANT value;
  PropVariantInit(&value);
  if (FAILED(reader->GetPresentationAttribute(kMediaSource, MF_PD_DURATION,
                                              &value))) {
    return std::nullopt;
  }
  std::optional<LONGLONG> duration;
  if (value.vt == VT_UI8) {
    duration = static_cast<LONGLONG>(value.uhVal.QuadPart);
  }
  PropVariantClear(&value);
  return duration;
}

std::vector<Segment> ReadableSegments(
    const std::vector<std::wstring>& paths) {
  std::vector<Segment> segments;
  for (const std::wstring& path : paths) {
    ComPtr<IMFSourceReader> reader;
    if (path.empty() ||
        FAILED(::MFCreateSourceReaderFromURL(path.c_str(), nullptr,
                                             &reader))) {
      continue;
    }
    const std::optional<LONGLONG> duration = SegmentDuration(reader.Get());
    if (!duration.has_value() || *duration <= 0) {
      continue;
    }
    segments.push_back(Segment{reader, *duration});
  }
  return segments;
}

bool IsJoinedMajorType(const GUID& major_type) {
  return major_type == MFMediaType_Video || major_type == MFMediaType_Audio;
}

std::optional<std::vector<JoinedStream>> FirstSegmentStreams(
    IMFSourceReader* reader) {
  std::vector<JoinedStream> streams;
  for (DWORD index = 0;; ++index) {
    ComPtr<IMFMediaType> type;
    const HRESULT read = reader->GetNativeMediaType(index, 0, &type);
    if (read == MF_E_INVALIDSTREAMNUMBER) {
      break;
    }
    GUID major_type = GUID_NULL;
    if (FAILED(read) || FAILED(type->GetMajorType(&major_type))) {
      return std::nullopt;
    }
    if (IsJoinedMajorType(major_type)) {
      streams.push_back(JoinedStream{index, major_type, 0});
    }
  }
  if (streams.empty()) {
    return std::nullopt;
  }
  return streams;
}

bool SelectStreams(IMFSourceReader* reader,
                   const std::vector<JoinedStream>& streams,
                   bool* missing) {
  if (FAILED(reader->SetStreamSelection(kAllStreams, FALSE))) {
    return false;
  }
  for (const JoinedStream& stream : streams) {
    ComPtr<IMFMediaType> type;
    GUID major_type = GUID_NULL;
    if (FAILED(reader->GetNativeMediaType(stream.source_index, 0, &type)) ||
        FAILED(type->GetMajorType(&major_type)) ||
        major_type != stream.major_type) {
      *missing = true;
      return false;
    }
    if (FAILED(reader->SetStreamSelection(stream.source_index, TRUE)) ||
        FAILED(reader->SetCurrentMediaType(stream.source_index, nullptr,
                                           type.Get()))) {
      return false;
    }
  }
  return true;
}

const JoinedStream* StreamFor(const std::vector<JoinedStream>& streams,
                              DWORD source_index) {
  for (const JoinedStream& stream : streams) {
    if (stream.source_index == source_index) {
      return &stream;
    }
  }
  return nullptr;
}

bool CopySamples(IMFSourceReader* reader,
                 IMFSinkWriter* writer,
                 const std::vector<JoinedStream>& streams,
                 LONGLONG offset) {
  size_t ended = 0;
  while (ended < streams.size()) {
    DWORD stream_index = 0;
    DWORD flags = 0;
    LONGLONG timestamp = 0;
    ComPtr<IMFSample> sample;
    if (FAILED(reader->ReadSample(kAnyStream, 0, &stream_index, &flags,
                                  &timestamp, &sample)) ||
        (flags & MF_SOURCE_READERF_ERROR) != 0) {
      return false;
    }
    const JoinedStream* stream = StreamFor(streams, stream_index);
    if (sample.Get() != nullptr && stream != nullptr) {
      LONGLONG time = 0;
      if (FAILED(sample->GetSampleTime(&time)) ||
          FAILED(sample->SetSampleTime(time + offset)) ||
          FAILED(writer->WriteSample(stream->writer_index, sample.Get()))) {
        return false;
      }
    }
    if ((flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0) {
      ++ended;
    }
  }
  return true;
}

std::optional<std::string> JoinSegments(
    const std::vector<std::wstring>& paths,
    const std::wstring& output) {
  std::vector<Segment> segments = ReadableSegments(paths);
  if (segments.empty()) {
    return std::string(kNoSegmentMessage);
  }
  IMFSourceReader* first = segments.front().reader.Get();
  std::optional<std::vector<JoinedStream>> found = FirstSegmentStreams(first);
  if (!found.has_value()) {
    return std::string(kJoinFailedMessage);
  }
  std::vector<JoinedStream> streams = std::move(*found);
  ComPtr<IMFSinkWriter> writer;
  if (FAILED(::MFCreateSinkWriterFromURL(output.c_str(), nullptr, nullptr,
                                         &writer))) {
    return std::string(kJoinFailedMessage);
  }
  for (JoinedStream& stream : streams) {
    ComPtr<IMFMediaType> native;
    if (FAILED(first->GetNativeMediaType(stream.source_index, 0, &native)) ||
        FAILED(writer->AddStream(native.Get(), &stream.writer_index))) {
      return std::string(kJoinFailedMessage);
    }
  }
  if (FAILED(writer->BeginWriting())) {
    return std::string(kJoinFailedMessage);
  }
  LONGLONG offset = 0;
  for (const Segment& segment : segments) {
    bool missing = false;
    if (!SelectStreams(segment.reader.Get(), streams, &missing)) {
      return std::string(missing ? kMissingStreamMessage : kJoinFailedMessage);
    }
    if (!CopySamples(segment.reader.Get(), writer.Get(), streams, offset)) {
      return std::string(kJoinFailedMessage);
    }
    offset += segment.duration;
  }
  if (FAILED(writer->Finalize())) {
    return std::string(kJoinFailedMessage);
  }
  return std::nullopt;
}

DWORD WINAPI JoinOffThread(LPVOID parameter) {
  JoinJob* job = static_cast<JoinJob*>(parameter);
  job->failure = std::string(kJoinFailedMessage);
  if (SUCCEEDED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {
    if (SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
      job->failure = JoinSegments(job->segments, job->output);
      if (FAILED(::MFShutdown())) {
        OutputDebugStringW(L"Field Notes could not stop Media Foundation.\n");
      }
    }
    ::CoUninitialize();
  }
  if (job->failure.has_value()) {
    ::DeleteFileW(job->output.c_str());
  }
  if (!::PostMessage(job->window, job->message, 0,
                     reinterpret_cast<LPARAM>(job))) {
    delete job;
  }
  return 0;
}

std::optional<std::vector<std::string>> SegmentsArgument(
    const flutter::EncodableValue* arguments) {
  const flutter::EncodableMap* map =
      std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) {
    return std::nullopt;
  }
  const flutter::EncodableMap::const_iterator entry =
      map->find(flutter::EncodableValue(kSegmentsArgument));
  if (entry == map->end()) {
    return std::nullopt;
  }
  const flutter::EncodableList* list =
      std::get_if<flutter::EncodableList>(&entry->second);
  if (list == nullptr || list->size() < kMinimumSegments) {
    return std::nullopt;
  }
  std::vector<std::string> segments;
  segments.reserve(list->size());
  for (const flutter::EncodableValue& value : *list) {
    const std::string* segment = std::get_if<std::string>(&value);
    if (segment == nullptr || segment->empty()) {
      return std::nullopt;
    }
    segments.push_back(*segment);
  }
  return segments;
}

}

VideoJoinBridge::VideoJoinBridge(flutter::BinaryMessenger* messenger,
                                 HWND window)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kVideoJoinChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      joined_message_(::RegisterWindowMessageW(kJoinedMessageName)) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             Result result) { Handle(call, std::move(result)); });
}

bool VideoJoinBridge::IsJoinedMessage(UINT message) const {
  return joined_message_ != 0 && message == joined_message_;
}

void VideoJoinBridge::CompleteJoin(LPARAM job) {
  const std::unique_ptr<JoinJob> finished(reinterpret_cast<JoinJob*>(job));
  if (finished->failure.has_value()) {
    finished->result->Error(kJoinFailedCode, *finished->failure);
    return;
  }
  finished->result->Success(flutter::EncodableValue(finished->output_utf8));
}

void VideoJoinBridge::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    Result result) {
  if (call.method_name() != kJoinMethod) {
    result->NotImplemented();
    return;
  }
  const std::optional<std::vector<std::string>> segments =
      SegmentsArgument(call.arguments());
  const std::string* output = StringArgument(call.arguments(), kOutputArgument);
  if (!segments.has_value() || output == nullptr || output->empty()) {
    result->Error(kBadArgumentsCode, kBadArgumentsMessage);
    return;
  }
  Join(*segments, *output, std::move(result));
}

void VideoJoinBridge::Join(const std::vector<std::string>& segments,
                           const std::string& output,
                           Result result) {
  if (joined_message_ == 0) {
    result->Error(kJoinFailedCode, kJoinFailedMessage);
    return;
  }
  std::vector<std::wstring> paths;
  paths.reserve(segments.size());
  for (const std::string& segment : segments) {
    paths.push_back(Utf16FromUtf8(segment));
  }
  JoinJob* job = new JoinJob{window_,
                             joined_message_,
                             std::move(paths),
                             Utf16FromUtf8(output),
                             output,
                             std::move(result),
                             std::nullopt};
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
