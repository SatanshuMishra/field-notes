import 'dart:io';

import 'a11y_rules.dart';

bool get a11yWriteBaseline =>
    const bool.fromEnvironment('A11Y_SWEEP_WRITE_BASELINE');

class A11yBaselineResult {
  const A11yBaselineResult({
    required this.missing,
    required this.added,
    required this.stale,
  });

  final bool missing;
  final List<A11yFinding> added;
  final List<String> stale;

  bool get matches => !missing && added.isEmpty && stale.isEmpty;
}

A11yBaselineResult compareA11yBaseline(
  String path,
  List<A11yFinding> findings,
) {
  final File file = File(path);
  if (!file.existsSync()) {
    return const A11yBaselineResult(
      missing: true,
      added: <A11yFinding>[],
      stale: <String>[],
    );
  }
  final List<String> lines = <String>[
    for (final String line in file.readAsLinesSync())
      if (line.trim() case final String trimmed when trimmed.isNotEmpty)
        trimmed,
  ];
  final Set<String> baselined = lines.toSet();
  final Set<String> current = <String>{
    for (final A11yFinding finding in findings) finding.id,
  };
  return A11yBaselineResult(
    missing: false,
    added: List<A11yFinding>.unmodifiable(
      <A11yFinding>[
        for (final A11yFinding finding in findings)
          if (!baselined.contains(finding.id)) finding,
      ]..sort((A11yFinding a, A11yFinding b) => a.id.compareTo(b.id)),
    ),
    stale: List<String>.unmodifiable(
      <String>[
        for (final String line in baselined)
          if (!current.contains(line)) line,
      ]..sort(),
    ),
  );
}

String describeA11yBaseline(String path, A11yBaselineResult result) {
  if (result.missing) {
    return '$path baseline missing';
  }
  if (result.matches) {
    return '$path baseline matches';
  }
  return <String>[
    '$path baseline does not match',
    if (result.added.isNotEmpty) ...<String>[
      'New findings, not in the baseline:',
      for (final A11yFinding finding in result.added) ...<String>[
        '  ${finding.id}',
        '    ${a11yRuleDescriptions[finding.rule] ?? finding.rule} '
            'Rect: ${finding.rect}',
      ],
    ],
    if (result.stale.isNotEmpty) ...<String>[
      'Stale baseline lines, no longer found:',
      for (final String line in result.stale) '  $line',
    ],
  ].join('\n');
}

void writeA11yBaseline(String path, List<A11yFinding> findings) {
  final List<String> ids = <String>{
    for (final A11yFinding finding in findings) finding.id,
  }.toList()..sort();
  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(ids.map((String id) => '$id\n').join());
}
