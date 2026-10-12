import 'package:field_notes/app/app.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/ui/update_rail_chip.dart';
import 'package:field_notes/features/updates/ui/update_restart_splash.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/update_overrides.dart';
import 'support/app_shell_harness.dart';

final ReleaseInfo _release = ReleaseInfo(
  version: AppVersion.tryParse('2.4.0')!,
  tag: 'v2.4.0',
  publishedAt: DateTime(2026, 7, 18, 12),
  notes: ReleaseNotes(
    intro: 'Settings are easier to find.',
    groups: const <ReleaseNoteGroup>[],
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
  ],
);

final class _Restarting extends UpdateController {
  int installs = 0;

  @override
  UpdateStatus build() => UpdateAvailable(_release, updateQuietNow);

  @override
  Future<void> check() async {}

  @override
  Future<void> install() async {
    installs++;
    state = UpdateRestarting(_release);
  }
}

final class _FailingRestart extends UpdateController {
  int installs = 0;

  @override
  UpdateStatus build() => UpdateAvailable(_release, updateQuietNow);

  @override
  Future<void> check() async {}

  @override
  Future<void> install() async {
    installs++;
    state = UpdateRestarting(_release);
  }

  void fail() {
    state = UpdateAvailable(
      _release,
      updateQuietNow,
      lastFailure: InstallFailure.installer,
    );
  }
}

bool _reaches(WidgetTester tester, Offset position, Finder target) {
  final RenderObject object = tester.renderObject(target);
  final HitTestResult result = tester.hitTestOnBinding(position);
  return result.path.any(
    (HitTestEntry entry) => identical(entry.target, object),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'the restart splash covers an open notes panel and takes every input',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1140, 726);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _Restarting updates = _Restarting();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ...shellOverrides(),
            installedAppProvider.overrideWith(
              (Ref ref) async => const InstalledApp(version: '1.4.2'),
            ),
            updateControllerProvider.overrideWith(() => updates),
            updateRouteProvider.overrideWith(
              (Ref ref) async => InstallRoute.restartInPlace,
            ),
          ],
          child: const FieldNotesApp(),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byKey(updateRailChipKey));
      await _settle(tester);
      expect(find.byKey(updateNotesPanelKey), findsOneWidget);
      final Offset action = tester.getCenter(find.byKey(updateNotesActionKey));
      await tester.tapAt(action);
      await _settle(tester);
      expect(updates.installs, 1);

      final Finder splash = find.byKey(updateRestartSplashKey);
      expect(splash, findsOneWidget);
      final Offset middle = tester.getCenter(splash);
      expect(
        _reaches(tester, middle, find.byType(UpdateRestartSplash)),
        isTrue,
      );
      if (find.byKey(updateNotesPanelKey).evaluate().isNotEmpty) {
        expect(
          _reaches(tester, middle, find.byKey(updateNotesPanelKey)),
          isFalse,
        );
        expect(
          _reaches(tester, action, find.byKey(updateNotesActionKey)),
          isFalse,
        );
      }
      expect(
        find.bySemanticsLabel(RegExp('Restarting Field Notes')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Update & restart'), findsNothing);
      await tester.tapAt(action);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(updates.installs, 1);
      handle.dispose();
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'a failed restart gives the notes panel back its Return and Esc keys',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1140, 726);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _FailingRestart updates = _FailingRestart();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ...shellOverrides(),
            installedAppProvider.overrideWith(
              (Ref ref) async => const InstalledApp(version: '1.4.2'),
            ),
            updateControllerProvider.overrideWith(() => updates),
            updateRouteProvider.overrideWith(
              (Ref ref) async => InstallRoute.restartInPlace,
            ),
          ],
          child: const FieldNotesApp(),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byKey(updateRailChipKey));
      await _settle(tester);
      await tester.tap(find.byKey(updateNotesActionKey));
      await _settle(tester);
      expect(updates.installs, 1);
      expect(find.byKey(updateRestartSplashKey), findsOneWidget);

      updates.fail();
      await _settle(tester);
      expect(find.byKey(updateRestartSplashKey), findsNothing);
      expect(find.byKey(updateNotesPanelKey), findsOneWidget);
      expect(
        find.text(installFailureText(InstallFailure.installer)),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(updates.installs, 2, reason: 'Return retries the update');
      expect(find.byKey(updateRestartSplashKey), findsOneWidget);

      updates.fail();
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(
        find.byKey(updateNotesPanelKey),
        findsNothing,
        reason: 'Esc closes the panel',
      );
      expect(updates.installs, 2);
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );
}
