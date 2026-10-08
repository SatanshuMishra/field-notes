#include "system_channels.h"

#include <windows.h>

#include <flutter/standard_method_codec.h>
#include <roapi.h>
#include <shellapi.h>
#include <windows.ui.notifications.h>
#include <wrl/client.h>
#include <wrl/wrappers/corewrappers.h>

#include <cstdint>
#include <optional>
#include <string>

#include "utils.h"

namespace {

using ABI::Windows::UI::Notifications::IToastNotificationManagerStatics;
using ABI::Windows::UI::Notifications::IToastNotifier;
using ABI::Windows::UI::Notifications::NotificationSetting;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Wrappers::HStringReference;

using Channel = flutter::MethodChannel<flutter::EncodableValue>;
using Call = flutter::MethodCall<flutter::EncodableValue>;
using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

constexpr char kNotificationSettingsChannelName[] =
    "field_notes/notification_settings";
constexpr char kOpenMethod[] = "open";
constexpr char kStatusMethod[] = "status";
constexpr char kCameraSettingsChannelName[] = "field_notes/camera_settings";
constexpr char kOpenCameraSettingsMethod[] = "openCameraSettings";
constexpr char kDeviceStorageChannelName[] = "field_notes/device_storage";
constexpr char kFreeBytesMethod[] = "freeBytes";
constexpr char kPathArgument[] = "path";
constexpr wchar_t kNotificationSettingsUri[] = L"ms-settings:notifications";
constexpr wchar_t kCameraPrivacySettingsUri[] = L"ms-settings:privacy-webcam";

std::unique_ptr<Channel> ChannelNamed(flutter::BinaryMessenger* messenger,
                                      const char* name) {
  return std::make_unique<Channel>(
      messenger, name, &flutter::StandardMethodCodec::GetInstance());
}

bool OpenSettingsPage(const wchar_t* uri) {
  const HINSTANCE opened =
      ::ShellExecuteW(nullptr, L"open", uri, nullptr, nullptr, SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(opened) > 32;
}

bool ToastsEnabled() {
  ComPtr<IToastNotificationManagerStatics> manager;
  if (FAILED(::RoGetActivationFactory(
          HStringReference(
              RuntimeClass_Windows_UI_Notifications_ToastNotificationManager)
              .Get(),
          IID_PPV_ARGS(&manager)))) {
    return true;
  }
  ComPtr<IToastNotifier> notifier;
  if (FAILED(manager->CreateToastNotifierWithId(
          HStringReference(kAppUserModelId).Get(), &notifier))) {
    return true;
  }
  NotificationSetting setting =
      NotificationSetting::NotificationSetting_Enabled;
  if (FAILED(notifier->get_Setting(&setting))) {
    return true;
  }
  return setting == NotificationSetting::NotificationSetting_Enabled;
}

std::wstring ParentFolder(const std::wstring& path) {
  const size_t separator = path.find_last_of(L"\\/");
  if (separator == std::wstring::npos) {
    return std::wstring();
  }
  const std::wstring parent = path.substr(0, separator);
  const std::wstring folder =
      parent.empty() || parent.back() == L':' ? parent + L'\\' : parent;
  return folder.size() < path.size() ? folder : std::wstring();
}

std::wstring NearestExistingFolder(const std::wstring& path) {
  for (std::wstring candidate = path; !candidate.empty();
       candidate = ParentFolder(candidate)) {
    const DWORD attributes = ::GetFileAttributesW(candidate.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
      return candidate;
    }
  }
  return std::wstring();
}

std::optional<int64_t> FreeBytesNear(const std::string& path) {
  const std::wstring folder = NearestExistingFolder(Utf16FromUtf8(path));
  if (folder.empty()) {
    return std::nullopt;
  }
  ULARGE_INTEGER free_bytes_available_to_caller{};
  if (!::GetDiskFreeSpaceExW(folder.c_str(), &free_bytes_available_to_caller,
                             nullptr, nullptr)) {
    return std::nullopt;
  }
  return static_cast<int64_t>(free_bytes_available_to_caller.QuadPart);
}

void HandleNotificationSettings(const Call& call, Result result) {
  if (call.method_name() == kOpenMethod) {
    if (!OpenSettingsPage(kNotificationSettingsUri)) {
      result->Error("unavailable", "Windows Settings did not open.");
      return;
    }
    result->Success();
  } else if (call.method_name() == kStatusMethod) {
    result->Success(flutter::EncodableValue(
        std::string(ToastsEnabled() ? "enabled" : "disabled")));
  } else {
    result->NotImplemented();
  }
}

void HandleCameraSettings(const Call& call, Result result) {
  if (call.method_name() != kOpenCameraSettingsMethod) {
    result->NotImplemented();
    return;
  }
  if (!OpenSettingsPage(kCameraPrivacySettingsUri)) {
    OutputDebugStringW(L"Field Notes could not open the camera settings.\n");
  }
  result->Success();
}

void HandleDeviceStorage(const Call& call, Result result) {
  if (call.method_name() != kFreeBytesMethod) {
    result->NotImplemented();
    return;
  }
  const std::string* path = StringArgument(call.arguments(), kPathArgument);
  if (path == nullptr) {
    result->Error("bad_arguments", "A path is required");
    return;
  }
  const std::optional<int64_t> available = FreeBytesNear(*path);
  if (!available.has_value()) {
    result->Success();
    return;
  }
  result->Success(flutter::EncodableValue(*available));
}

}

SystemChannels::SystemChannels(flutter::BinaryMessenger* messenger)
    : notification_settings_(
          ChannelNamed(messenger, kNotificationSettingsChannelName)),
      camera_settings_(ChannelNamed(messenger, kCameraSettingsChannelName)),
      device_storage_(ChannelNamed(messenger, kDeviceStorageChannelName)) {
  notification_settings_->SetMethodCallHandler(HandleNotificationSettings);
  camera_settings_->SetMethodCallHandler(HandleCameraSettings);
  device_storage_->SetMethodCallHandler(HandleDeviceStorage);
}
