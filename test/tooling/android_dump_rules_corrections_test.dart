import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/a11y/android_dump_rules.dart';

String _node({
  required String bounds,
  String className = 'android.view.View',
  String desc = '',
  String text = '',
  bool clickable = false,
  bool longClickable = false,
  bool enabled = true,
  bool scrollable = false,
  String children = '',
}) {
  final String open =
      '<node index="0" text="$text" resource-id="" class="$className" '
      'package="dev.satanshumishra.field_notes" content-desc="$desc" '
      'checkable="false" checked="false" clickable="$clickable" '
      'enabled="$enabled" focusable="true" focused="false" '
      'scrollable="$scrollable" long-clickable="$longClickable" '
      'password="false" selected="false" bounds="$bounds"';
  return children.isEmpty ? '$open />\n' : '$open>\n$children</node>\n';
}

String _dump(String children) =>
    "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\n"
    '<hierarchy rotation="0">\n'
    '${_node(bounds: '[0,0][1080,2195]', className: 'android.widget.FrameLayout', children: children)}'
    '</hierarchy>\n';

List<String> _findings(String children) =>
    androidDumpFindings(_dump(children), state: 's', density: 420);

bool _hasPrefix(List<String> ids, String prefix) =>
    ids.any((String id) => id.startsWith(prefix));

void main() {
  test('a long-press-only node is judged for role and doubled targets', () {
    final List<String> ids = _findings(
      _node(
        bounds: '[53,232][1028,574]',
        longClickable: true,
        children: _node(
          bounds: '[53,232][1028,574]',
          className: 'android.widget.Button',
          desc: 'Morning note',
          clickable: true,
        ),
      ),
    );
    expect(
      _hasPrefix(ids, 'missing-role | s | <unlabelled> | '),
      isTrue,
      reason: '$ids',
    );
    expect(
      _hasPrefix(ids, 'doubled-target | s | Morning note | '),
      isTrue,
      reason: '$ids',
    );
  });

  test('an enabled button with no click action is caught as inert', () {
    final List<String> ids = _findings(
      _node(
            bounds: '[42,1494][400,1640]',
            className: 'android.widget.Button',
            desc: 'Earlier log',
          ) +
          _node(
            bounds: '[600,1494][958,1640]',
            className: 'android.widget.Button',
            desc: 'Later log',
            enabled: false,
          ),
    );
    expect(
      _hasPrefix(ids, 'inert-button | s | Earlier log | '),
      isTrue,
      reason: '$ids',
    );
    expect(
      _hasPrefix(ids, 'inert-button | s | Later log | '),
      isFalse,
      reason: '$ids',
    );
  });

  test('a node cut off by the window or a scroller is not judged as small', () {
    final List<String> ids = _findings(
      _node(
            bounds: '[0,232][1080,2109]',
            scrollable: true,
            children: _node(
              bounds: '[53,2085][1028,2109]',
              className: 'android.widget.Button',
              desc: 'Voice card',
              clickable: true,
            ),
          ) +
          _node(
            bounds: '[58,2125][170,2195]',
            className: 'android.widget.Button',
            desc: 'Today',
            clickable: true,
          ) +
          _node(
            bounds: '[245,2125][403,2195]',
            className: 'android.widget.Button',
            desc: 'Calendar',
            clickable: true,
          ) +
          _node(
            bounds: '[954,106][1059,211]',
            className: 'android.widget.Button',
            desc: 'Settings',
            clickable: true,
          ),
    );
    expect(
      _hasPrefix(ids, 'small-target | s | Voice card | '),
      isFalse,
      reason: '$ids',
    );
    expect(
      _hasPrefix(ids, 'small-target | s | Calendar | '),
      isFalse,
      reason: '$ids',
    );
    expect(
      _hasPrefix(ids, 'small-target | s | Today | '),
      isTrue,
      reason: '$ids',
    );
    expect(
      _hasPrefix(ids, 'small-target | s | Settings | '),
      isTrue,
      reason: '$ids',
    );
  });

  test('text and content description are each checked for repeats', () {
    final List<String> ids = _findings(
      _node(bounds: '[42,300][1038,500]', desc: 'Tide', text: 'Low&#10;Low') +
          _node(
            bounds: '[42,600][1038,1200]',
            className: 'android.widget.EditText',
            text: 'Beach day&#10;&#65532;&#10;The tide was out.&#10;&#65532;',
          ),
    );
    expect(
      _hasPrefix(ids, 'repeated-text | s | Tide | '),
      isTrue,
      reason: '$ids',
    );
    expect(
      ids.where((String id) => id.startsWith('repeated-text | s | Beach day')),
      isEmpty,
      reason: '$ids',
    );
  });
}
