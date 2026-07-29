import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';

import '../app_harness.dart';

const ValueKey<String> _settingsKey = ValueKey<String>('settings-button');
const ValueKey<String> _soundKey = ValueKey<String>('sound-button');

SidebarShell _shell({
  ShellDestination selected = ShellDestination.today,
  bool soundOn = true,
}) {
  return SidebarShell(
    destinations: ShellDestination.primary,
    selected: selected,
    soundOn: soundOn,
    onSelect: (_) {},
    onSound: () {},
    streak: const SizedBox.shrink(),
    body: const SizedBox.shrink(),
  );
}

Color? _fillOf(WidgetTester tester, Key key) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(DecoratedBox))
        .first,
  );
  final Decoration decoration = box.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

IconStickerGlyph _glyphOf(WidgetTester tester, Key key) {
  return tester.widget<IconStickerButton>(find.byKey(key)).glyph;
}

void main() {
  group('SidebarShell footer', () {
    testWidgets('the settings button fills with coral only while settings is '
        'the selected destination', (WidgetTester tester) async {
      await tester.pumpWidget(appHarness(_shell()));
      expect(_fillOf(tester, _settingsKey), Palette.cardLight);

      await tester.pumpWidget(
        appHarness(_shell(selected: ShellDestination.settings)),
      );
      expect(_fillOf(tester, _settingsKey), Palette.coral);
    });

    testWidgets('the sound glyph follows the sound-enabled state',
        (WidgetTester tester) async {
      await tester.pumpWidget(appHarness(_shell()));
      expect(_glyphOf(tester, _soundKey), IconStickerGlyph.soundOn);

      await tester.pumpWidget(appHarness(_shell(soundOn: false)));
      expect(_glyphOf(tester, _soundKey), IconStickerGlyph.soundOff);
    });

    testWidgets('both footer buttons expose an accessible label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(appHarness(_shell()));

      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      expect(find.bySemanticsLabel('Sound effects on'), findsOneWidget);

      await tester.pumpWidget(appHarness(_shell(soundOn: false)));
      expect(find.bySemanticsLabel('Sound effects off'), findsOneWidget);

      handle.dispose();
    });
  });
}
