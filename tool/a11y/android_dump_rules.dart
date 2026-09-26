import 'dart:io';

const String _usage =
    'usage: dart run tool/a11y/android_dump_rules.dart --density <dpi> '
    '--state <id> <file> [--state <id> <file> ...]';

const String _editText = 'android.widget.EditText';

const String _button = 'android.widget.Button';

const Set<String> _roleClasses = <String>{
  _button,
  'android.widget.CheckBox',
  'android.widget.Switch',
  'android.widget.ToggleButton',
  'android.widget.RadioButton',
  _editText,
  'android.widget.SeekBar',
};

const Map<String, String> _namedReferences = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
};

final RegExp _reference = RegExp(
  r'&(?:#x([0-9A-Fa-f]+)|#([0-9]+)|(amp|lt|gt|quot|apos));',
);

final RegExp _startTag = RegExp(
  r'<([^\s/>!?]+)((?:\s+[^\s=/>]+\s*=\s*(?:"[^"]*"|\x27[^\x27]*\x27))*)\s*(/?)>',
);

final RegExp _endTag = RegExp(r'</([^\s>]+)\s*>');

final RegExp _attribute = RegExp(
  r'([^\s=/>]+)\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)',
);

final RegExp _boundsPattern = RegExp(
  r'^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$',
);

final RegExp _lineBreak = RegExp(r'[\r\n]');

typedef _Request = ({int density, List<(String, String)> dumps});

final class _Bounds {
  const _Bounds(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;

  int get height => bottom - top;

  bool matches(_Bounds other) =>
      (left - other.left).abs() <= 2 &&
      (top - other.top).abs() <= 2 &&
      (right - other.right).abs() <= 2 &&
      (bottom - other.bottom).abs() <= 2;
}

final class _Node {
  const _Node({
    required this.className,
    required this.description,
    required this.text,
    required this.anchor,
    required this.clickable,
    required this.longClickable,
    required this.enabled,
    required this.scrollable,
    required this.bounds,
    required this.scrollers,
  });

  final String className;
  final List<String> description;
  final List<String> text;
  final String anchor;
  final bool clickable;
  final bool longClickable;
  final bool enabled;
  final bool scrollable;
  final _Bounds bounds;
  final List<_Bounds> scrollers;

  List<String> get lines => description.isNotEmpty ? description : text;

  bool get labelled => lines.isNotEmpty;

  String get label => labelled ? lines.join(' / ') : '<unlabelled>';

  bool get tappable => clickable || longClickable;

  bool get repeatsText =>
      _repeats(description) || (className != _editText && _repeats(text));
}

List<String> androidDumpFindings(
  String xml, {
  required String state,
  required int density,
}) => _sorted(_numbered(_findings(_parse(xml), state, density)));

void main(List<String> arguments) {
  final _Request? request = _request(arguments);
  if (request == null) {
    stderr.writeln(_usage);
    exitCode = 2;
    return;
  }
  try {
    final List<String> ids = _requestFindings(request);
    for (final String id in ids) {
      stdout.writeln(id);
    }
    exitCode = ids.isEmpty ? 0 : 1;
  } on FileSystemException catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  } on FormatException catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  }
}

_Request? _request(
  List<String> arguments, {
  int? density,
  List<(String, String)> dumps = const <(String, String)>[],
}) => switch (arguments) {
  [] =>
    density == null || dumps.isEmpty ? null : (density: density, dumps: dumps),
  ['--density', final String value, ...final List<String> rest]
      when density == null =>
    switch (int.tryParse(value)) {
      final int parsed when parsed > 0 => _request(
        rest,
        density: parsed,
        dumps: dumps,
      ),
      _ => null,
    },
  ['--state', final String state, final String path, ...final List<String> rest]
      when state.isNotEmpty && path.isNotEmpty =>
    _request(
      rest,
      density: density,
      dumps: <(String, String)>[...dumps, (state, path)],
    ),
  _ => null,
};

List<String> _requestFindings(_Request request) {
  final Map<String, List<String>> byState = <String, List<String>>{};
  for (final (String state, String path) in request.dumps) {
    byState[state] = <String>[
      ...?byState[state],
      ..._dumpFindings(path, state, request.density),
    ];
  }
  return _sorted(<String>[
    for (final List<String> ids in byState.values) ..._numbered(ids),
  ]);
}

List<String> _dumpFindings(String path, String state, int density) {
  try {
    return _findings(_parse(File(path).readAsStringSync()), state, density);
  } on FormatException catch (error) {
    throw FormatException(
      '$path: ${error.message}',
      error.source,
      error.offset,
    );
  }
}

List<String> _findings(List<_Node> nodes, String state, int density) {
  if (nodes.isEmpty) {
    return const <String>[];
  }
  final _Bounds screen = nodes.first.bounds;
  final int minimum = (48 * density / 160).ceil();
  String id(String rule, _Node node) =>
      '$rule | $state | ${node.label} | ${node.anchor}';
  return <String>[
    for (final _Node node in nodes) ...<String>[
      if (node.tappable && !node.labelled && node.className != _editText)
        id('unlabelled-tap', node),
      if (node.tappable && !_roleClasses.contains(node.className))
        id('missing-role', node),
      if (node.className == _button && node.enabled && !node.tappable)
        id('inert-button', node),
      if (node.repeatsText) id('repeated-text', node),
      if (node.tappable &&
          ((!_clippedAcross(node, screen) && node.bounds.width < minimum) ||
              (!_clippedAlong(node, screen) && node.bounds.height < minimum)))
        id('small-target', node),
    ],
    for (final _Node node in _doubledTargets(nodes)) id('doubled-target', node),
  ];
}

bool _clippedAcross(_Node node, _Bounds screen) =>
    node.bounds.left <= screen.left ||
    node.bounds.right >= screen.right ||
    node.scrollers.any(
      (_Bounds scroller) =>
          (node.bounds.left == scroller.left) !=
          (node.bounds.right == scroller.right),
    );

bool _clippedAlong(_Node node, _Bounds screen) =>
    node.bounds.top <= screen.top ||
    node.bounds.bottom >= screen.bottom ||
    node.scrollers.any(
      (_Bounds scroller) =>
          (node.bounds.top == scroller.top) !=
          (node.bounds.bottom == scroller.bottom),
    );

bool _repeats(List<String> lines) => lines.toSet().length < lines.length;

List<_Node> _doubledTargets(List<_Node> nodes) {
  final List<_Node> tappable = <_Node>[
    for (final _Node node in nodes)
      if (node.tappable) node,
  ];
  return <_Node>[
    for (int first = 0; first < tappable.length; first++)
      for (int second = first + 1; second < tappable.length; second++)
        if (tappable[first].bounds.matches(tappable[second].bounds))
          tappable[first].labelled && !tappable[second].labelled
              ? tappable[first]
              : tappable[second],
  ];
}

List<String> _numbered(List<String> ids) {
  final Map<String, int> counts = <String, int>{};
  for (final String id in ids) {
    counts.update(id, (int count) => count + 1, ifAbsent: () => 1);
  }
  return <String>[
    for (final MapEntry<String, int>(key: String id, value: int count)
        in counts.entries)
      for (int number = 1; number <= count; number++)
        number == 1 ? id : '$id #$number',
  ];
}

List<String> _sorted(List<String> ids) => <String>[...ids]..sort();

List<_Node> _parse(String xml) {
  final List<_Node> nodes = <_Node>[];
  final List<(String, _Node?)> open = <(String, _Node?)>[];
  var elements = 0;
  var position = xml.indexOf('<');
  while (position >= 0) {
    final int end;
    if (xml.startsWith('<?', position)) {
      end = _skipPast(xml, '?>', position);
    } else if (xml.startsWith('<!--', position)) {
      end = _skipPast(xml, '-->', position);
    } else if (xml.startsWith('<![CDATA[', position)) {
      end = _skipPast(xml, ']]>', position);
    } else if (xml.startsWith('<!', position)) {
      end = _skipPast(xml, '>', position);
    } else if (_endTag.matchAsPrefix(xml, position) case final Match tag) {
      if (open.isEmpty || open.last.$1 != tag[1]) {
        throw FormatException('unexpected </${tag[1]}>', xml, position);
      }
      open.removeLast();
      end = tag.end;
    } else if (_startTag.matchAsPrefix(xml, position) case final Match tag) {
      final String name = tag[1]!;
      final _Node? enclosing = open.isEmpty ? null : open.last.$2;
      final _Node? node = name == 'node'
          ? _node(_attributes(tag[2]!), enclosing)
          : null;
      if (node != null) {
        nodes.add(node);
      }
      if (tag[3] != '/') {
        open.add((name, node ?? enclosing));
      }
      elements++;
      end = tag.end;
    } else {
      throw FormatException('malformed tag', xml, position);
    }
    position = xml.indexOf('<', end);
  }
  if (open.isNotEmpty) {
    throw FormatException('unclosed <${open.last.$1}>', xml, xml.length);
  }
  if (elements == 0) {
    throw const FormatException('no XML element');
  }
  return List<_Node>.unmodifiable(nodes);
}

int _skipPast(String xml, String terminator, int start) {
  final int end = xml.indexOf(terminator, start);
  if (end < 0) {
    throw FormatException('unterminated markup', xml, start);
  }
  return end + terminator.length;
}

Map<String, String> _attributes(String source) => <String, String>{
  for (final Match match in _attribute.allMatches(source))
    match[1]!: _decoded(match[2] ?? match[3]!),
};

_Node _node(Map<String, String> attributes, _Node? parent) => _Node(
  className: attributes['class'] ?? '',
  description: _lines(attributes['content-desc'] ?? ''),
  text: _lines(attributes['text'] ?? ''),
  anchor: switch (parent) {
    null => '<root>',
    _Node(labelled: true, :final String label) => label,
    _Node(:final String anchor) => anchor,
  },
  clickable: attributes['clickable'] == 'true',
  longClickable: attributes['long-clickable'] == 'true',
  enabled: attributes['enabled'] == 'true',
  scrollable: attributes['scrollable'] == 'true',
  bounds: _bounds(attributes['bounds']),
  scrollers: switch (parent) {
    null => const <_Bounds>[],
    _Node(
      scrollable: true,
      :final List<_Bounds> scrollers,
      :final _Bounds bounds,
    ) =>
      List<_Bounds>.unmodifiable(<_Bounds>[...scrollers, bounds]),
    _Node(:final List<_Bounds> scrollers) => scrollers,
  },
);

List<String> _lines(String text) => List<String>.unmodifiable(<String>[
  for (final String line in text.split(_lineBreak).map(_trimmed))
    if (line.isNotEmpty) line,
]);

String _trimmed(String line) => line.trim();

_Bounds _bounds(String? value) {
  final Match? match = value == null ? null : _boundsPattern.firstMatch(value);
  if (match == null) {
    throw FormatException('malformed bounds: $value');
  }
  return _Bounds(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
    int.parse(match[4]!),
  );
}

String _decoded(String raw) {
  if (raw.replaceAll(_reference, '').contains('&')) {
    throw FormatException('malformed character reference', raw);
  }
  return raw.replaceAllMapped(_reference, _character);
}

String _character(Match match) {
  final String? name = match[3];
  if (name != null) {
    return _namedReferences[name]!;
  }
  final String? hex = match[1];
  final int? code = hex == null
      ? int.tryParse(match[2]!)
      : int.tryParse(hex, radix: 16);
  if (code == null || code > 0x10FFFF) {
    throw FormatException('character reference out of range', match[0]);
  }
  return String.fromCharCode(code);
}
