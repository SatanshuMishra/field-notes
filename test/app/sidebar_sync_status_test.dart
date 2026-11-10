import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/sync_overrides.dart';
import 'support/mac_app_shell.dart';

const String _address = 'https://sync.example.com';

final TargetPlatformVariant _macOS = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final Finder _box = find.byKey(sidebarSyncStatusKey);

Rect _streak(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byKey(sidebarRailKey),
    matching: find.byType(StreakPill),
  ),
);

Color _dotColour(WidgetTester tester) {
  final DecoratedBox dot = tester.widget<DecoratedBox>(
    find.descendant(of: _box, matching: find.byKey(sidebarSyncDotKey)),
  );
  return (dot.decoration as BoxDecoration).color!;
}

typedef _Case = ({SyncStatus status, String words, Color? dot});

List<_Case> _cases(DateTime now, FieldNotesColors colors) => <_Case>[
  (status: const SyncingStatus(), words: 'Syncing…', dot: null),
  (
    status: SyncedStatus(now.subtract(const Duration(minutes: 4))),
    words: 'Synced · 4 min ago',
    dot: colors.sage,
  ),
  (
    status: const OfflineStatus(),
    words: 'Offline · will sync later',
    dot: colors.muted,
  ),
  (status: const PausedStatus(), words: 'Sync paused', dot: colors.muted),
  (
    status: const AttentionStatus(AttentionReason.unreachable),
    words: "Can't reach server",
    dot: colors.dangerInk,
  ),
  (
    status: const NotSyncedYetStatus(),
    words: 'Not synced yet',
    dot: colors.muted,
  ),
];

void main() {
  testWidgets(
    'the sidebar boxes the sync status under the streak only while sync is on',
    (WidgetTester tester) async {
      final DateTime now = DateTime.now().toUtc();
      await pumpMacAppShell(
        tester,
        sync: syncOnOverrides(
          status: SyncedStatus(now.subtract(const Duration(minutes: 4))),
        ),
      );

      expect(_box, findsOneWidget);
      expect(
        find.descendant(of: _box, matching: find.text('Synced · 4 min ago')),
        findsOneWidget,
      );
      expect(find.text(_address), findsNothing);
      expect(find.textContaining('sync.example.com'), findsNothing);
      final Rect box = tester.getRect(_box);
      expect(box.top, greaterThanOrEqualTo(_streak(tester).bottom));
      expect(
        box.bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const ValueKey<String>('settings-button')))
              .top,
        ),
      );

      await pumpMacAppShell(tester, sync: syncOffOverrides());

      expect(_box, findsNothing);
      expect(find.textContaining('Synced'), findsNothing);

      await pumpMacAppShell(tester, sync: syncOffOverrides(), collapsed: true);

      expect(_box, findsNothing);
    },
    variant: _macOS,
  );

  testWidgets('each status shows its words and its mark in the box', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    for (final _Case each in _cases(now, FieldNotesColors.light)) {
      await pumpMacAppShell(
        tester,
        sync: syncOnOverrides(status: each.status),
        settle: each.dot != null,
      );

      expect(
        find.descendant(of: _box, matching: find.text(each.words)),
        findsOneWidget,
        reason: each.words,
      );
      final Color? dot = each.dot;
      if (dot == null) {
        expect(
          find.descendant(
            of: _box,
            matching: find.byKey(sidebarSyncSpinnerKey),
          ),
          findsOneWidget,
          reason: each.words,
        );
        expect(find.byKey(sidebarSyncDotKey), findsNothing, reason: each.words);
      } else {
        expect(
          _dotColour(tester).toARGB32(),
          dot.toARGB32(),
          reason: each.words,
        );
        expect(
          find.byKey(sidebarSyncSpinnerKey),
          findsNothing,
          reason: each.words,
        );
      }
    }
  }, variant: _macOS);

  testWidgets('the collapsed rail keeps the words in a tooltip and semantics', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final DateTime now = DateTime.now().toUtc();
    for (final _Case each in _cases(now, FieldNotesColors.light)) {
      await pumpMacAppShell(
        tester,
        sync: syncOnOverrides(status: each.status),
        collapsed: true,
        settle: each.dot != null,
      );

      expect(_box, findsOneWidget, reason: each.words);
      expect(find.text(each.words), findsNothing, reason: each.words);
      expect(
        tester
            .widget<Tooltip>(
              find.descendant(of: _box, matching: find.byType(Tooltip)),
            )
            .message,
        each.words,
        reason: each.words,
      );
      expect(
        tester.getSemantics(_box),
        isSemantics(label: each.words, isButton: true, hasTapAction: true),
        reason: each.words,
      );
      expect(
        find.descendant(
          of: _box,
          matching: find.byKey(
            each.dot == null ? sidebarSyncSpinnerKey : sidebarSyncDotKey,
          ),
        ),
        findsOneWidget,
        reason: each.words,
      );
      expect(
        tester.getRect(_box).top,
        greaterThanOrEqualTo(_streak(tester).bottom),
        reason: each.words,
      );
    }
    semantics.dispose();
  }, variant: _macOS);
}
