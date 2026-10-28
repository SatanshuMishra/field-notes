import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_harness.dart';

const double _rowWidth = 352;
const double _gap = 16;
const double _desktopRowWidth = 640;
const double _desktopGap = 20;
const String _label = 'Pause the Meadow in the background';
const String _description =
    "Stops the Meadow's motion while Field Notes is open but another window "
    'or app is in front. Saves battery.';
const Key _wideKey = ValueKey<String>('wide-control');

Future<void> _pumpRow(
  WidgetTester tester,
  Widget control, {
  double width = _rowWidth,
}) async {
  await tester.pumpWidget(
    settingsHarness(
      SizedBox(
        width: width,
        child: SettingsFieldRow(
          label: _label,
          description: _description,
          control: control,
        ),
      ),
    ),
  );
}

Rect _textColumn(WidgetTester tester) => tester.getRect(
  find.ancestor(of: find.text(_label), matching: find.byType(MergeSemantics)),
);

void main() {
  testWidgets('on the phone a switch takes its own width and the label the '
      'rest', (WidgetTester tester) async {
    await _pumpRow(
      tester,
      SettingsToggle(
        semanticLabel: _label,
        value: false,
        onChanged: (bool value) {},
      ),
    );

    final Rect toggle = tester.getRect(find.byType(SettingsToggle));
    final Rect text = _textColumn(tester);
    expect(toggle.right, _rowWidth);
    expect(toggle.width, lessThan(_rowWidth / 4));
    expect(text.left, 0);
    expect(text.width, _rowWidth - _gap - toggle.width);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on the phone a control that fills its slot still stops at two '
      'thirds of the row', (WidgetTester tester) async {
    await _pumpRow(
      tester,
      const SizedBox(key: _wideKey, width: double.infinity, height: 48),
    );

    const double slot = (_rowWidth - _gap) * 2 / 3;
    final Rect wide = tester.getRect(find.byKey(_wideKey));
    expect(wide.right, _rowWidth);
    expect(wide.width, moreOrLessEquals(slot));
    expect(
      _textColumn(tester).width,
      moreOrLessEquals(_rowWidth - _gap - slot),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on the desktop a switch sits right-aligned at its natural width '
      'after a 20 pixel gap', (WidgetTester tester) async {
    await _pumpRow(
      tester,
      SettingsToggle(
        semanticLabel: _label,
        value: false,
        onChanged: (bool value) {},
      ),
      width: _desktopRowWidth,
    );

    final Rect toggle = tester.getRect(find.byType(SettingsToggle));
    final Rect text = _textColumn(tester);
    expect(toggle.right, _desktopRowWidth);
    expect(toggle.width, 36);
    expect(text.left, 0);
    expect(toggle.left - text.right, _desktopGap);
    expect(text.width, _desktopRowWidth - _desktopGap - toggle.width);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('on the desktop a control that fills its slot stops at half the '
      'row', (WidgetTester tester) async {
    await _pumpRow(
      tester,
      const SizedBox(key: _wideKey, width: double.infinity, height: 24),
      width: _desktopRowWidth,
    );

    final Rect wide = tester.getRect(find.byKey(_wideKey));
    expect(wide.right, _desktopRowWidth);
    expect(wide.width, moreOrLessEquals(_desktopRowWidth / 2));
    expect(
      _textColumn(tester).width,
      moreOrLessEquals(_desktopRowWidth - _desktopGap - _desktopRowWidth / 2),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('at twice the text size a label that would split mid-word puts '
      'its control below it', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final double width = switch (defaultTargetPlatform) {
      TargetPlatform.android => _rowWidth,
      _ => _desktopRowWidth / 2,
    };
    await tester.pumpWidget(
      settingsHarness(
        SizedBox(
          width: width,
          child: const SettingsFieldRow(
            label: 'Appearance',
            description: 'Light, dark, or match your device.',
            control: SizedBox(key: _wideKey, width: 200, height: 40),
          ),
        ),
      ),
    );

    final RenderParagraph label = tester.renderObject<RenderParagraph>(
      find.text('Appearance'),
    );
    expect(
      label
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 10),
          )
          .map((TextBox box) => box.top)
          .toSet(),
      hasLength(1),
    );
    expect(
      tester.getRect(find.byKey(_wideKey)).top,
      greaterThanOrEqualTo(
        tester
            .getRect(
              find.ancestor(
                of: find.text('Appearance'),
                matching: find.byType(MergeSemantics),
              ),
            )
            .bottom,
      ),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
