import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';

void main() {
  for (final String text in <String>[
    'Forward 10 seconds',
    'Back 10 seconds',
    'Muted',
    'Sound on',
  ]) {
    testWidgets('the video key label "$text" is announced as a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: fieldNotesTheme(
            platform: TargetPlatform.macOS,
            brightness: Brightness.dark,
          ),
          home: Center(
            child: VideoSkipLabel(key: videoSkipLabelKey, text: text),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(videoSkipLabelKey)),
        matchesSemantics(label: text, isLiveRegion: true),
      );
      semantics.dispose();
    });
  }
}
