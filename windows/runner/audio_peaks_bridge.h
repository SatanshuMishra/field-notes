#ifndef RUNNER_AUDIO_PEAKS_BRIDGE_H_
#define RUNNER_AUDIO_PEAKS_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

class AudioPeaksBridge {
 public:
  AudioPeaksBridge(flutter::BinaryMessenger* messenger, HWND window);

  AudioPeaksBridge(const AudioPeaksBridge&) = delete;
  AudioPeaksBridge& operator=(const AudioPeaksBridge&) = delete;

  bool IsDecodedMessage(UINT message) const;

  void CompleteDecode(LPARAM job);

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Decode(
      const std::string& path,
      int window_ms,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  UINT decoded_message_;
};

#endif
