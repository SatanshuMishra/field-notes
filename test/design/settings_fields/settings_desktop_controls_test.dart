import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

const Size _desktopWindow = Size(1140, 726);
const Size _phoneView = Size(384, 832);

const Key _toggleOnKey = ValueKey<String>('toggle-on');
const Key _toggleOffKey = ValueKey<String>('toggle-off');
const Key _segmentedKey = ValueKey<String>('segmented');
const Key _selectKey = ValueKey<String>('select');
const Key _neutralKey = ValueKey<String>('neutral');
const Key _primaryKey = ValueKey<String>('primary');
const Key _dangerKey = ValueKey<String>('danger');
const Key _disabledKey = ValueKey<String>('disabled');

const List<SettingsSegment<String>> _appearance = <SettingsSegment<String>>[
  SettingsSegment<String>(value: 'light', label: 'Light'),
  SettingsSegment<String>(value: 'dark', label: 'Dark'),
  SettingsSegment<String>(value: 'system', label: 'System'),
];

const List<SettingsSelectOption<int>> _weekStarts = <SettingsSelectOption<int>>[
  SettingsSelectOption<int>(value: 0, label: 'Sunday'),
  SettingsSelectOption<int>(value: 1, label: 'Monday'),
];

Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  required List<Widget> children,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (platform == TargetPlatform.android) {
    tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final Widget child in children) ...<Widget>[
                  child,
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

List<Rect> _rects(Finder finder) => finder.evaluate().map((Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}).toList();

Finder _decorations(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox));

List<BoxDecoration> _decorationsOf(WidgetTester tester, Key key) => tester
    .widgetList<DecoratedBox>(_decorations(key))
    .map((DecoratedBox box) => box.decoration as BoxDecoration)
    .toList();

BorderSide _side(BoxDecoration decoration) =>
    (decoration.border! as Border).top;

Rect _globalRect(SemanticsNode node) =>
    <SemanticsNode>[
      for (SemanticsNode? at = node; at != null; at = at.parent) at,
    ].fold(
      node.rect,
      (Rect rect, SemanticsNode at) => switch (at.transform) {
        final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
        null => rect,
      },
    );

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void _expectSmallSans(TextStyle style, double size, FontWeight weight) {
  expect(style.fontFamily, TypographyTokens.sans);
  expect(style.fontSize, size);
  expect(style.fontWeight, weight);
}

void main() {
  testWidgets(
    'desktop settings controls are drawn small with 24 pixel targets',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<bool> toggled = <bool>[];
      final List<String> picked = <String>[];
      final List<String> presses = <String>[];
      await _pump(
        tester,
        platform: TargetPlatform.macOS,
        size: _desktopWindow,
        children: <Widget>[
          SettingsToggle(
            key: _toggleOnKey,
            value: true,
            semanticLabel: 'Spell check',
            onChanged: toggled.add,
          ),
          SettingsToggle(
            key: _toggleOffKey,
            value: false,
            semanticLabel: 'Pause the Meadow',
            onChanged: toggled.add,
          ),
          SettingsSegmented<String>(
            key: _segmentedKey,
            segments: _appearance,
            value: 'light',
            onChanged: picked.add,
          ),
          SettingsSelect<int>(
            key: _selectKey,
            options: _weekStarts,
            value: 1,
            onChanged: (int _) {},
          ),
          SettingsActionButton(
            key: _neutralKey,
            label: 'Show tour',
            onPressed: () => presses.add('neutral'),
          ),
          SettingsActionButton(
            key: _primaryKey,
            label: 'Update now',
            tone: SettingsActionTone.primary,
            onPressed: () => presses.add('primary'),
          ),
          SettingsActionButton(
            key: _dangerKey,
            label: 'Delete all',
            tone: SettingsActionTone.danger,
            onPressed: () => presses.add('danger'),
          ),
          const SettingsActionButton(
            key: _disabledKey,
            label: 'Checking',
            onPressed: null,
          ),
        ],
      );
      final FieldNotesColors colors = FieldNotesColors.light;

      for (final (Key key, bool on) in <(Key, bool)>[
        (_toggleOnKey, true),
        (_toggleOffKey, false),
      ]) {
        final List<BoxDecoration> parts = _decorationsOf(tester, key);
        final List<Rect> rects = _rects(_decorations(key));
        final BoxDecoration track = parts[0];
        final BoxDecoration knob = parts[1];
        expect(rects[0].size, const Size(36, 20));
        expect(track.borderRadius, BorderRadius.circular(10));
        expect(_side(track).width, 1.5);
        expect(_side(track).color.toARGB32(), colors.line.toARGB32());
        expect(
          track.color!.toARGB32(),
          on ? Palette.coral.toARGB32() : colors.panelTop.toARGB32(),
        );
        expect(rects[1].size, const Size(14, 14));
        expect(knob.shape, BoxShape.circle);
        expect(_side(knob).width, closeTo(1.2, 1e-6));
        expect(_side(knob).color.toARGB32(), colors.line.toARGB32());
        expect(knob.color!.toARGB32(), colors.cardBright.toARGB32());
        expect(rects[1].left - rects[0].left, on ? 1.5 + 1.5 + 16 : 1.5 + 1.5);
        expect(rects[1].center.dy, rects[0].center.dy);
        expect(
          tester
              .widget<AnimatedAlign>(
                find.descendant(
                  of: find.byKey(key),
                  matching: find.byType(AnimatedAlign),
                ),
              )
              .duration,
          const Duration(milliseconds: 150),
        );
        final Rect target = tester.getRect(find.byKey(key));
        expect(target.width, greaterThanOrEqualTo(36));
        expect(target.height, greaterThanOrEqualTo(24));
        expect(rects[0].center, target.center);
      }
      final Rect toggleTarget = tester.getRect(find.byKey(_toggleOnKey));
      final Rect toggleTrack = _rects(_decorations(_toggleOnKey))[0];
      expect(toggleTarget.top, lessThan(toggleTrack.top));
      await tester.tapAt(Offset(toggleTrack.center.dx, toggleTarget.top + 0.5));
      await tester.tapAt(
        Offset(toggleTrack.center.dx, toggleTarget.bottom - 0.5),
      );
      expect(toggled, <bool>[false, false]);
      expect(
        _globalRect(tester.getSemantics(find.bySemanticsLabel('Spell check')))
            .height,
        greaterThanOrEqualTo(24),
      );

      final List<BoxDecoration> segmentParts = _decorationsOf(
        tester,
        _segmentedKey,
      );
      final List<Rect> segmentRects = _rects(_decorations(_segmentedKey));
      final BoxDecoration frame = segmentParts[0];
      expect(frame.color!.toARGB32(), colors.panelTop.toARGB32());
      expect(frame.borderRadius, BorderRadius.circular(9));
      expect(_side(frame).width, 1.5);
      expect(_side(frame).color.toARGB32(), colors.line.toARGB32());
      expect(segmentRects[1].left - segmentRects[0].left, 1.5 + 1.5);
      expect(segmentRects[1].top - segmentRects[0].top, 1.5 + 1.5);
      for (int index = 0; index < _appearance.length; index++) {
        final String label = _appearance[index].label;
        final bool selected = index == 0;
        final BoxDecoration segment = segmentParts[index + 1];
        final Rect segmentRect = segmentRects[index + 1];
        expect(segment.borderRadius, BorderRadius.circular(7), reason: label);
        expect(
          segment.color!.toARGB32(),
          selected ? Palette.coral.toARGB32() : 0x00000000,
          reason: label,
        );
        final TextStyle style = _styleOf(tester, label);
        _expectSmallSans(style, 12, FontWeight.w600);
        expect(
          style.color!.toARGB32(),
          selected ? Palette.onAccent.toARGB32() : colors.ink.toARGB32(),
          reason: label,
        );
        final Rect text = tester.getRect(find.text(label));
        expect(text.left - segmentRect.left, 10, reason: label);
        expect(text.top - segmentRect.top, 3, reason: label);
        expect(
          _globalRect(tester.getSemantics(find.bySemanticsLabel(label))).height,
          greaterThanOrEqualTo(24),
          reason: label,
        );
      }
      final Rect band = tester.getRect(find.byKey(_segmentedKey));
      expect(band.height, greaterThanOrEqualTo(24));
      for (final String label in <String>['Dark', 'System']) {
        final double x = tester.getCenter(find.text(label)).dx;
        await tester.tapAt(Offset(x, band.top + 0.5));
        await tester.tapAt(Offset(x, band.bottom - 0.5));
      }
      expect(picked, <String>['dark', 'dark', 'system', 'system']);

      final BoxDecoration field = _decorationsOf(tester, _selectKey).first;
      final Rect fieldRect = _rects(_decorations(_selectKey)).first;
      expect(field.color!.toARGB32(), colors.cardBright.toARGB32());
      expect(field.borderRadius, BorderRadius.circular(9));
      expect(_side(field).width, 1.5);
      expect(_side(field).color.toARGB32(), colors.line.toARGB32());
      final TextStyle value = _styleOf(tester, 'Monday');
      _expectSmallSans(value, 13, FontWeight.w400);
      expect(value.color!.toARGB32(), colors.ink.toARGB32());
      final Rect valueRect = tester.getRect(find.text('Monday'));
      expect(valueRect.left - fieldRect.left, 1.5 + 10);
      expect(valueRect.top - fieldRect.top, 1.5 + 4);
      final Finder chevron = find.descendant(
        of: find.byKey(_selectKey),
        matching: find.byType(Icon),
      );
      expect(tester.widget<Icon>(chevron).size, 14);
      expect(tester.getRect(chevron).left - valueRect.right, 7);
      expect(
        tester.getRect(find.byKey(_selectKey)).height,
        greaterThanOrEqualTo(24),
      );

      for (final (
            Key key,
            String label,
            Color? fill,
            Color border,
            Color ink,
            bool shadow,
          )
          in <(Key, String, Color?, Color, Color, bool)>[
            (
              _neutralKey,
              'Show tour',
              null,
              Palette.coral,
              colors.accentInk,
              false,
            ),
            (
              _primaryKey,
              'Update now',
              Palette.coral,
              colors.line,
              Palette.onAccent,
              true,
            ),
            (
              _dangerKey,
              'Delete all',
              Palette.danger,
              colors.line,
              Palette.onAccent,
              true,
            ),
          ]) {
        final BoxDecoration pill = _decorationsOf(tester, key).first;
        final Rect pillRect = _rects(_decorations(key)).first;
        expect(pill.borderRadius, BorderRadius.circular(13), reason: label);
        expect(pill.color?.toARGB32(), fill?.toARGB32(), reason: label);
        expect(_side(pill).width, 1.5, reason: label);
        expect(_side(pill).color.toARGB32(), border.toARGB32(), reason: label);
        if (shadow) {
          expect(pill.boxShadow, hasLength(1), reason: label);
          final BoxShadow hard = pill.boxShadow!.single;
          expect(hard.offset, const Offset(1.5, 1.5), reason: label);
          expect(hard.blurRadius, 0, reason: label);
          expect(
            hard.color.toARGB32(),
            colors.shadow.toARGB32(),
            reason: label,
          );
        } else {
          expect(pill.boxShadow ?? const <BoxShadow>[], isEmpty, reason: label);
        }
        final TextStyle style = _styleOf(tester, label);
        _expectSmallSans(style, 12, FontWeight.w600);
        expect(style.color!.toARGB32(), ink.toARGB32(), reason: label);
        final Rect text = tester.getRect(find.text(label));
        expect(text.left - pillRect.left, 1.5 + 12, reason: label);
        expect(text.top - pillRect.top, 1.5 + 5, reason: label);
        expect(
          tester.getRect(find.byKey(key)).height,
          greaterThanOrEqualTo(24),
          reason: label,
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: label,
        );
      }
      await tester.tap(find.byKey(_primaryKey));
      await tester.tap(find.byKey(_dangerKey));
      expect(presses, <String>['primary', 'danger']);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(_neutralKey)));
      await tester.pump();
      expect(
        _decorationsOf(tester, _neutralKey).first.color!.toARGB32(),
        Palette.coral.withValues(alpha: 0.08).toARGB32(),
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(_decorationsOf(tester, _neutralKey).first.color, isNull);

      Focus.of(tester.element(find.text('Show tour'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, <String>['primary', 'danger', 'neutral']);

      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byKey(_disabledKey),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.5,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Checking')),
        isSemantics(
          label: 'Checking',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      await tester.tap(find.byKey(_disabledKey), warnIfMissed: false);
      expect(presses, <String>['primary', 'danger', 'neutral']);
      expect(
        tester.getRect(find.byKey(_disabledKey)).height,
        greaterThanOrEqualTo(24),
      );

      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets('phone settings controls keep their 48 pixel targets', (
    WidgetTester tester,
  ) async {
    void neutral() {}
    void primary() {}
    void danger() {}
    await _pump(
      tester,
      platform: TargetPlatform.android,
      size: _phoneView,
      children: <Widget>[
        SettingsToggle(key: _toggleOnKey, value: true, onChanged: (bool _) {}),
        SettingsActionButton(
          key: _neutralKey,
          label: 'Show tour',
          onPressed: neutral,
        ),
        SettingsActionButton(
          key: _primaryKey,
          label: 'Update now',
          tone: SettingsActionTone.primary,
          onPressed: primary,
        ),
        SettingsActionButton(
          key: _dangerKey,
          label: 'Delete all',
          tone: SettingsActionTone.danger,
          onPressed: danger,
        ),
      ],
    );

    final List<Rect> toggleParts = _rects(_decorations(_toggleOnKey));
    expect(toggleParts[0].size, const Size(52, 30));
    expect(toggleParts[1].size, const Size(22, 22));
    final Rect toggle = tester.getRect(find.byKey(_toggleOnKey));
    expect(toggle.width, greaterThanOrEqualTo(48));
    expect(toggle.height, greaterThanOrEqualTo(48));

    for (final (
          Key key,
          String label,
          StickerButtonVariant variant,
          Object callback,
        )
        in <(Key, String, StickerButtonVariant, Object)>[
          (_neutralKey, 'Show tour', StickerButtonVariant.secondary, neutral),
          (_primaryKey, 'Update now', StickerButtonVariant.primary, primary),
          (_dangerKey, 'Delete all', StickerButtonVariant.danger, danger),
        ]) {
      final StickerButton button = tester.widget<StickerButton>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(StickerButton),
        ),
      );
      expect(button.label, label);
      expect(button.variant, variant, reason: label);
      expect(button.padTapTarget, isTrue, reason: label);
      expect(button.onPressed, same(callback), reason: label);
      final Rect target = tester.getRect(find.byKey(key));
      expect(target.height, greaterThanOrEqualTo(48), reason: label);
      expect(target.width, greaterThanOrEqualTo(48), reason: label);
    }
    expect(tester.takeException(), isNull);
  });
}
