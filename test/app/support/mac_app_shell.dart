import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import 'app_shell_harness.dart';

Future<void> pumpMacAppShell(
  WidgetTester tester, {
  required List<Override> sync,
  bool collapsed = false,
  bool settle = true,
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
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  await tester.pump();
  await tester.pump();
}
