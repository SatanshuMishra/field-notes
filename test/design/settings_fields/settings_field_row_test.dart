import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'settings_harness.dart';

const double _minTapTarget = 48;

const List<String> _dataButtonLabels = <String>[
  'Export…',
  'Reclaim space',
  'Delete all…',
];

const Key _plainControlKey = ValueKey<String>('plain-control');
const Key _leadingKey = ValueKey<String>('leading');
const Key _wrappedLeadingKey = ValueKey<String>('wrapped-leading');
const Key _markerKey = ValueKey<String>('marker');
const Key _belowKey = ValueKey<String>('below');

const String _plainLabel = 'Plain row';
const String _plainDescription = 'Nothing extra here';
const String _slottedLabel = 'Sync status';
const String _slottedDescription = 'Last change sent today';
const String _pressLabel = 'Manage devices';
const String _pressDescription = '2 devices · add or remove';
const String _controlLabel = 'chevron';

void _usePhoneWidth(WidgetTester tester) {
  tester.view.physicalSize = const Size(411, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _dataRows(ValueChanged<String> onPressed) {
  return SettingsSection(
    title: 'Data',
    children: <Widget>[
      SettingsFieldRow(
        label: 'Export',
        description: 'Save a zip of every entry and photo.',
        control: StickerButton(
          label: 'Export…',
          variant: StickerButtonVariant.secondary,
          padTapTarget: true,
          onPressed: () => onPressed('Export…'),
        ),
      ),
      SettingsFieldRow(
        label: 'Reclaim space',
        description: 'Remove photo files no entry or draft still refers to.',
        control: StickerButton(
          label: 'Reclaim space',
          variant: StickerButtonVariant.secondary,
          padTapTarget: true,
          onPressed: () => onPressed('Reclaim space'),
        ),
      ),
      SettingsFieldRow(
        label: 'Delete all',
        description: 'Erase every entry, photo, and mood on this device.',
        control: StickerButton(
          label: 'Delete all…',
          variant: StickerButtonVariant.danger,
          padTapTarget: true,
          onPressed: () => onPressed('Delete all…'),
        ),
      ),
    ],
  );
}

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

Rect _buttonNodeRect(WidgetTester tester, String label) =>
    _globalRect(tester.getSemantics(find.bySemanticsLabel(label)));

Rect _tapBoxAroundPaintedButton(WidgetTester tester, String label) {
  final Rect painted = tester.getRect(
    find
        .descendant(
          of: find.widgetWithText(StickerButton, label),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return Rect.fromCenter(
    center: painted.center,
    width: math.max(painted.width, _minTapTarget),
    height: math.max(painted.height, _minTapTarget),
  );
}

Rect _textColumn(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(MergeSemantics)),
);

Rect _rowRect(WidgetTester tester, String label) =>
    tester.getRect(find.widgetWithText(SettingsFieldRow, label));

Iterable<RenderObject> _renderPath(RenderObject from, RenderObject to) sync* {
  for (RenderObject? node = from.parent; node != null; node = node.parent) {
    yield node;
    if (identical(node, to)) {
      return;
    }
  }
}

void main() {
  group('SettingsFieldRow', () {
    testWidgets('renders the label, description, and control', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsFieldRow(
              label: 'Daily reminder',
              description: 'Get a nudge to write',
              control: Text('control-slot'),
            ),
          ),
        ),
      );

      expect(find.text('Daily reminder'), findsOneWidget);
      expect(find.text('Get a nudge to write'), findsOneWidget);
      expect(find.text('control-slot'), findsOneWidget);
    });

    testWidgets('omits the description when none is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsFieldRow(label: 'Storage mode', control: Text('c')),
          ),
        ),
      );

      expect(find.text('Storage mode'), findsOneWidget);
    });

    testWidgets('hosts a trailing danger StickerButton and forwards taps', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 360,
            child: SettingsFieldRow(
              label: 'Delete all',
              control: StickerButton(
                label: 'Delete all…',
                variant: StickerButtonVariant.danger,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Delete all…'), findsOneWidget);
      await tester.tap(find.byType(StickerButton));
      expect(taps, 1);
    });

    testWidgets(
      "a trailing button's node is its own 48 dp target, not the row",
      (WidgetTester tester) async {
        _usePhoneWidth(tester);
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(settingsHarness(_dataRows((String _) {})));

        for (final String label in _dataButtonLabels) {
          final Rect node = _buttonNodeRect(tester, label);
          final Rect target = _tapBoxAroundPaintedButton(tester, label);
          expect(
            node.width,
            greaterThanOrEqualTo(_minTapTarget),
            reason: label,
          );
          expect(
            node.height,
            greaterThanOrEqualTo(_minTapTarget),
            reason: label,
          );
          expect(
            target.inflate(0.01).intersect(node),
            node,
            reason: '$label node $node lies outside $target',
          );
        }
        handle.dispose();
      },
    );

    testWidgets("a tap anywhere on the button's node presses it", (
      WidgetTester tester,
    ) async {
      _usePhoneWidth(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> presses = <String>[];
      await tester.pumpWidget(settingsHarness(_dataRows(presses.add)));

      for (final String label in _dataButtonLabels) {
        final Rect inset = _buttonNodeRect(tester, label).deflate(2);
        for (final Offset corner in <Offset>[
          inset.topLeft,
          inset.topRight,
          inset.bottomLeft,
          inset.bottomRight,
        ]) {
          final int before = presses.length;
          await tester.tapAt(corner);
          await tester.pump();
          expect(presses.skip(before), <String>[
            label,
          ], reason: '$label at $corner');
        }
      }
      handle.dispose();
    });
  });

  testWidgets(
    'field rows take a leading mark, a hanging marker, content below and a '
    'whole-row action',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1140, 726);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final SemanticsHandle handle = tester.ensureSemantics();
      final String wrappedLabel = List<String>.filled(30, 'wrapping').join(' ');
      int presses = 0;
      int controlPresses = 0;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: SizedBox(
                  width: 640,
                  child: Column(
                    children: <Widget>[
                      const SettingsFieldRow(
                        label: _plainLabel,
                        description: _plainDescription,
                        control: SizedBox(
                          key: _plainControlKey,
                          width: 36,
                          height: 20,
                        ),
                      ),
                      const SettingsFieldRow(
                        label: _slottedLabel,
                        description: _slottedDescription,
                        leading: SizedBox(
                          key: _leadingKey,
                          width: 8,
                          height: 8,
                        ),
                        marker: SizedBox(key: _markerKey, width: 8, height: 8),
                        below: SizedBox(key: _belowKey, width: 300, height: 8),
                        control: SizedBox(width: 36, height: 20),
                      ),
                      SettingsFieldRow(
                        label: wrappedLabel,
                        leading: const SizedBox(
                          key: _wrappedLeadingKey,
                          width: 8,
                          height: 8,
                        ),
                        control: const SizedBox(width: 36, height: 20),
                      ),
                      SettingsFieldRow(
                        label: _pressLabel,
                        description: _pressDescription,
                        control: SettingsActionButton(
                          label: _controlLabel,
                          onPressed: () => controlPresses++,
                        ),
                        onPressed: () => presses++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final Rect plainRow = _rowRect(tester, _plainLabel);
      final Rect plainText = _textColumn(tester, _plainLabel);
      final Rect plainControl = tester.getRect(find.byKey(_plainControlKey));
      expect(plainText.left, plainRow.left);
      expect(plainControl.right, plainRow.right);
      expect(plainControl.left - plainText.right, moreOrLessEquals(20));
      expect(plainRow.height, plainText.height);
      expect(tester.getRect(find.text(_plainLabel)).left, plainRow.left);
      final SemanticsNode plainNode = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^$_plainLabel')),
      );
      expect(plainNode.getSemanticsData().flagsCollection.isButton, isFalse);
      expect(
        find.descendant(
          of: find.widgetWithText(SettingsFieldRow, _plainLabel),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );

      final Rect slottedRow = _rowRect(tester, _slottedLabel);
      final Rect slottedText = _textColumn(tester, _slottedLabel);
      final Rect slottedLabel = tester.getRect(find.text(_slottedLabel));
      final Rect leading = tester.getRect(find.byKey(_leadingKey));
      expect(leading.left, slottedText.left);
      expect(slottedLabel.left - leading.right, moreOrLessEquals(8));
      expect(leading.center.dy, moreOrLessEquals(slottedLabel.center.dy));

      final double lineHeight = tester.getRect(find.text(_plainLabel)).height;
      final Rect wrapped = tester.getRect(find.text(wrappedLabel));
      final Rect wrappedLeading = tester.getRect(
        find.byKey(_wrappedLeadingKey),
      );
      expect(wrapped.height, greaterThan(lineHeight * 2));
      expect(wrapped.left - wrappedLeading.right, moreOrLessEquals(8));
      expect(
        wrappedLeading.center.dy,
        moreOrLessEquals(wrapped.top + lineHeight / 2),
      );

      final Rect marker = tester.getRect(find.byKey(_markerKey));
      expect(marker.left, moreOrLessEquals(slottedText.left - 16));
      expect(marker.top, moreOrLessEquals(slottedText.top + 7));
      expect(slottedRow.left, plainRow.left);
      expect(slottedText.left, plainText.left);
      expect(slottedRow.width, plainRow.width);
      final RenderObject rowBox = tester.renderObject(
        find.widgetWithText(SettingsFieldRow, _slottedLabel),
      );
      for (final RenderObject node in _renderPath(
        tester.renderObject(find.byKey(_markerKey)),
        rowBox,
      )) {
        expect(
          node,
          isNot(
            anyOf(
              isA<RenderClipRect>(),
              isA<RenderClipRRect>(),
              isA<RenderClipPath>(),
              isA<RenderClipOval>(),
            ),
          ),
        );
        if (node is RenderStack) {
          expect(node.clipBehavior, Clip.none);
        }
      }

      final Rect description = tester.getRect(find.text(_slottedDescription));
      final Rect below = tester.getRect(find.byKey(_belowKey));
      expect(below.top - description.bottom, moreOrLessEquals(8));
      expect(below.left, slottedText.left);

      final SemanticsNode pressNode = tester.getSemantics(
        find.bySemanticsLabel(_pressLabel),
      );
      expect(
        pressNode,
        isSemantics(
          label: _pressLabel,
          hint: _pressDescription,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(pressNode.childrenCount, 0);
      expect(find.bySemanticsLabel(_controlLabel), findsNothing);
      expect(find.bySemanticsLabel(_pressDescription), findsNothing);

      final Rect pressRow = _rowRect(tester, _pressLabel);
      await tester.tapAt(tester.getCenter(find.text(_pressLabel)));
      await tester.pump();
      expect(presses, 1);
      await tester.tapAt(tester.getCenter(find.text(_controlLabel)));
      await tester.pump();
      expect(presses, 2);
      expect(controlPresses, 0);
      await tester.tapAt(pressRow.topLeft + const Offset(1, 1));
      await tester.pump();
      expect(presses, 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 5);
      expect(controlPresses, 0);

      final int hoverFill = FieldNotesColors.light.ink
          .withValues(alpha: 0.06)
          .toARGB32();
      Iterable<Rect> filled() => find
          .descendant(
            of: find.widgetWithText(SettingsFieldRow, _pressLabel),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .where(
            (Element element) =>
                ((element.widget as DecoratedBox).decoration as BoxDecoration)
                    .color
                    ?.toARGB32() ==
                hoverFill,
          )
          .map((Element element) {
            final RenderBox box = element.renderObject! as RenderBox;
            return box.localToGlobal(Offset.zero) & box.size;
          });
      expect(filled(), isEmpty);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(pressRow.center);
      await tester.pump();
      expect(filled(), <Rect>[pressRow]);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(filled(), isEmpty);

      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );
}
