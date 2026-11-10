#ifndef RUNNER_VIDEO_FRAMES_BRIDGE_H_
#define RUNNER_VIDEO_FRAMES_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

class VideoFramesBridge {
 public:
  VideoFramesBridge(flutter::BinaryMessenger* messenger, HWND window);

  VideoFramesBridge(const VideoFramesBridge&) = delete;
  VideoFramesBridge& operator=(const VideoFramesBridge&) = delete;

  bool IsFrameMessage(UINT message) const;

  void CompleteFrame(LPARAM job);

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  UINT frame_message_;
};

#endif
