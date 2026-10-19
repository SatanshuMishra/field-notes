import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const int _mousePointerId = 47;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();
const int _sidebarToggleWash = 0x144A3B2E;
final int _appearanceWash = _ink.withValues(alpha: 0.08).toARGB32();
final int _captionHover = _black.withValues(alpha: 0.0373).toARGB32();
const int _closeRed = 0xFFC42B1C;

const Size _desktop = Size(1280, 800);
const Size _phone = Size(360, 740);

enum _Shape { circle, rounded }

class _Row {
  const _Row(this.label, this.control, this.fill, this.shape, {this.radius});

  final String label;
  final Finder control;
  final int fill;
  final _Shape shape;
  final double? radius;
}

class _CaptionRow {
  const _CaptionRow(this.label, this.key, this.fill);

  final String label;
  final Key key;
  final int fill;
}

Finder _pressable(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Pressable && widget.label == label,
);

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    if (decoration is! BoxDecoration ||
        decoration.color?.toARGB32() != row.fill) {
      return false;
    }
    return switch (row.shape) {
      _Shape.circle => decoration.shape == BoxShape.circle,
      _Shape.rounded =>
        decoration.borderRadius == BorderRadius.circular(row.radius!),
    };
  }),
);

Finder _captionFill(_CaptionRow row) => find.descendant(
  of: find.byKey(row.key),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is ColoredBox && widget.color.toARGB32() == row.fill,
  ),
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _quietWindowChannel(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (MethodCall call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Widget child,
}) async {
  _view(tester, platform == TargetPlatform.android ? _phone : _desktop);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        streakSummaryProvider.overrideWithValue(
          const StreakSummary(current: 3, longest: 3),
        ),
        appearanceProvider.overrideWithValue(Appearance.light),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

BottomBarShell _bottomBar(ShellDestination selected) => BottomBarShell(
  destinations: ShellDestination.primary,
  selected: selected,
  onSelect: (ShellDestination _) {},
  onCapture: () {},
  body: const SizedBox.shrink(),
);

SidebarShell _sidebar({required bool collapsed}) => SidebarShell(
  destinations: ShellDestination.primary,
  selected: ShellDestination.today,
  onSelect: (ShellDestination _) {},
  onSound: () {},
  streak: const SizedBox.shrink(),
  collapsed: collapsed,
  onCollapsedChanged: (bool _) {},
  body: const SizedBox.shrink(),
);

Future<void> _rest(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(Offset.zero);
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    await _rest(tester, mouse);
    expect(row.control, findsOneWidget, reason: row.label);
    expect(_hoverFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(row), findsOneWidget, reason: row.label);
    final SemanticsNode node = tester.getSemantics(row.control);
    expect(node, isSemantics(isButton: true), reason: row.label);
    expect(node.label, row.label, reason: row.label);
  }
  await _rest(tester, mouse);
}

Future<void> _expectCaptionRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_CaptionRow> rows,
) async {
  for (final _CaptionRow row in rows) {
    await _rest(tester, mouse);
    expect(find.byKey(row.key), findsOneWidget, reason: row.label);
    expect(_captionFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(find.byKey(row.key)));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.basic, reason: row.label);
    expect(_captionFill(row), findsOneWidget, reason: row.label);
    final SemanticsNode node = tester.getSemantics(find.byKey(row.key));
    expect(node, isSemantics(isButton: true), reason: row.label);
    expect(node.label, row.label, reason: row.label);
  }
  await _rest(tester, mouse);
}

void main() {
  testWidgets(
    'every shell control shows the click cursor and hover while the Windows '
    'title-bar buttons keep the default cursor',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      _quietWindowChannel(tester);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: _mousePointerId,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        child: _bottomBar(ShellDestination.today),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Settings',
          _pressable('Settings'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Today',
          _pressable('Today'),
          _lightRow,
          _Shape.rounded,
          radius: 26,
        ),
        _Row(
          'Calendar',
          _pressable('Calendar'),
          _lightRow,
          _Shape.rounded,
          radius: 26,
        ),
        _Row(
          'New entry',
          _pressable('New entry'),
          _dark,
          _Shape.rounded,
          radius: 23,
        ),
        _Row(
          'Meadow',
          _pressable('Meadow'),
          _lightRow,
          _Shape.rounded,
          radius: 26,
        ),
        _Row(
          'Search',
          _pressable('Search'),
          _lightRow,
          _Shape.rounded,
          radius: 26,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        child: _bottomBar(ShellDestination.garden),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Settings',
          _pressable('Settings'),
          _dark,
          _Shape.rounded,
          radius: 12,
        ),
        _Row('Today', _pressable('Today'), _dark, _Shape.rounded, radius: 26),
        _Row(
          'Calendar',
          _pressable('Calendar'),
          _dark,
          _Shape.rounded,
          radius: 26,
        ),
        _Row(
          'New entry',
          _pressable('New entry'),
          _dark,
          _Shape.rounded,
          radius: 23,
        ),
        _Row('Meadow', _pressable('Meadow'), _dark, _Shape.rounded, radius: 26),
        _Row('Search', _pressable('Search'), _dark, _Shape.rounded, radius: 26),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.macOS,
        child: _sidebar(collapsed: false),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Collapse sidebar (⌘\\)',
          _pressable('Collapse sidebar (⌘\\)'),
          _sidebarToggleWash,
          _Shape.circle,
        ),
        _Row('Today', _pressable('Today'), _dark, _Shape.rounded, radius: 12),
        _Row(
          'Calendar',
          _pressable('Calendar'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Meadow',
          _pressable('Meadow'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Search',
          _pressable('Search'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Settings',
          _pressable('Settings'),
          _lightRow,
          _Shape.rounded,
          radius: 8,
        ),
        _Row(
          'Sound effects on',
          _pressable('Sound effects on'),
          _lightRow,
          _Shape.rounded,
          radius: 8,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.macOS,
        child: _sidebar(collapsed: true),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Expand sidebar (⌘\\)',
          _pressable('Expand sidebar (⌘\\)'),
          _sidebarToggleWash,
          _Shape.circle,
        ),
        _Row('Today', _pressable('Today'), _dark, _Shape.rounded, radius: 12),
        _Row(
          'Calendar',
          _pressable('Calendar'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Meadow',
          _pressable('Meadow'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Search',
          _pressable('Search'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.macOS,
        child: const Scaffold(body: Center(child: AppearanceToggle())),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Switch to dark',
          _pressable('Switch to dark'),
          _appearanceWash,
          _Shape.rounded,
          radius: 9,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        child: const Scaffold(body: Center(child: AppearanceToggle())),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Switch to dark',
          _pressable('Switch to dark'),
          _appearanceWash,
          _Shape.rounded,
          radius: 15,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.windows,
        child: const Scaffold(body: Center(child: WindowsCaptionButtons())),
      );
      await _expectCaptionRows(tester, mouse, <_CaptionRow>[
        _CaptionRow('Minimize', windowsMinimizeButtonKey, _captionHover),
        _CaptionRow('Maximize', windowsMaximizeButtonKey, _captionHover),
        _CaptionRow('Close', windowsCloseButtonKey, _closeRed),
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      semantics.dispose();
    },
  );
}
