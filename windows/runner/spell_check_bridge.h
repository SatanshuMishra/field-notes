#ifndef RUNNER_SPELL_CHECK_BRIDGE_H_
#define RUNNER_SPELL_CHECK_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <spellcheck.h>
#include <wrl/client.h>

#include <memory>
#include <string>

class SpellCheckBridge {
 public:
  explicit SpellCheckBridge(flutter::BinaryMessenger* messenger);

  SpellCheckBridge(const SpellCheckBridge&) = delete;
  SpellCheckBridge& operator=(const SpellCheckBridge&) = delete;

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableList Check(const std::wstring& text);

  ISpellChecker* Checker();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  Microsoft::WRL::ComPtr<ISpellChecker> checker_;
  bool checker_created_ = false;
};

#endif
