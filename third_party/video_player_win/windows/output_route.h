#pragma once

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace field_notes_output_route {

inline std::mutex& StoreMutex() {
  static std::mutex store_mutex;
  return store_mutex;
}

inline std::optional<std::string>& StoredId() {
  static std::optional<std::string> stored_id;
  return stored_id;
}

inline std::optional<std::string> PreferredOutputDeviceId() {
  std::lock_guard<std::mutex> lock(StoreMutex());
  return StoredId();
}

inline void SetPreferredOutputDeviceId(std::optional<std::string> id) {
  std::lock_guard<std::mutex> lock(StoreMutex());
  StoredId() = std::move(id);
}

inline void RegisterChannel(flutter::BinaryMessenger* messenger,
                            const std::string& channel_name) {
  static std::vector<
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>>
      channels;
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, channel_name,
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "setPreferredOutputDevice") {
          result->NotImplemented();
          return;
        }
        std::optional<std::string> id;
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments) {
          auto found = arguments->find(flutter::EncodableValue("id"));
          if (found != arguments->end()) {
            const auto* value = std::get_if<std::string>(&found->second);
            if (value) {
              id = *value;
            }
          }
        }
        SetPreferredOutputDeviceId(std::move(id));
        result->Success();
      });
  channels.push_back(std::move(channel));
}

}
