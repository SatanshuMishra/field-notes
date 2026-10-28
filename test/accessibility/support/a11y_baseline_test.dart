import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_baseline.dart';
import 'a11y_rules.dart';
import 'a11y_state.dart';

const Key _plantedKey = ValueKey<String>('planted');

void _noop() {}

A11yFinding _settings({int occurrence = 1}) => A11yFinding(
  rule: 'small-target',
  state: 's1',
  label: 'Settings',
  anchor: '',
  rect: const Rect.fromLTWH(10, 20, 30, 40),
  occurrence: occurrence,
);

A11yFinding _finding(String rule, String label) => A11yFinding(
  rule: rule,
  state: 'baseline',
  label: label,
  anchor: '',
  rect: const Rect.fromLTWH(10, 20, 30, 40),
);

Directory _scratch() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'a11y_baseline_',
  );
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

File _baselineHolding(Directory directory, String name, String text) =>
    File('${directory.path}/$name.txt')..writeAsStringSync(text);

final A11yState _probe = A11yState(
  id: 'p1',
  pump: (WidgetTester tester, A11yVariant variant) async {
    variant.useWindow(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: variant.theme,
        builder: variant.scaleText,
        home: Material(
          child: Center(
            child: Semantics(
              key: _plantedKey,
              container: true,
              button: true,
              label: 'Probe',
              onTap: _noop,
              child: const SizedBox(width: 30, height: 30),
            ),
          ),
        ),
      ),
    );
  },
  proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
);

void main() {
  test('a baseline line without a reason fails the sweep', () {
    final Directory directory = _scratch();
    final File bare = _baselineHolding(
      directory,
      'bare',
      'small-target | s1 | Settings | <root>\n',
    );
    final File reasoned = _baselineHolding(
      directory,
      'reasoned',
      "small-target | s1 | Settings | <root> # Flutter's own control\n",
    );

    final A11yBaselineResult failed = compareA11yBaseline(
      bare.path,
      <A11yFinding>[_settings()],
    );
    expect(failed.matches, isFalse);
    expect(
      describeA11yBaseline(bare.path, failed),
      contains('small-target | s1 | Settings | <root>'),
    );
    expect(failed.unreasoned, <String>[
      'small-target | s1 | Settings | <root>',
    ]);

    final A11yBaselineResult matched = compareA11yBaseline(
      reasoned.path,
      <A11yFinding>[_settings()],
    );
    expect(matched.matches, isTrue);
  });

  test('an occurrence suffixed line keeps its occurrence', () {
    final File file = _baselineHolding(
      _scratch(),
      'suffixed',
      "small-target | s1 | Settings | <root> #2 # Flutter's own control\n",
    );
    final A11yBaselineResult result = compareA11yBaseline(
      file.path,
      <A11yFinding>[_settings(), _settings(occurrence: 2)],
    );
    expect(result.unreasoned, isEmpty);
    expect(result.stale, isEmpty);
    expect(
      <String>[for (final A11yFinding finding in result.added) finding.id],
      <String>['small-target | s1 | Settings | <root>'],
    );
  });

  test('an occurrence suffix is not a reason', () {
    final File file = _baselineHolding(
      _scratch(),
      'suffix-only',
      'small-target | s1 | Settings | <root> #2\n',
    );
    final A11yBaselineResult result = compareA11yBaseline(
      file.path,
      <A11yFinding>[_settings(occurrence: 2)],
    );
    expect(result.matches, isFalse);
    expect(result.unreasoned, <String>[
      'small-target | s1 | Settings | <root> #2',
    ]);
    expect(
      describeA11yBaseline(file.path, result),
      allOf(
        contains('no'),
        contains('small-target | s1 | Settings | <root> #2'),
      ),
    );
  });

  testWidgets('each area platform and theme has its own baseline', (
    WidgetTester tester,
  ) async {
    final Directory root = _scratch();
    final Map<String, List<A11yFinding>> found = <String, List<A11yFinding>>{};
    for (final A11yVariant variant in a11yVariants) {
      final A11yStateResult result = await runA11yState(
        tester,
        _probe,
        variant: variant,
        checks: A11yChecks.full,
      );
      found[variant.baseline] = <A11yFinding>[
        ...?found[variant.baseline],
        ...switch (result) {
          A11yLoaded(:final List<A11yFinding> findings) => findings,
          A11yNotLoaded(:final String message) => throw TestFailure(message),
        },
      ];
    }
    for (final MapEntry<String, List<A11yFinding>> baseline in found.entries) {
      writeA11yBaseline(
        a11yBaselinePath('probe', baseline.key, root: root.path),
        baseline.value,
      );
    }

    expect(
      <String>[
        for (final FileSystemEntity file in Directory(
          '${root.path}/probe',
        ).listSync())
          file.uri.pathSegments.last,
      ]..sort(),
      <String>[
        'android-dark.txt',
        'android-light.txt',
        'macos-dark.txt',
        'macos-light.txt',
        'windows-dark.txt',
        'windows-light.txt',
      ],
    );
    expect(
      a11yBaselinePath('probe', 'windows-dark', root: root.path),
      '${root.path}/probe/windows-dark.txt',
    );
    for (final MapEntry<String, List<A11yFinding>> baseline in found.entries) {
      final String path = a11yBaselinePath(
        'probe',
        baseline.key,
        root: root.path,
      );
      expect(File(path).readAsStringSync(), contains(' | p1 | Probe | '));
      expect(
        compareA11yBaseline(path, baseline.value).matches,
        isTrue,
        reason: path,
      );
    }
    expect(
      File(a11yBaselinePath('probe', 'android-light', root: root.path))
          .readAsLinesSync(),
      contains('small-target | p1 | Probe | <root> # open: small-target'),
    );
    expect(
      File(a11yBaselinePath('probe', 'macos-light', root: root.path))
          .readAsLinesSync(),
      isNot(contains(startsWith('small-target | p1 | Probe'))),
    );
  });

  test('the baseline flags new and stale findings', () {
    final Directory directory = _scratch();
    final String path = '${directory.path}/area.txt';
    final File file = File(path);
    final A11yFinding kept = _finding('missing-role', 'Cancel');
    final A11yFinding added = _finding('unlabelled-tap', '');

    final A11yBaselineResult missing = compareA11yBaseline(path, <A11yFinding>[
      kept,
    ]);
    expect(missing.missing, isTrue);
    expect(missing.matches, isFalse);
    expect(describeA11yBaseline(path, missing), '$path baseline missing');

    file.writeAsStringSync('${kept.id} # open: missing-role\n');
    final A11yBaselineResult grown = compareA11yBaseline(path, <A11yFinding>[
      kept,
      added,
    ]);
    expect(grown.missing, isFalse);
    expect(grown.matches, isFalse);
    expect(
      <String>[for (final A11yFinding finding in grown.added) finding.id],
      <String>[added.id],
    );
    expect(grown.stale, isEmpty);
    expect(
      describeA11yBaseline(path, grown),
      allOf(
        contains(added.id),
        contains(a11yRuleDescriptions['unlabelled-tap']),
        contains(added.rect.toString()),
      ),
    );

    const String gone =
        "small-target | baseline | Close | <root> # Flutter's own control";
    file.writeAsStringSync('${kept.id} # open: missing-role\n$gone\n');
    final A11yBaselineResult shrunk = compareA11yBaseline(path, <A11yFinding>[
      kept,
    ]);
    expect(shrunk.matches, isFalse);
    expect(shrunk.added, isEmpty);
    expect(shrunk.stale, <String>[gone]);
    expect(describeA11yBaseline(path, shrunk), contains(gone));

    file.writeAsStringSync('  \n${kept.id} # open: missing-role\n\t\n');
    expect(compareA11yBaseline(path, <A11yFinding>[kept]).matches, isTrue);
  });

  test('writing a baseline keeps reasons and opens new lines', () {
    final Directory directory = _scratch();
    final String path = '${directory.path}/area.txt';
    final A11yFinding kept = _finding('missing-role', 'Dismiss');
    final A11yFinding added = _finding('small-target', 'Close');
    File(path).writeAsStringSync("${kept.id} # Flutter's own control\n");

    writeA11yBaseline(path, <A11yFinding>[added, kept]);

    expect(File(path).readAsLinesSync(), <String>[
      "missing-role | baseline | Dismiss | <root> # Flutter's own control",
      'small-target | baseline | Close | <root> # open: small-target',
    ]);
    expect(
      compareA11yBaseline(path, <A11yFinding>[kept, added]).matches,
      isTrue,
    );
  });
}
