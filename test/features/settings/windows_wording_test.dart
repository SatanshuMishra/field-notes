import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/reminders/notifications_off_notice.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _deviceLabel(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  String? label;
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: fieldNotesTheme(platform: platform),
      home: Builder(
        builder: (BuildContext context) {
          label = thisDeviceLabel(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return label!;
}

void main() {
  testWidgets('Windows names the PC where macOS names the Mac', (
    WidgetTester tester,
  ) async {
    expect(await _deviceLabel(tester, TargetPlatform.windows), 'This PC');
    expect(await _deviceLabel(tester, TargetPlatform.macOS), 'This Mac');
    expect(await _deviceLabel(tester, TargetPlatform.android), 'This phone');
    expect(
      syncOffIntroDesktop(TargetPlatform.windows),
      'Your journal is stored only on this PC. Turn on sync to keep it on your '
      'other devices too. Everything is encrypted before it leaves this PC.',
    );
    expect(
      keepMediaCaptionDesktop(TargetPlatform.windows),
      'Download every photo, voice note and video in the background. On for '
      'PCs.',
    );
    expect(syncOffIntroDesktop(TargetPlatform.macOS), syncOffIntroMac);
    expect(keepMediaCaptionDesktop(TargetPlatform.macOS), keepMediaMacCaption);
  });

  test('Windows opens Settings where macOS opens System Settings', () {
    expect(openSettingsLabelFor(TargetPlatform.windows), 'Open Settings');
    expect(
      openSettingsFailureFor(TargetPlatform.windows),
      'Could not open Settings.',
    );
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      expect(openSettingsLabelFor(platform), 'Open System Settings');
      expect(
        openSettingsFailureFor(platform),
        'Could not open System Settings.',
      );
    }
  });
}
