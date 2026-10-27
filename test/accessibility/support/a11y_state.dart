import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_baseline.dart';
import 'a11y_rules.dart';
import 'a11y_variants.dart';

export 'a11y_variants.dart';

enum A11yStateKind { toggled, checked, selected }

enum A11yChecks { semantic, full }

class A11yStatefulControl {
  const A11yStatefulControl.finder(
    Finder this.finder,
    this.kind, {
    this.count = 1,
  }) : assert(count > 0),
       label = null;

  const A11yStatefulControl.label(String this.label, this.kind)
    : finder = null,
      count = 1;

  final Finder? finder;
  final String? label;
  final A11yStateKind kind;
  final int count;
}

class A11yProof {
  const A11yProof(this.finder, {this.count = 1}) : assert(count > 0);

  final Finder finder;
  final int count;
}

typedef A11yPumpBody = Future<void> Function(
  WidgetTester tester,
  A11yVariant variant,
);

final class A11yPump {
  const A11yPump(this._body, this.platforms);

  final A11yPumpBody _body;
  final Set<TargetPlatform> platforms;

  A11yVariant get defaultVariant => A11yVariant(
    platform: switch (debugDefaultTargetPlatformOverride) {
      final TargetPlatform ambient? when platforms.contains(ambient) => ambient,
      _ => a11yPlatforms.firstWhere(platforms.contains),
    },
  );

  Future<void> call(WidgetTester tester, [A11yVariant? variant]) {
    final A11yVariant chosen = variant ?? defaultVariant;
    return _onPlatform(chosen.platform, () => _body(tester, chosen));
  }
}

Future<T> _onPlatform<T>(
  TargetPlatform platform,
  Future<T> Function() body,
) async {
  final TargetPlatform? previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

class A11yState {
  A11yState({
    required this.id,
    required A11yPumpBody pump,
    required this.proof,
    this.stateful = const <A11yStatefulControl>[],
    this.platforms = a11yPlatforms,
  }) : assert(platforms.isNotEmpty && platforms.every(a11yPlatforms.contains)),
       pump = A11yPump(pump, platforms);

  final String id;
  final A11yPump pump;
  final List<A11yProof> proof;
  final List<A11yStatefulControl> stateful;
  final Set<TargetPlatform> platforms;

  bool runsIn(A11yVariant variant) => platforms.contains(variant.platform);
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

const Duration _settleStep = Duration(milliseconds: 100);
const Duration _settleLimit = Duration(seconds: 1);
const Duration _timersRunOut = Duration(minutes: 1);

String? _proofGap(A11yProof proof) {
  final int found = proof.finder.evaluate().length;
  return found >= proof.count
      ? null
      : 'expected at least ${proof.count} '
            '${proof.finder.describeMatch(Plurality.many)}, found $found';
}

Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      _settleStep,
      EnginePhase.sendSemanticsUpdate,
      _settleLimit,
    );
  } on FlutterError catch (error) {
    if (!error.message.contains('pumpAndSettle timed out')) {
      rethrow;
    }
  }
}

void _useVariantEnvironment(WidgetTester tester, A11yVariant variant) {
  tester.platformDispatcher.textScaleFactorTestValue = variant.textScale.factor;
  tester.platformDispatcher.platformBrightnessTestValue = variant.brightness;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

Future<A11yStateResult> _loadAndCheck(
  WidgetTester tester,
  A11yState state,
  A11yVariant variant,
  A11yChecks checks,
  A11yWatch? watch,
) async {
  try {
    await state.pump(tester, variant);
    if (watch != null) {
      watch.watchTextFromHere();
      await _settle(tester);
    }
  } catch (error) {
    return A11yNotLoaded('${state.id} did not load: pumping threw $error');
  }
  watch?.stop();
  if (tester.takeException() case final Object error) {
    return A11yNotLoaded('${state.id} did not load: pumping threw $error');
  }
  final List<String> gaps = <String>[
    if (state.proof.isEmpty) 'it names no key widget',
    for (final A11yProof proof in state.proof)
      if (_proofGap(proof) case final String gap) gap,
    ...a11yStatefulGaps(tester, state.stateful),
  ];
  if (gaps.isNotEmpty) {
    return A11yNotLoaded('${state.id} did not load: ${gaps.join('; ')}');
  }
  final String stateId = '${state.id}${variant.idSuffix}';
  return A11yLoaded(switch ((checks, watch)) {
    (A11yChecks.full, final A11yWatch watch) => await a11yFullFindings(
      tester,
      state: stateId,
      variant: variant,
      watch: watch,
      stateful: state.stateful,
    ),
    _ => a11yFindings(tester, state: stateId, stateful: state.stateful),
  });
}

Future<A11yStateResult> runA11yState(
  WidgetTester tester,
  A11yState state, {
  A11yVariant? variant,
  A11yChecks checks = A11yChecks.semantic,
}) async {
  final A11yVariant chosen = variant ?? state.pump.defaultVariant;
  if (!state.runsIn(chosen)) {
    return A11yNotLoaded(
      '${state.id} did not load: it does not run on ${chosen.platformName}',
    );
  }
  final SemanticsHandle handle = tester.ensureSemantics();
  _useVariantEnvironment(tester, chosen);
  final A11yWatch? watch = switch (checks) {
    A11yChecks.full => A11yWatch.start(tester),
    A11yChecks.semantic => null,
  };
  try {
    return await _onPlatform(
      chosen.platform,
      () => _loadAndCheck(tester, state, chosen, checks, watch),
    );
  } finally {
    watch?.close();
    handle.dispose();
  }
}

void a11ySweepArea({
  required String area,
  required String groupName,
  required List<A11yState> states,
  String root = a11yBaselineRoot,
  bool? writeBaseline,
}) {
  final List<String> keys = <String>[
    for (final A11yState state in states)
      for (final TargetPlatform platform in state.platforms)
        '${state.id} ${a11yPlatformName(platform)}',
  ];
  if (keys.toSet().length != keys.length) {
    throw ArgumentError.value(
      keys,
      'states',
      'state ids must be unique on each platform',
    );
  }
  final bool write = writeBaseline ?? a11yWriteBaseline;
  group(groupName, () {
    final Map<String, A11yStateResult> results = <String, A11yStateResult>{};

    String keyOf(A11yState state, A11yVariant variant) =>
        '${state.id} ${variant.name}';

    for (final A11yState state in states) {
      for (final A11yVariant variant in a11yVariants) {
        if (!state.runsIn(variant)) {
          continue;
        }
        testWidgets(keyOf(state, variant), (WidgetTester tester) async {
          final A11yStateResult result = await runA11yState(
            tester,
            state,
            variant: variant,
            checks: A11yChecks.full,
          );
          results[keyOf(state, variant)] = result;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(_timersRunOut);
          if (result case A11yNotLoaded(:final String message)) {
            fail(message);
          }
        });
      }
    }

    for (final String baseline in a11yBaselineNames) {
      test('matches the $baseline baseline', () {
        final List<(A11yState, A11yVariant)> runs = <(A11yState, A11yVariant)>[
          for (final A11yState state in states)
            for (final A11yVariant variant in a11yVariants)
              if (variant.baseline == baseline && state.runsIn(variant))
                (state, variant),
        ];
        final List<String> problems = <String?>[
          for (final (A11yState state, A11yVariant variant) in runs)
            switch (results[keyOf(state, variant)]) {
              null => '${keyOf(state, variant)} was never recorded',
              A11yNotLoaded(:final String message) => message,
              A11yLoaded() => null,
            },
        ].nonNulls.toList();
        if (problems.isNotEmpty) {
          fail(problems.join('\n'));
        }
        final List<A11yFinding> findings = <A11yFinding>[
          for (final (A11yState state, A11yVariant variant) in runs)
            if (results[keyOf(state, variant)] case A11yLoaded(
              :final List<A11yFinding> findings,
            ))
              ...findings,
        ];
        final String path = a11yBaselinePath(area, baseline, root: root);
        if (write) {
          writeA11yBaseline(path, findings);
          return;
        }
        final A11yBaselineResult result = compareA11yBaseline(path, findings);
        if (!result.matches) {
          fail(describeA11yBaseline(path, result));
        }
      });
    }
  });
}
