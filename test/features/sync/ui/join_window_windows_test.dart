import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/sync/ui/join_journal_flow.dart';
import 'package:field_notes/features/sync/ui/join_window.dart';
import 'package:field_notes/features/sync/ui/mac_code_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _desktop = Size(1280, 800);

Future<void> _pump(WidgetTester tester, TargetPlatform platform) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = _desktop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<TextEditingController> words = <TextEditingController>[
    for (int index = 0; index < 8; index++) TextEditingController(),
  ];
  final TextEditingController address = TextEditingController();
  addTearDown(() {
    for (final TextEditingController word in words) {
      word.dispose();
    }
    address.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: JoinWindow(
          words: words,
          address: address,
          onCode: (String code) {},
          onCancel: () {},
          onWordsChanged: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Windows join window offers only the eight words', (
    WidgetTester tester,
  ) async {
    await _pump(tester, TargetPlatform.windows);

    expect(find.byKey(joinTypeColumnKey), findsOneWidget);
    final Rect type = tester.getRect(find.byKey(joinTypeColumnKey));
    expect(type.width, lessThanOrEqualTo(joinWindowTypeOnlyWidth));
    expect(type.center.dx, closeTo(_desktop.width / 2, 0.5));
    expect(find.byKey(joinScanColumnKey), findsNothing);
    expect(find.text(joinScanHelp), findsNothing);
    expect(find.byType(MacCodeScanner), findsNothing);
    expect(find.byType(DashedDivider), findsNothing);
    expect(find.text(joinOrLabel), findsNothing);
    expect(find.textContaining('Mac'), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    expect(joinWindowScans(TargetPlatform.macOS), isTrue);
    for (final TargetPlatform platform in TargetPlatform.values) {
      if (platform != TargetPlatform.macOS) {
        expect(joinWindowScans(platform), isFalse, reason: '$platform');
      }
    }
  });
}
