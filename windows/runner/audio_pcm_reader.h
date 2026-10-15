#ifndef RUNNER_AUDIO_PCM_READER_H_
#define RUNNER_AUDIO_PCM_READER_H_

#include <windows.h>

#include <functional>
#include <string>

enum class PcmEncoding { kFloat32, kInt16 };

struct PcmFormat {
  UINT32 sample_rate;
  UINT32 channels;
  UINT32 bits_per_sample;

  bool operator==(const PcmFormat& other) const {
    return sample_rate == other.sample_rate && channels == other.channels &&
           bits_per_sample == other.bits_per_sample;
  }

  bool operator!=(const PcmFormat& other) const { return !(*this == other); }
};

using PcmCallback =
    std::function<bool(const PcmFormat& format, const BYTE* data,
                       DWORD length)>;

bool ReadPcm(const std::wstring& path,
             PcmEncoding encoding,
             const PcmCallback& callback);

#endif
