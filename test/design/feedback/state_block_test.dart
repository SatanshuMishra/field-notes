import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/theme_harness.dart';

const String _title = 'Nothing planted yet today';
const String _message = 'A voice, a video or a few words is enough.';
const String _action = 'New log';
const Size _window = Size(420, 700);

const List<(String, Brightness, FieldNotesColors)> _themes =
    <(String, Brightness, FieldNotesColors)>[
      ('light', Brightness.light, FieldNotesColors.light),
      ('dark', Brightness.dark, FieldNotesColors.dark),
    ];

Future<void> _pump(
  WidgetTester tester,
  Widget block, {
  Brightness brightness = Brightness.light,
  Size size = _window,
}) => pumpThemed(
  tester,
  Padding(padding: const EdgeInsets.all(16), child: block),
  brightness: brightness,
  platform: TargetPlatform.macOS,
  size: size,
);

Iterable<DashedBorderPainter> _dashes(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(StateBlock),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((CustomPaint paint) => paint.painter)
    .whereType<DashedBorderPainter>();

Color? _colourOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

StickerButton _button(WidgetTester tester) =>
    tester.widget<StickerButton>(find.byType(StickerButton));

void main() {
  for (final (String name, Brightness brightness, FieldNotesColors colors)
      in _themes) {
    testWidgets('loading draws three dashed lines and a caption in $name', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const StateBlock.loading(), brightness: brightness);

      final List<DashedBorderPainter> dashes = _dashes(tester).toList();
      expect(dashes, hasLength(4));
      expect(dashes.first.color, colors.ink35);
      expect(dashes.first.radius, Shapes.radius16);
      expect(
        dashes.skip(1).map((DashedBorderPainter painter) => painter.color),
        everyElement(colors.ink22),
      );
      expect(find.text(stateBlockLoadingLabel), findsOneWidget);
      expect(_colourOf(tester, stateBlockLoadingLabel), colors.muted);
      expect(find.byType(StickerButton), findsNothing);
    });

    testWidgets('empty shows a daffodil, words and a primary action in $name', (
      WidgetTester tester,
    ) async {
      int presses = 0;
      await _pump(
        tester,
        StateBlock.empty(
          title: _title,
          message: _message,
          actionLabel: _action,
          onAction: () => presses++,
        ),
        brightness: brightness,
      );

      expect(
        tester.widget<FlowerBloom>(find.byType(FlowerBloom)).kind,
        FlowerKind.daffodil,
      );
      expect(_colourOf(tester, _title), colors.ink);
      expect(_colourOf(tester, _message), colors.muted);
      expect(_button(tester).variant, StickerButtonVariant.primary);

      await tester.tap(find.text(_action));
      expect(presses, 1);
    });

    testWidgets('error shows a heart and a secondary retry in $name', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await _pump(
        tester,
        StateBlock.error(
          title: "Today didn't load",
          message: 'Your logs are safe. Try again in a moment.',
          onRetry: () => retries++,
        ),
        brightness: brightness,
      );

      expect(
        tester.widget<FlowerBloom>(find.byType(FlowerBloom)).kind,
        FlowerKind.bleedingHeart,
      );
      expect(_button(tester).variant, StickerButtonVariant.secondary);
      expect(_button(tester).label, stateBlockRetryLabel);

      await tester.tap(find.text(stateBlockRetryLabel));
      expect(retries, 1);
    });
  }

  testWidgets('empty without an action shows only its words', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const StateBlock.empty(title: _title, message: _message),
    );

    expect(find.byType(StickerButton), findsNothing);
  });

  testWidgets('a caller can replace the art and the retry words', (
    WidgetTester tester,
  ) async {
    const Key artKey = ValueKey<String>('art');
    await _pump(
      tester,
      StateBlock.error(
        title: _title,
        message: _message,
        retryLabel: 'Look again',
        art: const SizedBox.square(key: artKey, dimension: 44),
        onRetry: () {},
      ),
    );

    expect(find.byKey(artKey), findsOneWidget);
    expect(find.byType(FlowerBloom), findsNothing);
    expect(find.text('Look again'), findsOneWidget);
  });

  testWidgets('the block fills the width it is given', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const StateBlock.loading());

    expect(tester.getSize(find.byType(StateBlock)).width, _window.width - 32);
  });

  testWidgets('long words wrap without overflowing a narrow window', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      StateBlock.error(
        title: 'A very long title that cannot possibly fit on one line here',
        message: 'A very long message that also needs several lines to fit.',
        onRetry: () {},
      ),
      size: const Size(200, 700),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers hear the words and the action, not the art', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(
      tester,
      StateBlock.error(title: _title, message: _message, onRetry: () {}),
    );

    expect(find.bySemanticsLabel(_title), findsOneWidget);
    expect(find.bySemanticsLabel(_message), findsOneWidget);
    expect(find.bySemanticsLabel(FlowerKind.bleedingHeart.label), findsNothing);
    expect(
      tester.getSemantics(find.text(_title)),
      matchesSemantics(label: _title, isHeader: true, isLiveRegion: true),
    );
    expect(
      tester
          .getSemantics(find.text(stateBlockRetryLabel))
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('loading announces itself as a live region', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester, const StateBlock.loading());

    expect(
      tester.getSemantics(find.text(stateBlockLoadingLabel)),
      matchesSemantics(label: stateBlockLoadingLabel, isLiveRegion: true),
    );
    semantics.dispose();
  });
}
