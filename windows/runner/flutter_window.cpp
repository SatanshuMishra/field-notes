#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter::BinaryMessenger* messenger =
      flutter_controller_->engine()->messenger();
  window_channel_ = std::make_unique<WindowChannel>(messenger, this);
  system_channels_ = std::make_unique<SystemChannels>(messenger);
  spell_check_bridge_ = std::make_unique<SpellCheckBridge>(messenger);
  pasteboard_bridge_ =
      std::make_unique<PasteboardBridge>(messenger, GetHandle());
  file_drop_bridge_.Attach(new FileDropBridge(
      messenger, flutter_controller_->view()->GetNativeWindow()));
  file_drop_bridge_.Get()->Register();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (file_drop_bridge_.Get() != nullptr) {
    file_drop_bridge_.Get()->Revoke();
    file_drop_bridge_.Reset();
  }
  pasteboard_bridge_ = nullptr;
  spell_check_bridge_ = nullptr;
  system_channels_ = nullptr;
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (pasteboard_bridge_ && pasteboard_bridge_->IsImageFileMessage(message)) {
    pasteboard_bridge_->CompleteImageFile(lparam);
    return 0;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SIZE: {
      const LRESULT handled =
          Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      if (window_channel_) {
        window_channel_->OnSize();
      }
      return handled;
    }
    case WM_ACTIVATE: {
      const LRESULT handled =
          Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      if (window_channel_) {
        window_channel_->OnActivate(LOWORD(wparam) != WA_INACTIVE);
      }
      return handled;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
