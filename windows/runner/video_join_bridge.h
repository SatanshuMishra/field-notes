#ifndef RUNNER_VIDEO_JOIN_BRIDGE_H_
#define RUNNER_VIDEO_JOIN_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

class VideoJoinBridge {
 public:
  VideoJoinBridge(flutter::BinaryMessenger* messenger, HWND window);

  VideoJoinBridge(const VideoJoinBridge&) = delete;
  VideoJoinBridge& operator=(const VideoJoinBridge&) = delete;

  bool IsJoinedMessage(UINT message) const;

  void CompleteJoin(LPARAM job);

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Join(
      const std::vector<std::string>& segments,
      const std::string& output,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  UINT joined_message_;
};

#endif
