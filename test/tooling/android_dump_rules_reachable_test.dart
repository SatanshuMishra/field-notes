import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/a11y/android_dump_rules.dart';

String _node({
  required String bounds,
  String className = 'android.view.View',
  String desc = '',
  bool checkable = false,
  bool clickable = false,
  String children = '',
}) {
  final String open =
      '<node index="0" text="" resource-id="" class="$className" '
      'package="dev.satanshumishra.field_notes" content-desc="$desc" '
      'checkable="$checkable" checked="false" clickable="$clickable" '
      'enabled="true" focusable="true" focused="false" '
      'scrollable="false" long-clickable="false" '
      'password="false" selected="false" bounds="$bounds"';
  return children.isEmpty ? '$open />\n' : '$open>\n$children</node>\n';
}

String _dump(String children) =>
    "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\n"
    '<hierarchy rotation="0">\n'
    '${_node(bounds: '[0,0][1080,2195]', className: 'android.widget.FrameLayout', children: children)}'
    '</hierarchy>\n';

List<String> _findingsInside(String parentBounds) => androidDumpFindings(
  _dump(
    _node(
      bounds: parentBounds,
      children: _node(
        bounds: '[71,1206][197,1332]',
        className: 'android.widget.CheckBox',
        desc: 'call the ferry office',
        checkable: true,
        clickable: true,
      ),
    ),
  ),
  state: 's',
  density: 420,
);

Iterable<String> _smallTargets(List<String> ids) =>
    ids.where((String id) => id.startsWith('small-target | '));

void main() {
  test(
    'a node that reaches past its parent is judged by the part inside it',
    () {
      final List<String> narrow = _findingsInside('[95,1133][174,1387]');
      expect(_smallTargets(narrow), <String>[
        'small-target | s | call the ferry office | <root>',
      ], reason: '$narrow');

      final List<String> wide = _findingsInside('[42,1133][1038,1387]');
      expect(_smallTargets(wide), isEmpty, reason: '$wide');
    },
  );
}
