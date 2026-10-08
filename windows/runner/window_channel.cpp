#include "window_channel.h"

#include <flutter/standard_method_codec.h>

#include <string>
#include <utility>
#include <variant>

namespace {

constexpr char kWindowChannelName[] = "field_notes/window";
constexpr char kStartDragMethod[] = "startDrag";
constexpr char kTitlebarDoubleClickMethod[] = "titlebarDoubleClick";
constexpr char kSetAppearanceMethod[] = "setAppearance";
constexpr char kMinimizeMethod[] = "minimize";
constexpr char kMaximizeOrRestoreMethod[] = "maximizeOrRestore";
constexpr char kCloseMethod[] = "close";
constexpr char kStartResizeMethod[] = "startResize";
constexpr char kWindowStateMethod[] = "windowState";
constexpr char kStateChangedMethod[] = "stateChanged";
constexpr char kTopEdge[] = "top";
constexpr char kDarkAppearance[] = "dark";
constexpr char kLightAppearance[] = "light";

bool LeftButtonDown() {
  return (::GetKeyState(VK_LBUTTON) & 0x8000) != 0;
}

void RunSystemLoop(HWND window, WPARAM command) {
  if (!LeftButtonDown()) {
    return;
  }
  ::ReleaseCapture();
  ::SendMessage(window, WM_SYSCOMMAND, command, 0);
}

bool IsMaximized(HWND window) {
  return window != nullptr && ::IsZoomed(window) != FALSE;
}

bool IsActive(HWND window) {
  return window != nullptr && ::GetForegroundWindow() == window;
}

Win32Window::Appearance AppearanceNamed(
    const flutter::EncodableValue* argument) {
  const std::string* name = std::get_if<std::string>(argument);
  if (name != nullptr && *name == kDarkAppearance) {
    return Win32Window::Appearance::kDark;
  }
  if (name != nullptr && *name == kLightAppearance) {
    return Win32Window::Appearance::kLight;
  }
  return Win32Window::Appearance::kSystem;
}

flutter::EncodableValue StateValue(bool maximized, bool active) {
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("maximized"),
       flutter::EncodableValue(maximized)},
      {flutter::EncodableValue("active"), flutter::EncodableValue(active)},
  });
}

}

WindowChannel::WindowChannel(flutter::BinaryMessenger* messenger,
                             Win32Window* window)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kWindowChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      maximized_(IsMaximized(window->GetHandle())),
      active_(IsActive(window->GetHandle())) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { Handle(call, std::move(result)); });
}

void WindowChannel::OnSize() {
  const bool maximized = IsMaximized(window_->GetHandle());
  if (maximized == maximized_) {
    return;
  }
  maximized_ = maximized;
  SendState();
}

void WindowChannel::OnActivate(bool active) {
  if (active == active_) {
    return;
  }
  active_ = active;
  SendState();
}

void WindowChannel::SendState() {
  channel_->InvokeMethod(kStateChangedMethod,
                         std::make_unique<flutter::EncodableValue>(
                             StateValue(maximized_, active_)));
}

void WindowChannel::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HWND window = window_->GetHandle();
  if (window == nullptr) {
    result->Error("unavailable", "The window is closed.");
    return;
  }
  const std::string& method = call.method_name();
  if (method == kStartDragMethod) {
    RunSystemLoop(window, SC_MOVE | HTCAPTION);
    result->Success();
  } else if (method == kTitlebarDoubleClickMethod ||
             method == kMaximizeOrRestoreMethod) {
    ::ShowWindow(window, IsMaximized(window) ? SW_RESTORE : SW_MAXIMIZE);
    result->Success();
  } else if (method == kSetAppearanceMethod) {
    window_->SetAppearance(AppearanceNamed(call.arguments()));
    result->Success();
  } else if (method == kMinimizeMethod) {
    ::ShowWindow(window, SW_MINIMIZE);
    result->Success();
  } else if (method == kCloseMethod) {
    if (!::PostMessage(window, WM_CLOSE, 0, 0)) {
      result->Error("unavailable", "The window did not close.");
      return;
    }
    result->Success();
  } else if (method == kStartResizeMethod) {
    const std::string* edge = std::get_if<std::string>(call.arguments());
    if (edge == nullptr || *edge != kTopEdge) {
      result->Error("bad_arguments", "startResize expects \"top\"");
      return;
    }
    RunSystemLoop(window, SC_SIZE | WMSZ_TOP);
    result->Success();
  } else if (method == kWindowStateMethod) {
    result->Success(StateValue(IsMaximized(window), IsActive(window)));
  } else {
    result->NotImplemented();
  }
}
