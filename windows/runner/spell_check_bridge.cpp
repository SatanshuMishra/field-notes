#include "spell_check_bridge.h"

#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <utility>

#include "utils.h"

namespace {

using Microsoft::WRL::ComPtr;

constexpr char kSpellCheckChannelName[] = "field_notes/spellcheck";
constexpr char kSpellCheckMethod[] = "check";
constexpr char kTextArgument[] = "text";
constexpr size_t kMaxSpellSuggestions = 5;
constexpr wchar_t kFallbackLanguage[] = L"en-US";

bool Supports(ISpellCheckerFactory* factory, const wchar_t* language) {
  BOOL supported = FALSE;
  return SUCCEEDED(factory->IsSupported(language, &supported)) &&
         supported != FALSE;
}

std::wstring LanguageFor(ISpellCheckerFactory* factory) {
  wchar_t locale[LOCALE_NAME_MAX_LENGTH] = {};
  if (::GetUserDefaultLocaleName(locale, LOCALE_NAME_MAX_LENGTH) > 0 &&
      Supports(factory, locale)) {
    return locale;
  }
  if (Supports(factory, kFallbackLanguage)) {
    return kFallbackLanguage;
  }
  return std::wstring();
}

flutter::EncodableList ReplacementFor(ISpellingError* error) {
  LPWSTR replacement = nullptr;
  if (FAILED(error->get_Replacement(&replacement)) || replacement == nullptr) {
    return flutter::EncodableList();
  }
  const flutter::EncodableList suggestions{
      flutter::EncodableValue(Utf8FromUtf16(replacement))};
  ::CoTaskMemFree(replacement);
  return suggestions;
}

flutter::EncodableList SuggestionsFor(ISpellChecker* checker,
                                      const std::wstring& word) {
  flutter::EncodableList suggestions;
  ComPtr<IEnumString> words;
  if (FAILED(checker->Suggest(word.c_str(), &words)) ||
      words.Get() == nullptr) {
    return suggestions;
  }
  while (suggestions.size() < kMaxSpellSuggestions) {
    LPOLESTR next = nullptr;
    ULONG fetched = 0;
    if (words->Next(1, &next, &fetched) != S_OK || fetched == 0 ||
        next == nullptr) {
      break;
    }
    suggestions.push_back(flutter::EncodableValue(Utf8FromUtf16(next)));
    ::CoTaskMemFree(next);
  }
  return suggestions;
}

flutter::EncodableValue SpanValue(ULONG start,
                                  ULONG length,
                                  const flutter::EncodableList& suggestions) {
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("start"),
       flutter::EncodableValue(static_cast<int32_t>(start))},
      {flutter::EncodableValue("end"),
       flutter::EncodableValue(static_cast<int32_t>(start + length))},
      {flutter::EncodableValue("suggestions"),
       flutter::EncodableValue(suggestions)},
  });
}

}

SpellCheckBridge::SpellCheckBridge(flutter::BinaryMessenger* messenger)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kSpellCheckChannelName,
              &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { Handle(call, std::move(result)); });
}

void SpellCheckBridge::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != kSpellCheckMethod) {
    result->NotImplemented();
    return;
  }
  const std::string* text = StringArgument(call.arguments(), kTextArgument);
  if (text == nullptr) {
    result->Error("bad-arguments", "check expects a string under \"text\"");
    return;
  }
  result->Success(flutter::EncodableValue(Check(Utf16FromUtf8(*text))));
}

ISpellChecker* SpellCheckBridge::Checker() {
  if (checker_created_) {
    return checker_.Get();
  }
  checker_created_ = true;
  ComPtr<ISpellCheckerFactory> factory;
  if (FAILED(::CoCreateInstance(__uuidof(SpellCheckerFactory), nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&factory)))) {
    return nullptr;
  }
  const std::wstring language = LanguageFor(factory.Get());
  if (language.empty() ||
      FAILED(factory->CreateSpellChecker(language.c_str(), &checker_))) {
    return nullptr;
  }
  return checker_.Get();
}

flutter::EncodableList SpellCheckBridge::Check(const std::wstring& text) {
  flutter::EncodableList spans;
  ISpellChecker* checker = Checker();
  if (checker == nullptr || text.empty()) {
    return spans;
  }
  ComPtr<IEnumSpellingError> errors;
  if (FAILED(checker->Check(text.c_str(), &errors)) ||
      errors.Get() == nullptr) {
    return spans;
  }
  for (;;) {
    ComPtr<ISpellingError> error;
    if (errors->Next(&error) != S_OK || error.Get() == nullptr) {
      break;
    }
    CORRECTIVE_ACTION action = CORRECTIVE_ACTION_NONE;
    ULONG start = 0;
    ULONG length = 0;
    if (FAILED(error->get_CorrectiveAction(&action)) ||
        FAILED(error->get_StartIndex(&start)) ||
        FAILED(error->get_Length(&length))) {
      continue;
    }
    if (action != CORRECTIVE_ACTION_GET_SUGGESTIONS &&
        action != CORRECTIVE_ACTION_REPLACE) {
      continue;
    }
    if (length == 0 || start > text.size() || length > text.size() - start) {
      continue;
    }
    spans.push_back(SpanValue(
        start, length,
        action == CORRECTIVE_ACTION_REPLACE
            ? ReplacementFor(error.Get())
            : SuggestionsFor(checker, text.substr(start, length))));
  }
  return spans;
}
