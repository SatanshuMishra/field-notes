import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/widgets/anchored_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _anchorKey = ValueKey<String>('anchor');
const Key _menuKey = ValueKey<String>('menu');
const List<String> _labels = <String>['Sunday', 'Monday', 'Saturday'];

Future<void> _pumpOpen(
  WidgetTester tester, {
  required Alignment alignment,
  required double anchorWidth,
  required bool widensToFitChoices,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Material(
        child: Align(
          alignment: alignment,
          child: SizedBox(
            key: _anchorKey,
            width: anchorWidth,
            height: 24,
            child: AnchoredDropdown<String>(
              menuKey: _menuKey,
              current: 'Monday',
              onSelected: (String _) {},
              widensToFitChoices: widensToFitChoices,
              choices: <AnchoredDropdownChoice<String>>[
                for (final String label in _labels)
                  AnchoredDropdownChoice<String>(value: label, label: label),
              ],
              builder: (BuildContext context, bool open, VoidCallback toggle) =>
                  GestureDetector(onTap: toggle, child: const Text('Mon')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_anchorKey));
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry<String, Alignment> placement in <String, Alignment>{
    'start': Alignment.topLeft,
    'end': Alignment.topRight,
  }.entries) {
    testWidgets(
      'a menu that widens to fit its choices under a narrow anchor at the ${placement.key} shows each choice in full, on screen',
      (WidgetTester tester) async {
        await _pumpOpen(
          tester,
          alignment: placement.value,
          anchorWidth: 48,
          widensToFitChoices: true,
        );

        final Rect screen =
            Offset.zero &
            tester.view.physicalSize / tester.view.devicePixelRatio;
        final Rect menu = tester.getRect(find.byKey(_menuKey));
        expect(menu.width, greaterThan(48));
        expect(
          menu.left >= screen.left &&
              menu.top >= screen.top &&
              menu.right <= screen.right &&
              menu.bottom <= screen.bottom,
          isTrue,
          reason: 'menu drawn at $menu, outside $screen',
        );
        for (final String label in _labels) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse,
            reason: '$label is cut off',
          );
        }
      },
    );
  }

  testWidgets('a menu that does not widen keeps its anchor\'s width', (
    WidgetTester tester,
  ) async {
    await _pumpOpen(
      tester,
      alignment: Alignment.topCenter,
      anchorWidth: 280,
      widensToFitChoices: false,
    );

    expect(tester.getSize(find.byKey(_menuKey)).width, 280);
  });
}
