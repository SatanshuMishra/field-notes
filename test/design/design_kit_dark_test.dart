import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import '../support/theme_harness.dart';

const Color _coral = Color(0xFFC76A54);
const Color _line = Color(0xFF9D8870);
const Color _shadow = Color(0xFF070504);
const Color _cardWarm = Color(0xFF29221B);
const Color _ink = Color(0xFFEFE3CE);
const Color _panelTop = Color(0xFF1E1914);
const Color _cardBright = Color(0xFF211B16);
const Color _toastInk = Color(0xFFFBF3E4);
const Color _ringOnDark = Color(0xFFE9DCC6);

const Key _lightRingKey = ValueKey<String>('light-ring');
const Key _darkRingKey = ValueKey<String>('dark-ring');

Future<void> _pumpDark(WidgetTester tester, Widget child) =>
    pumpThemed(tester, Center(child: child), brightness: Brightness.dark);

List<BoxDecoration> _decorationsIn(WidgetTester tester, Finder owner) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: owner, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration as BoxDecoration)
    .toList();

Color _borderColour(BoxDecoration decoration) =>
    (decoration.border! as Border).top.color;

Color? _fillBehind(WidgetTester tester, String label) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

Color? _textColour(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

FocusNode _focusNode(String label) {
  final FocusNode node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

void main() {
  test('design kit names no light-only colour', () {
    expect(
      lightOnlyTokenUses(<String>[
        'lib/design/widgets',
        'lib/design/feedback',
        'lib/design/settings_fields',
        'lib/design/focus',
        'lib/design/motion',
      ]),
      isEmpty,
    );
  });

  testWidgets('sticker button and card draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(tester, StickerButton(label: 'Go', onPressed: () {}));
    final BoxDecoration primary = _decorationsIn(
      tester,
      find.byType(StickerButton),
    ).single;
    expect(primary.color, _coral);
    expect(_borderColour(primary), _line);
    expect(primary.boxShadow, <BoxShadow>[
      const BoxShadow(color: _shadow, offset: Offset(2, 2)),
    ]);

    await _pumpDark(
      tester,
      StickerButton(
        label: 'Later',
        variant: StickerButtonVariant.secondary,
        onPressed: () {},
      ),
    );
    final BoxDecoration secondary = _decorationsIn(
      tester,
      find.byType(StickerButton),
    ).single;
    expect(secondary.color, _cardWarm);
    expect(_textColour(tester, 'Later'), _ink);

    await _pumpDark(tester, const StickerCard(child: Text('Card')));
    final BoxDecoration card = _decorationsIn(
      tester,
      find.byType(StickerCard),
    ).single;
    expect(card.color, _cardWarm);
    expect(_borderColour(card), _line);
    expect(card.boxShadow, <BoxShadow>[
      const BoxShadow(color: Color(0x33000000), offset: Offset(3, 3)),
    ]);
  });

  testWidgets('settings toggle and segmented control draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(tester, SettingsToggle(value: false, onChanged: (_) {}));
    final List<BoxDecoration> toggle = _decorationsIn(
      tester,
      find.byType(SettingsToggle),
    );
    expect(toggle, hasLength(2));
    expect(toggle.first.color, _panelTop);
    expect(_borderColour(toggle.first), _line);
    expect(toggle.last.color, _cardBright);
    expect(_borderColour(toggle.last), _line);

    await _pumpDark(
      tester,
      SettingsSegmented<String>(
        segments: const <SettingsSegment<String>>[
          SettingsSegment<String>(value: 'device', label: 'On this device'),
          SettingsSegment<String>(value: 'server', label: 'Sync to server'),
        ],
        value: 'device',
        onChanged: (_) {},
      ),
    );
    final BoxDecoration track = _decorationsIn(
      tester,
      find.byType(SettingsSegmented<String>),
    ).first;
    expect(track.color, _panelTop);
    expect(_fillBehind(tester, 'On this device'), Palette.coral);
  });

  testWidgets('dark toast and focus ring draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      const Toast(message: 'Saved', variant: ToastVariant.dark),
    );
    final GlassSurface glass = tester.widget<GlassSurface>(
      find.descendant(
        of: find.byType(Toast),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(glass.tone, GlassTone.toast);
    expect(_textColour(tester, 'Saved')!.toARGB32(), _toastInk.toARGB32());

    _useKeyboardHighlight();
    final FocusNode lightNode = _focusNode('light');
    final FocusNode darkNode = _focusNode('dark');
    await _pumpDark(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FocusRing(
            key: _lightRingKey,
            focusNode: lightNode,
            onPressed: () {},
            child: const SizedBox(width: 120, height: 48),
          ),
          const SizedBox(height: 24),
          FocusRing(
            key: _darkRingKey,
            focusNode: darkNode,
            surface: FocusRingSurface.dark,
            onPressed: () {},
            child: const SizedBox(width: 120, height: 48),
          ),
        ],
      ),
    );

    lightNode.requestFocus();
    await tester.pumpAndSettle();
    expect(
      tester.renderObject(
        find.descendant(
          of: find.byKey(_lightRingKey),
          matching: find.byKey(focusRingKey),
        ),
      ),
      paints..rect(color: _ink, strokeWidth: 3, style: PaintingStyle.stroke),
    );

    darkNode.requestFocus();
    await tester.pumpAndSettle();
    expect(
      tester.renderObject(
        find.descendant(
          of: find.byKey(_darkRingKey),
          matching: find.byKey(focusRingKey),
        ),
      ),
      paints
        ..rect(color: _ringOnDark, strokeWidth: 2, style: PaintingStyle.stroke),
    );
  });
}
