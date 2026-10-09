#ifndef RUNNER_SYSTEM_CHANNELS_H_
#define RUNNER_SYSTEM_CHANNELS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

constexpr wchar_t kAppUserModelId[] = L"dev.satanshumishra.FieldNotes";

class SystemChannels {
 public:
  explicit SystemChannels(flutter::BinaryMessenger* messenger);

  SystemChannels(const SystemChannels&) = delete;
  SystemChannels& operator=(const SystemChannels&) = delete;

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      notification_settings_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      camera_settings_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      device_storage_;
};

#endif
