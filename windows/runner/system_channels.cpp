#include "system_channels.h"

#include <windows.h>

#include <flutter/standard_method_codec.h>
#include <mmdeviceapi.h>
#include <propidl.h>
#include <roapi.h>
#include <shellapi.h>
#include <windows.ui.notifications.h>
#include <wrl/client.h>
#include <wrl/wrappers/corewrappers.h>

#include <initguid.h>

#include <functiondiscoverykeys_devpkey.h>

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
constexpr char kStayAwakeChannelName[] = "field_notes/stay_awake";
constexpr char kHoldMethod[] = "hold";
constexpr char kReleaseMethod[] = "release";
constexpr char kAudioOutputChannelName[] = "field_notes/audio_output";
constexpr char kDefaultOutputNameMethod[] = "defaultOutputName";
constexpr char kOpenSoundSettingsMethod[] = "openSoundSettings";
constexpr char kListOutputsMethod[] = "listOutputs";
constexpr char kOutputIdKey[] = "id";
constexpr char kOutputNameKey[] = "name";
constexpr wchar_t kNotificationSettingsUri[] = L"ms-settings:notifications";
constexpr wchar_t kCameraPrivacySettingsUri[] = L"ms-settings:privacy-webcam";
constexpr wchar_t kSoundSettingsUri[] = L"ms-settings:sound";

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
  const bool network =
      path.rfind(L"\\\\", 0) == 0 || path.rfind(L"//", 0) == 0;
  if (network && parent.find_first_not_of(L"\\/") == std::wstring::npos) {
    return std::wstring();
  }
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

std::optional<std::string> DefaultOutputName() {
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL,
                                IID_PPV_ARGS(enumerator.GetAddressOf())))) {
    return std::nullopt;
  }
  ComPtr<IMMDevice> device;
  if (FAILED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole,
                                                 device.GetAddressOf()))) {
    return std::nullopt;
  }
  ComPtr<IPropertyStore> properties;
  if (FAILED(device->OpenPropertyStore(STGM_READ,
                                       properties.GetAddressOf()))) {
    return std::nullopt;
  }
  PROPVARIANT name;
  ::PropVariantInit(&name);
  std::optional<std::string> friendly_name;
  if (SUCCEEDED(properties->GetValue(PKEY_Device_FriendlyName, &name)) &&
      name.vt == VT_LPWSTR && name.pwszVal != nullptr &&
      name.pwszVal[0] != L'\0') {
    friendly_name = Utf8FromUtf16(name.pwszVal);
  }
  ::PropVariantClear(&name);
  if (friendly_name.has_value() && friendly_name->empty()) {
    return std::nullopt;
  }
  return friendly_name;
}

std::optional<std::string> FriendlyName(IMMDevice* device) {
  ComPtr<IPropertyStore> properties;
  if (FAILED(device->OpenPropertyStore(STGM_READ,
                                       properties.GetAddressOf()))) {
    return std::nullopt;
  }
  PROPVARIANT name;
  ::PropVariantInit(&name);
  std::optional<std::string> friendly_name;
  if (SUCCEEDED(properties->GetValue(PKEY_Device_FriendlyName, &name)) &&
      name.vt == VT_LPWSTR && name.pwszVal != nullptr &&
      name.pwszVal[0] != L'\0') {
    friendly_name = Utf8FromUtf16(name.pwszVal);
  }
  ::PropVariantClear(&name);
  if (friendly_name.has_value() && friendly_name->empty()) {
    return std::nullopt;
  }
  return friendly_name;
}

flutter::EncodableList ListOutputs() {
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL,
                                IID_PPV_ARGS(enumerator.GetAddressOf())))) {
    return flutter::EncodableList();
  }
  ComPtr<IMMDeviceCollection> endpoints;
  if (FAILED(enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE,
                                            endpoints.GetAddressOf()))) {
    return flutter::EncodableList();
  }
  UINT count = 0;
  if (FAILED(endpoints->GetCount(&count))) {
    return flutter::EncodableList();
  }
  flutter::EncodableList outputs;
  for (UINT index = 0; index < count; ++index) {
    ComPtr<IMMDevice> device;
    if (FAILED(endpoints->Item(index, device.GetAddressOf()))) {
      continue;
    }
    LPWSTR raw_id = nullptr;
    if (FAILED(device->GetId(&raw_id)) || raw_id == nullptr) {
      continue;
    }
    const std::string id = Utf8FromUtf16(raw_id);
    ::CoTaskMemFree(raw_id);
    const std::optional<std::string> name = FriendlyName(device.Get());
    if (id.empty() || !name.has_value()) {
      continue;
    }
    outputs.push_back(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue(std::string(kOutputIdKey)),
         flutter::EncodableValue(id)},
        {flutter::EncodableValue(std::string(kOutputNameKey)),
         flutter::EncodableValue(*name)},
    }));
  }
  return outputs;
}

void HandleAudioOutput(const Call& call, Result result) {
  if (call.method_name() == kDefaultOutputNameMethod) {
    const std::optional<std::string> name = DefaultOutputName();
    if (!name.has_value()) {
      result->Success();
      return;
    }
    result->Success(flutter::EncodableValue(*name));
  } else if (call.method_name() == kListOutputsMethod) {
    result->Success(flutter::EncodableValue(ListOutputs()));
  } else if (call.method_name() == kOpenSoundSettingsMethod) {
    if (!OpenSettingsPage(kSoundSettingsUri)) {
      OutputDebugStringW(L"Field Notes could not open the sound settings.\n");
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
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

void HandleStayAwake(const Call& call, Result result) {
  if (call.method_name() == kHoldMethod) {
    ::SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED |
                              ES_DISPLAY_REQUIRED);
    result->Success();
  } else if (call.method_name() == kReleaseMethod) {
    ::SetThreadExecutionState(ES_CONTINUOUS);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}

SystemChannels::SystemChannels(flutter::BinaryMessenger* messenger)
    : notification_settings_(
          ChannelNamed(messenger, kNotificationSettingsChannelName)),
      camera_settings_(ChannelNamed(messenger, kCameraSettingsChannelName)),
      audio_output_(ChannelNamed(messenger, kAudioOutputChannelName)),
      device_storage_(ChannelNamed(messenger, kDeviceStorageChannelName)),
      stay_awake_(ChannelNamed(messenger, kStayAwakeChannelName)) {
  notification_settings_->SetMethodCallHandler(HandleNotificationSettings);
  camera_settings_->SetMethodCallHandler(HandleCameraSettings);
  audio_output_->SetMethodCallHandler(HandleAudioOutput);
  device_storage_->SetMethodCallHandler(HandleDeviceStorage);
  stay_awake_->SetMethodCallHandler(HandleStayAwake);
}
