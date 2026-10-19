import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const int _mousePointerId = 37;
const int _mouseDevice = 1;
const Key _rowKey = ValueKey<String>('row');
const Key _pillKey = ValueKey<String>('pill');
const Key _darkKey = ValueKey<String>('dark');
const Key _builderKey = ValueKey<String>('builder');
const Key _disabledKey = ValueKey<String>('disabled');
const Size _controlSize = Size(160, 40);
const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(10));
const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusPill),
);
const BorderRadius _darkRadius = BorderRadius.all(Radius.circular(16));

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: fieldNotesTheme(platform: TargetPlatform.macOS),
    home: Material(child: Center(child: child)),
  ),
);

Widget _face() => SizedBox.fromSize(
  size: _controlSize,
  child: const Center(child: Text('Face')),
);

Future<TestGesture> _mousePointer(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: _mousePointerId,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Future<void> _hover(WidgetTester tester, TestGesture mouse, Key key) async {
  await mouse.moveTo(tester.getCenter(find.byKey(key)));
  await tester.pump();
}

BoxDecoration _fillOf(WidgetTester tester, Key key) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byKey(pressableHoverFillKey),
    ),
  );
  return box.decoration as BoxDecoration;
}

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

void main() {
  testWidgets(
    'the shared pressable shows the hover style, the click cursor and its label',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Pressable(
              key: _rowKey,
              label: 'Open entry',
              onPressed: () {},
              borderRadius: _rowRadius,
              child: _face(),
            ),
            const SizedBox(height: 24),
            Pressable(
              key: _pillKey,
              label: 'Export journal',
              onPressed: () {},
              borderRadius: _pillRadius,
              shape: HoverShape.pill,
              child: _face(),
            ),
            const SizedBox(height: 24),
            ColoredBox(
              color: Palette.mediaGround,
              child: Pressable(
                key: _darkKey,
                label: 'Switch camera',
                onPressed: () {},
                borderRadius: _darkRadius,
                surface: FocusRingSurface.dark,
                child: _face(),
              ),
            ),
          ],
        ),
      );
      final TestGesture mouse = await _mousePointer(tester);

      expect(_fillOf(tester, _rowKey).color, isNull);
      expect(_fillOf(tester, _darkKey).color, isNull);

      await _hover(tester, mouse, _rowKey);
      final BoxDecoration row = _fillOf(tester, _rowKey);
      expect(
        row.color?.toARGB32(),
        FieldNotesColors.light.ink.withValues(alpha: 0.06).toARGB32(),
      );
      expect(row.borderRadius, _rowRadius);
      expect(_cursor(), SystemMouseCursors.click);
      expect(_fillOf(tester, _pillKey).color, isNull);

      await _hover(tester, mouse, _pillKey);
      final BoxDecoration pill = _fillOf(tester, _pillKey);
      expect(
        pill.color?.toARGB32(),
        Palette.coral.withValues(alpha: 0.08).toARGB32(),
      );
      expect(pill.borderRadius, _pillRadius);
      expect(_fillOf(tester, _rowKey).color, isNull);
      expect(_cursor(), SystemMouseCursors.click);

      await _hover(tester, mouse, _darkKey);
      final BoxDecoration dark = _fillOf(tester, _darkKey);
      expect(
        dark.color?.toARGB32(),
        const Color(0xFFFFFFFF).withValues(alpha: 0.12).toARGB32(),
      );
      expect(dark.borderRadius, _darkRadius);
      expect(_cursor(), SystemMouseCursors.click);

      expect(
        tester.getSemantics(find.byKey(_rowKey)),
        isSemantics(
          label: 'Open entry',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_pillKey)),
        isSemantics(label: 'Export journal', isButton: true),
      );
      expect(
        tester.getSemantics(find.byKey(_darkKey)),
        isSemantics(label: 'Switch camera', isButton: true),
      );
      expect(find.bySemanticsLabel('Face'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'a tap reports where it landed and the keyboard presses the centre',
    (WidgetTester tester) async {
      final List<Offset> presses = <Offset>[];
      final FocusNode focusNode = FocusNode(debugLabel: 'seek');
      addTearDown(focusNode.dispose);
      await _pump(
        tester,
        Pressable(
          key: _rowKey,
          label: 'Seek',
          focusNode: focusNode,
          onPressedAt: presses.add,
          child: _face(),
        ),
      );

      await tester.tapAt(
        tester.getTopLeft(find.byKey(_rowKey)) + const Offset(30, 10),
      );
      await tester.pump();
      expect(presses, <Offset>[const Offset(30, 10)]);

      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, <Offset>[
        const Offset(30, 10),
        _controlSize.center(Offset.zero),
      ]);
    },
  );

  testWidgets(
    'a builder keeps its own hover visual and a disabled control defers the cursor',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final List<bool> hoverStates = <bool>[];
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Pressable(
              key: _builderKey,
              label: 'Mute',
              onPressed: () {},
              paintsHover: false,
              builder: (BuildContext context, bool hovered) {
                hoverStates.add(hovered);
                return _face();
              },
            ),
            const SizedBox(height: 24),
            Pressable(
              key: _disabledKey,
              label: 'Save',
              onPressed: null,
              borderRadius: _rowRadius,
              child: _face(),
            ),
          ],
        ),
      );
      final TestGesture mouse = await _mousePointer(tester);

      await _hover(tester, mouse, _builderKey);
      expect(hoverStates.last, isTrue);
      expect(_fillOf(tester, _builderKey).color, isNull);
      expect(_cursor(), SystemMouseCursors.click);

      await _hover(tester, mouse, _disabledKey);
      expect(hoverStates.last, isFalse);
      expect(_fillOf(tester, _disabledKey).color, isNull);
      expect(_cursor(), SystemMouseCursors.basic);
      expect(
        tester.getSemantics(find.byKey(_disabledKey)),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      semantics.dispose();
    },
  );
}
