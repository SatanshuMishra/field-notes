import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/day_detail/day_detail_heading.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/notes/notes_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../support/theme_harness.dart';
import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart';

const Size _surface = Size(1200, 1000);
const String _date = '2026-07-19';
const Color _darkCard = Color(0xFF272222);
const Color _darkLine = Color(0xFF968888);
const Color _darkCardShadow = Color(0x29000000);
const Color _darkInk = Color(0xFFEDE1E1);
const Color _darkPaper = Color(0xFF292424);

final DateTime _today = DateTime(2026, 7, 23, 9);

String _longNote() {
  final StringBuffer buffer = StringBuffer(
    'The peonies finally opened along the back fence.',
  );
  int word = 0;
  while (buffer.length < 260) {
    buffer.write(' petal${word++}');
  }
  return buffer.toString();
}

Entry _note(String text) => entryOf(type: EntryType.text, textContent: text);

List<Override> _overrides(FakeJournalRepository repository) => <Override>[
  journalRepositoryProvider.overrideWithValue(repository),
  draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
  dayDetailMediaResolverProvider.overrideWith((Ref ref) => FakeMediaResolver()),
  notesMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeMediaResolver(),
  ),
  todayClockProvider.overrideWithValue(() => _today),
];

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

Color? _textColour(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  test('entry cards, day detail and log viewer name no light-only colour', () {
    expect(
      lightOnlyTokenUses(<String>[
        'lib/features/entry_cards',
        'lib/features/day_detail',
        'lib/features/log_viewer',
      ]),
      isEmpty,
    );
  });

  testWidgets('compact log card draws its dark colours', (
    WidgetTester tester,
  ) async {
    final Entry entry = _note(_longNote());
    for (final CompactLogDensity density in CompactLogDensity.values) {
      await pumpThemed(
        tester,
        ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            CompactLogCard(
              entry: entry,
              resolver: FakeMediaResolver(),
              density: density,
              onOpen: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ],
        ),
        brightness: Brightness.dark,
        size: _surface,
      );
      await tester.pump();

      final BoxDecoration card = _decorationOf(
        tester,
        find
            .descendant(
              of: find.byType(StickerCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(card.color, _darkCard, reason: '$density fill');
      expect((card.border! as Border).top.color, _darkLine, reason: '$density');
      expect(card.boxShadow!.single.color, _darkCardShadow, reason: '$density');
      expect(card.boxShadow!.single.blurRadius, 0, reason: '$density');
      expect(
        _textColour(tester, logPreviewOf(entry).lead),
        _darkInk,
        reason: '$density body text',
      );
    }
  });

  testWidgets('day detail and log viewer panels draw their dark paper', (
    WidgetTester tester,
  ) async {
    await pumpThemed(
      tester,
      ProviderScope(
        key: const ValueKey<String>('day-detail-scope'),
        overrides: _overrides(FakeJournalRepository()),
        child: const DayDetailPanel(date: _date),
      ),
      brightness: Brightness.dark,
      size: _surface,
    );
    await tester.pumpAndSettle();

    final Container dayPanel = tester.widget<Container>(
      find.byKey(dayDetailPanelKey),
    );
    expect((dayPanel.decoration! as BoxDecoration).color, _darkPaper);
    expect(
      _textColour(tester, dayDetailHeadingFor(_date, today: _today).title),
      _darkInk,
    );

    final Entry entry = _note('Watered the roses.');
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      await pumpThemed(
        tester,
        ProviderScope(
          key: ValueKey<String>('log-viewer-scope-$platform'),
          overrides: _overrides(FakeJournalRepository(entries: <Entry>[entry])),
          child: LogViewerPanel(
            date: _date,
            entryId: entry.id,
            exit: LogViewerExit.back,
          ),
        ),
        brightness: Brightness.dark,
        platform: platform,
        size: _surface,
      );
      await tester.pumpAndSettle();

      final Color? paper = platform == TargetPlatform.macOS
          ? (tester
                        .widget<Container>(
                          find.descendant(
                            of: find.byKey(logViewerPanelKey),
                            matching: find.byKey(composerPanelKey),
                          ),
                        )
                        .decoration!
                    as BoxDecoration)
                .color
          : tester
                .widget<PhoneSheet>(
                  find.descendant(
                    of: find.byKey(logViewerPanelKey),
                    matching: find.byType(PhoneSheet),
                  ),
                )
                .color;
      expect(paper, _darkPaper, reason: '$platform');
      expect(
        _textColour(tester, logPreviewOf(entry).heading),
        _darkInk,
        reason: '$platform',
      );
    }
  });
}
