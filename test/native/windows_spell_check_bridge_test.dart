import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/platform/spell_check_service.dart';

const String _runner = 'windows/runner';

String _source(String name) {
  final File file = File('$_runner/$name');
  expect(file.existsSync(), isTrue, reason: '$_runner/$name is missing');
  return file.readAsStringSync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Windows spell check bridge answers the macOS contract', () async {
    final String bridge = _source('spell_check_bridge.cpp');

    final List<MethodCall> calls = <MethodCall>[];
    const MethodChannel channel = MethodChannel(spellCheckChannelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return <Object?>[
            <String, Object?>{
              'start': 0,
              'end': 3,
              'suggestions': <String>['the', 'tea'],
            },
          ];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final List<SuggestionSpan>? spans = await const NativeSpellCheckService()
        .fetchSpellCheckSuggestions(const Locale('en', 'US'), 'teh cat');
    expect(spans, const <SuggestionSpan>[
      SuggestionSpan(TextRange(start: 0, end: 3), <String>['the', 'tea']),
    ]);
    final Map<Object?, Object?> arguments =
        calls.single.arguments as Map<Object?, Object?>;

    expect(
      bridge,
      contains('kSpellCheckChannelName[] = "$spellCheckChannelName"'),
    );
    expect(bridge, contains('kSpellCheckMethod[] = "${calls.single.method}"'));
    expect(calls.single.method, spellCheckMethod);
    expect(bridge, contains('kTextArgument[] = "${arguments.keys.single}"'));

    final RegExpMatch? cap = RegExp(
      r'constexpr size_t kMaxSpellSuggestions = (\d+);',
    ).firstMatch(bridge);
    expect(cap, isNotNull, reason: 'the suggestion cap must be a constant');
    expect(int.parse(cap!.group(1)!), maxSpellSuggestions);
    expect(
      bridge,
      contains('while (suggestions.size() < kMaxSpellSuggestions)'),
    );

    expect(bridge, contains('ComPtr<ISpellCheckerFactory> factory;'));
    expect(bridge, contains('__uuidof(SpellCheckerFactory)'));
    expect(
      bridge,
      contains('::GetUserDefaultLocaleName(locale, LOCALE_NAME_MAX_LENGTH)'),
    );
    expect(bridge, contains('factory->IsSupported(language, &supported)'));
    expect(bridge, contains('kFallbackLanguage[] = L"en-US"'));
    expect(
      bridge,
      contains('factory->CreateSpellChecker(language.c_str(), &checker_)'),
    );
    expect(bridge, contains('checker->Check(text.c_str(), &errors)'));
    expect(bridge, contains('checker->Suggest(word.c_str(), &words)'));
    expect(bridge, contains('error->get_Replacement(&replacement)'));
    expect(bridge, contains('action != CORRECTIVE_ACTION_GET_SUGGESTIONS'));
    expect(bridge, contains('action != CORRECTIVE_ACTION_REPLACE'));
    expect(
      bridge,
      isNot(contains('CORRECTIVE_ACTION_DELETE')),
      reason: 'repeated words are not spelling errors, as on macOS',
    );

    for (final String key in <String>['start', 'end', 'suggestions']) {
      expect(bridge, contains('flutter::EncodableValue("$key")'));
    }
    expect(bridge, contains('static_cast<int32_t>(start)'));
    expect(bridge, contains('static_cast<int32_t>(start + length)'));
    expect(bridge, contains('Check(Utf16FromUtf8(*text))'));

    final String swift = File('macos/Runner/SpellCheckBridge.swift')
        .readAsStringSync();
    expect(swift, contains('code: "bad-arguments"'));
    expect(
      swift,
      contains(r'message: "check expects a string under \"text\""'),
    );
    expect(
      bridge,
      contains(
        r'result->Error("bad-arguments", "check expects a string under \"text\"");',
      ),
    );
    expect(bridge, isNot(matches(RegExp(r'\b(try|catch|throw)\b'))));

    expect(
      _source('flutter_window.cpp'),
      contains('std::make_unique<SpellCheckBridge>(messenger)'),
    );
    expect(_source('CMakeLists.txt'), contains('"spell_check_bridge.cpp"'));
  });
}
