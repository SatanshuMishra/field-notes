import 'dart:math';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/features/sync/ui/recovery_phrase_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';

const String _mismatch = "That word doesn't match. Check your phrase.";

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.android},
);

Finder _field(int position) => find.ancestor(
  of: find.text(recoveryCheckLabel(position)),
  matching: find.byType(Column),
);

Finder _editable(int position) => find
    .descendant(of: _field(position).first, matching: find.byType(EditableText))
    .first;

void main() {
  testWidgets('sync stays off until the two words match', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final PendingEnrolment enrolment = (await tester.runAsync(
      () => stubRelayEnrolment(database, random: Random(7)).start(
        relayUrl: Uri.parse('https://sync.example.com'),
        inviteCode: 'invite-1',
      ),
    ))!;
    Future<String?> syncEnabled() => tester.runAsync<String?>(
      () => readSyncState(database, SyncStateKeys.syncEnabled),
    );
    int confirmed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecoveryPhraseCheck(
            enrolment: enrolment,
            onBack: () {},
            onConfirmed: () => confirmed++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final List<int> positions = enrolment.positions;
    expect(positions, hasLength(2));
    expect(find.text(checkPhraseTitle), findsOneWidget);
    expect(find.text(checkPhraseMessage), findsOneWidget);
    for (final int position in positions) {
      expect(find.text(recoveryCheckLabel(position)), findsOneWidget);
    }
    final String first = enrolment.words[positions.first - 1];
    final String second = enrolment.words[positions.last - 1];
    final String wrong = enrolment.words.firstWhere(
      (String word) => word != first,
    );

    await tester.enterText(_editable(positions.first), wrong);
    await tester.enterText(_editable(positions.last), second);
    await tester.pump();
    await tester.tap(find.byKey(turnOnSyncKey));
    await tester.pumpAndSettle();

    expect(find.text(_mismatch), findsOneWidget);
    expect(confirmed, 0);
    expect(await syncEnabled(), isNull);

    await tester.enterText(
      _editable(positions.first),
      '  ${first.toUpperCase()} ',
    );
    await tester.pump();
    expect(find.text(_mismatch), findsNothing);
    await tester.tap(find.byKey(turnOnSyncKey));
    await tester.pumpAndSettle();

    expect(find.text(_mismatch), findsNothing);
    expect(confirmed, 1);
    expect(await syncEnabled(), syncEnabledValue);
  }, variant: _bothPlatforms);
}
