import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'a11y_report.dart';

List<String> _section(String report, String title, List<String> titles) {
  final List<String> lines = report.split('\n');
  final int start = lines.indexOf(title);
  final int end = lines.indexWhere(
    (String line) => titles.contains(line),
    start + 1,
  );
  return lines.sublist(start + 1, end < 0 ? lines.length : end);
}

void main() {
  test('the report lists findings per platform', () {
    final Directory root = Directory.systemTemp.createTempSync('a11y_report_');
    addTearDown(() => root.deleteSync(recursive: true));
    final Directory shell = Directory('${root.path}/shell')..createSync();
    File(
      '${shell.path}/android-light.txt',
    ).writeAsStringSync('small-target | a1 | Settings | <root> # open: gear\n');
    File('${shell.path}/windows-dark.txt').writeAsStringSync(
      "missing-role | a5 | Dismiss | <root> # Flutter's own control\n",
    );

    final String report = a11yReport(root);
    const List<String> titles = <String>['Android', 'macOS', 'Windows'];

    final List<String> android = _section(report, 'Android', titles);
    expect(android, contains('  small-target: 1 open, 0 accepted'));
    expect(
      android,
      contains(
        allOf(
          contains('open'),
          contains('shell light'),
          contains('small-target | a1 | Settings | <root> # open: gear'),
        ),
      ),
    );

    expect(_section(report, 'macOS', titles), <String>['  no findings']);

    final List<String> windows = _section(report, 'Windows', titles);
    expect(windows, contains('  missing-role: 0 open, 1 accepted'));
    expect(
      windows,
      contains(
        allOf(
          contains('accepted'),
          contains('shell dark'),
          contains(
            "missing-role | a5 | Dismiss | <root> # Flutter's own control",
          ),
        ),
      ),
    );
  });
}
