import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.danger = false});

  final bool danger;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Future<bool>? result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (BuildContext buttonContext) => ElevatedButton(
              onPressed: () {
                result = showConfirmDialog(
                  buttonContext,
                  title: 'Delete this entry?',
                  message: 'This log will be removed. This can’t be undone.',
                  confirmLabel: 'Delete',
                  danger: widget.danger,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('confirm resolves true only when the confirm button is tapped',
      (WidgetTester tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    bool? confirmedTrue;
    tester
        .state<_HarnessState>(find.byType(_Harness))
        .result!
        .then((bool value) => confirmedTrue = value);

    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();
    expect(confirmedTrue, isTrue);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    bool? confirmedFalse;
    tester
        .state<_HarnessState>(find.byType(_Harness))
        .result!
        .then((bool value) => confirmedFalse = value);

    await tester.tap(find.byKey(confirmDialogCancelKey));
    await tester.pumpAndSettle();
    expect(confirmedFalse, isFalse);
  });

  testWidgets('cancel, a scrim tap and Escape all resolve false',
      (WidgetTester tester) async {
    await tester.pumpWidget(const _Harness());

    Future<void> openAndClose(Future<void> Function() close) async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      bool? resolved;
      tester
          .state<_HarnessState>(find.byType(_Harness))
          .result!
          .then((bool value) => resolved = value);

      await close();
      await tester.pumpAndSettle();
      expect(resolved, isFalse);
    }

    await openAndClose(() => tester.tap(find.byKey(confirmDialogCancelKey)));
    await openAndClose(() => tester.tapAt(const Offset(10, 10)));
    await openAndClose(() => tester.sendKeyEvent(LogicalKeyboardKey.escape));
  });

  testWidgets('a destructive confirm paints its button in the danger colour',
      (WidgetTester tester) async {
    await tester.pumpWidget(const _Harness(danger: true));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final DecoratedBox dangerBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(confirmDialogConfirmKey),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((dangerBox.decoration as BoxDecoration).color, Palette.danger);

    await tester.tap(find.byKey(confirmDialogCancelKey));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const _Harness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final DecoratedBox coralBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(confirmDialogConfirmKey),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((coralBox.decoration as BoxDecoration).color, Palette.coral);
  });

  testWidgets('dialog text carries no fallback underline',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showConfirmDialog(
                context,
                title: 'Delete this entry?',
                message: 'This cannot be undone.',
                confirmLabel: 'Delete',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final BuildContext titleContext =
        tester.element(find.text('Delete this entry?'));
    final TextDecoration? decoration =
        DefaultTextStyle.of(titleContext).style.decoration;
    expect(decoration == null || decoration == TextDecoration.none, isTrue);
  });
}
