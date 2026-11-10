import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/theme_harness.dart';

const String _label = 'Open settings';
const Key _childKey = ValueKey<String>('child');

const List<(TargetPlatform, double, double)> _targets =
    <(TargetPlatform, double, double)>[
      (TargetPlatform.macOS, 32, 36),
      (TargetPlatform.windows, 40, 40),
      (TargetPlatform.android, 48, 48),
    ];

const List<TargetPlatform> _desktops = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.windows,
];

Widget _iconButton() => IconStickerButton(
  glyph: IconStickerGlyph.gear,
  glyphColor: FieldNotesColors.light.ink,
  background: FieldNotesColors.light.cardLight,
  semanticLabel: _label,
  onPressed: () {},
);

Widget _iconPressable({String? tooltip}) => Pressable(
  label: _label,
  iconOnly: true,
  tooltip: tooltip,
  onPressed: () {},
  child: const SizedBox.square(dimension: 40),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  TargetPlatform platform,
) => pumpThemed(tester, Center(child: child), platform: platform);

Tooltip _soleTooltip(WidgetTester tester) =>
    tester.widget<Tooltip>(find.byType(Tooltip));

void main() {
  for (final (TargetPlatform platform, double icon, double button)
      in _targets) {
    test('$platform floors an icon at $icon and a button at $button', () {
      expect(minIconTargetOn(platform), icon);
      expect(minButtonTargetOn(platform), button);
    });

    testWidgets('MinTarget.icon holds $icon on $platform', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const MinTarget.icon(child: SizedBox.shrink(key: _childKey)),
        platform,
      );

      expect(tester.getSize(find.byKey(_childKey)), Size.square(icon));
    });

    testWidgets('MinTarget.button holds $button on $platform', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const MinTarget.button(child: SizedBox.shrink(key: _childKey)),
        platform,
      );

      expect(tester.getSize(find.byKey(_childKey)), Size.square(button));
    });

    testWidgets('the icon sticker button targets $icon on $platform and '
        'keeps its 30 point face', (WidgetTester tester) async {
      await _pump(tester, _iconButton(), platform);

      expect(tester.getSize(find.byType(IconStickerButton)), Size.square(icon));
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.byType(IconStickerGlyphIcon),
                matching: find.byWidgetPredicate(
                  (Widget widget) =>
                      widget is SizedBox &&
                      widget.width == 30 &&
                      widget.height == 30,
                ),
              )
              .first,
        ),
        const Size.square(30),
      );
    });
  }

  test('existing dense controls keep their floors so no screen moves', () {
    expect(minTargetOn(TargetPlatform.macOS), 28);
    expect(minTargetOn(TargetPlatform.windows), 40);
    expect(minTargetOn(TargetPlatform.android), 48);
  });

  for (final TargetPlatform platform in _desktops) {
    testWidgets('an icon sticker button names itself on $platform', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _iconButton(), platform);

      expect(_soleTooltip(tester).message, _label);
      expect(_soleTooltip(tester).excludeFromSemantics, isTrue);
    });

    testWidgets('an icon-only pressable names itself on $platform', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _iconPressable(), platform);

      expect(_soleTooltip(tester).message, _label);
    });

    testWidgets('a written tooltip wins over the label on $platform', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _iconPressable(tooltip: 'Settings (S)'), platform);

      expect(_soleTooltip(tester).message, 'Settings (S)');
    });
  }

  testWidgets('icon-only controls show no tooltip on the phone', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _iconButton(), TargetPlatform.android);
    expect(find.byType(Tooltip), findsNothing);

    await _pump(
      tester,
      _iconPressable(tooltip: 'Settings'),
      TargetPlatform.android,
    );
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('a labelled pressable gains no tooltip on desktop', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Pressable(label: _label, onPressed: () {}, child: const Text(_label)),
      TargetPlatform.macOS,
    );

    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('a pressable that asks for a tooltip keeps it on the phone', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Pressable(
        label: _label,
        tooltip: _label,
        onPressed: () {},
        child: const SizedBox.square(dimension: 48),
      ),
      TargetPlatform.android,
    );

    expect(find.byTooltip(_label), findsOneWidget);
  });
}
