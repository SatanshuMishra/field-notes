import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerEarlierKey, logViewerLaterKey;
import 'package:field_notes/features/log_viewer/note_reading_room.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaStore;

const String _date = '2026-11-10';
const Size _compactPhone = Size(360, 780);
const double _fillInset = 12;

Entry _entry({
  required String id,
  required EntryType type,
  required int hour,
  required int minute,
}) => Entry(
  id: id,
  dayId: 'day-1',
  type: type,
  title: id,
  textContent: 'A note from late in the day.',
  createdAt: DateTime(2026, 11, 10, hour, minute).millisecondsSinceEpoch,
  updatedAt: 0,
);

Future<void> _openMiddleNote(
  WidgetTester tester, {
  required Entry earlier,
  required Entry later,
  List<Entry> before = const <Entry>[],
  List<Entry> after = const <Entry>[],
}) async {
  tester.view.physicalSize = _compactPhone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  final FakeJournalRepository repository = FakeJournalRepository(
    entries: <Entry>[
      ...before,
      earlier,
      _entry(id: 'middle', type: EntryType.text, hour: 23, minute: 0),
      later,
      ...after,
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(repository),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 11, 11, 9)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(
              showLogViewer(
                context,
                date: _date,
                entryId: 'middle',
                exit: LogViewerExit.close,
              ),
            ),
            child: const Text('open log'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await tester.pumpAndSettle();
  expect(find.byType(NoteReadingRoom), findsOneWidget);
}

void _expectOneLineInsideItsFill(
  WidgetTester tester, {
  required Key step,
  required String caption,
}) {
  final Finder words = find.descendant(
    of: find.byKey(step),
    matching: find.text(caption),
  );
  expect(words, findsOneWidget, reason: caption);
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(words);
  final Set<double> lineTops = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: caption.length),
      )
      .map((TextBox box) => box.top)
      .toSet();
  expect(lineTops, hasLength(1), reason: '$caption wraps');
  final Rect fill = tester.getRect(
    find.descendant(
      of: find.byKey(step),
      matching: find.byKey(pressableHoverFillKey),
    ),
  );
  final Rect arrow = tester.getRect(
    find.descendant(of: find.byKey(step), matching: find.byType(ChevronGlyph)),
  );
  final Rect content = tester.getRect(words).expandToInclude(arrow);
  expect(
    content.left - fill.left,
    greaterThanOrEqualTo(_fillInset),
    reason: caption,
  );
  expect(
    fill.right - content.right,
    greaterThanOrEqualTo(_fillInset),
    reason: caption,
  );
}

typedef _Step = ({int hour, int minute, String clock, EntryType kind});

const List<_Step> _earlierSteps = <_Step>[
  (hour: 0, minute: 58, clock: '12:58 AM', kind: EntryType.video),
  (hour: 10, minute: 58, clock: '10:58 AM', kind: EntryType.voice),
  (hour: 22, minute: 58, clock: '10:58 PM', kind: EntryType.video),
  (hour: 22, minute: 58, clock: '10:58 PM', kind: EntryType.voice),
];

const List<_Step> _laterSteps = <_Step>[
  (hour: 23, minute: 58, clock: '11:58 PM', kind: EntryType.voice),
  (hour: 23, minute: 58, clock: '11:58 PM', kind: EntryType.video),
];

String _caption(_Step step) => '${step.clock} · ${step.kind.name}';

void main() {
  for (int index = 0; index < _earlierSteps.length; index++) {
    final _Step earlier = _earlierSteps[index];
    final _Step later = _laterSteps[index % _laterSteps.length];
    testWidgets('on a 360 wide phone the step captions "${_caption(earlier)}" '
        'and "${_caption(later)}" stay on one line inside their fills', (
      WidgetTester tester,
    ) async {
      await _openMiddleNote(
        tester,
        earlier: _entry(
          id: 'earlier',
          type: earlier.kind,
          hour: earlier.hour,
          minute: earlier.minute,
        ),
        later: _entry(
          id: 'later',
          type: later.kind,
          hour: later.hour,
          minute: later.minute,
        ),
      );
      _expectOneLineInsideItsFill(
        tester,
        step: logViewerEarlierKey,
        caption: _caption(earlier),
      );
      _expectOneLineInsideItsFill(
        tester,
        step: logViewerLaterKey,
        caption: _caption(later),
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('on a 360 wide phone a "12 of 15" position still leaves '
      '"10:58 PM · video" on one line inside its fill', (
    WidgetTester tester,
  ) async {
    await _openMiddleNote(
      tester,
      earlier: _entry(
        id: 'earlier',
        type: EntryType.video,
        hour: 22,
        minute: 58,
      ),
      later: _entry(id: 'later', type: EntryType.voice, hour: 23, minute: 10),
      before: <Entry>[
        for (int hour = 8; hour < 18; hour++)
          _entry(
            id: 'morning-$hour',
            type: EntryType.text,
            hour: hour,
            minute: 0,
          ),
      ],
      after: <Entry>[
        _entry(id: 'late-1', type: EntryType.text, hour: 23, minute: 30),
        _entry(id: 'late-2', type: EntryType.text, hour: 23, minute: 58),
      ],
    );
    expect(find.text('12 of 15'), findsOneWidget);
    _expectOneLineInsideItsFill(
      tester,
      step: logViewerEarlierKey,
      caption: '10:58 PM · video',
    );
    _expectOneLineInsideItsFill(
      tester,
      step: logViewerLaterKey,
      caption: '11:10 PM · voice',
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
