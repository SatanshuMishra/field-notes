import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerLaterKey;
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../notes/support/notes_harness.dart' show FakeNoteMediaResolver;
import 'support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaStore;

const Size _window = Size(1440, 900);
const String _date = '2026-07-19';
const String _openDayLabel = 'open day';
const double _panelRadius = Shapes.radiusXl;
const double _panelBorderWidth = 2;

Entry _note(String id, int hour) => Entry(
  id: id,
  dayId: 'day-1',
  type: EntryType.text,
  textContent: 'A note written at $hour.',
  createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
  updatedAt: 0,
);

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showDayDetail(context, date: _date),
      child: const Text(_openDayLabel),
    ),
  );
}

Future<void> _openDay(WidgetTester tester) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  final MediaResolver resolver = FakeNoteMediaResolver();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(
            entries: <Entry>[
              _note('note-1', 8),
              _note('note-2', 14),
              _note('note-3', 19),
            ],
          ),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        dayDetailMediaResolverProvider.overrideWith((Ref ref) => resolver),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const _Launcher(),
      ),
    ),
  );
  await tester.tap(find.text(_openDayLabel));
  await tester.pumpAndSettle();
}

Future<Color> _pixelAt(WidgetTester tester, Offset global) async {
  final RenderRepaintBoundary boundary = tester
      .renderObjectList<RenderRepaintBoundary>(
        find.ancestor(
          of: find.byKey(dayDetailPanelKey),
          matching: find.byType(RepaintBoundary),
        ),
      )
      .first;
  final Offset local = boundary.globalToLocal(global);
  final Color? pixel = await tester.runAsync<Color>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    final int offset = (local.dy.floor() * image.width + local.dx.floor()) * 4;
    final Color sampled = Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
    image.dispose();
    return sampled;
  });
  return pixel!;
}

void main() {
  testWidgets(
    'hovering Later in the day modal leaves the bottom-right outline arc in '
    'the outline colour',
    (WidgetTester tester) async {
      await _openDay(tester);
      final Finder card = find.byWidgetPredicate(
        (Widget widget) =>
            widget is CompactLogCard && widget.entry.id == 'note-2',
      );
      await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 18));
      await tester.pumpAndSettle();

      final Finder panel = find.byKey(dayDetailPanelKey);
      final Finder later = find.descendant(
        of: panel,
        matching: find.byKey(logViewerLaterKey),
      );
      expect(later, findsOneWidget);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(later));
      await tester.pumpAndSettle();

      final Finder fill = find.descendant(
        of: later,
        matching: find.byKey(pressableHoverFillKey),
      );
      final BoxDecoration painted =
          tester.widget<DecoratedBox>(fill).decoration as BoxDecoration;
      expect(painted.color, isNotNull);
      final Rect panelRect = tester.getRect(panel);
      final Rect fillRect = tester.getRect(fill);
      expect(fillRect.right, greaterThan(panelRect.right - _panelRadius));
      expect(fillRect.bottom, greaterThan(panelRect.bottom - _panelRadius));

      final Offset arcCentre = panelRect.bottomRight.translate(
        -_panelRadius,
        -_panelRadius,
      );
      const double midBand = _panelRadius - _panelBorderWidth / 2;
      final Offset onArc =
          arcCentre +
          Offset(
            midBand * math.cos(math.pi / 4),
            midBand * math.sin(math.pi / 4),
          );
      final Color outline = FieldNotesColors.light.line;
      expect((await _pixelAt(tester, onArc)).toARGB32(), outline.toARGB32());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
