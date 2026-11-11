import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../../support/sync_overrides.dart';
import 'support/settings_harness.dart';

const Size _desktopWindow = Size(1440, 900);
const Size _phoneWindow = Size(384, 832);
const double _phoneCardTextInset = 16;
const double _tolerance = 0.5;
const Key _gearKey = ValueKey<String>('gear-button');
const Set<Type> _inputPanelRowsLeftForNightSky = <Type>{
  InputDeviceRow,
  InputVolumeRow,
  OutputDeviceRow,
  OutputVolumeRow,
};

List<JournalDevice> _devices(DateTime now) => <JournalDevice>[
  JournalDevice(
    deviceId: 'this-device',
    name: 'Studio Mac',
    createdAt: now.subtract(const Duration(days: 30)),
    lastSeenAt: now,
    isThisDevice: true,
  ),
  JournalDevice(
    deviceId: 'phone',
    name: 'Galaxy S24 Ultra',
    createdAt: now.subtract(const Duration(days: 20)),
    lastSeenAt: now.subtract(const Duration(hours: 3)),
    isThisDevice: false,
  ),
];

List<Override> _overrides({required bool syncing}) {
  final DateTime now = DateTime.now().toUtc();
  final List<Override> sync = syncing
      ? syncOnOverrides(status: SyncedStatus(now), devices: _devices(now))
      : syncOffOverrides();
  final Set<Object> replaced = <Object>{
    for (final Override override in sync) override.origin,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    ...sync,
    appSettingsProvider.overrideWith(
      (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
    ),
    settingsDataControllerProvider.overrideWith(
      (Ref ref) async => FakeSettingsDataController(),
    ),
  ];
}

Future<void> _pumpDesktop(WidgetTester tester, {required bool syncing}) async {
  tester.view.physicalSize = _desktopWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(syncing: syncing),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: context.colors.page,
            body: const SettingsScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPhone(WidgetTester tester, {required bool syncing}) async {
  tester.view.physicalSize = _phoneWindow;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(syncing: syncing),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(_gearKey));
  await tester.pumpAndSettle();
}

Finder _only(Element element) => find.byElementPredicate(
  (Element candidate) => candidate == element,
  description: '${element.widget.runtimeType}',
);

Rect _rectOfElement(Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Element _topmost(Iterable<Element> elements) => elements.reduce(
  (Element a, Element b) =>
      _rectOfElement(a).top <= _rectOfElement(b).top ? a : b,
);

Element? _firstText(Finder row) {
  final List<Element> texts = find
      .descendant(of: row, matching: find.byType(RichText), matchRoot: true)
      .evaluate()
      .where((Element element) => _rectOfElement(element).width > 0)
      .toList();
  if (texts.isEmpty) {
    return null;
  }
  return texts.reduce((Element a, Element b) {
    final Rect first = _rectOfElement(a);
    final Rect second = _rectOfElement(b);
    if ((first.left - second.left).abs() > _tolerance) {
      return first.left < second.left ? a : b;
    }
    return first.top <= second.top ? a : b;
  });
}

String _textOf(Element text) =>
    (text.widget as RichText).text.toPlainText().replaceAll('\n', ' ');

double _textColumnLeft(
  Finder section,
  SettingsSection widget, {
  required bool phone,
}) {
  final String? heading = phone ? widget.title : widget.groups.first.label;
  if (heading != null) {
    return _rectOfElement(
      _topmost(
        find.descendant(of: section, matching: find.text(heading)).evaluate(),
      ),
    ).left;
  }
  final Rect card = _rectOfElement(
    find
        .descendant(of: section, matching: find.byType(StickerCard))
        .evaluate()
        .first,
  );
  return card.left + _phoneCardTextInset;
}

typedef _Sweep = ({List<String> faults, Set<String> hoverRows});

_Sweep _sweep(String page, {required bool phone}) {
  final List<String> faults = <String>[];
  final Set<String> hoverRows = <String>{};
  for (final Element sectionElement
      in find.byType(SettingsSection).evaluate()) {
    final SettingsSection section = sectionElement.widget as SettingsSection;
    final Finder sectionFinder = _only(sectionElement);
    final double textColumn = _textColumnLeft(
      sectionFinder,
      section,
      phone: phone,
    );
    final Iterable<Widget> rows = section.groups
        .expand((SettingsGroup group) => group.rows)
        .where(
          (Widget row) =>
              !_inputPanelRowsLeftForNightSky.contains(row.runtimeType),
        );
    for (final Widget row in rows) {
      for (final Element rowElement
          in find
              .descendant(of: sectionFinder, matching: find.byWidget(row))
              .evaluate()) {
        final Finder rowFinder = _only(rowElement);
        final Element? text = _firstText(rowFinder);
        if (text == null) {
          continue;
        }
        final Rect textRect = _rectOfElement(text);
        final String name = '$page: "${_textOf(text)}"';
        if ((textRect.left - textColumn).abs() > _tolerance) {
          faults.add(
            '$name text starts at ${textRect.left}, heading at $textColumn',
          );
        }
        final List<Element> hover = find
            .ancestor(
              of: _only(text),
              matching: find.descendant(
                of: rowFinder,
                matching: find.byType(Pressable),
                matchRoot: true,
              ),
            )
            .evaluate()
            .toList();
        if (hover.isEmpty) {
          continue;
        }
        hoverRows.add(_textOf(text));
        final Rect area = _rectOfElement(hover.last);
        if (area.left > textRect.left - settingsGutter + _tolerance) {
          faults.add(
            '$name hover starts at ${area.left}, '
            '${textRect.left - area.left} px left of its text at '
            '${textRect.left}; needs $settingsGutter',
          );
        }
      }
    }
  }
  return (faults: faults, hoverRows: hoverRows);
}

void main() {
  for (final bool syncing in <bool>[true, false]) {
    final String state = syncing ? 'while syncing' : 'before sync is set up';

    testWidgets('every desktop settings row hovers past its words and keeps '
        'them on the heading $state', (WidgetTester tester) async {
      await _pumpDesktop(tester, syncing: syncing);
      final List<String> faults = <String>[];
      final Set<String> hoverRows = <String>{};
      for (final SettingsTab tab in SettingsTab.values) {
        await tester.tap(find.byKey(settingsTabKey(tab)));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSection), findsWidgets, reason: tab.label);
        final _Sweep sweep = _sweep('desktop ${tab.label}', phone: false);
        faults.addAll(sweep.faults);
        hoverRows.addAll(sweep.hoverRows);
      }
      expect(hoverRows, containsAll(_desktopHoverRows(syncing: syncing)));
      expect(faults, isEmpty);
    });

    testWidgets('every phone settings row hovers past its words and keeps '
        'them on the heading $state', (WidgetTester tester) async {
      await _pumpPhone(tester, syncing: syncing);
      final List<String> faults = <String>[];
      final Set<String> hoverRows = <String>{};
      for (final SettingsTab tab in SettingsTab.values) {
        await tester.tap(find.byKey(settingsTabKey(tab)));
        await tester.pumpAndSettle();
        final _Sweep sweep = _sweep('phone ${tab.label}', phone: true);
        faults.addAll(sweep.faults);
        hoverRows.addAll(sweep.hoverRows);
        await tester.tap(find.byType(SettingsBackPill));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSectionList), findsOneWidget);
      }
      expect(hoverRows, containsAll(_phoneHoverRows(syncing: syncing)));
      expect(faults, isEmpty);
    });
  }
}

const Set<String> _syncSetupRows = <String>{
  'Start syncing',
  'Join my journal',
  'Restore with recovery phrase',
};

Set<String> _desktopHoverRows({required bool syncing}) => <String>{
  'Input profile',
  if (syncing) 'Manage devices' else ..._syncSetupRows,
};

Set<String> _phoneHoverRows({required bool syncing}) => <String>{
  'Input profile',
  if (!syncing) ..._syncSetupRows,
};
