import 'dart:io';

const String a11yBaselineRoot = 'test/accessibility/baselines';

const String a11yReasonSeparator = ' # ';

const String a11yOpenReason = 'open';

final class A11yBaselineLine {
  const A11yBaselineLine({
    required this.text,
    required this.id,
    required this.reason,
  });

  factory A11yBaselineLine.parse(String line) {
    final String text = line.trim();
    final int at = text.lastIndexOf(a11yReasonSeparator);
    final String reason = at < 0
        ? ''
        : text.substring(at + a11yReasonSeparator.length).trim();
    return A11yBaselineLine(
      text: text,
      id: at < 0 ? text : text.substring(0, at).trim(),
      reason: reason.isEmpty ? null : reason,
    );
  }

  final String text;
  final String id;
  final String? reason;

  String get rule => id.split(' | ').first;

  bool get reasoned => reason != null;

  bool get open => reason?.startsWith(a11yOpenReason) ?? true;
}

List<A11yBaselineLine> readA11yBaselineLines(File file) =>
    List<A11yBaselineLine>.unmodifiable(<A11yBaselineLine>[
      for (final String line in file.readAsLinesSync())
        if (line.trim().isNotEmpty) A11yBaselineLine.parse(line),
    ]);

const Map<String, String> _platformTitles = <String, String>{
  'android': 'Android',
  'macos': 'macOS',
  'windows': 'Windows',
};

final class _ReportLine {
  const _ReportLine({
    required this.area,
    required this.theme,
    required this.line,
  });

  final String area;
  final String theme;
  final A11yBaselineLine line;
}

List<_ReportLine> _linesFor(Directory root, String platform) {
  final List<Directory> areas = root.listSync().whereType<Directory>().toList()
    ..sort((Directory a, Directory b) => a.path.compareTo(b.path));
  return <_ReportLine>[
    for (final Directory area in areas)
      for (final String theme in const <String>['light', 'dark'])
        if (File('${area.path}/$platform-$theme.txt') case final File file
            when file.existsSync())
          for (final A11yBaselineLine line in readA11yBaselineLines(file))
            _ReportLine(
              area: area.uri.pathSegments.lastWhere(
                (String segment) => segment.isNotEmpty,
              ),
              theme: theme,
              line: line,
            ),
  ];
}

String _status(A11yBaselineLine line) => line.open ? 'open' : 'accepted';

List<String> _section(String title, List<_ReportLine> lines) {
  final List<String> rules = <String>{
    for (final _ReportLine line in lines) line.line.rule,
  }.toList()..sort();
  return <String>[
    title,
    if (lines.isEmpty) '  no findings',
    for (final String rule in rules) ...<String>[
      '  $rule: '
          '${lines.where((_ReportLine line) => line.line.rule == rule && line.line.open).length} open, '
          '${lines.where((_ReportLine line) => line.line.rule == rule && !line.line.open).length} accepted',
      for (final _ReportLine line in lines)
        if (line.line.rule == rule)
          '    ${_status(line.line).padRight(8)}  ${line.area} ${line.theme}  '
              '${line.line.id}$a11yReasonSeparator${line.line.reason ?? ''}',
    ],
  ];
}

String a11yReport(Directory root) => <String>[
  for (final MapEntry<String, String> platform in _platformTitles.entries)
    ..._section(platform.value, _linesFor(root, platform.key)),
].join('\n');

void main(List<String> arguments) {
  final Directory root = Directory(
    arguments.isEmpty ? a11yBaselineRoot : arguments.first,
  );
  stdout.writeln(a11yReport(root));
}
