import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/streak/streak.dart';

import '../../support/sync_overrides.dart';
import '../app_harness.dart';
import '../support/mac_app_shell.dart';

const Key _settingsButton = ValueKey<String>('settings-button');
const Key _soundButton = ValueKey<String>('sound-button');

final TargetPlatformVariant _macOS = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final Matcher _boardGap = moreOrLessEquals(10, epsilon: 0.01);

Rect _streakRect(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byKey(sidebarRailKey),
    matching: find.byType(StreakPill),
  ),
);

Rect _faceRect(WidgetTester tester, Key button) {
  final Iterable<DecoratedBox> faces = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(button),
          matching: find.byType(DecoratedBox),
        ),
      )
      .where(
        (DecoratedBox box) => switch (box.decoration) {
          BoxDecoration(color: Color(), border: BoxBorder()) => true,
          _ => false,
        },
      );
  return tester.getRect(find.byWidget(faces.single));
}

List<double> _gapsBetween(List<Rect> stacked) => <double>[
  for (int index = 1; index < stacked.length; index += 1)
    stacked[index].top - stacked[index - 1].bottom,
];

List<BoxDecoration> _faceDecorations(WidgetTester tester, Finder box) =>
    <BoxDecoration>[
      for (final DecoratedBox face in tester.widgetList<DecoratedBox>(
        find.descendant(of: box, matching: find.byType(DecoratedBox)),
      ))
        if (face.decoration case final BoxDecoration decoration) decoration,
    ];

SidebarShell _shell({
  ShellDestination selected = ShellDestination.today,
  ValueChanged<ShellDestination>? onSelect,
  VoidCallback? onSound,
}) {
  return SidebarShell(
    destinations: ShellDestination.primary,
    selected: selected,
    onSelect: onSelect ?? (_) {},
    onSound: onSound ?? () {},
    streak: const SizedBox.shrink(),
    body: const SizedBox.shrink(),
  );
}

List<String> _recordWindowCalls(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (MethodCall call) async {
      calls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
  return calls;
}

(Rect, Rect) _windowButtonSlots(WidgetTester tester) {
  final Row strip = tester.widget<Row>(
    find
        .descendant(
          of: find.byKey(windowTitleBarKey),
          matching: find.byType(Row),
        )
        .first,
  );
  return (
    tester.getRect(find.byWidget(strip.children.first)),
    tester.getRect(find.byWidget(strip.children.last)),
  );
}

bool _isPaintedDot(Widget widget) {
  if (widget is! Container) {
    return false;
  }
  final Decoration? decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
}

void main() {
  group('SidebarShell', () {
    testWidgets('the titlebar paints no window buttons and keeps their slot', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appHarness(_shell()));

      final Rect bar = tester.getRect(find.byKey(windowTitleBarKey));
      expect(bar.top, 0);
      expect(bar.height, shellTitleBarHeight);
      final Rect slot = tester.getRect(
        find.byKey(const ValueKey<String>('traffic-lights')),
      );
      expect(slot.left, shellTitleBarPadding);
      expect(slot.width, windowButtonsSlotWidth);
      expect(
        find.descendant(
          of: find.byKey(windowTitleBarKey),
          matching: find.byWidgetPredicate(_isPaintedDot),
        ),
        findsNothing,
      );
      expect(
        tester.getCenter(find.text('field notes — a journal of days')).dx,
        640,
      );
    });

    testWidgets('the Windows title strip leaves room for the caption buttons', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final List<String> calls = _recordWindowCalls(tester);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          appHarness(_shell(), platform: TargetPlatform.windows),
        );

        final Rect bar = tester.getRect(find.byKey(windowTitleBarKey));
        expect(bar.top, 0);
        expect(bar.height, shellTitleBarHeight);
        final (Rect leading, Rect trailing) = _windowButtonSlots(tester);
        expect(
          tester.getRect(find.byKey(const ValueKey<String>('traffic-lights'))),
          leading,
        );
        expect(leading.width, 122);
        expect(trailing.width, 122);
        expect(leading.left, shellTitleBarPadding);
        expect(trailing.right, 1280 - shellTitleBarPadding);
        expect(trailing.left, 1280 - windowsCaptionButtonsWidth);
        expect(
          tester.getCenter(find.text('field notes — a journal of days')).dx,
          640,
        );

        await tester.drag(find.byKey(windowTitleBarKey), const Offset(60, 20));
        await tester.pumpAndSettle();

        expect(calls, <String>[startDragMethod]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      await tester.pumpWidget(appHarness(_shell()));
      await tester.pumpAndSettle();

      final (Rect leading, Rect trailing) = _windowButtonSlots(tester);
      expect(leading.width, 62);
      expect(trailing.width, 62);
      expect(
        tester.getCenter(find.text('field notes — a journal of days')).dx,
        640,
      );
    });

    testWidgets('dragging the titlebar starts a window drag', (
      WidgetTester tester,
    ) async {
      final List<String> calls = _recordWindowCalls(tester);
      await tester.pumpWidget(appHarness(_shell()));

      await tester.drag(find.byKey(windowTitleBarKey), const Offset(60, 20));
      await tester.pumpAndSettle();

      expect(calls, <String>[startDragMethod]);
    });

    testWidgets('double-clicking the titlebar runs the window double-click', (
      WidgetTester tester,
    ) async {
      final List<String> calls = _recordWindowCalls(tester);
      await tester.pumpWidget(appHarness(_shell()));

      await tester.tap(find.byKey(windowTitleBarKey));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(windowTitleBarKey));
      await tester.pumpAndSettle();

      expect(calls, <String>[titlebarDoubleClickMethod]);
    });

    testWidgets('a single click on the titlebar asks the window for nothing', (
      WidgetTester tester,
    ) async {
      final List<String> calls = _recordWindowCalls(tester);
      await tester.pumpWidget(appHarness(_shell()));

      await tester.tap(find.byKey(windowTitleBarKey));
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls, isEmpty);
    });

    testWidgets('reserves the window-button slot and renders every rail '
        'destination', (WidgetTester tester) async {
      await tester.pumpWidget(appHarness(_shell()));

      expect(
        find.byKey(const ValueKey<String>('traffic-lights')),
        findsOneWidget,
      );
      for (final ShellDestination d in ShellDestination.primary) {
        expect(find.byKey(ValueKey<String>('rail-${d.name}')), findsOneWidget);
      }
    });

    testWidgets('a rail item reports its destination on tap', (
      WidgetTester tester,
    ) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('rail-garden')));
      expect(picked, ShellDestination.garden);
    });

    testWidgets('the settings button selects the settings destination', (
      WidgetTester tester,
    ) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
      expect(picked, ShellDestination.settings);
    });

    testWidgets('the sound button invokes onSound', (
      WidgetTester tester,
    ) async {
      bool sounded = false;
      await tester.pumpWidget(
        appHarness(_shell(onSound: () => sounded = true)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('sound-button')));
      expect(sounded, isTrue);
    });

    testWidgets(
      'each rail item is a button that reports whether it is selected',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          appHarness(_shell(selected: ShellDestination.today)),
        );

        expect(
          tester.getSemantics(find.byKey(const ValueKey<String>('rail-today'))),
          isSemantics(
            label: 'Today',
            isButton: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey<String>('rail-garden')),
          ),
          isSemantics(
            label: 'Meadow',
            isButton: true,
            isSelected: false,
            hasTapAction: true,
          ),
        );

        handle.dispose();
      },
    );

    testWidgets('the settings button reports selected while Settings is open', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        appHarness(_shell(selected: ShellDestination.today)),
      );

      expect(
        tester.getSemantics(
          find.byKey(const ValueKey<String>('settings-button')),
        ),
        isSemantics(label: 'Settings', isButton: true, isSelected: false),
      );

      await tester.pumpWidget(
        appHarness(_shell(selected: ShellDestination.settings)),
      );

      expect(
        tester.getSemantics(
          find.byKey(const ValueKey<String>('settings-button')),
        ),
        isSemantics(label: 'Settings', isButton: true, isSelected: true),
      );

      handle.dispose();
    });

    testWidgets('the sync status is one box with no server address that opens '
        'Sync & storage', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final DateTime now = DateTime.now().toUtc();
      await pumpMacAppShell(
        tester,
        sync: syncOnOverrides(
          status: SyncedStatus(now.subtract(const Duration(minutes: 4))),
        ),
      );
      final Finder box = find.byKey(sidebarSyncStatusKey);

      expect(box, findsOneWidget);
      expect(find.textContaining('sync.example.com'), findsNothing);
      expect(
        tester.getSemantics(box),
        isSemantics(
          label: 'Synced · 4 min ago',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSize(box),
        const Size(shellSidebarOpenWidth - 24, sidebarSyncBoxMinHeight),
      );
      final FieldNotesColors colors = FieldNotesColors.light;
      const BorderRadius stickerRadius = BorderRadius.all(
        Radius.circular(Shapes.radiusIconButton),
      );
      final List<BoxDecoration> faces = _faceDecorations(tester, box);
      final BoxDecoration outline = faces.singleWhere(
        (BoxDecoration face) => face.border != null,
      );
      final BoxDecoration fill = faces.singleWhere(
        (BoxDecoration face) => face.color == colors.cardLight,
      );
      expect(outline.border, FieldNotesShadows(colors).outline);
      expect(outline.borderRadius, stickerRadius);
      expect(fill.borderRadius, stickerRadius);
      expect(
        tester.getSize(find.byKey(_settingsButton)),
        const Size.square(32),
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byKey(_settingsButton),
            matching: find.byType(IconStickerGlyphIcon),
          ),
        ),
        const Size.square(iconStickerGlyphExtent),
      );
      expect(find.text(syncNowLabel), findsNothing);

      await tester.tap(box);
      await tester.pumpAndSettle();

      expect(find.text(syncNowLabel), findsOneWidget);
      handle.dispose();
    }, variant: _macOS);

    testWidgets(
      'the collapsed rail sizes the status, settings and sound boxes 44 by 44',
      (WidgetTester tester) async {
        await pumpMacAppShell(
          tester,
          sync: syncOnOverrides(status: SyncedStatus(DateTime.now().toUtc())),
          collapsed: true,
        );

        expect(
          tester.getSize(find.byKey(sidebarRailKey)).width,
          shellSidebarCollapsedWidth,
        );
        for (final Key key in <Key>[
          sidebarSyncStatusKey,
          _settingsButton,
          _soundButton,
        ]) {
          expect(
            tester.getSize(find.byKey(key)),
            const Size.square(sidebarRailBoxExtent),
            reason: '$key',
          );
        }
        expect(
          tester.getSize(
            find.descendant(
              of: find.byKey(_soundButton),
              matching: find.byType(IconStickerGlyphIcon),
            ),
          ),
          const Size.square(18),
        );
      },
      variant: _macOS,
    );

    testWidgets('collapsed rail boxes are evenly spaced', (
      WidgetTester tester,
    ) async {
      await pumpMacAppShell(
        tester,
        sync: syncOnOverrides(status: SyncedStatus(DateTime.now().toUtc())),
        collapsed: true,
      );

      expect(
        _gapsBetween(<Rect>[
          _streakRect(tester),
          tester.getRect(find.byKey(sidebarSyncStatusKey)),
          _faceRect(tester, _settingsButton),
          _faceRect(tester, _soundButton),
        ]),
        <Matcher>[_boardGap, _boardGap, _boardGap],
      );

      await pumpMacAppShell(tester, sync: syncOffOverrides(), collapsed: true);

      expect(
        _gapsBetween(<Rect>[
          _streakRect(tester),
          _faceRect(tester, _settingsButton),
          _faceRect(tester, _soundButton),
        ]),
        <Matcher>[_boardGap, _boardGap],
      );
    }, variant: _macOS);

    testWidgets('expanded sidebar boxes are evenly spaced', (
      WidgetTester tester,
    ) async {
      await pumpMacAppShell(
        tester,
        sync: syncOnOverrides(status: SyncedStatus(DateTime.now().toUtc())),
      );

      expect(
        _gapsBetween(<Rect>[
          _streakRect(tester),
          tester.getRect(find.byKey(sidebarSyncStatusKey)),
          _faceRect(tester, _settingsButton),
        ]),
        <Matcher>[_boardGap, _boardGap],
      );
      expect(
        _faceRect(tester, _soundButton).top,
        _faceRect(tester, _settingsButton).top,
      );

      await pumpMacAppShell(tester, sync: syncOffOverrides());

      expect(
        _gapsBetween(<Rect>[
          _streakRect(tester),
          _faceRect(tester, _settingsButton),
        ]),
        <Matcher>[_boardGap],
      );
    }, variant: _macOS);
  });
}
