#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <knownfolders.h>
#include <ole2.h>
#include <shlobj.h>
#include <shobjidl.h>

#include <algorithm>
#include <string>
#include <utility>
#include <vector>

#include "flutter_window.h"
#include "system_channels.h"
#include "utils.h"
#include "window_geometry.h"

namespace {

struct OpeningFrame {
  Win32Window::Point origin;
  Win32Window::Size size;
};

RECT WorkAreaOf(HMONITOR monitor) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (::GetMonitorInfo(monitor, &info)) {
    return info.rcWork;
  }
  RECT work{0, 0, 0, 0};
  if (::SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0)) {
    return work;
  }
  return RECT{0, 0, ::GetSystemMetrics(SM_CXSCREEN),
              ::GetSystemMetrics(SM_CYSCREEN)};
}

OpeningFrame OpeningFrameUnderCursor() {
  POINT cursor{0, 0};
  if (!::GetCursorPos(&cursor)) {
    cursor = POINT{0, 0};
  }
  HMONITOR monitor = ::MonitorFromPoint(cursor, MONITOR_DEFAULTTOPRIMARY);
  const RECT work = WorkAreaOf(monitor);
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const SIZE opening =
      WindowSizeForContent(kOpeningWindowWidth, kOpeningWindowHeight, dpi);
  const SIZE minimum =
      WindowSizeForContent(kMinimumContentWidth, kMinimumContentHeight, dpi);
  const LONG work_width = work.right - work.left;
  const LONG work_height = work.bottom - work.top;
  const LONG width = std::max(std::min(opening.cx, work_width), minimum.cx);
  const LONG height = std::max(std::min(opening.cy, work_height), minimum.cy);
  const LONG left = work.left + (work_width - width) / 2;
  const LONG top = work.top + (work_height - height) / 2;
  return OpeningFrame{
      Win32Window::Point(static_cast<int>(left), static_cast<int>(top)),
      Win32Window::Size(static_cast<int>(width), static_cast<int>(height))};
}

void StartInUserFolder() {
  PWSTR profile = nullptr;
  if (SUCCEEDED(::SHGetKnownFolderPath(FOLDERID_Profile, KF_FLAG_DEFAULT,
                                       nullptr, &profile)) &&
      !::SetCurrentDirectoryW(profile)) {
    OutputDebugStringW(L"Field Notes could not start in the user folder.\n");
  }
  ::CoTaskMemFree(profile);
}

int RunFieldNotes() {
  if (FAILED(::SetCurrentProcessExplicitAppUserModelID(kAppUserModelId))) {
    OutputDebugStringW(L"Field Notes could not set its app user model ID.\n");
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  const OpeningFrame frame = OpeningFrameUnderCursor();
  if (!window.Create(L"Field Notes", frame.origin, frame.size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  return EXIT_SUCCESS;
}

}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (::SetDllDirectoryW(L"")) {
    StartInUserFolder();
  } else {
    OutputDebugStringW(L"Field Notes could not narrow its DLL search.\n");
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  const bool ole_ready = SUCCEEDED(::OleInitialize(nullptr));

  const int exit_code = RunFieldNotes();

  if (ole_ready) {
    ::OleUninitialize();
  }
  return exit_code;
}
