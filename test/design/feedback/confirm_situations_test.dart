import 'dart:io';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _open = 'Open';
const Size _phone = Size(412, 915);
const Size _desktop = Size(1280, 800);
const Offset _outside = Offset(5, 5);

const List<TargetPlatform> _platforms = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.android,
];

class _Situation {
  const _Situation({
    required this.name,
    required this.title,
    required this.message,
    required this.safe,
    required this.action,
    required this.home,
  });

  final String name;
  final String title;
  final String message;
  final String safe;
  final String action;
  final Widget Function(ValueChanged<bool> onResult) home;
}

Widget _opener(Future<bool> Function(BuildContext) ask, ValueChanged<bool> on) {
  return Scaffold(
    body: Center(
      child: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () async => on(await ask(context)),
          child: const Text(_open),
        ),
      ),
    ),
  );
}

Widget _guardOpener({required ValueChanged<bool> on, Object? popResult}) {
  return Navigator(
    onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
      builder: (BuildContext _) => Scaffold(
        body: ComposerGuard(
          isDirty: () => true,
          popResult: popResult,
          onDiscard: () async => on(true),
          builder: (BuildContext context, VoidCallback requestClose) => Center(
            child: TextButton(
              onPressed: requestClose,
              child: const Text(_open),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _chipOpener({required ValueChanged<bool> on, Object? popResult}) {
  return Scaffold(
    body: ComposerGuard(
      isDirty: () => false,
      popResult: popResult,
      onDiscard: () async {},
      builder: (BuildContext context, VoidCallback requestClose) =>
          Center(child: DraftRestoredChip(onDiscard: () => on(true))),
    ),
  );
}

Widget Function(ValueChanged<bool>) _confirmWith({
  required String title,
  required String message,
  required String safe,
  required String action,
}) {
  return (ValueChanged<bool> on) => _opener(
    (BuildContext context) => showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: action,
      cancelLabel: safe,
      danger: true,
    ),
    on,
  );
}

final List<_Situation> _situations = <_Situation>[
  _Situation(
    name: 'leaving a new note',
    title: 'Let this one go?',
    message: "Nothing will be saved. That's okay too.",
    safe: 'Keep going',
    action: 'Let it go',
    home: (ValueChanged<bool> on) => _guardOpener(on: on),
  ),
  _Situation(
    name: 'leaving note edits',
    title: 'Discard your edits?',
    message: 'Your note stays as it was.',
    safe: 'Keep editing',
    action: 'Discard edits',
    home: (ValueChanged<bool> on) => _guardOpener(on: on, popResult: false),
  ),
  _Situation(
    name: 'deleting the journal',
    title: 'Delete everything?',
    message: "This erases every log, photo and mood on this device. It can't be undone.",
    safe: 'Keep my journal',
    action: 'Delete everything',
    home: (ValueChanged<bool> on) => _opener(confirmDeleteAll, on),
  ),
  _Situation(
    name: 'deleting a log from today',
    title: 'Delete this log?',
    message: "It's gone for good, on every device.",
    safe: 'Keep it',
    action: 'Delete',
    home: _confirmWith(
      title: todayDeleteTitle,
      message: todayDeleteMessage,
      safe: todayKeepLabel,
      action: todayDeleteLabel,
    ),
  ),
  _Situation(
    name: 'deleting a log from the viewer or a day',
    title: 'Delete this log?',
    message: "It's gone for good, on every device.",
    safe: 'Keep it',
    action: 'Delete',
    home: _confirmWith(
      title: logViewerDeleteTitle,
      message: logViewerDeleteMessage,
      safe: logViewerKeepLabel,
      action: logViewerDeleteLabel,
    ),
  ),
  _Situation(
    name: 'removing a device',
    title: 'Remove Studio Mac?',
    message: 'It stops syncing with this journal. Nothing on it is deleted.',
    safe: 'Keep it',
    action: 'Remove',
    home: _confirmWith(
      title: removeDevicePrompt('Studio Mac'),
      message: removeDeviceMessage,
      safe: deviceKeepLabel,
      action: deviceRemoveLabel,
    ),
  ),
];

Future<void> _show(
  WidgetTester tester,
  TargetPlatform platform,
  Widget home,
) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = platform == TargetPlatform.android
      ? _phone
      : _desktop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester) async {
  await tester.tap(find.text(_open));
  await tester.pumpAndSettle();
}

Future<void> Function(WidgetTester) _everywhere(
  Future<void> Function(WidgetTester, _Situation, TargetPlatform) body,
) {
  return (WidgetTester tester) async {
    try {
      for (final _Situation situation in _situations) {
        for (final TargetPlatform platform in _platforms) {
          await body(tester, situation, platform);
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  };
}

void main() {
  testWidgets(
    'every situation shows the words from the copy table',
    _everywhere((
      WidgetTester tester,
      _Situation situation,
      TargetPlatform platform,
    ) async {
      await _show(tester, platform, situation.home((bool _) {}));
      await _ask(tester);

      final String reason = '${situation.name} on $platform';
      expect(find.text(situation.title), findsOneWidget, reason: reason);
      expect(find.text(situation.message), findsOneWidget, reason: reason);
      expect(find.text(situation.safe), findsOneWidget, reason: reason);
      expect(find.text(situation.action), findsOneWidget, reason: reason);
    }),
  );

  testWidgets(
    'the buttons follow the platform order',
    _everywhere((
      WidgetTester tester,
      _Situation situation,
      TargetPlatform platform,
    ) async {
      await _show(tester, platform, situation.home((bool _) {}));
      await _ask(tester);

      final Offset safe = tester.getCenter(find.text(situation.safe));
      final Offset action = tester.getCenter(find.text(situation.action));
      final String reason = '${situation.name} on $platform';
      switch (platform) {
        case TargetPlatform.macOS:
          expect(safe.dx, lessThan(action.dx), reason: reason);
        case TargetPlatform.windows:
          expect(action.dx, lessThan(safe.dx), reason: reason);
        default:
          expect(action.dy, lessThan(safe.dy), reason: reason);
          expect(find.byType(PhoneSheet), findsOneWidget, reason: reason);
      }
    }),
  );

  testWidgets(
    'Enter, Escape and tapping outside all mean safe',
    _everywhere((
      WidgetTester tester,
      _Situation situation,
      TargetPlatform platform,
    ) async {
      final List<bool> results = <bool>[];
      await _show(tester, platform, situation.home(results.add));
      final List<Future<void> Function()> dismissals =
          <Future<void> Function()>[
            () => tester.sendKeyEvent(LogicalKeyboardKey.enter),
            () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
            () => tester.tapAt(_outside),
          ];

      for (final Future<void> Function() dismiss in dismissals) {
        await _ask(tester);
        expect(find.text(situation.title), findsOneWidget);
        await dismiss();
        await tester.pumpAndSettle();
        expect(
          find.text(situation.title),
          findsNothing,
          reason: '${situation.name} on $platform',
        );
        expect(results, isNot(contains(true)));
      }
    }),
  );

  testWidgets(
    'the safe button holds focus with no ring until Tab',
    _everywhere((
      WidgetTester tester,
      _Situation situation,
      TargetPlatform platform,
    ) async {
      await _show(tester, platform, situation.home((bool _) {}));
      await _ask(tester);

      final String reason = '${situation.name} on $platform';
      expect(find.byKey(focusRingKey), findsNothing, reason: reason);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(find.byKey(focusRingKey), findsOneWidget, reason: reason);
    }),
  );

  testWidgets('the safe button is the one that takes focus on open', (
    WidgetTester tester,
  ) async {
    try {
      for (final TargetPlatform platform in _platforms) {
        final _Situation situation = _situations.first;
        await _show(tester, platform, situation.home((bool _) {}));
        await _ask(tester);

        final BuildContext? focused =
            FocusManager.instance.primaryFocus?.context;
        final Element safe = tester.element(find.byKey(composerKeepEditingKey));
        bool inside = identical(focused, safe);
        focused?.visitAncestorElements((Element ancestor) {
          inside = inside || identical(ancestor, safe);
          return !inside;
        });
        expect(inside, isTrue, reason: '$platform');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('the restored draft chip', () {
    for (final (String name, Object? popResult, String title, String action)
        in <(String, Object?, String, String)>[
          ('a new note', null, 'Let this one go?', 'Let it go'),
          ('an edit', false, 'Discard your edits?', 'Discard edits'),
        ]) {
      testWidgets('asks before discarding the draft of $name', (
        WidgetTester tester,
      ) async {
        try {
          final List<bool> discards = <bool>[];
          await _show(
            tester,
            TargetPlatform.macOS,
            _chipOpener(on: discards.add, popResult: popResult),
          );

          await tester.tap(find.byKey(draftRestoredDiscardKey));
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          expect(discards, isEmpty);

          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.text(title), findsNothing);
          expect(discards, isEmpty);

          await tester.tap(find.byKey(draftRestoredDiscardKey));
          await tester.pumpAndSettle();
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(discards, <bool>[true]);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });

  test('the private confirmation dialogs are gone', () {
    for (final String path in <String>[
      'lib/features/capture/core/composer_guard.dart',
      'lib/features/settings/widgets/delete_all_dialog.dart',
      'lib/features/mood/mood_banner_for_date.dart',
    ]) {
      final String source = File(path).readAsStringSync();
      expect(source, contains('showConfirmDialog('), reason: path);
      expect(source, isNot(contains('showDialog')), reason: path);
      expect(source, isNot(contains('ConfirmDialog extends')), reason: path);
    }
  });
}
