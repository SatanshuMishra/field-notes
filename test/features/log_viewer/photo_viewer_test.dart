import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/note_photos.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/log_viewer/photo_viewer.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

import '../notes/support/notes_harness.dart' show FakeNoteMediaResolver;

const String _day = 'Saturday, July 5';
const double _titleBar = 42;
const double _statusBar = 34;
const double _gestureBar = 24;

const List<NotePhoto> _photos = <NotePhoto>[
  NotePhoto(reference: 'a1b2c3d4e5f6', caption: 'The harbour wall'),
  NotePhoto(reference: 'b2c3d4e5f6a1', caption: 'Gulls on the pier'),
  NotePhoto(reference: 'c3d4e5f6a1b2', caption: ''),
];

const List<String> _dockLabels = <String>['Previous', 'Back to note', 'Next'];

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(384, 832);
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

void _mac(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

Future<void> _pumpOpener(
  WidgetTester tester, {
  required TargetPlatform platform,
  required int initialIndex,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<String>('$platform-$brightness'),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform, brightness: brightness),
      home: Builder(
        builder: (BuildContext context) => Center(
          child: TextButton(
            onPressed: () => showPhotoViewer(
              context,
              photos: _photos,
              initialIndex: initialIndex,
              dayTitle: _day,
              resolver: FakeNoteMediaResolver()..memoizeAll(),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  required int initialIndex,
  Brightness brightness = Brightness.light,
}) async {
  await _pumpOpener(
    tester,
    platform: platform,
    initialIndex: initialIndex,
    brightness: brightness,
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.byType(PhotoViewer), findsOneWidget);
}

double _routeOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(PhotoViewer),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

double _overlayOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.ancestor(
              of: find.byType(ViewerDock),
              matching: find.byType(AnimatedOpacity),
            ),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

Finder _circle(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is ViewerGlassCircle && widget.label == label,
);

Finder _glassOf(Finder control) =>
    find.descendant(of: control, matching: find.byType(GlassSurface));

String? _shownPhoto(WidgetTester tester) =>
    tester.widget<MediaImage>(find.byType(MediaImage)).mediaId;

void main() {
  testWidgets("the photo viewer steps only within the note's photos", (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await _open(tester, platform: TargetPlatform.android, initialIndex: 1);

    expect(
      find.text('Gulls on the pier · 2 of 3 · Saturday, July 5'),
      findsOneWidget,
    );
    expect(_shownPhoto(tester), _photos[1].reference);

    await tester.tap(_circle('Next'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 · Saturday, July 5'), findsOneWidget);
    expect(_shownPhoto(tester), _photos[2].reference);
    expect(_circle('Next'), findsNothing);
    expect(_circle('Previous'), findsOneWidget);

    await tester.flingFrom(const Offset(300, 420), const Offset(-160, 0), 1200);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 · Saturday, July 5'), findsOneWidget);
    expect(_shownPhoto(tester), _photos[2].reference);

    expect(
      photoViewerQuietLine(
        photo: _photos.first,
        index: 0,
        count: 1,
        dayTitle: _day,
      ),
      'The harbour wall · Saturday, July 5',
    );
  });

  testWidgets('the phone photo viewer has a three-control dock', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    for (final Brightness brightness in Brightness.values) {
      await _open(
        tester,
        platform: TargetPlatform.android,
        initialIndex: 1,
        brightness: brightness,
      );

      expect(
        tester.getRect(find.byType(MediaImage)),
        const Rect.fromLTWH(0, 0, 384, 832),
      );
      for (final String label in _dockLabels) {
        final Finder circle = _circle(label);
        expect(circle, findsOneWidget, reason: label);
        final Rect hit = tester.getRect(circle);
        expect(
          hit.width,
          greaterThan(48 - precisionErrorTolerance),
          reason: label,
        );
        expect(
          hit.height,
          greaterThan(48 - precisionErrorTolerance),
          reason: label,
        );
        expect(hit.center.dy, greaterThan(832 * 2 / 3), reason: label);
        final Finder glass = _glassOf(circle);
        expect(tester.widget<GlassSurface>(glass).tone, GlassTone.media);
        expect(tester.getSize(glass), const Size.square(48));
        final Finder text = find.text(label);
        expect(text, findsOneWidget, reason: label);
        expect(
          tester.widget<Text>(text).style?.color?.toARGB32(),
          Palette.mediaInk.toARGB32(),
        );
        expect(tester.getRect(text).top, greaterThan(hit.bottom - 1));
      }
      final List<double> columns = <double>[
        for (final String label in _dockLabels)
          tester.getCenter(_circle(label)).dx,
      ];
      expect(columns[0], lessThan(columns[1]));
      expect(columns[1], moreOrLessEquals(192));
      expect(columns[2], greaterThan(columns[1]));
      final Rect quiet = tester.getRect(
        find.text('Gulls on the pier · 2 of 3 · Saturday, July 5'),
      );
      expect(quiet.top, greaterThanOrEqualTo(_statusBar));
      expect(quiet.center.dx, moreOrLessEquals(192, epsilon: 1));

      await tester.tapAt(const Offset(192, 416));
      await tester.pumpAndSettle();
      for (final String label in _dockLabels) {
        expect(_circle(label).hitTestable(), findsNothing, reason: label);
      }
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(
                of: find.byType(ViewerDock),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        0,
      );

      await tester.tapAt(const Offset(192, 416));
      await tester.pumpAndSettle();
      for (final String label in _dockLabels) {
        expect(_circle(label).hitTestable(), findsOneWidget, reason: label);
      }

      await tester.flingFrom(
        const Offset(300, 420),
        const Offset(-160, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 · Saturday, July 5'), findsOneWidget);
      expect(_shownPhoto(tester), _photos[2].reference);

      await tester.tap(_circle('Back to note'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsNothing);
    }
  });

  testWidgets('the phone overlays stay up while a dock control has focus', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await _open(tester, platform: TargetPlatform.android, initialIndex: 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    expect(focused?.findAncestorWidgetOfExactType<ViewerDock>(), isNotNull);

    await tester.tapAt(const Offset(192, 416));
    await tester.pumpAndSettle();
    for (final String label in _dockLabels) {
      expect(_circle(label).hitTestable(), findsOneWidget, reason: label);
    }
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byType(ViewerDock),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      1,
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(192, 416));
    await tester.pumpAndSettle();
    for (final String label in _dockLabels) {
      expect(_circle(label).hitTestable(), findsNothing, reason: label);
    }
  });

  testWidgets('the Mac photo viewer insets the photo under a back pill', (
    WidgetTester tester,
  ) async {
    _mac(tester, const Size(1440, 900));
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final Brightness brightness in Brightness.values) {
      await _open(
        tester,
        platform: TargetPlatform.macOS,
        initialIndex: 1,
        brightness: brightness,
      );

      expect(
        tester.getRect(find.byType(MediaImage)),
        const Rect.fromLTRB(24, _titleBar + 56, 1440 - 24, 900 - 84),
      );
      expect(find.byType(ViewerDock), findsNothing);

      final Finder pill = find.bySemanticsLabel('Back to note');
      expect(pill, findsOneWidget);
      final Rect pillHit = tester.getRect(pill);
      expect(pillHit.topLeft, const Offset(18, _titleBar + 16));
      expect(pillHit.height, 48);
      expect(pillHit.width, greaterThanOrEqualTo(48));
      final Finder pillText = find.text('Back to note');
      expect(
        tester.widget<Text>(pillText).style?.color?.toARGB32(),
        Palette.mediaInk.toARGB32(),
      );
      final Finder pillGlass = find.ancestor(
        of: pillText,
        matching: find.byType(GlassSurface),
      );
      expect(tester.widget<GlassSurface>(pillGlass).tone, GlassTone.media);
      expect(pillHit.contains(tester.getCenter(pillGlass)), isTrue);

      final Finder quiet = find.text(
        'Gulls on the pier · 2 of 3 · Saturday, July 5',
      );
      expect(tester.getCenter(quiet).dx, moreOrLessEquals(720, epsilon: 1));
      expect(
        tester.getCenter(quiet).dy,
        moreOrLessEquals(pillHit.center.dy, epsilon: 1),
      );

      final Finder capsule = find.byType(ViewerCapsule);
      final Rect capsuleRect = tester.getRect(capsule);
      expect(capsuleRect.bottom, 900 - 24);
      expect(capsuleRect.center.dx, moreOrLessEquals(720));
      expect(
        tester.widget<GlassSurface>(_glassOf(capsule).first).tone,
        GlassTone.media,
      );
      final Finder position = find.descendant(
        of: capsule,
        matching: find.text('2 of 3'),
      );
      expect(position, findsOneWidget);
      expect(
        tester.widget<Text>(position).style?.color?.toARGB32(),
        Palette.mediaInk.toARGB32(),
      );
      final Finder previous = find.descendant(
        of: capsule,
        matching: _circle('Previous'),
      );
      final Finder next = find.descendant(
        of: capsule,
        matching: _circle('Next'),
      );
      expect(previous, findsOneWidget);
      expect(next, findsOneWidget);
      for (final Finder step in <Finder>[previous, next]) {
        expect(tester.getSize(step), const Size.square(48));
        expect(tester.getSize(_glassOf(step)), const Size.square(40));
      }
      expect(
        tester.getCenter(previous).dx,
        lessThan(tester.getRect(position).left),
      );
      expect(
        tester.getCenter(next).dx,
        greaterThan(tester.getRect(position).right),
      );
      expect(tester.getCenter(position).dx, moreOrLessEquals(720, epsilon: 1));

      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: capsule, matching: find.text('3 of 3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: capsule, matching: _circle('Next')),
        findsNothing,
      );
      expect(
        tester.getCenter(find.text('3 of 3')).dx,
        moreOrLessEquals(720, epsilon: 1),
      );

      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsNothing);
    }
    semantics.dispose();
  });

  testWidgets('arrows step photos on the Mac', (WidgetTester tester) async {
    _mac(tester, const Size(1280, 800));
    await _open(tester, platform: TargetPlatform.macOS, initialIndex: 0);
    final Finder capsule = find.byType(ViewerCapsule);
    expect(
      find.text('The harbour wall · 1 of 3 · Saturday, July 5'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: capsule, matching: find.text('2 of 3')),
      findsOneWidget,
    );
    expect(
      find.text('Gulls on the pier · 2 of 3 · Saturday, July 5'),
      findsOneWidget,
    );
    expect(_shownPhoto(tester), _photos[1].reference);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: capsule, matching: find.text('1 of 3')),
      findsOneWidget,
    );
    expect(_shownPhoto(tester), _photos[0].reference);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: capsule, matching: find.text('1 of 3')),
      findsOneWidget,
    );
    expect(
      find.text('The harbour wall · 1 of 3 · Saturday, July 5'),
      findsOneWidget,
    );
    expect(_shownPhoto(tester), _photos[0].reference);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets(
    'with reduce motion the photo viewer and its overlays never fade',
    (WidgetTester tester) async {
      _phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpOpener(
        tester,
        platform: TargetPlatform.android,
        initialIndex: 1,
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(_routeOpacity(tester), 1);
      expect(_overlayOpacity(tester), 1);

      await tester.tapAt(const Offset(192, 416));
      await tester.pump();
      expect(_overlayOpacity(tester), 0);

      await tester.tapAt(const Offset(192, 416));
      await tester.pump();
      expect(_overlayOpacity(tester), 1);
    },
  );

  testWidgets('opening a photo pauses other playback', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      if (platform == TargetPlatform.macOS) {
        _mac(tester, const Size(1280, 800));
      } else {
        _phone(tester);
      }
      final Object inline = Object();
      final List<Object> paused = <Object>[];
      playbackFocus.claim(inline, () => paused.add(inline));
      addTearDown(() => playbackFocus.release(inline));

      await _open(tester, platform: platform, initialIndex: 0);

      expect(paused, <Object>[inline], reason: '$platform');
    }
  });

  testWidgets('the Mac photo steps have 48-point hit areas', (
    WidgetTester tester,
  ) async {
    _mac(tester, const Size(1440, 900));
    await _open(tester, platform: TargetPlatform.macOS, initialIndex: 1);
    final Finder capsule = find.byType(ViewerCapsule);
    Finder step(String label) =>
        find.descendant(of: capsule, matching: _circle(label));

    for (final String label in <String>['Previous', 'Next']) {
      expect(tester.getSize(step(label)), const Size.square(48), reason: label);
      expect(
        tester.getSize(_glassOf(step(label))),
        const Size.square(40),
        reason: label,
      );
    }

    await tester.tapAt(tester.getCenter(step('Next')) + const Offset(22, 0));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: capsule, matching: find.text('3 of 3')),
      findsOneWidget,
    );

    await tester.tapAt(
      tester.getCenter(step('Previous')) - const Offset(22, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: capsule, matching: find.text('2 of 3')),
      findsOneWidget,
    );
  });
}
