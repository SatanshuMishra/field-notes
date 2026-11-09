import 'package:field_notes/features/capture/video/camera_picture_fill.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _portrait = 9 / 16;
const double _landscape = 16 / 9;
const double _edgeSlack = 0.5;
const Color _pictureInk = Color(0xFF6B8F71);
const Color _ambientInk = Color(0xFF8C6B5A);
const Color _black = Color(0xFF000000);
const double _leastBlurSigma = 16;

typedef _Shape = ({double aspect, Size window});

const List<_Shape> _shapes = <_Shape>[
  (aspect: _portrait, window: Size(412, 915)),
  (aspect: _portrait, window: Size(915, 412)),
  (aspect: _landscape, window: Size(1440, 900)),
  (aspect: _landscape, window: Size(2560, 800)),
  (aspect: _landscape, window: Size(500, 1100)),
  (aspect: _landscape, window: Size(1280, 720)),
];

void _useWindow(WidgetTester tester, Size window) {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _stage({
  required double aspect,
  Widget picture = const ColoredBox(color: _pictureInk),
  Widget? ambient = const ColoredBox(color: _ambientInk),
  bool ready = true,
  bool reduceMotion = false,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: CameraPictureStage(
          pictureAspect: aspect,
          picture: picture,
          ambient: ambient,
          ready: ready,
        ),
      ),
    ),
  );
}

double _blurSigma(ImageFiltered filtered) {
  final RegExpMatch? match = RegExp(r'ImageFilter\.blur\(([\d.]+),')
      .firstMatch(filtered.imageFilter.toString());
  expect(match, isNotNull, reason: '${filtered.imageFilter}');
  return double.parse(match!.group(1)!);
}

double _fadeOf(WidgetTester tester, Finder finder) {
  final Element element = tester.element(finder);
  double product = _ownFade(element.widget);
  element.visitAncestorElements((Element ancestor) {
    product *= _ownFade(ancestor.widget);
    return true;
  });
  return product;
}

double _ownFade(Widget widget) {
  if (widget is Opacity) {
    return widget.opacity;
  }
  if (widget is FadeTransition) {
    return widget.opacity.value;
  }
  return 1;
}

bool _covers(Rect rect, Size window) =>
    rect.left <= 0 &&
    rect.top <= 0 &&
    rect.right >= window.width &&
    rect.bottom >= window.height;

List<Widget> _between(WidgetTester tester, Finder inner, Key outer) {
  final List<Widget> chain = <Widget>[];
  tester.element(inner).visitAncestorElements((Element ancestor) {
    chain.add(ancestor.widget);
    return ancestor.widget.key != outer;
  });
  return chain;
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: _pictureInk);
}

void main() {
  testWidgets('the whole picture is visible at every window shape', (
    WidgetTester tester,
  ) async {
    for (final _Shape shape in _shapes) {
      _useWindow(tester, shape.window);
      await tester.pumpWidget(_stage(aspect: shape.aspect));
      await tester.pump(const Duration(milliseconds: 300));

      final Rect picture = tester.getRect(find.byKey(cameraPictureKey));
      final Size window = shape.window;
      final String at = '${shape.aspect} in $window';
      expect(
        picture.width / picture.height,
        closeTo(shape.aspect, 0.01),
        reason: at,
      );
      expect(picture.left, greaterThanOrEqualTo(-_edgeSlack), reason: at);
      expect(picture.top, greaterThanOrEqualTo(-_edgeSlack), reason: at);
      expect(
        picture.right,
        lessThanOrEqualTo(window.width + _edgeSlack),
        reason: at,
      );
      expect(
        picture.bottom,
        lessThanOrEqualTo(window.height + _edgeSlack),
        reason: at,
      );
      final bool spansWidth =
          picture.left.abs() <= _edgeSlack &&
          (picture.right - window.width).abs() <= _edgeSlack;
      final bool spansHeight =
          picture.top.abs() <= _edgeSlack &&
          (picture.bottom - window.height).abs() <= _edgeSlack;
      expect(spansWidth || spansHeight, isTrue, reason: at);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'the fill covers the whole window whenever the picture leaves a band',
    (WidgetTester tester) async {
      for (final _Shape shape in <_Shape>[
        (aspect: _portrait, window: const Size(412, 915)),
        (aspect: _landscape, window: const Size(2560, 800)),
      ]) {
        _useWindow(tester, shape.window);
        await tester.pumpWidget(_stage(aspect: shape.aspect));
        await tester.pump(const Duration(milliseconds: 300));

        final Finder fill = find.byKey(cameraPictureFillKey);
        final String at = '${shape.aspect} in ${shape.window}';
        expect(fill, findsOneWidget, reason: at);
        expect(_covers(tester.getRect(fill), shape.window), isTrue, reason: at);
        final Finder blur = find.descendant(
          of: fill,
          matching: find.byType(ImageFiltered),
        );
        expect(blur, findsOneWidget, reason: at);
        expect(
          _blurSigma(tester.widget<ImageFiltered>(blur)),
          greaterThanOrEqualTo(_leastBlurSigma),
          reason: at,
        );
        expect(
          find.descendant(
            of: blur,
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is ColoredBox && widget.color == _ambientInk,
            ),
          ),
          findsOneWidget,
          reason: at,
        );
        expect(
          find.descendant(
            of: fill,
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is ColoredBox &&
                  widget.color.a > 0 &&
                  widget.color.a < 1,
            ),
          ),
          findsOneWidget,
          reason: at,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('no fill is drawn when the picture fills the window exactly', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, const Size(1280, 720));

    await tester.pumpWidget(_stage(aspect: _landscape));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(cameraPictureKey), findsOneWidget);
    expect(find.byKey(cameraPictureFillKey), findsNothing);
  });

  testWidgets('with reduced motion no moving fill is drawn', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, const Size(412, 915));

    await tester.pumpWidget(_stage(aspect: _portrait, reduceMotion: true));
    await tester.pump();

    expect(find.byKey(cameraPictureFillKey), findsNothing);
    expect(find.byKey(cameraPictureKey), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ColoredBox &&
            widget.color.toARGB32() == _black.toARGB32(),
      ),
      findsNothing,
    );
  });

  testWidgets('the fill ignores touches and is hidden from screen readers', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, const Size(412, 915));

    await tester.pumpWidget(_stage(aspect: _portrait));
    await tester.pump(const Duration(milliseconds: 300));

    final Finder blur = find.descendant(
      of: find.byKey(cameraPictureFillKey),
      matching: find.byType(ImageFiltered),
    );
    expect(blur, findsOneWidget);
    final List<Widget> above = _between(tester, blur, cameraPictureFillKey);
    expect(
      above.whereType<IgnorePointer>().where((IgnorePointer w) => w.ignoring),
      isNotEmpty,
    );
    expect(
      above.whereType<ExcludeSemantics>().where(
        (ExcludeSemantics w) => w.excluding,
      ),
      isNotEmpty,
    );
  });

  testWidgets(
    'the picture stays the same element when the fill appears or the window changes',
    (WidgetTester tester) async {
      _useWindow(tester, const Size(1280, 720));
      await tester.pumpWidget(
        _stage(aspect: _landscape, picture: const _Counter(), ambient: null),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final State first = tester.state(find.byType(_Counter));
      expect(find.byKey(cameraPictureFillKey), findsNothing);

      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        _stage(
          aspect: _landscape,
          picture: const _Counter(),
          ambient: const ColoredBox(color: _ambientInk),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(cameraPictureFillKey), findsOneWidget);
      expect(tester.state(find.byType(_Counter)), same(first));
    },
  );

  testWidgets('a picture that is ready when it first shows still fades in', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, const Size(1280, 720));

    await tester.pumpWidget(_stage(aspect: _landscape));
    await tester.pump(const Duration(milliseconds: 130));

    final double midway = _fadeOf(tester, find.byKey(cameraPictureKey));
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));

    await tester.pump(const Duration(milliseconds: 300));

    expect(_fadeOf(tester, find.byKey(cameraPictureKey)), closeTo(1, 1e-9));
  });
}
