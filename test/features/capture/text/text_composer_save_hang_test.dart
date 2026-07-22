import 'dart:async';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/capture_test_support.dart';

class _HangingCaptureService implements CaptureService {
  final Completer<CaptureResult> _never = Completer<CaptureResult>();
  int captureCalls = 0;

  @override
  Future<CaptureResult> capture(CaptureRequest request) {
    captureCalls++;
    return _never.future;
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.timeout});

  final Duration timeout;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss note composer',
        pageBuilder: (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return TextComposerConnector(
            date: '2026-07-21',
            saveTimeout: timeout,
          );
        },
      ),
      child: const Text('open'),
    );
  }
}

void main() {
  testWidgets(
      'when capture() never completes, the save is bounded: the "Saving..." '
      'state clears and a timeout error is surfaced instead of hanging',
      (WidgetTester tester) async {
    final _HangingCaptureService service = _HangingCaptureService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          captureServiceProvider.overrideWith((Ref ref) => service),
        ],
        child: captureHarness(
          const _Trigger(timeout: Duration(milliseconds: 100)),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(find.byType(EditableText), 'a slow day');
    await tester.pump();

    await tester.tap(find.text('Save note'));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));

    expect(service.captureCalls, 1);
    expect(find.text(textSaveTimeoutMessage), findsOneWidget);
    expect(find.text('Saving...'), findsNothing);
    expect(find.text('Save note'), findsOneWidget);
    expect(find.byType(TextComposerSheet), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
