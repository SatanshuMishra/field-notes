#ifndef RUNNER_WINDOW_CHANNEL_H_
#define RUNNER_WINDOW_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

#include "win32_window.h"

class WindowChannel {
 public:
  WindowChannel(flutter::BinaryMessenger* messenger, Win32Window* window);

  WindowChannel(const WindowChannel&) = delete;
  WindowChannel& operator=(const WindowChannel&) = delete;

  void OnSize();

  void OnActivate(bool active);

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SendState();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  Win32Window* window_;
  bool maximized_;
  bool active_;
};

#endif
