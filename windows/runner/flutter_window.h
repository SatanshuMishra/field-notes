#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <wrl/client.h>

#include <memory>

#include "file_drop_bridge.h"
#include "pasteboard_bridge.h"
#include "spell_check_bridge.h"
#include "system_channels.h"
#include "win32_window.h"
#include "window_channel.h"

class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  flutter::DartProject project_;

  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<WindowChannel> window_channel_;

  std::unique_ptr<SystemChannels> system_channels_;

  std::unique_ptr<SpellCheckBridge> spell_check_bridge_;

  std::unique_ptr<PasteboardBridge> pasteboard_bridge_;

  Microsoft::WRL::ComPtr<FileDropBridge> file_drop_bridge_;
};

#endif
