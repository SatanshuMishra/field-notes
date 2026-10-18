#pragma once

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <functional>
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

inline std::optional<std::wstring> PreferredOutputEndpointId() {
  const std::optional<std::string> id = PreferredOutputDeviceId();
  if (!id || id->empty()) {
    return std::nullopt;
  }
  const int length = ::MultiByteToWideChar(
      CP_UTF8, 0, id->data(), static_cast<int>(id->size()), nullptr, 0);
  if (length <= 0) {
    return std::nullopt;
  }
  std::wstring endpoint_id(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, id->data(), static_cast<int>(id->size()),
                        endpoint_id.data(), length);
  return endpoint_id;
}

inline void RegisterChannel(flutter::BinaryMessenger* messenger,
                            const std::string& channel_name,
                            std::function<void()> on_change = nullptr) {
  static std::vector<
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>>
      channels;
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, channel_name,
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [on_change](const flutter::MethodCall<flutter::EncodableValue>& call,
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
        if (on_change) {
          on_change();
        }
        result->Success();
      });
  channels.push_back(std::move(channel));
}

}
