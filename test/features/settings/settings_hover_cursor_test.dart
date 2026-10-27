import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraDescription, CameraPlatform;
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/updates/bundled_changelog.dart';
import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/settings/sections/about_section.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/widgets/reminder_time_sheet.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/sync/ui/join_scan_page.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/features/sync/ui/sync_flow_page.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/ui/update_rail_chip.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sync_overrides.dart';
import '../../support/update_overrides.dart';
import 'support/fake_settings_repository.dart';

const int _mousePointerId = 47;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _white = Color(0xFFFFFFFF);
const Color _coral = Color(0xFFB8566A);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _lightPill = _coral.withValues(alpha: 0.08).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();
final int _railChipHover = _coral.withValues(alpha: 0.16).toARGB32();

const Size _desktop = Size(1440, 900);
const Size _phone = Size(384, 832);
const String _openNew = 'open new notes';
const String _openInstalled = 'open installed notes';

final DateTime _now = updateQuietNow;

final ReleaseInfo _release = ReleaseInfo(
  version: AppVersion.tryParse('2.4.0')!,
  tag: 'v2.4.0',
  publishedAt: DateTime(2026, 7, 18, 12),
  notes: ReleaseNotes(
    intro: 'Settings are easier to find.',
    groups: <ReleaseNoteGroup>[
      ReleaseNoteGroup(title: 'New', items: <String>['An About page.']),
    ],
  ),
  pageUrl: Uri.parse(
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v2.4.0',
  ),
  assets: <ReleaseAsset>[
    ReleaseAsset(
      name: 'field-notes-2.4.0-macos.dmg',
      url: Uri.parse('https://github.com/a/field-notes-2.4.0-macos.dmg'),
      size: 38000000,
    ),
    ReleaseAsset(
      name: 'field-notes-2.4.0-android.apk',
      url: Uri.parse('https://github.com/a/field-notes-2.4.0-android.apk'),
      size: 41000000,
    ),
  ],
);

final class _FixedUpdates extends UpdateController {
  _FixedUpdates(this._initial);

  final UpdateStatus _initial;

  @override
  UpdateStatus build() => _initial;

  @override
  Future<void> check() async {}

  @override
  Future<void> install() async {}
}

final class _NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[];
}

enum _Shape { circle, rounded }

class _Row {
  const _Row(
    this.label,
    this.control,
    this.fill,
    this.shape, {
    this.radius,
    this.labelSource,
  });

  final String label;
  final Finder control;
  final int fill;
  final _Shape shape;
  final double? radius;
  final Finder? labelSource;
}

Finder _pressable(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Pressable && widget.label == label,
);

Finder _pressableAround(Finder inner) => find
    .ancestor(of: inner, matching: find.byType(Pressable), matchRoot: true)
    .first;

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matchRoot: true,
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

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

void _view(WidgetTester tester, Size size) {
  final bool phone = size == _phone;
  final FakeViewPadding bars = phone
      ? const FakeViewPadding(top: 34, bottom: 24)
      : FakeViewPadding.zero;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = bars;
  tester.view.viewPadding = bars;
  addTearDown(tester.view.reset);
}

List<Override> _updateOverrides(UpdateStatus status) => <Override>[
  settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  ...updateQuietOverrides(),
  installedAppProvider.overrideWith(
    (Ref ref) async => const InstalledApp(version: '1.4.2'),
  ),
  updateControllerProvider.overrideWith(() => _FixedUpdates(status)),
  updateRouteProvider.overrideWith(
    (Ref ref) async => InstallRoute.restartInPlace,
  ),
  installedReleaseNotesProvider.overrideWith(
    (Ref ref) async => ChangelogSection(
      notes: ReleaseNotes(
        intro: 'The first release.',
        groups: const <ReleaseNoteGroup>[],
      ),
      date: DateTime(2026, 7, 1, 12),
    ),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Widget child,
  List<Override> overrides = const <Override>[],
}) async {
  _view(tester, platform == TargetPlatform.android ? _phone : _desktop);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUpdateHost(
  WidgetTester tester, {
  required TargetPlatform platform,
  required String open,
}) async {
  await _pump(
    tester,
    platform: platform,
    overrides: _updateOverrides(UpdateAvailable(_release, _now)),
    child: Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) => Column(
        children: <Widget>[
          TextButton(
            onPressed: () => showUpdateNotes(context, ref, newVersion: true),
            child: const Text(_openNew),
          ),
          TextButton(
            onPressed: () => showUpdateNotes(context, ref, newVersion: false),
            child: const Text(_openInstalled),
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text(open));
  await tester.pumpAndSettle();
}

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(row.control, findsOneWidget, reason: row.label);
    await tester.ensureVisible(row.control);
    await tester.pumpAndSettle();
    expect(_hoverFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(row), findsOneWidget, reason: row.label);
    final SemanticsNode node = tester.getSemantics(
      row.labelSource ?? row.control,
    );
    expect(node, isSemantics(isButton: true), reason: row.label);
    expect(node.label, row.label, reason: row.label);
  }
  await mouse.moveTo(Offset.zero);
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets(
    "every settings, sync and update control, including the update modal's "
    'buttons, shows the click cursor, hover and a label',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final CameraPlatform cameras = CameraPlatform.instance;
      CameraPlatform.instance = _NoCameras();
      addTearDown(() => CameraPlatform.instance = cameras);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: _mousePointerId,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        overrides: _updateOverrides(UpdateCurrent(_now)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 60, 14, 60),
          child: AboutSection(onFeedback: (String message) {}),
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Check for updates',
          _pressable('Check for updates'),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'Release notes',
          _pressable('Release notes'),
          _lightRow,
          _Shape.rounded,
          radius: 11,
        ),
        _Row(
          'Website',
          _pressable('Website'),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'GitHub',
          _pressable('GitHub'),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        overrides: _updateOverrides(UpdateAvailable(_release, _now)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 60, 14, 60),
          child: AboutSection(onFeedback: (String message) {}),
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Update to 2.4.0…',
          _pressable('Update to 2.4.0…'),
          _dark,
          _Shape.rounded,
          radius: 14,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        child: Center(
          child: ReminderTimeSheet(
            initial: const TimeOfDay(hour: 9, minute: 0),
            onDone: (TimeOfDay time) {},
          ),
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Hour up',
          _pressable('Hour up'),
          _lightRow,
          _Shape.rounded,
          radius: 8,
        ),
        _Row(
          'Hour down',
          _pressable('Hour down'),
          _lightRow,
          _Shape.rounded,
          radius: 8,
        ),
        _Row(
          'Minute up',
          _pressable('Minute up'),
          _lightRow,
          _Shape.rounded,
          radius: 8,
        ),
        _Row(
          'Minute down',
          _pressable('Minute down'),
          _lightRow,
          _Shape.rounded,
          radius: 8,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        overrides: <Override>[
          ..._updateOverrides(UpdateAvailable(_release, _now)),
          ...syncOffOverrides(),
        ],
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SettingsSectionList(onOpen: (SettingsTab tab) {}),
              SettingsBackPill(label: 'Settings', onPressed: () {}),
            ],
          ),
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Update available: 2.4.0',
          _pressable('Update available: 2.4.0'),
          _lightRow,
          _Shape.rounded,
          radius: 16,
        ),
        _Row(
          'Journal',
          _pressable('Journal'),
          _lightRow,
          _Shape.rounded,
          radius: 11,
        ),
        _Row(
          'Back to Settings',
          _pressable('Back to Settings'),
          _lightPill,
          _Shape.rounded,
          radius: 24,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.macOS,
        child: Center(
          child: SettingsTabRail(
            selected: SettingsTab.journal,
            onSelected: (SettingsTab tab) {},
          ),
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Sync & storage',
          _pressable('Sync & storage'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row('Data', _pressable('Data'), _lightRow, _Shape.rounded, radius: 12),
        _Row(
          'About',
          _pressable('About'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.macOS,
        child: Center(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SyncActionRow(
                  label: 'Restore from a backup',
                  description: 'Bring back a journal you saved.',
                  onPressed: () {},
                ),
                const SizedBox(height: 24),
                SyncFlowButton(
                  action: SyncFlowAction(label: 'Not now', onPressed: () {}),
                ),
                const SizedBox(height: 24),
                SyncFlowButton(
                  action: SyncFlowAction(
                    label: 'Continue',
                    primary: true,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 24),
                SyncFlowButton(
                  action: SyncFlowAction(
                    label: 'Remove',
                    danger: true,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Restore from a backup',
          _pressable('Restore from a backup'),
          _lightRow,
          _Shape.rounded,
          radius: 11,
        ),
        _Row(
          'Not now',
          _pressable('Not now'),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'Continue',
          _pressable('Continue'),
          _dark,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'Remove',
          _pressable('Remove'),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        child: SyncFlowPage(
          title: 'Start syncing',
          actions: <SyncFlowAction>[
            SyncFlowAction(label: 'Continue', primary: true, onPressed: () {}),
          ],
          onClose: () {},
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row('Close', _pressable('Close'), _lightRow, _Shape.circle),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.android,
        child: JoinScanPage(
          onScan: (_) {},
          onCancel: () {},
          onTypeWords: () {},
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Cancel',
          _pressableAround(
            find.descendant(
              of: find.byType(JoinScanPage),
              matching: find.text('Cancel'),
            ),
          ),
          _dark,
          _Shape.rounded,
          radius: 11,
          labelSource: find.byWidgetPredicate(
            (Widget widget) =>
                widget is GlassCircleButton && widget.label == 'Cancel',
          ),
        ),
        _Row(
          'Type the 8 words instead',
          _pressable('Type the 8 words instead'),
          _dark,
          _Shape.rounded,
          radius: 24,
        ),
      ]);

      await _pumpUpdateHost(
        tester,
        platform: TargetPlatform.macOS,
        open: _openNew,
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row('Close', _pressable('Close'), _lightRow, _Shape.circle),
        _Row(
          'Later',
          _pressable('Later'),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Update & restart',
          _pressable('Update & restart'),
          _dark,
          _Shape.rounded,
          radius: 12,
        ),
      ]);

      await _pumpUpdateHost(
        tester,
        platform: TargetPlatform.android,
        open: _openNew,
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Update & restart',
          _pressable('Update & restart'),
          _dark,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'Later',
          _pressable('Later'),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
      ]);

      await _pumpUpdateHost(
        tester,
        platform: TargetPlatform.android,
        open: _openInstalled,
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Close',
          _pressable('Close'),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
      ]);

      await _pump(
        tester,
        platform: TargetPlatform.macOS,
        overrides: _updateOverrides(UpdateAvailable(_release, _now)),
        child: const Center(
          child: SizedBox(width: 220, child: UpdateRailChip(collapsed: false)),
        ),
      );
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Update available, version 2.4.0',
          _pressable('Update available, version 2.4.0'),
          _railChipHover,
          _Shape.rounded,
          radius: 12,
        ),
      ]);

      semantics.dispose();
    },
  );
}
