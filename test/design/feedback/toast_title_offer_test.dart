import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/motion/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _message = 'Voice memo saved';
const String _action = 'Add a title';
const String _fieldLabel = 'Title';
const String _showLabel = 'show';
const String _title = 'Morning walk';
const String _failure = 'Could not save your title.';

Future<List<String>> _showOffer(WidgetTester tester) async {
  final List<String> titled = <String>[];
  Future<bool> keep(String title) {
    titled.add(title);
    return Future<bool>.value(true);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showTransientToast(
                context,
                _message,
                titleOffer: ToastTitleOffer(
                  actionLabel: _action,
                  fieldLabel: _fieldLabel,
                  failureMessage: _failure,
                  onTitled: keep,
                ),
              ),
              child: const Text(_showLabel),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_showLabel));
  await tester.pump();
  await tester.pump(Motion.toastRise);
  return titled;
}

Future<void> _startNaming(WidgetTester tester) async {
  await tester.tap(find.text(_action));
  await tester.pump();
}

Future<void> _finish(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

Finder get _field => find.byKey(toastTitleFieldKey);

void main() {
  testWidgets('the offer shows its action past the plain toast lifetime', (
    WidgetTester tester,
  ) async {
    await _showOffer(tester);
    expect(find.text(_message), findsOneWidget);
    expect(find.text(_action), findsOneWidget);

    await tester.pump(kToastLifetime);
    expect(find.text(_action), findsOneWidget);

    await tester.pump(kToastActionLifetime);
    await tester.pump();
    expect(find.text(_message), findsNothing);
    await _finish(tester);
  });

  testWidgets('the action opens a focused field and holds the toast open', (
    WidgetTester tester,
  ) async {
    await _showOffer(tester);

    await _startNaming(tester);

    expect(_field, findsOneWidget);
    expect(find.text(toastTitleDoneLabel), findsOneWidget);
    expect(tester.widget<TextField>(_field).focusNode!.hasFocus, isTrue);

    await tester.pump(kToastActionLifetime * 2);
    expect(_field, findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Enter saves the trimmed title and closes the toast', (
    WidgetTester tester,
  ) async {
    final List<String> titled = await _showOffer(tester);
    await _startNaming(tester);

    await tester.enterText(_field, '  $_title  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(titled, <String>[_title]);
    expect(find.text(_message), findsNothing);
    await _finish(tester);
  });

  testWidgets('Done saves the title once', (WidgetTester tester) async {
    final List<String> titled = await _showOffer(tester);
    await _startNaming(tester);

    await tester.enterText(_field, _title);
    await tester.tap(find.text(toastTitleDoneLabel));
    await tester.pump();

    expect(titled, <String>[_title]);
    expect(find.text(_message), findsNothing);
    await _finish(tester);
  });

  testWidgets('a tap elsewhere saves what was typed', (
    WidgetTester tester,
  ) async {
    final List<String> titled = await _showOffer(tester);
    await _startNaming(tester);

    await tester.enterText(_field, _title);
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();

    expect(titled, <String>[_title]);
    expect(find.text(_message), findsNothing);
    await _finish(tester);
  });

  testWidgets('Done with nothing typed names nothing', (
    WidgetTester tester,
  ) async {
    final List<String> titled = await _showOffer(tester);
    await _startNaming(tester);

    await tester.tap(find.text(toastTitleDoneLabel));
    await tester.pump();

    expect(titled, isEmpty);
    expect(find.text(_message), findsNothing);
    await _finish(tester);
  });

  testWidgets('Escape abandons what was typed', (WidgetTester tester) async {
    final List<String> titled = await _showOffer(tester);
    await _startNaming(tester);

    await tester.enterText(_field, _title);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(titled, isEmpty);
    expect(find.text(_message), findsNothing);
    await _finish(tester);
  });

  testWidgets('the action is a full-size target with a spoken name', (
    WidgetTester tester,
  ) async {
    await _showOffer(tester);

    final Finder control = find.ancestor(
      of: find.text(_action),
      matching: find.byType(Pressable),
    );
    final Size target = tester.getSize(control);
    expect(target.height, greaterThanOrEqualTo(toastActionMinTarget));
    expect(target.width, greaterThanOrEqualTo(toastActionMinTarget));
    expect(
      tester.getSemantics(control),
      isSemantics(label: _action, isButton: true, hasEnabledState: true),
    );
    await _finish(tester);
  });

  testWidgets('the field is named for a screen reader', (
    WidgetTester tester,
  ) async {
    await _showOffer(tester);
    await _startNaming(tester);

    expect(find.bySemanticsLabel(RegExp(_fieldLabel)), findsWidgets);
    await _finish(tester);
  });

  testWidgets('an action and a title offer cannot share one toast', (
    WidgetTester tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      () => showTransientToast(
        captured,
        _message,
        action: ToastAction(label: 'Undo', onPressed: () {}),
        titleOffer: ToastTitleOffer(
          actionLabel: _action,
          fieldLabel: _fieldLabel,
          failureMessage: _failure,
          onTitled: (String _) => Future<bool>.value(true),
        ),
      ),
      throwsAssertionError,
    );
  });
}
