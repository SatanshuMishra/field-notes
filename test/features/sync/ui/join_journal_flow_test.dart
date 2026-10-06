import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/sync/ui/join_journal_flow.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class _NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[];
}

Future<void> _pumpFlow(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: JoinJournalFlow())),
    ),
  );
  await tester.pump();
}

void main() {
  test('only a pairing code is taken from what the scanner reads', () {
    expect(
      pairingCodeIn(<String?>[
        null,
        'https://example.com',
        '  FieldNotes-Pair:abc  ',
      ]),
      '  FieldNotes-Pair:abc  ',
    );
    expect(pairingCodeIn(<String?>['fieldnotes-pairing:abc', null]), isNull);
    expect(pairingCodeIn(const <String?>[]), isNull);
  });

  testWidgets('a phone scans the code with the on-device reader', (
    WidgetTester tester,
  ) async {
    final CameraPlatform original = CameraPlatform.instance;
    CameraPlatform.instance = _NoCameras();
    addTearDown(() => CameraPlatform.instance = original);

    await _pumpFlow(tester);

    expect(find.byType(ReaderWidget), findsOneWidget);
    expect(find.text(typeWordsInsteadLabel), findsOneWidget);

    await tester.tap(find.byKey(typeWordsInsteadKey));
    await tester.pump();

    expect(find.byType(ReaderWidget), findsNothing);
    expect(find.text(joinWordsLabel), findsOneWidget);
    expect(find.text(joinBackLabel), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Mac joins by typing the 8 words', (WidgetTester tester) async {
    await _pumpFlow(tester);

    expect(find.byType(ReaderWidget), findsNothing);
    expect(find.text(joinWordsLabel), findsOneWidget);
    expect(find.text(syncCancelLabel), findsOneWidget);
    expect(find.text(joinBackLabel), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
