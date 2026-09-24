import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoSide, MdPhotoSize;
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/editor/photo_caption_field.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, NoteEditorController, NoteEditorView;

import '../../../../support/note_editor_driver.dart';
import '../../../../support/photo_line_fixture.dart';
import '../../../notes/support/notes_harness.dart'
    show
        FakeNoteMediaResolver,
        availablePhoto,
        photoIdA,
        photoIdB,
        photoIdC,
        prefixOf;

const double _tolerance = 0.5;
const Duration _hold = Duration(milliseconds: 110);

class _Harness {
  _Harness(String text, {this.importer, this.bottomInset = 0})
    : controller = NoteEditorController(text: text);

  final Key key = UniqueKey();
  final NoteEditorController controller;
  final PhotoToolbarImporter? importer;
  final double bottomInset;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  Widget app({double width = 720, double height = 700}) {
    return MaterialApp(
      key: key,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ComposerMediaScope(
          resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
            prefixOf(photoIdA): availablePhoto(
              photoIdA,
              width: 1200,
              height: 900,
            ),
            prefixOf(photoIdB): availablePhoto(
              photoIdB,
              width: 1200,
              height: 900,
            ),
          })..memoizeAll(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: noteEditorFor(
                NoteEditorConfig(
                  controller: controller,
                  focusNode: focusNode,
                  undoController: undo,
                  scrollController: scroll,
                  photoImporter: importer,
                  bottomInset: bottomInset,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    undo.dispose();
    scroll.dispose();
  }
}

Future<_Harness> _pump(
  WidgetTester tester,
  String text, {
  double width = 720,
  double height = 700,
  PhotoToolbarImporter? importer,
  double bottomInset = 0,
}) async {
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Harness harness = _Harness(
    text,
    importer: importer,
    bottomInset: bottomInset,
  );
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.app(width: width, height: height));
  await tester.pump();
  return harness;
}

Rect _figure(WidgetTester tester, [int ordinal = 0]) =>
    tester.getRect(NoteEditorDriver(tester).photoFinder(ordinal));

Rect _bar(WidgetTester tester) => tester.getRect(find.byKey(photoToolbarKey));

Rect _editor(WidgetTester tester) =>
    tester.getRect(find.byType(NoteEditorView));

bool _hasPrimaryFocus(WidgetTester tester, Key key) =>
    Focus.of(tester.element(find.byKey(key))).hasPrimaryFocus;

String _prose(int words) =>
    List<String>.generate(words, (int i) => 'word${i % 7}').join(' ');

String _lines(int count) =>
    List<String>.generate(count, (int i) => 'line $i').join('\n');

Future<void> _selectPhoto(WidgetTester tester, [int ordinal = 0]) async {
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.press(driver.photoFinder(ordinal), _hold);
  await tester.pump();
}

Future<void> _press(
  WidgetTester tester,
  Key key, [
  Duration hold = _hold,
]) async {
  await NoteEditorDriver(tester).press(find.byKey(key), hold);
  await tester.pump();
}

Future<List<String>> _pickB() async => <String>[prefixOf(photoIdB)];

typedef _Step = ({Key control, String expected});

String _retitled(String source, String from, String to) =>
    source.replaceFirst('"$from"', '"$to"');

void main() {
  final String a = mdPhotoLine(photoIdA);
  final String b = mdPhotoLine(photoIdB);

  test('the bar is placed above, below or on the photo inside the surface', () {
    const Rect surface = Rect.fromLTWH(0, 0, 560, 400);
    const Size bar = Size(300, 38);

    expect(
      photoToolbarOffset(
        figure: const Rect.fromLTWH(130, 200, 300, 150),
        surface: surface,
        bar: bar,
      ),
      const Offset(130, 152),
    );
    expect(
      photoToolbarOffset(
        figure: const Rect.fromLTWH(0, 20, 560, 150),
        surface: surface,
        bar: bar,
      ),
      const Offset(130, 180),
    );
    expect(
      photoToolbarOffset(
        figure: const Rect.fromLTRB(130, -10, 430, 410),
        surface: surface,
        bar: bar,
      ),
      const Offset(130, 0),
    );
    expect(
      photoToolbarOffset(
        figure: const Rect.fromLTRB(130, 30, 430, 450),
        surface: surface,
        bar: bar,
      ),
      const Offset(130, 40),
    );
    expect(
      photoToolbarOffset(
        figure: const Rect.fromLTWH(500, 100, 60, 45),
        surface: surface,
        bar: bar,
      ).dx,
      260,
    );
  });

  testWidgets('the bar width adds up its real controls', (
    WidgetTester tester,
  ) async {
    double label(String text) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: TypographyTokens.toolbarSans),
        textDirection: TextDirection.ltr,
      )..layout();
      final double width = painter.width;
      painter.dispose();
      return width;
    }

    double control(double content, double target) =>
        math.max(target, content + 2 * photoToolbarControlPadding);

    const double rule = 1 + 2 * photoToolbarGroupGap;
    const double gap = photoToolbarControlGap;
    for (final double target in <double>[
      photoToolbarTarget,
      photoToolbarTouchTarget,
    ]) {
      final double sizes =
          3 * control(label('S'), target) +
          control(label('Full'), target) +
          3 * gap;
      final double sides = 3 * control(18, target) + 2 * gap;
      final double moves = 3 * control(14, target) + 2 * gap;
      final double more = control(14, target);
      final double caption = control(label(photoToolbarCaptionLabel), target);
      final double remove = control(14, target);
      final double tail = rule + caption + rule + remove;

      expect(
        photoToolbarWidthFor(
          scaler: TextScaler.noScaling,
          placement: true,
          moves: true,
          target: target,
        ),
        closeTo(10 + sizes + rule + sides + rule + moves + tail, 1e-6),
      );
      expect(
        photoToolbarWidthFor(
          scaler: TextScaler.noScaling,
          placement: true,
          moves: false,
          target: target,
        ),
        closeTo(10 + sizes + rule + sides + rule + more + tail, 1e-6),
      );
      expect(
        photoToolbarWidthFor(
          scaler: TextScaler.noScaling,
          placement: false,
          moves: true,
          target: target,
        ),
        closeTo(10 + moves + tail, 1e-6),
      );
    }
  });

  testWidgets(
    'every control works for held presses on a centred last photo, a full '
    'photo and a floated photo',
    (WidgetTester tester) async {
      const String c = 'one\n\n![](photo/a1b2c3d4e5f6 "centre medium")';
      const String f = 'one\n\n![](photo/a1b2c3d4e5f6 "right full")\n\ntwo';
      const String l = 'one\n\n![](photo/a1b2c3d4e5f6 "left small")\n\ntwo';
      final Map<String, List<_Step>> cases = <String, List<_Step>>{
        c: <_Step>[
          (
            control: photoToolbarSizeKey(MdPhotoSize.small),
            expected: _retitled(c, 'centre medium', 'centre small'),
          ),
          (control: photoToolbarSizeKey(MdPhotoSize.medium), expected: c),
          (
            control: photoToolbarSizeKey(MdPhotoSize.large),
            expected: _retitled(c, 'centre medium', 'centre large'),
          ),
          (
            control: photoToolbarSizeKey(MdPhotoSize.full),
            expected: _retitled(c, 'centre medium', 'centre full'),
          ),
          (
            control: photoToolbarSideKey(MdPhotoSide.left),
            expected: _retitled(c, 'centre medium', 'left medium'),
          ),
          (control: photoToolbarSideKey(MdPhotoSide.centre), expected: c),
          (
            control: photoToolbarSideKey(MdPhotoSide.right),
            expected: _retitled(c, 'centre medium', 'right medium'),
          ),
          (
            control: photoToolbarMoveUpKey,
            expected: '![](photo/a1b2c3d4e5f6 "centre medium")\none',
          ),
          (control: photoToolbarMoveDownKey, expected: c),
          (
            control: photoToolbarReplaceKey,
            expected: 'one\n\n![](photo/b2c3d4e5f6a1 "centre medium")',
          ),
          (control: photoToolbarCaptionKey, expected: c),
          (control: photoToolbarRemoveKey, expected: 'one'),
        ],
        f: <_Step>[
          (
            control: photoToolbarSizeKey(MdPhotoSize.small),
            expected: _retitled(f, 'right full', 'right small'),
          ),
          (
            control: photoToolbarSizeKey(MdPhotoSize.medium),
            expected: _retitled(f, 'right full', 'right medium'),
          ),
          (
            control: photoToolbarSizeKey(MdPhotoSize.large),
            expected: _retitled(f, 'right full', 'right large'),
          ),
          (control: photoToolbarSizeKey(MdPhotoSize.full), expected: f),
          (control: photoToolbarSideKey(MdPhotoSide.left), expected: f),
          (control: photoToolbarSideKey(MdPhotoSide.centre), expected: f),
          (control: photoToolbarSideKey(MdPhotoSide.right), expected: f),
          (
            control: photoToolbarMoveUpKey,
            expected: '![](photo/a1b2c3d4e5f6 "right full")\none\n\ntwo',
          ),
          (
            control: photoToolbarMoveDownKey,
            expected: 'one\n\ntwo\n![](photo/a1b2c3d4e5f6 "right full")',
          ),
          (
            control: photoToolbarReplaceKey,
            expected: f.replaceFirst('a1b2c3d4e5f6', 'b2c3d4e5f6a1'),
          ),
          (control: photoToolbarCaptionKey, expected: f),
          (control: photoToolbarRemoveKey, expected: 'one\n\ntwo'),
        ],
        l: <_Step>[
          (control: photoToolbarSizeKey(MdPhotoSize.small), expected: l),
          (
            control: photoToolbarSizeKey(MdPhotoSize.medium),
            expected: _retitled(l, 'left small', 'left medium'),
          ),
          (
            control: photoToolbarSizeKey(MdPhotoSize.large),
            expected: _retitled(l, 'left small', 'left large'),
          ),
          (
            control: photoToolbarSizeKey(MdPhotoSize.full),
            expected: _retitled(l, 'left small', 'left full'),
          ),
          (control: photoToolbarSideKey(MdPhotoSide.left), expected: l),
          (
            control: photoToolbarSideKey(MdPhotoSide.centre),
            expected: _retitled(l, 'left small', 'centre small'),
          ),
          (
            control: photoToolbarSideKey(MdPhotoSide.right),
            expected: _retitled(l, 'left small', 'right small'),
          ),
          (
            control: photoToolbarMoveUpKey,
            expected: '![](photo/a1b2c3d4e5f6 "left small")\none\n\ntwo',
          ),
          (
            control: photoToolbarMoveDownKey,
            expected: 'one\n\ntwo\n![](photo/a1b2c3d4e5f6 "left small")',
          ),
          (
            control: photoToolbarReplaceKey,
            expected: l.replaceFirst('a1b2c3d4e5f6', 'b2c3d4e5f6a1'),
          ),
          (control: photoToolbarCaptionKey, expected: l),
          (control: photoToolbarRemoveKey, expected: 'one\n\ntwo'),
        ],
      };

      for (final MapEntry<String, List<_Step>> entry in cases.entries) {
        for (final _Step step in entry.value) {
          for (final int hold in <int>[30, 110, 300]) {
            final String reason = '${step.control} held $hold ms on '
                '${entry.key}';
            final _Harness harness = await _pump(
              tester,
              entry.key,
              importer: _pickB,
            );
            await _selectPhoto(tester);
            expect(find.byKey(photoToolbarKey), findsOneWidget, reason: reason);

            await _press(tester, step.control, Duration(milliseconds: hold));
            await tester.pump();

            expect(tester.takeException(), isNull, reason: reason);
            expect(harness.controller.text, step.expected, reason: reason);
            if (step.control == photoToolbarCaptionKey) {
              expect(
                find.byKey(photoCaptionFieldEditorKey),
                findsOneWidget,
                reason: reason,
              );
            }
            if (step.control == photoToolbarRemoveKey) {
              expect(find.text(photoRemovedMessage), findsOneWidget);
              expect(find.text(photoRemovedUndoLabel), findsOneWidget);
              dismissTransientToast();
              await tester.pump();
            }
            if (step.expected != entry.key) {
              harness.controller.undo();
              await tester.pump();
              expect(harness.controller.text, entry.key, reason: reason);
            }
          }
        }
      }
    },
  );

  testWidgets('the toolbar rides the photo edge when there is no room above or '
      'below', (WidgetTester tester) async {
    final String full = mdPhotoLine(photoIdA, size: MdPhotoSize.full);
    final String note = '${_lines(12)}\n$full\n${_lines(12)}';
    final _Harness harness = await _pump(
      tester,
      note,
      width: 560,
      height: 400,
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    harness.focusNode.requestFocus();
    await tester.pump();
    await driver.setSelection(
      TextSelection.collapsed(offset: note.indexOf(full) + 4),
    );

    final Rect view = _editor(tester);
    final double top = _figure(tester).top - view.top;

    for (final double offset in <double>[0, 120, 240, 360, 480, 600]) {
      harness.scroll.jumpTo(
        offset.clamp(0.0, harness.scroll.position.maxScrollExtent),
      );
      await tester.pump();
      if (find.byKey(photoToolbarKey).evaluate().isEmpty) {
        continue;
      }
      final Rect bar = _bar(tester);
      final Rect figure = _figure(tester);
      expect(bar.top, greaterThanOrEqualTo(view.top - _tolerance));
      expect(bar.bottom, lessThanOrEqualTo(view.bottom + _tolerance));
      expect(bar.left, greaterThanOrEqualTo(view.left - _tolerance));
      expect(bar.right, lessThanOrEqualTo(view.right + _tolerance));
      expect(
        bar.bottom,
        greaterThanOrEqualTo(figure.top - photoToolbarGap - _tolerance),
        reason: 'at $offset',
      );
      expect(
        bar.top,
        lessThanOrEqualTo(figure.bottom + photoToolbarGap + _tolerance),
        reason: 'at $offset',
      );
    }

    harness.scroll.jumpTo(top + 10);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsOneWidget);
    final Rect bar = _bar(tester);
    final Rect figure = _figure(tester);
    expect(figure.top, closeTo(view.top - 10, _tolerance));
    expect(figure.bottom, closeTo(view.bottom + 10, _tolerance));
    for (final Rect outer in <Rect>[figure, view]) {
      expect(bar.top, greaterThanOrEqualTo(outer.top - _tolerance));
      expect(bar.bottom, lessThanOrEqualTo(outer.bottom + _tolerance));
      expect(bar.left, greaterThanOrEqualTo(outer.left - _tolerance));
      expect(bar.right, lessThanOrEqualTo(outer.right + _tolerance));
    }
  });

  testWidgets('size and side groups are hidden on a phone column', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a\ntwo', width: 350, importer: _pickB);
    await _selectPhoto(tester);

    expect(find.byKey(photoToolbarKey), findsOneWidget);
    for (final MdPhotoSize size in MdPhotoSize.values) {
      expect(find.byKey(photoToolbarSizeKey(size)), findsNothing);
    }
    for (final MdPhotoSide side in MdPhotoSide.values) {
      expect(find.byKey(photoToolbarSideKey(side)), findsNothing);
    }
    expect(find.byKey(photoToolbarCaptionKey), findsOneWidget);
    expect(find.byKey(photoToolbarRemoveKey), findsOneWidget);
    if (find.byKey(photoToolbarMoveUpKey).evaluate().isEmpty) {
      await _press(tester, photoToolbarMoreKey);
    }
    expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);
    expect(find.byKey(photoToolbarMoveDownKey), findsOneWidget);
    expect(find.byKey(photoToolbarReplaceKey), findsOneWidget);
  });

  testWidgets('left and right are disabled only when the photo cannot float', (
    WidgetTester tester,
  ) async {
    Future<_Harness> open(String line) async {
      final _Harness harness = await _pump(
        tester,
        'one\n$line\ntwo',
        width: 560,
      );
      await _selectPhoto(tester);
      expect(find.byKey(photoToolbarKey), findsOneWidget);
      return harness;
    }

    SemanticsNode side(MdPhotoSide side) =>
        tester.getSemantics(find.byKey(photoToolbarSideKey(side)));

    final String large = mdPhotoLine(photoIdA, size: MdPhotoSize.large);
    final _Harness onLarge = await open(large);
    expect(
      side(MdPhotoSide.left),
      isSemantics(isEnabled: false, hint: photoToolbarNoFloatHint),
    );
    expect(
      side(MdPhotoSide.right),
      isSemantics(
        isEnabled: false,
        isSelected: true,
        hint: photoToolbarNoFloatHint,
      ),
    );
    expect(side(MdPhotoSide.centre), isSemantics(isEnabled: true));
    await _press(tester, photoToolbarSideKey(MdPhotoSide.left));
    expect(onLarge.controller.text, 'one\n$large\ntwo');

    await open(a);
    expect(side(MdPhotoSide.left), isSemantics(isEnabled: true));
    expect(side(MdPhotoSide.centre), isSemantics(isEnabled: true));
    expect(side(MdPhotoSide.right), isSemantics(isSelected: true));

    await open(mdPhotoLine(photoIdA, size: MdPhotoSize.full));
    for (final MdPhotoSide each in MdPhotoSide.values) {
      expect(side(each), isSemantics(isEnabled: false, isSelected: false));
    }

    await open(mdPhotoLine(photoIdA, side: MdPhotoSide.centre));
    expect(side(MdPhotoSide.left), isSemantics(isEnabled: true));
    expect(side(MdPhotoSide.right), isSemantics(isEnabled: true));

    const String invalid = '![](photo/a1b2c3d4e5f6 "left left")';
    final _Harness onInvalid = await open(invalid);
    for (final MdPhotoSize size in MdPhotoSize.values) {
      expect(
        tester.getSemantics(find.byKey(photoToolbarSizeKey(size))),
        isSemantics(isSelected: false),
      );
    }
    for (final MdPhotoSide each in MdPhotoSide.values) {
      expect(side(each), isSemantics(isSelected: false));
    }
    expect(side(MdPhotoSide.left), isSemantics(isEnabled: true));
    expect(side(MdPhotoSide.right), isSemantics(isEnabled: true));
    await _press(tester, photoToolbarSideKey(MdPhotoSide.left));
    expect(
      onInvalid.controller.text,
      'one\n![](photo/a1b2c3d4e5f6 "left medium")\ntwo',
    );

    final _Harness fresh = await open(invalid);
    await _press(tester, photoToolbarSizeKey(MdPhotoSize.small));
    expect(
      fresh.controller.text,
      'one\n![](photo/a1b2c3d4e5f6 "centre small")\ntwo',
    );
  });

  testWidgets('it shows only while a photo is selected', (
    WidgetTester tester,
  ) async {
    final String note = 'one\n$a\ntwo';
    final _Harness harness = await _pump(tester, note);
    harness.focusNode.requestFocus();
    await tester.pump();
    await NoteEditorDriver(
      tester,
    ).setSelection(const TextSelection.collapsed(offset: 1));

    expect(find.byKey(photoToolbarKey), findsNothing);

    await _selectPhoto(tester);

    expect(find.byKey(photoToolbarKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsNothing);
    expect(harness.focusNode.hasFocus, isTrue);
  });

  testWidgets('the move controls carry a glyph each, not a word', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a\ntwo\n$b\nthree', importer: _pickB);

    await _selectPhoto(tester);

    for (final Key key in <Key>[
      photoToolbarMoveUpKey,
      photoToolbarMoveDownKey,
      photoToolbarReplaceKey,
    ]) {
      expect(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
        findsNothing,
        reason: '$key still carries a word',
      );
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    }
  });

  testWidgets('every control centres its mark and lets it keep its own size', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a\ntwo\n$b\nthree', importer: _pickB);

    await _selectPhoto(tester);

    final Map<String, Key> controls = <String, Key>{
      for (final MdPhotoSize size in MdPhotoSize.values)
        photoToolbarSizeLabel(size): photoToolbarSizeKey(size),
      for (final MdPhotoSide side in MdPhotoSide.values)
        photoToolbarSideLabel(side): photoToolbarSideKey(side),
      photoToolbarMoveUpLabel: photoToolbarMoveUpKey,
      photoToolbarMoveDownLabel: photoToolbarMoveDownKey,
      photoToolbarReplaceLabel: photoToolbarReplaceKey,
      photoToolbarCaptionLabel: photoToolbarCaptionKey,
      photoToolbarRemoveLabel: photoToolbarRemoveKey,
    };

    controls.forEach((String name, Key key) {
      final Rect box = tester.getRect(find.byKey(key));
      final Finder mark = find.descendant(
        of: find.byKey(key),
        matching: find.byType(Opacity),
      );
      final Rect drawn = tester.getRect(mark);
      final RenderBox render = tester.renderObject<RenderBox>(mark);

      expect(
        render.size.height,
        closeTo(render.getMaxIntrinsicHeight(double.infinity), _tolerance),
        reason: '$name is stretched to the height of its control',
      );
      expect(
        render.size.width,
        closeTo(render.getMaxIntrinsicWidth(double.infinity), _tolerance),
        reason: '$name is stretched to the width of its control',
      );
      expect(
        drawn.center.dy,
        closeTo(box.center.dy, _tolerance),
        reason: '$name rides off the centre of its control',
      );
      expect(
        drawn.center.dx,
        closeTo(box.center.dx, _tolerance),
        reason: '$name sits off the centre of its control',
      );
    });
  });

  testWidgets(
    'every control meets the platform target',
    (WidgetTester tester) async {
      await _pump(tester, 'one\n$a\ntwo\n$b\nthree', importer: _pickB);
      await _selectPhoto(tester);
      final double target = photoToolbarTargetFor(defaultTargetPlatform);

      for (final Key key in <Key>[
        for (final MdPhotoSize size in MdPhotoSize.values)
          photoToolbarSizeKey(size),
        for (final MdPhotoSide side in MdPhotoSide.values)
          photoToolbarSideKey(side),
        photoToolbarMoveUpKey,
        photoToolbarMoveDownKey,
        photoToolbarReplaceKey,
        photoToolbarCaptionKey,
        photoToolbarRemoveKey,
      ]) {
        final Size size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(target), reason: '$key');
        expect(size.height, greaterThanOrEqualTo(target), reason: '$key');
      }
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('it carries no placement preview of its own', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a\ntwo');

    await _selectPhoto(tester);

    expect(find.byKey(photoToolbarKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(photoToolbarKey)).height,
      lessThanOrEqualTo(
        photoToolbarTargetFor(defaultTargetPlatform) + 2 * photoToolbarPadding,
      ),
    );
  });

  testWidgets('a Full photo takes no side, so the side controls go quiet', (
    WidgetTester tester,
  ) async {
    final String full = mdPhotoLine(photoIdA, size: MdPhotoSize.full);
    final _Harness harness = await _pump(tester, 'one\n$full\ntwo');

    await _selectPhoto(tester);
    await _press(tester, photoToolbarSideKey(MdPhotoSide.left));
    await _press(tester, photoToolbarSideKey(MdPhotoSide.centre));

    expect(harness.controller.text, 'one\n$full\ntwo');
    for (final MdPhotoSide side in <MdPhotoSide>[
      MdPhotoSide.left,
      MdPhotoSide.centre,
    ]) {
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byKey(photoToolbarSideKey(side)),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        lessThan(1),
      );
    }
  });

  testWidgets('it stays inside the editor when the photo sits at the bottom', (
    WidgetTester tester,
  ) async {
    final String note = '${_lines(20)}\n$a\n${_lines(20)}';
    final _Harness harness = await _pump(tester, note, height: 320);
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    harness.focusNode.requestFocus();
    await tester.pump();
    await driver.setSelection(
      TextSelection.collapsed(offset: note.indexOf(a) + 4),
    );

    final Rect editor = _editor(tester);
    for (final double offset in <double>[0, 40, 90, 140]) {
      harness.scroll.jumpTo(
        offset.clamp(0.0, harness.scroll.position.maxScrollExtent),
      );
      await tester.pump();
      if (find.byKey(photoToolbarKey).evaluate().isEmpty) {
        continue;
      }
      final Rect bar = _bar(tester);
      expect(
        bar.top,
        greaterThanOrEqualTo(editor.top - _tolerance),
        reason: '$offset',
      );
      expect(
        bar.bottom,
        lessThanOrEqualTo(editor.bottom + _tolerance),
        reason: 'at scroll $offset',
      );
    }
  });

  testWidgets('Size and Side rewrite only the selected photo', (
    WidgetTester tester,
  ) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _Harness harness = await _pump(tester, note);

    await _selectPhoto(tester, 1);
    expect(find.byKey(photoToolbarKey), findsOneWidget);

    await _press(tester, photoToolbarSizeKey(MdPhotoSize.large));
    await _press(tester, photoToolbarSideKey(MdPhotoSide.left));

    final String rewritten = mdPhotoLine(
      photoIdB,
      side: MdPhotoSide.left,
      size: MdPhotoSize.large,
    );
    expect(rewritten, contains('"left large"'));
    expect(harness.controller.text, 'one\n$a\ntwo\n$rewritten\nthree');
  });

  testWidgets('the move controls sit in the bar itself', (
    WidgetTester tester,
  ) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _Harness harness = await _pump(tester, note, importer: _pickB);

    await _selectPhoto(tester, 1);

    expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);
    expect(find.byKey(photoToolbarMoveDownKey), findsOneWidget);
    expect(find.byKey(photoToolbarReplaceKey), findsOneWidget);

    await _press(tester, photoToolbarMoveUpKey);

    expect(harness.controller.text, 'one\n$a\n$b\ntwo\n\nthree');
  });

  testWidgets('a narrow bar drops the move controls and keeps the rest', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a\ntwo', width: 200, importer: _pickB);

    await _selectPhoto(tester);

    expect(find.byKey(photoToolbarKey), findsOneWidget);
    for (final MdPhotoSize size in MdPhotoSize.values) {
      expect(find.byKey(photoToolbarSizeKey(size)), findsNothing);
    }
    for (final MdPhotoSide side in MdPhotoSide.values) {
      expect(find.byKey(photoToolbarSideKey(side)), findsNothing);
    }
    expect(find.byKey(photoToolbarMoreKey), findsOneWidget);
    expect(find.byKey(photoToolbarMoveUpKey), findsNothing);
    expect(find.byKey(photoToolbarMoveDownKey), findsNothing);
    expect(find.byKey(photoToolbarReplaceKey), findsNothing);
    expect(find.byKey(photoToolbarCaptionKey), findsOneWidget);
    expect(find.byKey(photoToolbarRemoveKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(photoToolbarKey)).width,
      lessThanOrEqualTo(200),
    );

    await _press(tester, photoToolbarMoreKey);

    expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);
    expect(find.byKey(photoToolbarMoveDownKey), findsOneWidget);
    expect(find.byKey(photoToolbarReplaceKey), findsOneWidget);
  });

  testWidgets('the overflow menu runs its actions for held presses', (
    WidgetTester tester,
  ) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    for (final int hold in <int>[30, 110, 300]) {
      for (final Key item in <Key>[
        photoToolbarMoveUpKey,
        photoToolbarMoveDownKey,
        photoToolbarReplaceKey,
      ]) {
        final _Harness harness = await _pump(
          tester,
          note,
          width: 200,
          importer: () async => <String>[prefixOf(photoIdC)],
        );
        await _selectPhoto(tester, 1);
        await _press(tester, photoToolbarMoreKey, Duration(milliseconds: hold));
        expect(find.byKey(item), findsOneWidget);

        await _press(tester, item, Duration(milliseconds: hold));
        await tester.pump();

        expect(harness.controller.text, isNot(note), reason: '$item $hold');
        if (item == photoToolbarMoveUpKey) {
          expect(harness.controller.text, 'one\n$a\n$b\ntwo\n\nthree');
        }
        if (item == photoToolbarReplaceKey) {
          expect(
            harness.controller.text,
            note.replaceFirst(b, mdPhotoLine(photoIdC)),
          );
        }
        expect(find.byKey(photoToolbarMoveUpKey), findsNothing);
        expect(find.byKey(photoToolbarMoveDownKey), findsNothing);
        expect(find.byKey(photoToolbarReplaceKey), findsNothing);
      }
    }
  });

  testWidgets('an open toolbar and overflow menu schedule no idle frames', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a\ntwo', width: 200, importer: _pickB);
    await _selectPhoto(tester);
    await _press(tester, photoToolbarMoreKey);
    await tester.pumpAndSettle();

    expect(find.byKey(photoToolbarKey), findsOneWidget);
    expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Replace keeps the caption and the title bytes', (
    WidgetTester tester,
  ) async {
    const String porch = '![Porch](photo/a1b2c3d4e5f6 "right large")';
    final _Harness harness = await _pump(
      tester,
      'one\n$porch\ntwo',
      importer: _pickB,
    );
    await _selectPhoto(tester);

    await _press(tester, photoToolbarReplaceKey);
    await tester.pump();

    expect(
      harness.controller.text,
      'one\n![Porch](photo/b2c3d4e5f6a1 "right large")\ntwo',
    );
  });

  testWidgets('a marked control on a non-canonical title makes no change', (
    WidgetTester tester,
  ) async {
    const String loose = '![](photo/a1b2c3d4e5f6 "Right  Medium")';
    final _Harness harness = await _pump(tester, 'one\n$loose\ntwo');
    await _selectPhoto(tester);

    await _press(tester, photoToolbarSizeKey(MdPhotoSize.medium));

    expect(tester.takeException(), isNull);
    expect(harness.controller.text, 'one\n$loose\ntwo');
  });

  testWidgets('it flips below the photo when there is no room above', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a');
    await _selectPhoto(tester);

    expect(
      _bar(tester).top,
      greaterThanOrEqualTo(_figure(tester).bottom - _tolerance),
    );

    await _pump(tester, '${_lines(10)}\n$a');
    await _selectPhoto(tester);

    expect(
      _bar(tester).bottom,
      lessThanOrEqualTo(_figure(tester).top + _tolerance),
    );
  });

  testWidgets('it keeps clear of the bottom inset band', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'one\n$a', bottomInset: 400);
    await _selectPhoto(tester);

    expect(
      _bar(tester).bottom,
      lessThanOrEqualTo(_editor(tester).bottom - 400 + _tolerance),
    );

    await _pump(tester, 'one\n$a');
    await _selectPhoto(tester);

    expect(
      _bar(tester).top,
      greaterThanOrEqualTo(_figure(tester).bottom - _tolerance),
    );
    expect(_bar(tester).bottom, greaterThan(_editor(tester).bottom - 400));
  });

  test('the bar never takes the slot above a photo that starts in the band '
      'under the surface', () {
    const Rect surface = Rect.fromLTWH(0, 0, 720, 600);
    const Size bar = Size(300, 58);

    final Offset clear = photoToolbarOffset(
      figure: const Rect.fromLTWH(210, 590, 300, 225),
      surface: surface,
      bar: bar,
    );
    expect(clear, const Offset(210, 522));

    final Offset banded = photoToolbarOffset(
      figure: const Rect.fromLTWH(210, 630, 300, 225),
      surface: surface,
      bar: bar,
    );
    expect(banded.dy + bar.height, lessThanOrEqualTo(surface.bottom));
    expect(banded.dy, greaterThanOrEqualTo(surface.top));
  });

  testWidgets('it hides while the photo starts inside the bottom inset band', (
    WidgetTester tester,
  ) async {
    const double inset = 100;
    final String note = '${_lines(40)}\n$a\n${_lines(40)}';
    final _Harness harness = await _pump(tester, note, bottomInset: inset);
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    harness.focusNode.requestFocus();
    await tester.pump();
    await driver.setSelection(
      TextSelection.collapsed(offset: note.indexOf(a) + 4),
    );

    Future<void> placePhotoTop(double y) async {
      final double shift = _figure(tester).top - _editor(tester).top - y;
      harness.scroll.jumpTo(harness.scroll.offset + shift);
      await tester.pump();
      expect(_figure(tester).top - _editor(tester).top, closeTo(y, _tolerance));
    }

    final double bandTop = _editor(tester).bottom - inset;

    await placePhotoTop(590);

    expect(find.byKey(photoToolbarKey), findsOneWidget);
    expect(_bar(tester).bottom, lessThanOrEqualTo(bandTop + _tolerance));
    expect(
      _figure(tester).top - _bar(tester).bottom,
      lessThanOrEqualTo(photoToolbarGap + _tolerance),
    );

    await placePhotoTop(650);

    expect(find.byKey(photoToolbarKey), findsNothing);
  });

  testWidgets('it stays inside the writing surface and hides when the photo '
      'scrolls away', (WidgetTester tester) async {
    final String photo = mdPhotoLine(photoIdA, size: MdPhotoSize.full);
    final _Harness harness = await _pump(tester, '$photo\n${_prose(400)}');

    await _selectPhoto(tester);

    final Rect surface = _editor(tester);
    final Rect bar = _bar(tester);
    expect(bar.left, greaterThanOrEqualTo(surface.left - _tolerance));
    expect(bar.right, lessThanOrEqualTo(surface.right + _tolerance));
    expect(bar.top, greaterThanOrEqualTo(surface.top - _tolerance));
    expect(bar.bottom, lessThanOrEqualTo(surface.bottom + _tolerance));

    harness.scroll.jumpTo(harness.scroll.position.maxScrollExtent);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsNothing);
  });

  testWidgets('Tab walks its controls and Esc returns to the writing surface', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(tester, '${_lines(10)}\n$a');

    await _selectPhoto(tester);
    expect(harness.focusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _hasPrimaryFocus(tester, photoToolbarSizeKey(MdPhotoSize.small)),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _hasPrimaryFocus(tester, photoToolbarSizeKey(MdPhotoSize.medium)),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsOneWidget);
    expect(harness.focusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsNothing);
    expect(harness.focusNode.hasPrimaryFocus, isTrue);
  });
}
