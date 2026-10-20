import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/anchored_dropdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const int _mousePointerId = 41;
const int _mouseDevice = 1;
const Key _anchorKey = ValueKey<String>('anchor');
const Key _menuKey = ValueKey<String>('menu');
const Key _firstRowKey = ValueKey<String>('first-row');
const Key _secondRowKey = ValueKey<String>('second-row');
const String _firstLabel = 'MacBook Pro Microphone';
const String _secondLabel = 'WH-1000XM5';
const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(10));

Future<void> _pumpOpenDropdown(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Material(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 280,
            child: AnchoredDropdown<String>(
              menuKey: _menuKey,
              current: 'headphones',
              onSelected: (String _) {},
              choices: const <AnchoredDropdownChoice<String>>[
                AnchoredDropdownChoice<String>(
                  key: _firstRowKey,
                  value: 'built-in',
                  label: _firstLabel,
                ),
                AnchoredDropdownChoice<String>(
                  key: _secondRowKey,
                  value: 'headphones',
                  label: _secondLabel,
                ),
              ],
              builder: (BuildContext context, bool open, VoidCallback toggle) =>
                  GestureDetector(
                    key: _anchorKey,
                    onTap: toggle,
                    child: const SizedBox(
                      height: 44,
                      child: Center(child: Text('Input device')),
                    ),
                  ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_anchorKey));
  await tester.pumpAndSettle();
}

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

Iterable<BoxDecoration> _paintedFills(WidgetTester tester, Key rowKey) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(rowKey),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .where(
      (BoxDecoration decoration) =>
          decoration.color != null && decoration.color!.a > 0,
    );

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

void main() {
  testWidgets(
    "the anchored drop-down's rows show the rounded highlight, the click cursor and their labels",
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpOpenDropdown(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
      final TestGesture mouse = await _mousePointer(tester);

      await mouse.moveTo(tester.getCenter(find.byKey(_firstRowKey)));
      await tester.pump();

      expect(_cursor(), SystemMouseCursors.click);

      final List<BoxDecoration> firstFills = _paintedFills(
        tester,
        _firstRowKey,
      ).toList();
      expect(firstFills, hasLength(1));
      expect(
        firstFills.single.color?.toARGB32(),
        FieldNotesColors.light.ink.withValues(alpha: 0.12).toARGB32(),
      );
      expect(firstFills.single.borderRadius, _rowRadius);
      expect(_paintedFills(tester, _secondRowKey), isEmpty);

      final SemanticsNode firstRow = tester.getSemantics(
        find.descendant(
          of: find.byKey(_firstRowKey),
          matching: find.text(_firstLabel),
        ),
      );
      expect(firstRow.childrenCount, 0);
      expect(
        firstRow,
        isSemantics(
          label: _firstLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      final SemanticsNode secondRow = tester.getSemantics(
        find.descendant(
          of: find.byKey(_secondRowKey),
          matching: find.text(_secondLabel),
        ),
      );
      expect(secondRow.childrenCount, 0);
      expect(
        secondRow,
        isSemantics(
          label: _secondLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      semantics.dispose();
    },
  );
}
