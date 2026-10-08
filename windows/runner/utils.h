#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <windows.h>

#include <shellapi.h>

#include <flutter/encodable_value.h>

#include <string>
#include <vector>

void CreateAndAttachConsole();

std::string Utf8FromUtf16(const wchar_t* utf16_string);

std::wstring Utf16FromUtf8(const std::string& utf8_string);

std::vector<std::string> GetCommandLineArguments();

std::vector<std::string> PathsFromDrop(HDROP drop);

const std::string* StringArgument(const flutter::EncodableValue* arguments,
                                  const char* key);

#endif
