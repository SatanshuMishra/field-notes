import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_day_view.dart';
import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sync_overrides.dart';
import '../../support/theme_harness.dart';

const Color _coral = Color(0xFFB8566A);
const Color _line = Color(0xFF968888);
const Color _ink = Color(0xFFEDE1E1);
const Color _cardWarm = Color(0xFF272222);
const Color _cardBright = Color(0xFF1F1B1B);
const Color _muted = Color(0xFF9F9191);
const Color _mutedDeep = Color(0xFFB9A9A9);
const Color _placeholder = Color(0xFF6A605F);

const SearchDayView _view = SearchDayView(
  date: '2026-07-15',
  mood: Mood.happy,
  entryCount: 2,
  preview: 'Rainy morning walk',
  searchText: 'rainy morning walk',
);

Future<void> _pumpDark(WidgetTester tester, Widget child) => pumpThemed(
  tester,
  ProviderScope(child: child),
  brightness: Brightness.dark,
);

Color? _textColour(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

BoxDecoration _decorationAbove(WidgetTester tester, String label) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  test('search and settings name no light-only colour', () {
    expect(
      lightOnlyTokenUses(<String>[
        'lib/features/search',
        'lib/features/settings',
      ]),
      isEmpty,
    );
  });

  testWidgets('search field and day tile draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(tester, const SearchField());
    final InputDecoration field = tester
        .widget<InputDecorator>(find.byType(InputDecorator))
        .decoration;
    expect(field.fillColor, _cardBright);
    expect(
      (field.enabledBorder! as OutlineInputBorder).borderSide.color,
      _line,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.search)).color, _mutedDeep);
    expect(_textColour(tester, find.text('Search your days')), _placeholder);

    await _pumpDark(
      tester,
      Center(
        child: SearchDayTile(view: _view, onTap: () {}),
      ),
    );
    final DecoratedBox tile = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(StickerCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((tile.decoration as BoxDecoration).color, _cardWarm);
    expect(_textColour(tester, find.textContaining('July 15')), _mutedDeep);
  });

  testWidgets('settings tab rail draws its dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      Center(
        child: SettingsTabRail(
          selected: SettingsTab.syncStorage,
          onSelected: (SettingsTab tab) {},
        ),
      ),
    );
    final BoxDecoration selected = _decorationAbove(
      tester,
      SettingsTab.syncStorage.label,
    );
    expect(selected.color, _coral);
    expect((selected.border! as Border).top.color, _line);
    for (final SettingsTab tab in SettingsTab.values) {
      if (tab == SettingsTab.syncStorage) {
        continue;
      }
      expect(_textColour(tester, find.text(tab.label)), _ink);
      expect(_textColour(tester, find.text(tab.sublabel)), _muted);
    }
  });

  testWidgets('phone settings list and Back pill draw their dark colours', (
    WidgetTester tester,
  ) async {
    await pumpThemed(
      tester,
      ProviderScope(
        overrides: syncOffOverrides(),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SettingsSectionList(onOpen: (SettingsTab tab) {}),
              SettingsBackPill(label: settingsListTitle, onPressed: () {}),
            ],
          ),
        ),
      ),
      brightness: Brightness.dark,
      platform: TargetPlatform.android,
    );
    await tester.pumpAndSettle();

    final FieldNotesColors dark = FieldNotesColors.dark;
    final Finder list = find.byType(SettingsSectionList);
    final Finder pill = find.byType(SettingsBackPill);
    expect(
      _textColour(tester, find.text(settingsListEyebrow))!.toARGB32(),
      dark.accentInk.toARGB32(),
    );
    expect(
      _textColour(
        tester,
        find.descendant(of: list, matching: find.text(settingsListTitle)),
      )!.toARGB32(),
      _ink.toARGB32(),
    );
    final BoxDecoration card =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(StickerCard),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(card.color!.toARGB32(), _cardWarm.toARGB32());
    for (final SettingsTab tab in SettingsTab.values) {
      final Finder row = find.byKey(settingsTabKey(tab));
      expect(
        _textColour(
          tester,
          find.descendant(of: row, matching: find.text(tab.label)),
        )!.toARGB32(),
        _ink.toARGB32(),
      );
      final List<Text> texts = tester
          .widgetList<Text>(
            find.descendant(of: row, matching: find.byType(Text)),
          )
          .toList();
      expect(texts, hasLength(2), reason: tab.label);
      expect(texts.last.style!.color!.toARGB32(), _muted.toARGB32());
      expect(
        tester
            .widget<ChevronGlyph>(
              find.descendant(of: row, matching: find.byType(ChevronGlyph)),
            )
            .color
            .toARGB32(),
        _muted.toARGB32(),
      );
    }
    expect(find.text('Only on this phone'), findsOneWidget);

    final BoxDecoration glass =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.descendant(
                          of: pill,
                          matching: find.byType(GlassSurface),
                        ),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(glass.color!.toARGB32(), GlassColors.paperDark.tint.toARGB32());
    expect(
      _textColour(
        tester,
        find.descendant(of: pill, matching: find.text(settingsListTitle)),
      )!.toARGB32(),
      _ink.toARGB32(),
    );
    expect(
      tester
          .widget<ChevronGlyph>(
            find.descendant(of: pill, matching: find.byType(ChevronGlyph)),
          )
          .color
          .toARGB32(),
      _ink.toARGB32(),
    );
  });
}
