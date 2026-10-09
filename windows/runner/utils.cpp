#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>
#include <limits>
#include <variant>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  int input_length = static_cast<int>(wcsnlen(utf16_string, UNICODE_STRING_MAX_CHARS));
  int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, nullptr, 0, nullptr, nullptr);
  std::string utf8_string;
  if (target_length == 0 || static_cast<size_t>(target_length) > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}

std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty() ||
      utf8_string.size() >
          static_cast<size_t>(std::numeric_limits<int>::max())) {
    return std::wstring();
  }
  const int input_length = static_cast<int>(utf8_string.size());
  const int target_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            input_length, nullptr, 0);
  if (target_length <= 0) {
    return std::wstring();
  }
  std::wstring utf16_string(static_cast<size_t>(target_length), L'\0');
  const int converted_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            input_length, utf16_string.data(), target_length);
  if (converted_length != target_length) {
    return std::wstring();
  }
  return utf16_string;
}

std::vector<std::string> PathsFromDrop(HDROP drop) {
  std::vector<std::string> paths;
  if (drop == nullptr) {
    return paths;
  }
  const UINT count = ::DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT index = 0; index < count; ++index) {
    const UINT length = ::DragQueryFileW(drop, index, nullptr, 0);
    if (length == 0) {
      continue;
    }
    std::wstring path(static_cast<size_t>(length) + 1, L'\0');
    const UINT copied = ::DragQueryFileW(drop, index, path.data(), length + 1);
    if (copied == 0) {
      continue;
    }
    path.resize(copied);
    const std::string utf8_path = Utf8FromUtf16(path.c_str());
    if (!utf8_path.empty()) {
      paths.push_back(utf8_path);
    }
  }
  return paths;
}

const std::string* StringArgument(const flutter::EncodableValue* arguments,
                                  const char* key) {
  const flutter::EncodableMap* map =
      std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) {
    return nullptr;
  }
  const flutter::EncodableMap::const_iterator entry =
      map->find(flutter::EncodableValue(key));
  if (entry == map->end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&entry->second);
}
