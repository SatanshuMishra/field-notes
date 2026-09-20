import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../day_detail/support/day_detail_harness.dart' show sendSystemBack;
import 'capture_test_support.dart';

class _GuardedRoute extends StatelessWidget {
  const _GuardedRoute({
    required this.isDirty,
    required this.onDiscard,
    this.locked = false,
  });

  final ValueGetter<bool> isDirty;
  final Future<void> Function() onDiscard;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return ComposerGuard(
      isDirty: isDirty,
      onDiscard: onDiscard,
      locked: locked,
      popResult: 'closed',
      builder: (BuildContext context, VoidCallback requestClose) {
        return Scaffold(
          body: Column(
            children: <Widget>[
              const Text('guarded body'),
              TextButton(onPressed: requestClose, child: const Text('X')),
            ],
          ),
        );
      },
    );
  }
}

class _Opener extends StatelessWidget {
  const _Opener({required this.route, required this.onResult});

  final Widget route;
  final ValueChanged<Object?> onResult;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async => onResult(
        await Navigator.of(context).push<Object?>(
          MaterialPageRoute<Object?>(builder: (BuildContext _) => route),
        ),
      ),
      child: const Text('open'),
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('guarded body'), findsOneWidget);
}

void main() {
  testWidgets('a clean composer pops straight through on system back',
      (WidgetTester tester) async {
    int discards = 0;
    Object? result = 'unset';

    await tester.pumpWidget(
      captureHarness(
        _Opener(
          route: _GuardedRoute(
            isDirty: () => false,
            onDiscard: () async => discards++,
          ),
          onResult: (Object? value) => result = value,
        ),
      ),
    );

    await _open(tester);
    await sendSystemBack(tester);

    expect(find.text('guarded body'), findsNothing);
    expect(find.text(composerDiscardTitle), findsNothing);
    expect(discards, 1);
    expect(result, 'closed');
  });

  testWidgets(
      'a system back on a dirty composer is blocked and shows the confirm; '
      'Keep editing leaves the route in place', (WidgetTester tester) async {
    int discards = 0;
    Object? result = 'unset';

    await tester.pumpWidget(
      captureHarness(
        _Opener(
          route: _GuardedRoute(
            isDirty: () => true,
            onDiscard: () async => discards++,
          ),
          onResult: (Object? value) => result = value,
        ),
      ),
    );

    await _open(tester);
    await sendSystemBack(tester);

    expect(find.text('guarded body'), findsOneWidget);
    expect(find.text(composerDiscardTitle), findsOneWidget);
    expect(find.text(composerDiscardMessage), findsOneWidget);
    expect(discards, 0);

    await tester.tap(find.byKey(composerKeepEditingKey));
    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsNothing);
    expect(find.text('guarded body'), findsOneWidget);
    expect(discards, 0);
    expect(result, 'unset');
  });

  testWidgets('Discard runs the discard action and pops with the result',
      (WidgetTester tester) async {
    int discards = 0;
    Object? result = 'unset';

    await tester.pumpWidget(
      captureHarness(
        _Opener(
          route: _GuardedRoute(
            isDirty: () => true,
            onDiscard: () async => discards++,
          ),
          onResult: (Object? value) => result = value,
        ),
      ),
    );

    await _open(tester);
    await sendSystemBack(tester);
    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pumpAndSettle();

    expect(discards, 1);
    expect(result, 'closed');
    expect(find.text('guarded body'), findsNothing);
  });

  testWidgets('the X button routes through the same dirty check',
      (WidgetTester tester) async {
    int discards = 0;

    await tester.pumpWidget(
      captureHarness(
        _Opener(
          route: _GuardedRoute(
            isDirty: () => true,
            onDiscard: () async => discards++,
          ),
          onResult: (Object? _) {},
        ),
      ),
    );

    await _open(tester);
    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsOneWidget);
    expect(discards, 0);

    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pumpAndSettle();
    expect(discards, 1);
    expect(find.text('guarded body'), findsNothing);
  });

  testWidgets('a locked guard ignores both back and the X button',
      (WidgetTester tester) async {
    int discards = 0;

    await tester.pumpWidget(
      captureHarness(
        _Opener(
          route: _GuardedRoute(
            isDirty: () => false,
            onDiscard: () async => discards++,
            locked: true,
          ),
          onResult: (Object? _) {},
        ),
      ),
    );

    await _open(tester);
    await sendSystemBack(tester);
    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();

    expect(find.text('guarded body'), findsOneWidget);
    expect(find.text(composerDiscardTitle), findsNothing);
    expect(discards, 0);
  });
}
