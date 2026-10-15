#include "audio_pcm_reader.h"

#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <optional>

namespace {

using Microsoft::WRL::ComPtr;

constexpr DWORD kAudioStream =
    static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM);
constexpr DWORD kAllStreams = static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS);
constexpr UINT32 kFloatBits = 32;
constexpr UINT32 kInt16Bits = 16;

GUID SubtypeFor(PcmEncoding encoding) {
  return encoding == PcmEncoding::kFloat32 ? MFAudioFormat_Float
                                           : MFAudioFormat_PCM;
}

UINT32 BitsFor(PcmEncoding encoding) {
  return encoding == PcmEncoding::kFloat32 ? kFloatBits : kInt16Bits;
}

std::optional<PcmFormat> CurrentFormat(IMFSourceReader* reader,
                                       PcmEncoding encoding) {
  ComPtr<IMFMediaType> type;
  GUID subtype = GUID_NULL;
  PcmFormat format{0, 0, 0};
  if (FAILED(reader->GetCurrentMediaType(kAudioStream, &type)) ||
      FAILED(type->GetGUID(MF_MT_SUBTYPE, &subtype)) ||
      FAILED(type->GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                             &format.sample_rate)) ||
      FAILED(type->GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, &format.channels)) ||
      FAILED(type->GetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,
                             &format.bits_per_sample)) ||
      subtype != SubtypeFor(encoding) || format.sample_rate == 0 ||
      format.channels == 0 || format.bits_per_sample != BitsFor(encoding)) {
    return std::nullopt;
  }
  return format;
}

bool HandBuffer(IMFSample* sample,
                const PcmFormat& format,
                const PcmCallback& callback) {
  ComPtr<IMFMediaBuffer> buffer;
  BYTE* data = nullptr;
  DWORD length = 0;
  if (FAILED(sample->ConvertToContiguousBuffer(&buffer)) ||
      FAILED(buffer->Lock(&data, nullptr, &length))) {
    return false;
  }
  const bool handled = callback(format, data, length);
  return SUCCEEDED(buffer->Unlock()) && handled;
}

}

bool ReadPcm(const std::wstring& path,
             PcmEncoding encoding,
             const PcmCallback& callback) {
  ComPtr<IMFSourceReader> reader;
  ComPtr<IMFMediaType> requested;
  if (path.empty() ||
      FAILED(::MFCreateSourceReaderFromURL(path.c_str(), nullptr, &reader)) ||
      FAILED(reader->SetStreamSelection(kAllStreams, FALSE)) ||
      FAILED(reader->SetStreamSelection(kAudioStream, TRUE)) ||
      FAILED(::MFCreateMediaType(&requested)) ||
      FAILED(requested->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio)) ||
      FAILED(requested->SetGUID(MF_MT_SUBTYPE, SubtypeFor(encoding))) ||
      FAILED(requested->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,
                                  BitsFor(encoding))) ||
      FAILED(reader->SetCurrentMediaType(kAudioStream, nullptr,
                                         requested.Get()))) {
    return false;
  }
  std::optional<PcmFormat> format = CurrentFormat(reader.Get(), encoding);
  if (!format.has_value()) {
    return false;
  }
  bool ended = false;
  while (!ended) {
    DWORD flags = 0;
    ComPtr<IMFSample> sample;
    if (FAILED(reader->ReadSample(kAudioStream, 0, nullptr, &flags, nullptr,
                                  &sample)) ||
        (flags & MF_SOURCE_READERF_ERROR) != 0) {
      return false;
    }
    if ((flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) != 0) {
      format = CurrentFormat(reader.Get(), encoding);
      if (!format.has_value()) {
        return false;
      }
    }
    if (sample.Get() != nullptr &&
        !HandBuffer(sample.Get(), *format, callback)) {
      return false;
    }
    ended = (flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0;
  }
  return true;
}
