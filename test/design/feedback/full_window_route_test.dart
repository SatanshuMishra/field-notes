import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsData, SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/full_window_route.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/note_photos.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/immersive/immersive_route.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/photo_viewer.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../features/capture/core/capture_test_support.dart'
    show FakeDraftStore;
import '../../features/day_detail/support/day_detail_harness.dart';
import '../../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto;

const Key _openKey = ValueKey<String>('open-full-window');
const Key _insideKey = ValueKey<String>('inside-full-window');
const Offset _emptySpace = Offset(20, 20);
const Size _window = Size(800, 600);
const String _closeLabel = 'Close';
const String _insideLabel = 'Inside';
const String _soundMethod = 'SystemSound.play';

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<MethodCall> _recordPlatformCalls(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      calls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

Iterable<MethodCall> _soundRequests(List<MethodCall> calls) =>
    calls.where((MethodCall call) => call.method == _soundMethod);

Widget _insideButton({VoidCallback? onPressed}) {
  return Center(
    child: SizedBox(
      width: 100,
      height: 100,
      child: TextButton(
        key: _insideKey,
        onPressed: onPressed ?? () {},
        child: const Text(_insideLabel),
      ),
    ),
  );
}

Widget _fade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}

Future<void> _pumpOpener(
  WidgetTester tester,
  void Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(),
      home: Builder(
        builder: (BuildContext context) => Align(
          alignment: Alignment.bottomRight,
          child: TextButton(
            key: _openKey,
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
}

Future<String?> _showButtonRoute(
  BuildContext context, {
  VoidCallback? onPressed,
}) {
  return showFullWindowRoute<String>(
    context,
    barrierLabel: _closeLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => Material(
          type: MaterialType.transparency,
          child: _insideButton(onPressed: onPressed),
        ),
    transitionBuilder: _fade,
  );
}

ModalRoute<Object?> _routeHolding(WidgetTester tester, Finder content) =>
    ModalRoute.of(tester.element(content))!;

void main() {
  testWidgets(
    'an empty click on a full-window route requests no sound and keeps it open',
    (WidgetTester tester) async {
      _useWindow(tester, _window);
      await _pumpOpener(tester, (BuildContext context) {
        _showButtonRoute(context);
      });
      final ModalRoute<Object?> route = _routeHolding(
        tester,
        find.byKey(_insideKey),
      );

      final List<MethodCall> calls = _recordPlatformCalls(tester);
      await tester.tapAt(_emptySpace);
      await tester.pumpAndSettle();

      expect(_soundRequests(calls), isEmpty);
      expect(find.byKey(_insideKey), findsOneWidget);
      expect(route, isA<FullWindowRoute<String>>());
      expect(route.isCurrent, isTrue);
    },
  );

  testWidgets(
    'a full-window route passes clicks to its controls and closes when popped',
    (WidgetTester tester) async {
      _useWindow(tester, _window);
      int presses = 0;
      Future<String?>? closed;
      await _pumpOpener(tester, (BuildContext context) {
        closed = _showButtonRoute(context, onPressed: () => presses++);
      });

      await tester.tap(find.byKey(_insideKey));
      await tester.pump();
      expect(presses, 1);

      String? result;
      bool completed = false;
      closed!.then((String? value) {
        result = value;
        completed = true;
      });
      Navigator.of(tester.element(find.byKey(_insideKey))).pop('done');
      await tester.pumpAndSettle();

      expect(find.byKey(_insideKey), findsNothing);
      expect(completed, isTrue);
      expect(result, 'done');
    },
  );

  testWidgets('the full-window backdrop offers screen readers no action', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, _window);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpOpener(tester, (BuildContext context) {
      _showButtonRoute(context);
    });

    expect(find.bySemanticsLabel(_closeLabel), findsNothing);
    final SemanticsNode insideNode = tester.getSemantics(
      find.byKey(_insideKey),
    );
    expect(
      find.semantics.byPredicate((SemanticsNode node) {
        final SemanticsData data = node.getSemanticsData();
        final bool acts =
            data.hasAction(SemanticsAction.tap) ||
            data.hasAction(SemanticsAction.dismiss);
        return acts && node != insideNode;
      }),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets(
    'an empty click around the immersive recorder requests no sound',
    (WidgetTester tester) async {
      _useWindow(tester, _window);
      await _pumpOpener(tester, (BuildContext context) {
        showImmersiveRecorder<void>(
          context,
          barrierLabel: _closeLabel,
          builder: (BuildContext recorderContext) => _insideButton(),
        );
      });

      final List<MethodCall> calls = _recordPlatformCalls(tester);
      await tester.tapAt(_emptySpace);
      await tester.pumpAndSettle();

      expect(_soundRequests(calls), isEmpty);
      expect(find.byKey(_insideKey), findsOneWidget);
      expect(
        _routeHolding(tester, find.byKey(_insideKey)),
        isA<FullWindowRoute<void>>(),
      );
    },
  );

  testWidgets('an empty click around the note composer requests no sound', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, _window);
    await _pumpOpener(tester, (BuildContext context) {
      showComposerRoute<void>(
        context,
        barrierLabel: _closeLabel,
        child: _insideButton(),
      );
    });

    final List<MethodCall> calls = _recordPlatformCalls(tester);
    await tester.tapAt(_emptySpace);
    await tester.pumpAndSettle();

    expect(_soundRequests(calls), isEmpty);
    expect(find.byKey(_insideKey), findsOneWidget);
    expect(
      _routeHolding(tester, find.byKey(_insideKey)),
      isA<FullWindowRoute<void>>(),
    );
  });

  testWidgets('the log viewer opens as a full-window route', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, const Size(1440, 900));
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'Watered the roses.'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(repository),
          draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
          mediaStoreProvider.overrideWith(
            (Ref ref) async => FakeMediaStore(Directory.systemTemp),
          ),
          todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
        ],
        child: dayDetailHarness(
          Builder(
            builder: (BuildContext context) => TextButton(
              key: _openKey,
              onPressed: () => showLogViewer(
                context,
                date: '2026-07-19',
                entryId: 'entry-1',
                exit: LogViewerExit.close,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    expect(
      _routeHolding(tester, find.byType(LogViewerPanel)),
      isA<FullWindowRoute<LogViewerOutcome>>(),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the photo viewer opens as a full-window route', (
    WidgetTester tester,
  ) async {
    const String reference = 'a1b2c3d4e5f6';
    await _pumpOpener(tester, (BuildContext context) {
      showPhotoViewer(
        context,
        photos: const <NotePhoto>[
          NotePhoto(reference: reference, caption: 'The harbour wall'),
        ],
        initialIndex: 0,
        dayTitle: 'Saturday, July 5',
        resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
          reference: availablePhoto(reference),
        })..memoizeAll(),
      );
    });

    expect(
      _routeHolding(tester, find.byType(PhotoViewer)),
      isA<FullWindowRoute<void>>(),
    );
  });
}
