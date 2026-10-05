import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.android},
);

JournalDevice _device(
  String id,
  String name, {
  required bool thisDevice,
  Duration seen = Duration.zero,
}) {
  final DateTime now = DateTime.now().toUtc();
  return JournalDevice(
    deviceId: id,
    name: name,
    createdAt: now.subtract(const Duration(days: 9)),
    lastSeenAt: now.subtract(seen),
    isThisDevice: thisDevice,
  );
}

Future<void> _pumpList(WidgetTester tester, List<JournalDevice> devices) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ...syncOnOverrides(
          status: SyncedStatus(DateTime.now().toUtc()),
          devices: devices,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DeviceList(onFeedback: (String _) {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the last device offers delete everywhere instead of remove', (
    WidgetTester tester,
  ) async {
    await _pumpList(tester, <JournalDevice>[
      _device('this', 'Field phone', thisDevice: true),
      _device(
        'other',
        'Studio Mac',
        thisDevice: false,
        seen: const Duration(days: 2),
      ),
    ]);

    expect(find.text('Field phone'), findsOneWidget);
    expect(find.text('Studio Mac'), findsOneWidget);
    expect(find.text('Last seen 2 days ago'), findsOneWidget);
    expect(find.widgetWithText(StickerButton, 'Remove'), findsNWidgets(2));
    expect(find.text('Delete journal everywhere'), findsNothing);

    await _pumpList(tester, <JournalDevice>[
      _device('this', 'Field phone', thisDevice: true),
    ]);

    expect(find.text('Field phone'), findsOneWidget);
    expect(
      find.text(
        defaultTargetPlatform == TargetPlatform.android
            ? 'This phone'
            : 'This Mac',
      ),
      findsOneWidget,
    );
    expect(find.text('Remove'), findsNothing);
    final Finder deleteEverywhere = find.widgetWithText(
      StickerButton,
      'Delete journal everywhere',
    );
    expect(deleteEverywhere, findsOneWidget);

    await tester.tap(deleteEverywhere);
    await tester.pumpAndSettle();

    expect(find.byType(SyncDeleteAllDialog), findsOneWidget);
    expect(find.text('Delete your journal'), findsOneWidget);
    expect(find.text(removeFromThisDeviceMessage), findsOneWidget);
    expect(find.text(deleteJournalEverywhereMessage), findsOneWidget);
  }, variant: _bothPlatforms);
}
