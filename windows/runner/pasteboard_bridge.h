#ifndef RUNNER_PASTEBOARD_BRIDGE_H_
#define RUNNER_PASTEBOARD_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

class PasteboardBridge {
 public:
  PasteboardBridge(flutter::BinaryMessenger* messenger, HWND window);

  PasteboardBridge(const PasteboardBridge&) = delete;
  PasteboardBridge& operator=(const PasteboardBridge&) = delete;

  bool IsImageFileMessage(UINT message) const;

  void CompleteImageFile(LPARAM job);

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableValue Contents() const;

  flutter::EncodableValue Image() const;

  void ConvertImageFile(
      const std::string& path,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  UINT png_format_;
  UINT image_file_message_;
};

#endif
