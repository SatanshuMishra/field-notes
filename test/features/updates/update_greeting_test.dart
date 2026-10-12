import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';

const String _greeting = 'Updated to Field Notes 2.4.0';

final class _PendingGreeting extends UpdateGreeting {
  _PendingGreeting(this._version);

  final String? _version;

  @override
  String? build() => _version;
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required String? pending,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ...shellOverrides(),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        updateGreetingProvider.overrideWith(() => _PendingGreeting(pending)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

void main() {
  testWidgets('the greeting toast appears once', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpShell(
      tester,
      pending: '2.4.0',
    );

    expect(find.text(_greeting), findsOneWidget);
    expect(container.read(updateGreetingProvider), isNull);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(_greeting), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(_greeting), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(_greeting), findsNothing);
    expect(container.read(updateGreetingProvider), isNull);

    container.read(updateGreetingProvider.notifier).greet('2.4.1');
    await tester.pump();
    await tester.pump();
    expect(find.text('Updated to Field Notes 2.4.1'), findsOneWidget);
    expect(find.text(_greeting), findsNothing);
    expect(container.read(updateGreetingProvider), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Updated to Field Notes 2.4.1'), findsNothing);

    final ProviderContainer quiet = await _pumpShell(tester, pending: null);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Updated to Field Notes'), findsNothing);
    expect(quiet.read(updateGreetingProvider), isNull);
    await tester.pumpAndSettle();
  });
}
