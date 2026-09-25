import 'package:flutter_test/flutter_test.dart';

import 'a11y_baseline.dart';
import 'a11y_rules.dart';

enum A11yStateKind { toggled, checked, selected }

class A11yStatefulControl {
  const A11yStatefulControl.finder(Finder this.finder, this.kind)
    : label = null;

  const A11yStatefulControl.label(String this.label, this.kind) : finder = null;

  final Finder? finder;
  final String? label;
  final A11yStateKind kind;
}

class A11yProof {
  const A11yProof(this.finder, {this.count = 1}) : assert(count > 0);

  final Finder finder;
  final int count;
}

class A11yState {
  const A11yState({
    required this.id,
    required this.pump,
    required this.proof,
    this.stateful = const <A11yStatefulControl>[],
  });

  final String id;
  final Future<void> Function(WidgetTester tester) pump;
  final List<A11yProof> proof;
  final List<A11yStatefulControl> stateful;
}

sealed class A11yStateResult {
  const A11yStateResult();
}

final class A11yLoaded extends A11yStateResult {
  const A11yLoaded(this.findings);

  final List<A11yFinding> findings;
}

final class A11yNotLoaded extends A11yStateResult {
  const A11yNotLoaded(this.message);

  final String message;
}

String? _proofGap(A11yProof proof) {
  final int found = proof.finder.evaluate().length;
  return found >= proof.count
      ? null
      : 'expected at least ${proof.count} '
            '${proof.finder.describeMatch(Plurality.many)}, found $found';
}

Future<A11yStateResult> runA11yState(
  WidgetTester tester,
  A11yState state,
) async {
  final SemanticsHandle handle = tester.ensureSemantics();
  try {
    try {
      await state.pump(tester);
    } catch (error) {
      return A11yNotLoaded('${state.id} did not load: pumping threw $error');
    }
    final List<String> gaps = state.proof.isEmpty
        ? const <String>['it names no key widget']
        : <String>[
            for (final A11yProof proof in state.proof)
              if (_proofGap(proof) case final String gap) gap,
          ];
    if (gaps.isNotEmpty) {
      return A11yNotLoaded('${state.id} did not load: ${gaps.join('; ')}');
    }
    return A11yLoaded(
      a11yFindings(tester, state: state.id, stateful: state.stateful),
    );
  } finally {
    handle.dispose();
  }
}

String _baselinePath(String area) => 'test/accessibility/baselines/$area.txt';

void a11ySweepArea({
  required String area,
  required String groupName,
  required List<A11yState> states,
}) {
  final List<String> ids = <String>[
    for (final A11yState state in states) state.id,
  ];
  if (ids.toSet().length != ids.length) {
    throw ArgumentError.value(ids, 'states', 'state ids must be unique');
  }
  group(groupName, () {
    final Map<String, A11yStateResult> results = <String, A11yStateResult>{};

    for (final A11yState state in states) {
      testWidgets(state.id, (WidgetTester tester) async {
        final A11yStateResult result = await runA11yState(tester, state);
        results[state.id] = result;
        if (result case A11yNotLoaded(:final String message)) {
          fail(message);
        }
      });
    }

    test('matches the baseline', () {
      final List<String> problems = <String?>[
        for (final A11yState state in states)
          switch (results[state.id]) {
            null => '${state.id} was never recorded',
            A11yNotLoaded(:final String message) => message,
            A11yLoaded() => null,
          },
      ].nonNulls.toList();
      if (problems.isNotEmpty) {
        fail(problems.join('\n'));
      }
      final List<A11yFinding> findings = <A11yFinding>[
        for (final A11yState state in states)
          if (results[state.id] case A11yLoaded(
            :final List<A11yFinding> findings,
          ))
            ...findings,
      ];
      final String path = _baselinePath(area);
      if (a11yWriteBaseline) {
        writeA11yBaseline(path, findings);
        return;
      }
      final A11yBaselineResult result = compareA11yBaseline(path, findings);
      if (!result.matches) {
        fail(describeA11yBaseline(path, result));
      }
    });
  });
}
