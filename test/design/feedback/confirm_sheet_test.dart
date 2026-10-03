import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;

const String _title = 'Delete this entry?';
const String _message = 'This log will be removed. This can’t be undone.';

void _useSurface(WidgetTester tester, TargetPlatform platform) {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phone : _desktop;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
  } else {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
  }
  addTearDown(tester.view.reset);
}

Future<List<bool>> _open(WidgetTester tester, TargetPlatform platform) async {
  final List<bool> results = <bool>[];
  _useSurface(tester, platform);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async => results.add(
                await showConfirmDialog(
                  context,
                  title: _title,
                  message: _message,
                  confirmLabel: 'Delete',
                  danger: true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return results;
}

BoxDecoration _decorationOf(WidgetTester tester, Key key) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox)),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  testWidgets('a phone confirm opens as a sheet with the action above Cancel', (
    WidgetTester tester,
  ) async {
    final List<bool> phoneResults = await _open(
      tester,
      TargetPlatform.android,
    );

    expect(find.byType(PhoneSheet), findsOneWidget);
    expect(find.byKey(phoneSheetGrabberKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PhoneSheet),
        matching: find.text(_title),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PhoneSheet),
        matching: find.text(_message),
      ),
      findsOneWidget,
    );

    final TextStyle titleStyle = tester.widget<Text>(find.text(_title)).style!;
    expect(titleStyle.fontSize, 20);
    expect(titleStyle.fontFamily, TypographyTokens.serif);
    expect(titleStyle.fontWeight, FontWeight.w500);

    final Rect confirm = tester.getRect(find.byKey(confirmDialogConfirmKey));
    final Rect cancel = tester.getRect(find.byKey(confirmDialogCancelKey));
    expect(confirm.height, 48);
    expect(cancel.height, 48);
    expect(confirm.left, 12);
    expect(confirm.right, _phone.width - 12);
    expect(cancel.left, 12);
    expect(cancel.right, _phone.width - 12);
    expect(cancel.top, confirm.bottom + 8);
    expect(cancel.bottom, _phone.height - _gestureBar - 12);
    expect(
      find.descendant(
        of: find.byType(PhoneSheet),
        matching: find.byKey(confirmDialogConfirmKey),
      ),
      findsOneWidget,
    );

    final BoxDecoration action = _decorationOf(
      tester,
      confirmDialogConfirmKey,
    );
    expect(action.color!.toARGB32(), Palette.danger.toARGB32());
    expect(
      action.borderRadius,
      const BorderRadius.all(Radius.circular(14)),
    );
    expect((action.border! as Border).top.width, 1.5);
    expect(action.boxShadow!.single.offset, const Offset(2, 2));
    expect(action.boxShadow!.single.blurRadius, 0);
    final TextStyle actionStyle = tester.widget<Text>(find.text('Delete'))
        .style!;
    expect(actionStyle.color!.toARGB32(), Palette.onAccent.toARGB32());
    expect(actionStyle.fontSize, 14);
    expect(actionStyle.fontWeight, FontWeight.w600);

    final BoxDecoration cancelBox = _decorationOf(
      tester,
      confirmDialogCancelKey,
    );
    expect(
      cancelBox.color!.toARGB32(),
      FieldNotesColors.light.cardLight.toARGB32(),
    );
    expect(
      tester.widget<Text>(find.text('Cancel')).style!.color!.toARGB32(),
      FieldNotesColors.light.ink.toARGB32(),
    );

    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneSheet), findsNothing);
    expect(phoneResults, <bool>[true]);

    final List<bool> desktopResults = await _open(
      tester,
      TargetPlatform.macOS,
    );

    expect(find.byType(PhoneSheet), findsNothing);
    expect(find.byKey(phoneSheetGrabberKey), findsNothing);
    final Rect panel = tester.getRect(
      find
          .ancestor(of: find.text(_title), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(panel.center.dx, closeTo(_desktop.width / 2, 0.5));
    expect(panel.center.dy, closeTo(_desktop.height / 2, 0.5));
    expect(panel.width, lessThan(_desktop.width / 2));
    final Rect dialogConfirm = tester.getRect(
      find.byKey(confirmDialogConfirmKey),
    );
    final Rect dialogCancel = tester.getRect(
      find.byKey(confirmDialogCancelKey),
    );
    expect(dialogCancel.right, lessThan(dialogConfirm.left));
    expect(dialogCancel.center.dy, closeTo(dialogConfirm.center.dy, 0.5));

    await tester.tap(find.byKey(confirmDialogCancelKey));
    await tester.pumpAndSettle();
    expect(desktopResults, <bool>[false]);
  });
}
