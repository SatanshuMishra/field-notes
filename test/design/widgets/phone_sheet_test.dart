import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/mood/mood_picker.dart';
import 'package:field_notes/features/mood/mood_picker_sheet.dart';

typedef _Opener = Future<Object?> Function(BuildContext context);

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 900);
const double _statusBar = 34;
const double _gestureBar = 24;

const Key _closeKey = ValueKey<String>('close');
const Key _addKey = ValueKey<String>('add');
const Key _confirmKey = ValueKey<String>('confirm');
const Key _cancelKey = ValueKey<String>('cancel');
const Key _headerKey = ValueKey<String>('header');
const Key _bodyKey = ValueKey<String>('body');
const Key _pinnedKey = ValueKey<String>('pinned');

final Finder _surface = find
    .descendant(
      of: find.byType(PhoneSheet),
      matching: find.byType(DecoratedBox),
    )
    .first;

final Finder _grabber = find.byKey(phoneSheetGrabberKey);

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
}

void _useDesktop(WidgetTester tester) {
  tester.view.physicalSize = _desktop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<List<Object?>> _pumpOpeners(
  WidgetTester tester,
  Map<String, _Opener> openers, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final List<Object?> results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final MapEntry<String, _Opener> opener
                      in openers.entries)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        results.add(await opener.value(context));
                      },
                      child: SizedBox(
                        width: 160,
                        height: 48,
                        child: Center(child: Text(opener.key)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  return results;
}

Widget _footerSheet(BuildContext context) {
  return const PhoneSheet(
    title: 'Reminder time',
    actions: <Widget>[
      SizedBox(key: _closeKey, width: 96, height: 48),
      Expanded(child: SizedBox(key: _addKey, height: 48)),
    ],
    child: SizedBox(height: 120),
  );
}

Widget _columnFooterSheet(BuildContext context) {
  return const PhoneSheet(
    footerDirection: Axis.vertical,
    footerPadding: EdgeInsets.fromLTRB(12, 14, 12, 12),
    actions: <Widget>[
      SizedBox(key: _confirmKey, height: 48),
      SizedBox(key: _cancelKey, height: 48),
    ],
    child: SizedBox(height: 80),
  );
}

Widget _tallSheet(BuildContext context) {
  return const PhoneSheet(
    header: SizedBox(key: _headerKey, height: 30),
    aboveFooter: SizedBox(key: _pinnedKey, height: 44),
    actions: <Widget>[Expanded(child: SizedBox(key: _addKey, height: 48))],
    child: SizedBox(key: _bodyKey, height: 2000),
  );
}

Widget _shortSheet(BuildContext context) {
  return const PhoneSheet(child: SizedBox(height: 200));
}

class _ExpandableSheet extends StatefulWidget {
  const _ExpandableSheet({required this.changes});

  final List<bool> changes;

  @override
  State<_ExpandableSheet> createState() => _ExpandableSheetState();
}

class _ExpandableSheetState extends State<_ExpandableSheet> {
  bool _expanded = false;

  void _onExpandedChanged(bool expanded) {
    widget.changes.add(expanded);
    setState(() => _expanded = expanded);
  }

  @override
  Widget build(BuildContext context) {
    return PhoneSheet(
      expanded: _expanded,
      onExpandedChanged: _onExpandedChanged,
      header: const SizedBox(
        key: _headerKey,
        height: 60,
        child: Center(child: Text('Morning note')),
      ),
      actions: const <Widget>[
        Expanded(child: SizedBox(key: _addKey, height: 48)),
      ],
      child: const SizedBox(key: _bodyKey, height: 100),
    );
  }
}

_Opener _expandableOpener(List<bool> changes) {
  return (BuildContext context) => showPhoneSheet<String>(
    context,
    builder: (BuildContext context) => _ExpandableSheet(changes: changes),
  );
}

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) {
  return tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;
}

FieldNotesColors _colors(WidgetTester tester) {
  return tester.element(find.byType(PhoneSheet)).colors;
}

bool _isGrabberSized(Widget widget) {
  return widget is SizedBox && widget.width == 38 && widget.height == 4;
}

void _expectOneSharedSheet(WidgetTester tester, Finder content, String title) {
  expect(content, findsOneWidget);
  expect(find.byType(PhoneSheet), findsOneWidget);
  expect(
    find.descendant(of: content, matching: find.byType(PhoneSheet)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: find.byType(PhoneSheet), matching: find.text(title)),
    findsOneWidget,
  );
  expect(_grabber, findsOneWidget);
  expect(tester.getSize(_grabber), const Size(38, 4));
  expect(
    find.descendant(
      of: content,
      matching: find.byWidgetPredicate(_isGrabberSized),
    ),
    findsOneWidget,
  );
  expect(tester.getRect(_surface).bottom, _phone.height);
}

void main() {
  testWidgets(
    'a phone sheet has a grabber, a rounded top and a footer above the '
    'gesture inset',
    (WidgetTester tester) async {
      _usePhone(tester);
      await _pumpOpeners(tester, <String, _Opener>{
        'open': (BuildContext context) =>
            showPhoneSheet<void>(context, builder: _footerSheet),
      });

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneSheet), findsOneWidget);
      final FieldNotesColors colors = _colors(tester);

      final Rect sheet = tester.getRect(_surface);
      expect(sheet.left, 0);
      expect(sheet.right, _phone.width);
      expect(sheet.bottom, _phone.height);

      final BoxDecoration surface = _decorationOf(tester, _surface);
      expect(
        surface.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(22)),
      );
      final Border border = surface.border! as Border;
      expect(border.top.width, 2);
      expect(border.top.color.toARGB32(), colors.line.toARGB32());
      expect(border.bottom, BorderSide.none);
      expect(surface.color!.toARGB32(), colors.cardWarm.toARGB32());
      final BoxShadow shadow = surface.boxShadow!.single;
      expect(shadow.offset, const Offset(0, -14));
      expect(shadow.blurRadius, 34);
      expect(shadow.spreadRadius, -14);
      expect(shadow.color.toARGB32(), 0x8C322314);

      final Rect grabber = tester.getRect(_grabber);
      expect(grabber.size, const Size(38, 4));
      expect(grabber.top - sheet.top, 10);
      expect(grabber.center.dx, _phone.width / 2);
      final BoxDecoration grip = _decorationOf(
        tester,
        find.descendant(of: _grabber, matching: find.byType(DecoratedBox)),
      );
      expect(grip.color!.toARGB32(), colors.ink30.toARGB32());
      expect(grip.borderRadius, const BorderRadius.all(Radius.circular(3)));

      expect(
        tester.getTopLeft(find.text('Reminder time')).dy,
        grabber.bottom + 10,
      );

      final Rect footer = tester.getRect(find.byKey(phoneSheetFooterKey));
      expect(footer.bottom, _phone.height - _gestureBar);
      expect(footer.left, 0);
      expect(footer.right, _phone.width);
      final Rect close = tester.getRect(find.byKey(_closeKey));
      final Rect add = tester.getRect(find.byKey(_addKey));
      expect(close.left, 12);
      expect(add.left - close.right, 8);
      expect(add.right, _phone.width - 12);
      expect(close.top - footer.top, 10);
      expect(footer.bottom - add.bottom, 12);

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is ModalBarrier && widget.color?.toARGB32() == 0x572A241D,
        ),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(192, 60));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneSheet), findsNothing);
    },
  );

  testWidgets('the mood picker and capture chooser open as the shared phone '
      'sheet', (WidgetTester tester) async {
    _usePhone(tester);
    await _pumpOpeners(tester, <String, _Opener>{
      'mood': (BuildContext context) => showMoodPicker(context),
      'capture': (BuildContext context) => showCaptureChooser(
        context,
        availableTypes: const <EntryType>{EntryType.text},
      ),
    });

    await tester.tap(find.text('mood'));
    await tester.pumpAndSettle();
    _expectOneSharedSheet(
      tester,
      find.byType(MoodPickerSheet),
      'How are you feeling?',
    );
    expect(
      _decorationOf(tester, _surface).color!.toARGB32(),
      _colors(tester).cardWarm.toARGB32(),
    );

    await tester.tapAt(const Offset(192, 60));
    await tester.pumpAndSettle();
    expect(find.byType(MoodPickerSheet), findsNothing);
    expect(find.byType(PhoneSheet), findsNothing);

    await tester.tap(find.text('capture'));
    await tester.pumpAndSettle();
    _expectOneSharedSheet(
      tester,
      find.byType(CaptureChooserSheet),
      'Capture a moment',
    );
    expect(
      _decorationOf(tester, _surface).color!.toARGB32(),
      _colors(tester).panelTop.toARGB32(),
    );
  });

  testWidgets('on macOS the mood picker and capture chooser keep their '
      'centred panels', (WidgetTester tester) async {
    _useDesktop(tester);
    await _pumpOpeners(tester, <String, _Opener>{
      'mood': (BuildContext context) => showMoodPicker(context),
      'capture': (BuildContext context) => showCaptureChooser(
        context,
        availableTypes: const <EntryType>{EntryType.text},
      ),
    }, platform: TargetPlatform.macOS);

    await tester.tap(find.text('mood'));
    await tester.pumpAndSettle();
    expect(find.byType(MoodPickerSheet), findsOneWidget);
    expect(find.byType(PhoneSheet), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ModalBarrier && widget.color?.toARGB32() == 0x472A241D,
      ),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(MoodPickerSheet), findsNothing);

    await tester.tap(find.text('capture'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureChooserSheet), findsOneWidget);
    expect(find.byType(PhoneSheet), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CaptureChooserSheet),
        matching: find.byType(StickerCard),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a phone sheet stacks its footer actions in a column when '
      'asked', (WidgetTester tester) async {
    _usePhone(tester);
    await _pumpOpeners(tester, <String, _Opener>{
      'open': (BuildContext context) =>
          showPhoneSheet<void>(context, builder: _columnFooterSheet),
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final Rect footer = tester.getRect(find.byKey(phoneSheetFooterKey));
    final Rect confirm = tester.getRect(find.byKey(_confirmKey));
    final Rect cancel = tester.getRect(find.byKey(_cancelKey));
    expect(footer.bottom, _phone.height - _gestureBar);
    expect(confirm.left, 12);
    expect(confirm.width, _phone.width - 24);
    expect(confirm.top - footer.top, 14);
    expect(cancel.top - confirm.bottom, 8);
    expect(footer.bottom - cancel.bottom, 12);
  });

  testWidgets('a tall phone sheet stops 8 points below the status bar and '
      'scrolls its body', (WidgetTester tester) async {
    _usePhone(tester);
    await _pumpOpeners(tester, <String, _Opener>{
      'open': (BuildContext context) =>
          showPhoneSheet<void>(context, builder: _tallSheet),
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final Rect sheet = tester.getRect(_surface);
    expect(sheet.top, _statusBar + 8);
    expect(sheet.height, _phone.height - _statusBar - 8);

    final Rect grabber = tester.getRect(_grabber);
    final Rect header = tester.getRect(find.byKey(_headerKey));
    final double bodyTop = tester.getTopLeft(find.byKey(_bodyKey)).dy;
    expect(header.top, grabber.bottom + 2);
    expect(bodyTop, header.bottom);
    expect(
      tester.getRect(find.byKey(_pinnedKey)).bottom,
      tester.getRect(find.byKey(phoneSheetFooterKey)).top,
    );
    expect(
      tester.getRect(find.byKey(phoneSheetFooterKey)).bottom,
      _phone.height - _gestureBar,
    );

    await tester.dragFrom(const Offset(192, 400), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(_bodyKey)).dy, lessThan(bodyTop - 100));
    expect(tester.getRect(find.byKey(_headerKey)).top, header.top);
    expect(tester.getRect(_surface).top, sheet.top);
    expect(find.byType(PhoneSheet), findsOneWidget);
  });

  testWidgets('dragging the grabber follows the finger and closes past 60 '
      'points', (WidgetTester tester) async {
    _usePhone(tester);
    final List<Object?> results = await _pumpOpeners(tester, <String, _Opener>{
      'open': (BuildContext context) =>
          showPhoneSheet<String>(context, builder: _shortSheet),
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final double resting = tester.getTopLeft(_grabber).dy;
    expect(resting, _phone.height - _gestureBar - 200 - 2 - 4);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(_grabber),
    );
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(
      tester.getTopLeft(_grabber).dy,
      moreOrLessEquals(resting + 40, epsilon: 0.5),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(PhoneSheet), findsOneWidget);
    expect(
      tester.getTopLeft(_grabber).dy,
      moreOrLessEquals(resting, epsilon: 0.01),
    );
    expect(results, isEmpty);

    await tester.drag(_grabber, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneSheet), findsNothing);
    expect(results, <Object?>[null]);
  });

  testWidgets('an expandable sheet drags to full height and back', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final List<bool> changes = <bool>[];
    final List<Object?> results = await _pumpOpeners(tester, <String, _Opener>{
      'open': _expandableOpener(changes),
    });
    const double full = 832 - 34 - 8;

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final double content = tester.getSize(_surface).height;
    expect(content, lessThan(300));
    expect(tester.getRect(_surface).bottom, _phone.height);
    expect(
      tester.getCenter(find.byKey(_headerKey)).dy -
          tester.getRect(_surface).top,
      greaterThan(phoneSheetDragArea),
    );

    await tester.drag(find.byKey(_headerKey), const Offset(0, -40));
    await tester.pumpAndSettle();
    final Rect expanded = tester.getRect(_surface);
    expect(expanded.height, full);
    expect(expanded.top, _statusBar + 8);
    expect(expanded.bottom, _phone.height);
    expect(
      tester.getTopLeft(find.byKey(_bodyKey)).dy,
      tester.getRect(find.byKey(_headerKey)).bottom,
    );
    expect(
      tester.getRect(find.byKey(phoneSheetFooterKey)).bottom,
      _phone.height - _gestureBar,
    );
    expect(changes, <bool>[true]);

    await tester.drag(find.byKey(_headerKey), const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(tester.getSize(_surface).height, content);
    expect(tester.getRect(_surface).bottom, _phone.height);
    expect(changes, <bool>[true, false]);
    expect(results, isEmpty);

    await tester.drag(find.byKey(_headerKey), const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneSheet), findsNothing);
    expect(results, <Object?>[null]);
    expect(changes, <bool>[true, false]);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.getSize(_surface).height, content);

    await tester.tap(_grabber);
    await tester.pumpAndSettle();
    expect(tester.getSize(_surface).height, full);
    expect(tester.getRect(_surface).top, _statusBar + 8);

    await tester.tap(_grabber);
    await tester.pumpAndSettle();
    expect(tester.getSize(_surface).height, content);
    expect(changes, <bool>[true, false, true, false]);
    expect(find.byType(PhoneSheet), findsOneWidget);
  });

  testWidgets('an expandable sheet names its grabber toggle and reads a '
      'wobble as no tap', (WidgetTester tester) async {
    _usePhone(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<bool> changes = <bool>[];
    await _pumpOpeners(tester, <String, _Opener>{
      'open': _expandableOpener(changes),
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final double content = tester.getSize(_surface).height;

    final Finder toggle = find.byKey(phoneSheetGrabberToggleKey);
    final Rect reach = tester.getRect(toggle);
    expect(reach.width, greaterThanOrEqualTo(44));
    expect(reach.height, greaterThanOrEqualTo(44));
    expect(reach.contains(tester.getCenter(_grabber)), isTrue);
    expect(reach.center.dx, tester.getCenter(_grabber).dx);

    final TestGesture wobble = await tester.startGesture(
      tester.getCenter(_grabber),
    );
    await wobble.moveBy(const Offset(0, 10));
    await wobble.up();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(tester.getSize(_surface).height, content);

    expect(find.semantics.byLabel(phoneSheetExpandLabel), findsOne);
    tester.semantics.tap(find.semantics.byLabel(phoneSheetExpandLabel));
    await tester.pumpAndSettle();
    expect(changes, <bool>[true]);
    expect(tester.getSize(_surface).height, _phone.height - _statusBar - 8);

    expect(find.semantics.byLabel(phoneSheetShrinkLabel), findsOne);
    tester.semantics.tap(find.semantics.byLabel(phoneSheetShrinkLabel));
    await tester.pumpAndSettle();
    expect(changes, <bool>[true, false]);
    expect(tester.getSize(_surface).height, content);
    semantics.dispose();
  });

  testWidgets('the phone sheet slides up from the bottom edge', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _pumpOpeners(tester, <String, _Opener>{
      'open': (BuildContext context) =>
          showPhoneSheet<void>(context, builder: _shortSheet),
    });
    final double resting = _phone.height - _gestureBar - 200 - 2 - 4;

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.getTopLeft(_grabber).dy, greaterThan(resting + 1));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_grabber).dy, resting);
  });

  testWidgets('with reduce motion the phone sheet appears without sliding', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpOpeners(tester, <String, _Opener>{
      'open': (BuildContext context) =>
          showPhoneSheet<void>(context, builder: _shortSheet),
    });

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(
      tester.getTopLeft(_grabber).dy,
      _phone.height - _gestureBar - 200 - 2 - 4,
    );
  });
}
