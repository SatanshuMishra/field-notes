#ifndef RUNNER_LIVE_AUDIO_BRIDGE_H_
#define RUNNER_LIVE_AUDIO_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <map>
#include <memory>
#include <string>

class EncoderWorker;

class LiveAudioBridge {
 public:
  LiveAudioBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~LiveAudioBridge();

  LiveAudioBridge(const LiveAudioBridge&) = delete;
  LiveAudioBridge& operator=(const LiveAudioBridge&) = delete;

  bool IsRepliedMessage(UINT message) const;

  void CompleteReply(LPARAM reply);

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void OpenEncoder(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void AppendPcm(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void CloseEncoder(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void CancelEncoder(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void JoinAudio(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::shared_ptr<EncoderWorker> TakeEncoder(int id);

  void ForgetEncoder(int id);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  UINT replied_message_;
  int next_encoder_id_ = 1;
  std::map<int, std::shared_ptr<EncoderWorker>> encoders_;
};

#endif
