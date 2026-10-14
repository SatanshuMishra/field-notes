import 'package:field_notes/app/app.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/ui/update_restart_splash.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_shell_harness.dart';

final ReleaseInfo _release = ReleaseInfo(
  version: AppVersion.tryParse('2.4.0')!,
  tag: 'v2.4.0',
  publishedAt: DateTime(2026, 7, 18, 12),
  notes: ReleaseNotes(intro: '', groups: const <ReleaseNoteGroup>[]),
  pageUrl: Uri.parse('https://github.com/SatanshuMishra/field-notes'),
  assets: const <ReleaseAsset>[],
);

final class _AlreadyRestarting extends UpdateController {
  @override
  UpdateStatus build() => UpdateRestarting(_release);

  @override
  Future<void> check() async {}
}

void main() {
  testWidgets(
    'the restart splash text carries no underline',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1140, 726);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ...shellOverrides(),
            installedAppProvider.overrideWith(
              (Ref ref) async => const InstalledApp(version: '1.4.2'),
            ),
            updateControllerProvider.overrideWith(_AlreadyRestarting.new),
          ],
          child: const FieldNotesApp(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(updateRestartSplashKey), findsOneWidget);
      for (final String text in <String>[
        restartingTitle,
        openingVersionLine('2.4.0'),
      ]) {
        final RichText rich = tester.widget<RichText>(
          find.descendant(
            of: find.byType(UpdateRestartSplash),
            matching: find.byWidgetPredicate(
              (Widget w) => w is RichText && w.text.toPlainText() == text,
            ),
          ),
        );
        final TextDecoration? decoration = rich.text.style?.decoration;
        expect(
          decoration == null || decoration == TextDecoration.none,
          isTrue,
          reason: '$text is drawn with $decoration',
        );
        final TextStyle style = rich.text.style!;
        final bool isTitle = text == restartingTitle;
        expect(style.fontFamily, contains(isTitle ? 'Newsreader' : 'Caveat'));
        expect(style.fontSize, isTitle ? 24 : 17);
        expect(style.fontWeight, isTitle ? FontWeight.w500 : FontWeight.w600);
        expect(
          style.color!.toARGB32(),
          Color(isTitle ? 0xFF4A3B2E : 0xFFB8566A).toARGB32(),
        );
      }
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );
}
