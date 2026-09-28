import 'dart:io';

import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/platform/spell_check_service.dart';

const MethodChannel _channel = MethodChannel(spellCheckChannelName);

List<MethodCall> _mockChannel(Future<Object?> Function(MethodCall) answer) {
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) {
        calls.add(call);
        return answer(call);
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
  return calls;
}

String _pbxSection(String project, String id) {
  final int start = project.indexOf('\t\t$id /* Sources */ = {');
  expect(start, isNot(-1), reason: '$id must exist');
  final int end = project.indexOf('\t\t};', start);
  return project.substring(start, end);
}

String _runnerGroup(String project) {
  final int start = project.indexOf(
    '\t\t33FAB671232836740065AC1E /* Runner */ = {',
  );
  expect(start, isNot(-1));
  final int end = project.indexOf('\t\t};', start);
  return project.substring(start, end);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MacosSpellCheckService', () {
    test(
      'the macos service sends one block and reads ranges and suggestions',
      () async {
        final List<MethodCall> calls = _mockChannel(
          (MethodCall call) async => <Object?>[
            <String, Object?>{
              'start': 0,
              'end': 3,
              'suggestions': <String>['the', 'tech', 'ten', 'tea', 'Te', 'tee'],
            },
          ],
        );

        final List<SuggestionSpan>? spans = await const MacosSpellCheckService()
            .fetchSpellCheckSuggestions(const Locale('en'), 'teh harbour');

        expect(spans, <SuggestionSpan>[
          const SuggestionSpan(TextRange(start: 0, end: 3), <String>[
            'the',
            'tech',
            'ten',
            'tea',
            'Te',
          ]),
        ]);
        expect(calls, hasLength(1));
        expect(calls.single.method, 'check');
        expect(calls.single.arguments, <String, Object?>{
          'text': 'teh harbour',
        });
        expect(
          (calls.single.arguments as Map<Object?, Object?>).containsKey(
            'locale',
          ),
          isFalse,
        );
      },
    );

    test('empty text makes no call and returns an empty list', () async {
      final List<MethodCall> calls = _mockChannel(
        (MethodCall call) async => <Object?>[],
      );

      final List<SuggestionSpan>? spans = await const MacosSpellCheckService()
          .fetchSpellCheckSuggestions(const Locale('en'), '');

      expect(spans, isEmpty);
      expect(calls, isEmpty);
    });

    test('a missing plugin gives null', () async {
      final List<SuggestionSpan>? spans = await const MacosSpellCheckService()
          .fetchSpellCheckSuggestions(const Locale('en'), 'teh');

      expect(spans, isNull);
    });

    test('a platform exception gives null', () async {
      _mockChannel(
        (MethodCall call) async =>
            throw PlatformException(code: 'bad-arguments'),
      );

      final List<SuggestionSpan>? spans = await const MacosSpellCheckService()
          .fetchSpellCheckSuggestions(const Locale('en'), 'teh');

      expect(spans, isNull);
    });

    test(
      'empty and out-of-range spans are dropped and the rest sorted',
      () async {
        _mockChannel(
          (MethodCall call) async => <Object?>[
            <String, Object?>{
              'start': 8,
              'end': 11,
              'suggestions': <String>['two'],
            },
            <String, Object?>{'start': 2, 'end': 2, 'suggestions': <String>[]},
            <String, Object?>{
              'start': 9,
              'end': 40,
              'suggestions': <String>['far'],
            },
            <String, Object?>{
              'start': -1,
              'end': 2,
              'suggestions': <String>['neg'],
            },
            <String, Object?>{
              'start': 0,
              'end': 3,
              'suggestions': <String>['one'],
            },
          ],
        );

        final List<SuggestionSpan>? spans = await const MacosSpellCheckService()
            .fetchSpellCheckSuggestions(const Locale('en'), 'onn and twu');

        expect(spans, <SuggestionSpan>[
          const SuggestionSpan(TextRange(start: 0, end: 3), <String>['one']),
          const SuggestionSpan(TextRange(start: 8, end: 11), <String>['two']),
        ]);
      },
    );

    test('constructing the service sends nothing', () {
      final List<MethodCall> calls = _mockChannel(
        (MethodCall call) async => <Object?>[],
      );

      const MacosSpellCheckService service = MacosSpellCheckService(
        channel: _channel,
      );

      expect(service, isA<SpellCheckService>());
      expect(calls, isEmpty);
    });
  });

  group('noteSpellCheckService', () {
    test('android uses the default spell check service', () {
      expect(
        noteSpellCheckService(TargetPlatform.android),
        isA<DefaultSpellCheckService>(),
      );
      expect(
        noteSpellCheckService(TargetPlatform.macOS),
        isA<MacosSpellCheckService>(),
      );
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(noteSpellCheckService(platform), isNull, reason: '$platform');
      }
    });
  });

  group('macOS spell-check bridge sources', () {
    final String bridge = File(
      'macos/Runner/SpellCheckBridge.swift',
    ).readAsStringSync();
    final String window = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    final String project = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    test(
      'the bridge asks NSSpellChecker with automatic language detection',
      () {
        expect(bridge, contains('"$spellCheckChannelName"'));
        expect(bridge, contains('"$spellCheckMethod"'));
        expect(bridge, contains('NSSpellChecker'));
        expect(bridge, contains('automaticallyIdentifiesLanguages = true'));
        expect(bridge, contains('uniqueSpellDocumentTag'));
      },
    );

    test('the window registers the bridge', () {
      expect(window, contains('SpellCheckBridge(messenger:'));
    });

    test('the runner target compiles the bridge', () {
      expect(
        project,
        contains(
          'F1E1D0012EA0000100000001 /* SpellCheckBridge.swift */ = '
          '{isa = PBXFileReference;',
        ),
      );
      expect(
        _runnerGroup(project),
        contains('F1E1D0012EA0000100000001 /* SpellCheckBridge.swift */'),
      );
      expect(
        _pbxSection(project, '33CC10E92044A3C60003C045'),
        contains(
          'F1E1D0012EA0000100000002 /* SpellCheckBridge.swift in Sources */',
        ),
      );
      expect(
        _pbxSection(project, '331C80D1294CF70F00263BE5'),
        isNot(contains('SpellCheckBridge.swift')),
      );
    });
  });
}
