import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'settings_harness.dart';

const double _minTapTarget = 48;

const List<String> _dataButtonLabels = <String>[
  'Export…',
  'Reclaim space',
  'Delete all…',
];

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

Rect _globalRect(SemanticsNode node) => <SemanticsNode>[
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

void main() {
  group('SettingsFieldRow', () {
    testWidgets('renders the label, description, and control',
        (WidgetTester tester) async {
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

    testWidgets('omits the description when none is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsFieldRow(
              label: 'Storage mode',
              control: Text('c'),
            ),
          ),
        ),
      );

      expect(find.text('Storage mode'), findsOneWidget);
    });

    testWidgets('hosts a trailing danger StickerButton and forwards taps',
        (WidgetTester tester) async {
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

    testWidgets("a trailing button's node is its own 48 dp target, not the row",
        (WidgetTester tester) async {
      _usePhoneWidth(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(settingsHarness(_dataRows((String _) {})));

      for (final String label in _dataButtonLabels) {
        final Rect node = _buttonNodeRect(tester, label);
        final Rect target = _tapBoxAroundPaintedButton(tester, label);
        expect(node.width, greaterThanOrEqualTo(_minTapTarget), reason: label);
        expect(node.height, greaterThanOrEqualTo(_minTapTarget), reason: label);
        expect(
          target.inflate(0.01).intersect(node),
          node,
          reason: '$label node $node lies outside $target',
        );
      }
      handle.dispose();
    });

    testWidgets("a tap anywhere on the button's node presses it",
        (WidgetTester tester) async {
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
          expect(
            presses.skip(before),
            <String>[label],
            reason: '$label at $corner',
          );
        }
      }
      handle.dispose();
    });
  });
}
