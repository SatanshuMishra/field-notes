import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/settings/support/fake_settings_repository.dart';
import '../support/sync_overrides.dart';
import 'support/app_shell_harness.dart';

const String _address = 'https://sync.example.com';

final TargetPlatformVariant _macOS = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

Future<void> _pumpMac(
  WidgetTester tester, {
  required List<Override> sync,
  bool collapsed = false,
}) async {
  final Set<Object?> replaced = <Object?>{
    settingsRepositoryProvider,
    for (final Override override in sync) override.origin,
  };
  tester.view.physicalSize = const Size(1280, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (!replaced.contains(override.origin)) override,
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(
            initial: AppSettings.defaults.copyWith(sidebarCollapsed: collapsed),
          ),
        ),
        ...sync,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _streak(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byKey(sidebarRailKey),
    matching: find.byType(StreakPill),
  ),
);

void main() {
  testWidgets(
    'the sidebar shows the sync status under the streak only while sync is on',
    (WidgetTester tester) async {
      final DateTime now = DateTime.now().toUtc();
      final SyncedStatus status = SyncedStatus(now);
      final String label = status.label(now);
      await _pumpMac(tester, sync: syncOnOverrides(status: status));

      final Finder line = find.byKey(sidebarSyncLineKey);
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: line, matching: find.text(_address)),
        findsOneWidget,
      );
      final Rect streak = _streak(tester);
      final Rect statusLine = tester.getRect(find.text(label));
      final Rect addressLine = tester.getRect(find.text(_address));
      expect(statusLine.top, greaterThanOrEqualTo(streak.bottom));
      expect(addressLine.top, greaterThanOrEqualTo(statusLine.bottom));
      expect(find.byKey(sidebarSyncDotKey), findsNothing);

      await _pumpMac(tester, sync: syncOffOverrides());

      expect(find.byKey(sidebarSyncLineKey), findsNothing);
      expect(find.byKey(sidebarSyncDotKey), findsNothing);
      expect(find.text(_address), findsNothing);
      expect(find.textContaining('Synced'), findsNothing);

      await _pumpMac(tester, sync: syncOffOverrides(), collapsed: true);

      expect(find.byKey(sidebarSyncDotKey), findsNothing);
      expect(find.byKey(sidebarSyncLineKey), findsNothing);
    },
    variant: _macOS,
  );

  testWidgets('the collapsed rail shows a status dot', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final FieldNotesColors colors = FieldNotesColors.light;
    final DateTime now = DateTime.now().toUtc();
    final List<(SyncStatus, Color)> cases = <(SyncStatus, Color)>[
      (SyncedStatus(now), colors.sage),
      (const WaitingStatus(2), colors.accentInk),
      (const UploadingStatus(1), colors.accentInk),
      (const AttentionStatus(AttentionReason.unreachable), colors.dangerInk),
      (const OfflineStatus(), colors.muted),
      (const PausedStatus(), colors.muted),
    ];
    for (final (SyncStatus status, Color tone) in cases) {
      final String label = status.label(now);
      await _pumpMac(
        tester,
        sync: syncOnOverrides(status: status),
        collapsed: true,
      );

      final Finder dot = find.byKey(sidebarSyncDotKey);
      expect(dot, findsOneWidget, reason: label);
      expect(tester.widget<Tooltip>(dot).message, label, reason: label);
      final BoxDecoration fill =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: dot,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(fill.color!.toARGB32(), tone.toARGB32(), reason: label);
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      expect(
        tester.getRect(dot).top,
        greaterThanOrEqualTo(_streak(tester).bottom),
        reason: label,
      );
      expect(find.text(label), findsNothing, reason: label);
      expect(find.byKey(sidebarSyncLineKey), findsNothing, reason: label);
    }
    semantics.dispose();
  }, variant: _macOS);
}
