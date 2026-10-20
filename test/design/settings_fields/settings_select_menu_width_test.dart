import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';

const List<SettingsSelectOption<int>> _weekStarts = <SettingsSelectOption<int>>[
  SettingsSelectOption<int>(value: 0, label: 'Sunday'),
  SettingsSelectOption<int>(value: 1, label: 'Monday'),
  SettingsSelectOption<int>(value: 6, label: 'Saturday'),
];

Widget _selectAt(Alignment alignment) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(platform: TargetPlatform.macOS),
    home: Scaffold(
      backgroundColor: FieldNotesColors.light.page,
      body: Align(
        alignment: alignment,
        child: SettingsSelect<int>(
          options: _weekStarts,
          value: 1,
          onChanged: (_) {},
        ),
      ),
    ),
  );
}

Finder _menuLabel(String label) => find.text(label).last;

void main() {
  for (final MapEntry<String, Alignment> placement in <String, Alignment>{
    'at the start of its row': Alignment.topLeft,
    'at the end of its row': Alignment.topRight,
  }.entries) {
    testWidgets(
      'a desktop settings select ${placement.key} shows every choice in full, on screen',
      (WidgetTester tester) async {
        await tester.pumpWidget(_selectAt(placement.value));

        await tester.tap(find.text('Monday'));
        await tester.pumpAndSettle();

        final Rect screen =
            Offset.zero &
            tester.view.physicalSize / tester.view.devicePixelRatio;
        for (final String label in <String>['Sunday', 'Monday', 'Saturday']) {
          final RenderParagraph paragraph = tester
              .renderObject<RenderParagraph>(_menuLabel(label));
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '$label is cut off',
          );
          final Rect shown = tester.getRect(_menuLabel(label));
          expect(
            screen.contains(shown.topLeft) &&
                screen.contains(shown.bottomRight),
            isTrue,
            reason: '$label is drawn at $shown, outside $screen',
          );
        }
      },
    );
  }
}
