#ifndef RUNNER_AUDIO_CLEAN_BRIDGE_H_
#define RUNNER_AUDIO_CLEAN_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

enum class CleanWork { kDecode, kReplace };

class AudioCleanBridge {
 public:
  AudioCleanBridge(flutter::BinaryMessenger* messenger, HWND window);

  AudioCleanBridge(const AudioCleanBridge&) = delete;
  AudioCleanBridge& operator=(const AudioCleanBridge&) = delete;

  bool IsCleanedMessage(UINT message) const;

  void CompleteClean(LPARAM job);

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Start(
      CleanWork work,
      const std::string& input,
      const std::string& audio,
      const std::string& output,
      int bit_rate,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  UINT cleaned_message_;
};

#endif
