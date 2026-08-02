import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test_support.dart';

class _ComposerTrigger extends StatelessWidget {
  const _ComposerTrigger({required this.date, required this.onResult});

  final String date;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(await showTextComposer(context, date)),
      child: const Text('open'),
    );
  }
}

Widget _composerApp({
  required CaptureService service,
  required ValueChanged<String?> onResult,
}) {
  return ProviderScope(
    overrides: <Override>[
      captureServiceProvider.overrideWith((Ref ref) => service),
    ],
    child: captureHarness(
      _ComposerTrigger(date: '2026-07-19', onResult: onResult),
    ),
  );
}

void main() {
  testWidgets('saving an empty note announces the guard instead of writing',
      (WidgetTester tester) async {
    final List<String> saved = <String>[];

    await tester.pumpWidget(
      captureHarness(
        TextComposerSheet(onSave: saved.add, onCancel: () {}),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isEmpty);
    expect(find.text(emptySaveGuardMessage), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'a good day');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, <String>['a good day']);

    await tester.pump(composerToastLifetime);
  });

  testWidgets('a successful save closes the composer with the new entry id',
      (WidgetTester tester) async {
    final FakeCaptureService service = FakeCaptureService();
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(service: service, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'a good day');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'entry-1');
    expect(service.requests, hasLength(1));
    final TextCaptureRequest request =
        service.requests.single as TextCaptureRequest;
    expect(request.date, '2026-07-19');
    expect(request.text, 'a good day');
    expect(find.byType(TextComposerSheet), findsNothing);
  });

  testWidgets('a failed save shows the reason and keeps the typed note',
      (WidgetTester tester) async {
    final FakeCaptureService service = FakeCaptureService(
      failure: const CaptureException('Could not save your entry.'),
    );
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(service: service, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'do not lose me');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save your entry.'), findsOneWidget);
    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'do not lose me',
    );
    expect(result, 'unset');
  });

  testWidgets('the close X shuts the composer without capturing anything',
      (WidgetTester tester) async {
    final FakeCaptureService service = FakeCaptureService();
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(service: service, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'never mind');
    await tester.pump();
    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(service.requests, isEmpty);
    expect(find.byType(TextComposerSheet), findsNothing);
  });
}
