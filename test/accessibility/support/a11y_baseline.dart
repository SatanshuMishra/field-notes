import 'dart:io';

import 'a11y_report.dart';
import 'a11y_rules.dart';

export 'a11y_report.dart' show A11yBaselineLine, a11yBaselineRoot;

bool get a11yWriteBaseline =>
    const bool.fromEnvironment('A11Y_SWEEP_WRITE_BASELINE');

String a11yBaselinePath(
  String area,
  String baseline, {
  String root = a11yBaselineRoot,
}) => '$root/$area/$baseline.txt';

class A11yBaselineResult {
  const A11yBaselineResult({
    required this.missing,
    required this.added,
    required this.stale,
    this.unreasoned = const <String>[],
  });

  final bool missing;
  final List<A11yFinding> added;
  final List<String> stale;
  final List<String> unreasoned;

  bool get matches =>
      !missing && added.isEmpty && stale.isEmpty && unreasoned.isEmpty;
}

List<A11yBaselineLine> _linesAt(String path) {
  final File file = File(path);
  return file.existsSync()
      ? readA11yBaselineLines(file)
      : const <A11yBaselineLine>[];
}

A11yBaselineResult compareA11yBaseline(
  String path,
  List<A11yFinding> findings,
) {
  if (!File(path).existsSync()) {
    return const A11yBaselineResult(
      missing: true,
      added: <A11yFinding>[],
      stale: <String>[],
    );
  }
  final List<A11yBaselineLine> lines = _linesAt(path);
  final Set<String> baselined = <String>{
    for (final A11yBaselineLine line in lines) line.id,
  };
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
        for (final A11yBaselineLine line in lines)
          if (!current.contains(line.id)) line.text,
      ]..sort(),
    ),
    unreasoned: List<String>.unmodifiable(<String>[
      for (final A11yBaselineLine line in lines)
        if (!line.reasoned) line.text,
    ]),
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
    if (result.unreasoned.isNotEmpty) ...<String>[
      "Baseline lines with no '$a11yReasonSeparator<reason>':",
      for (final String line in result.unreasoned) '  $line',
    ],
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
  final Map<String, String> reasons = <String, String>{
    for (final A11yBaselineLine line in _linesAt(path))
      if (line.reason case final String reason) line.id: reason,
  };
  final Map<String, String> rules = <String, String>{
    for (final A11yFinding finding in findings) finding.id: finding.rule,
  };
  final List<String> ids = rules.keys.toList()..sort();
  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    ids
        .map(
          (String id) =>
              '$id$a11yReasonSeparator'
              '${reasons[id] ?? '$a11yOpenReason: ${rules[id]}'}\n',
        )
        .join(),
  );
}
