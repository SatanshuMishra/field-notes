import 'dart:convert';
import 'dart:io';

import 'package:field_notes/domain/notes/markdown/note_tree.dart';
import 'package:field_notes/domain/notes/markdown/source_lines.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';

final class ShapeNode {
  ShapeNode(
    this.kind, {
    Map<String, String> attributes = const <String, String>{},
    List<ShapeNode> children = const <ShapeNode>[],
    this.text = '',
  }) : attributes = Map<String, String>.unmodifiable(attributes),
       children = List<ShapeNode>.unmodifiable(children);

  final String kind;
  final Map<String, String> attributes;
  final List<ShapeNode> children;
  final String text;

  ShapeNode withChildren(List<ShapeNode> next) =>
      ShapeNode(kind, attributes: attributes, children: next, text: text);

  ShapeNode withText(String next) =>
      ShapeNode(kind, attributes: attributes, children: children, text: next);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! ShapeNode ||
        kind != other.kind ||
        text != other.text ||
        attributes.length != other.attributes.length ||
        children.length != other.children.length) {
      return false;
    }
    for (final MapEntry<String, String> entry in attributes.entries) {
      if (other.attributes[entry.key] != entry.value) {
        return false;
      }
    }
    for (int i = 0; i < children.length; i++) {
      if (children[i] != other.children[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    text,
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<String, String> entry in attributes.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAll(children),
  );

  @override
  String toString() {
    final List<String> keys = attributes.keys.toList()..sort();
    final String attributeText = keys.isEmpty
        ? ''
        : '(${keys.map((String k) => '$k: ${attributes[k]}').join(', ')})';
    final String textPart = text.isEmpty && kind != 'text' && kind != 'codeSpan'
        ? ''
        : ' ${jsonEncode(text)}';
    final String childPart = children.isEmpty ? '' : '[${children.join(', ')}]';
    return '$kind$attributeText$textPart$childPart';
  }
}

String shapeToString(List<ShapeNode> nodes) => '[${nodes.join(', ')}]';

const String fixtureDirectory = 'test/domain/notes/markdown/fixtures';

final class SpecExample {
  const SpecExample({
    required this.number,
    required this.section,
    required this.markdown,
    required this.html,
  });

  factory SpecExample.fromJson(Map<String, Object?> json) => SpecExample(
    number: json['example']! as int,
    section: json['section']! as String,
    markdown: json['markdown']! as String,
    html: json['html']! as String,
  );

  final int number;
  final String section;
  final String markdown;
  final String html;
}

final class Exclusion {
  const Exclusion({
    required this.number,
    required this.reason,
    required this.detail,
    this.rule,
  });

  factory Exclusion.fromJson(Map<String, Object?> json) => Exclusion(
    number: json['example']! as int,
    reason: json['reason']! as String,
    detail: json['detail']! as String,
    rule: json['rule'] as String?,
  );

  final int number;
  final String reason;
  final String detail;
  final String? rule;
}

List<SpecExample> loadSpecExamples(String fileName) {
  final List<Object?> raw =
      jsonDecode(File('$fixtureDirectory/$fileName').readAsStringSync())
          as List<Object?>;
  return List<SpecExample>.unmodifiable(<SpecExample>[
    for (final Object? entry in raw)
      SpecExample.fromJson(entry! as Map<String, Object?>),
  ]);
}

Map<String, Object?> loadManifest() =>
    jsonDecode(File('$fixtureDirectory/manifest.json').readAsStringSync())
        as Map<String, Object?>;

List<Exclusion> manifestExclusions(
  Map<String, Object?> manifest,
  String suite,
) {
  final Map<String, Object?> part = manifest[suite]! as Map<String, Object?>;
  return List<Exclusion>.unmodifiable(<Exclusion>[
    for (final Object? entry in part['excluded']! as List<Object?>)
      Exclusion.fromJson(entry! as Map<String, Object?>),
  ]);
}

String? exampleFailure(SpecExample example, {required bool tables}) {
  try {
    final List<ShapeNode> expected = shapeFromHtml(example.html);
    final List<ShapeNode> actual = shapeFromTree(
      parseNoteTree(example.markdown, tables: tables),
      example.markdown,
    );
    if (_listsEqual(expected, actual)) {
      return null;
    }
    return 'example ${example.number} (${example.section})\n'
        '  markdown: ${jsonEncode(example.markdown)}\n'
        '  expected: ${shapeToString(expected)}\n'
        '  actual:   ${shapeToString(actual)}';
  } on Object catch (error) {
    return 'example ${example.number} (${example.section})\n'
        '  markdown: ${jsonEncode(example.markdown)}\n'
        '  error: $error';
  }
}

bool _listsEqual(List<ShapeNode> a, List<ShapeNode> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

List<ShapeNode> shapeFromHtml(String html) {
  final _Element root = _HtmlReader(html).read();
  return _HtmlShaper().blocks(root.children);
}

List<ShapeNode> shapeFromTree(MdTree tree, String source) =>
    _TreeShaper(source, tree).blocks(tree.blocks);

String percentDecode(String value) {
  final StringBuffer buffer = StringBuffer();
  int at = 0;
  while (at < value.length) {
    final List<int> bytes = <int>[];
    int next = at;
    while (next + 2 < value.length &&
        value.codeUnitAt(next) == 0x25 &&
        _hexValue(value.codeUnitAt(next + 1)) != null &&
        _hexValue(value.codeUnitAt(next + 2)) != null) {
      bytes.add(
        _hexValue(value.codeUnitAt(next + 1))! * 16 +
            _hexValue(value.codeUnitAt(next + 2))!,
      );
      next += 3;
    }
    if (bytes.isEmpty) {
      buffer.writeCharCode(value.codeUnitAt(at));
      at++;
    } else {
      buffer.write(utf8.decode(bytes, allowMalformed: true));
      at = next;
    }
  }
  return buffer.toString();
}

int? _hexValue(int unit) {
  if (unit >= 0x30 && unit <= 0x39) {
    return unit - 0x30;
  }
  if (unit >= 0x41 && unit <= 0x46) {
    return unit - 0x41 + 10;
  }
  if (unit >= 0x61 && unit <= 0x66) {
    return unit - 0x61 + 10;
  }
  return null;
}

List<ShapeNode> _normaliseInlines(
  List<ShapeNode> nodes, {
  bool atBlockEnd = true,
}) {
  final List<ShapeNode> merged = <ShapeNode>[];
  for (final ShapeNode node in nodes) {
    final ShapeNode current = node.children.isEmpty || node.kind == 'text'
        ? node
        : node.withChildren(
            _normaliseInlines(node.children, atBlockEnd: false),
          );
    if (current.kind == 'text' && current.text.isEmpty) {
      continue;
    }
    if (current.kind == 'text' &&
        merged.isNotEmpty &&
        merged.last.kind == 'text') {
      final ShapeNode previous = merged.removeLast();
      merged.add(previous.withText(previous.text + current.text));
    } else {
      merged.add(current);
    }
  }
  final List<ShapeNode> trimmed = <ShapeNode>[];
  for (int i = 0; i < merged.length; i++) {
    final ShapeNode node = merged[i];
    final bool beforeSoftBreak =
        i + 1 < merged.length && merged[i + 1].kind == 'softBreak';
    final bool isLast = atBlockEnd && i == merged.length - 1;
    if (node.kind == 'text' && (beforeSoftBreak || isLast)) {
      final String text = _trimTrailingBlanks(node.text);
      if (text.isNotEmpty) {
        trimmed.add(node.withText(text));
      }
    } else {
      trimmed.add(node);
    }
  }
  return List<ShapeNode>.unmodifiable(trimmed);
}

String _trimTrailingBlanks(String text) {
  int end = text.length;
  while (end > 0 &&
      (text.codeUnitAt(end - 1) == 0x20 || text.codeUnitAt(end - 1) == 0x09)) {
    end--;
  }
  return text.substring(0, end);
}

String _codeSpanText(String text) =>
    text.replaceAll('\r\n', ' ').replaceAll('\n', ' ');

final class _Element {
  _Element(this.name, this.attributes);

  final String name;
  final Map<String, String> attributes;
  final List<Object> children = <Object>[];
}

const Set<String> _voidTags = <String>{'hr', 'br', 'input'};

const Set<String> _knownTags = <String>{
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'pre',
  'code',
  'blockquote',
  'ul',
  'ol',
  'li',
  'input',
  'table',
  'thead',
  'tbody',
  'tr',
  'th',
  'td',
  'em',
  'strong',
  'del',
  'a',
  'br',
};

const Set<String> _blockTags = <String>{
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'pre',
  'blockquote',
  'ul',
  'ol',
  'li',
  'table',
  'thead',
  'tbody',
  'tr',
  'th',
  'td',
};

final RegExp _tagPattern = RegExp(
  r'<(/?)([A-Za-z][A-Za-z0-9]*)((?:\s+[A-Za-z_:][-A-Za-z0-9_:.]*(?:\s*=\s*"[^"]*")?)*)\s*(/?)>',
);

final RegExp _attributePattern = RegExp(
  r'([A-Za-z_:][-A-Za-z0-9_:.]*)(?:\s*=\s*"([^"]*)")?',
);

final class _HtmlReader {
  _HtmlReader(this.html);

  final String html;

  _Element read() {
    final _Element root = _Element('#root', const <String, String>{});
    final List<_Element> stack = <_Element>[root];
    int at = 0;
    while (at < html.length) {
      final int open = html.indexOf('<', at);
      final int textEnd = open < 0 ? html.length : open;
      if (textEnd > at) {
        stack.last.children.add(_decodeEntities(html.substring(at, textEnd)));
      }
      if (open < 0) {
        break;
      }
      final Match? match = _tagPattern.matchAsPrefix(html, open);
      if (match == null) {
        throw UnsupportedError(
          'unsupported markup at $open: ${html.substring(open)}',
        );
      }
      final String name = match.group(2)!.toLowerCase();
      if (!_knownTags.contains(name)) {
        throw UnsupportedError('unsupported tag <$name>');
      }
      if (match.group(1)!.isNotEmpty) {
        if (stack.length < 2 || stack.last.name != name) {
          throw UnsupportedError('unbalanced closing tag </$name>');
        }
        stack.removeLast();
      } else {
        final _Element element = _Element(name, <String, String>{
          for (final RegExpMatch a in _attributePattern.allMatches(
            match.group(3)!,
          ))
            a.group(1)!.toLowerCase(): _decodeEntities(a.group(2) ?? ''),
        });
        stack.last.children.add(element);
        if (!_voidTags.contains(name) && match.group(4)!.isEmpty) {
          stack.add(element);
        }
      }
      at = match.end;
    }
    if (stack.length != 1) {
      throw UnsupportedError('unclosed tag <${stack.last.name}>');
    }
    return root;
  }
}

final RegExp _entityPattern = RegExp(
  r'&(amp|lt|gt|quot|#[0-9]+|#[xX][0-9A-Fa-f]+);',
);

String _decodeEntities(String text) =>
    text.replaceAllMapped(_entityPattern, (Match m) {
      final String name = m.group(1)!;
      switch (name) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
      }
      final bool isHex = name.length > 1 && (name[1] == 'x' || name[1] == 'X');
      final int code = int.parse(
        isHex ? name.substring(2) : name.substring(1),
        radix: isHex ? 16 : 10,
      );
      return String.fromCharCode(code == 0 || code > 0x10FFFF ? 0xFFFD : code);
    });

bool _isBlockElement(Object node) =>
    node is _Element && _blockTags.contains(node.name);

bool _isBlank(Object node) => node is String && node.trim().isEmpty;

final class _HtmlShaper {
  List<ShapeNode> blocks(List<Object> nodes) => <ShapeNode>[
    for (final Object node in nodes)
      if (!_isBlank(node)) block(node),
  ];

  ShapeNode block(Object node) {
    if (node is! _Element) {
      throw UnsupportedError('text outside a block: ${jsonEncode(node)}');
    }
    final String name = node.name;
    switch (name) {
      case 'p':
        return ShapeNode('paragraph', children: inlines(node.children));
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        return ShapeNode(
          'heading',
          attributes: <String, String>{'level': name.substring(1)},
          children: inlines(node.children),
        );
      case 'hr':
        return ShapeNode('thematicBreak');
      case 'pre':
        return codeBlock(node);
      case 'blockquote':
        return ShapeNode('blockQuote', children: blocks(node.children));
      case 'ul' || 'ol':
        return list(node);
      case 'table':
        return table(node);
    }
    throw UnsupportedError('unexpected block <$name>');
  }

  ShapeNode codeBlock(_Element pre) {
    final List<Object> content = <Object>[
      for (final Object child in pre.children)
        if (!_isBlank(child)) child,
    ];
    if (content.length != 1 ||
        content.single is! _Element ||
        (content.single as _Element).name != 'code') {
      throw UnsupportedError('pre without a single code element');
    }
    final _Element code = content.single as _Element;
    final String language = code.attributes['class'] ?? '';
    final String info = language.startsWith('language-')
        ? language.substring('language-'.length)
        : '';
    return ShapeNode(
      'codeBlock',
      attributes: <String, String>{'info': info},
      text: _textContent(code),
    );
  }

  String _textContent(_Element element) {
    final StringBuffer buffer = StringBuffer();
    for (final Object child in element.children) {
      if (child is String) {
        buffer.write(child);
      } else {
        throw UnsupportedError(
          'element <${(child as _Element).name}> inside <${element.name}>',
        );
      }
    }
    return buffer.toString();
  }

  ShapeNode list(_Element list) {
    final List<_Element> items = <_Element>[];
    for (final Object child in list.children) {
      if (_isBlank(child)) {
        continue;
      }
      if (child is! _Element || child.name != 'li') {
        throw UnsupportedError('list child that is not <li>');
      }
      items.add(child);
    }
    final bool tight = !items.any(
      (_Element li) =>
          li.children.any((Object c) => c is _Element && c.name == 'p'),
    );
    return ShapeNode(
      list.name == 'ul' ? 'bulletList' : 'orderedList',
      attributes: <String, String>{
        if (list.name == 'ol') 'start': list.attributes['start'] ?? '1',
        'tight': '$tight',
      },
      children: <ShapeNode>[for (final _Element li in items) listItem(li)],
    );
  }

  ShapeNode listItem(_Element li) {
    final (_Element? box, List<Object> rest) = _takeCheckbox(li.children);
    final String task = box == null
        ? 'none'
        : box.attributes.containsKey('checked')
        ? 'checked'
        : 'unchecked';
    final List<ShapeNode> children = <ShapeNode>[];
    final List<Object> run = <Object>[];
    void flush({required bool beforeTag}) {
      if (run.every(_isBlank)) {
        run.clear();
        return;
      }
      final List<Object> content = beforeTag ? _dropSeparator(run) : run;
      children.add(ShapeNode('paragraph', children: inlines(content)));
      run.clear();
    }

    for (final Object child in rest) {
      if (_isBlockElement(child)) {
        flush(beforeTag: true);
        children.add(block(child));
      } else {
        run.add(child);
      }
    }
    flush(beforeTag: true);
    return ShapeNode(
      'listItem',
      attributes: <String, String>{'task': task},
      children: children,
    );
  }

  (_Element?, List<Object>) _takeCheckbox(List<Object> children) {
    if (children.isNotEmpty && _isCheckbox(children.first)) {
      return (
        children.first as _Element,
        <Object>[..._dropOneSpace(children.skip(1).toList())],
      );
    }
    final int firstElement = children.indexWhere((Object c) => c is _Element);
    if (firstElement >= 0 &&
        children.take(firstElement).every(_isBlank) &&
        (children[firstElement] as _Element).name == 'p') {
      final _Element paragraph = children[firstElement] as _Element;
      if (paragraph.children.isNotEmpty &&
          _isCheckbox(paragraph.children.first)) {
        final _Element rebuilt = _Element('p', paragraph.attributes)
          ..children.addAll(_dropOneSpace(paragraph.children.skip(1).toList()));
        return (
          paragraph.children.first as _Element,
          <Object>[
            ...children.take(firstElement),
            rebuilt,
            ...children.skip(firstElement + 1),
          ],
        );
      }
    }
    return (null, children);
  }

  bool _isCheckbox(Object node) =>
      node is _Element &&
      node.name == 'input' &&
      node.attributes['type'] == 'checkbox';

  List<Object> _dropOneSpace(List<Object> nodes) {
    if (nodes.isNotEmpty && nodes.first is String) {
      final String first = nodes.first as String;
      if (first.startsWith(' ')) {
        return <Object>[first.substring(1), ...nodes.skip(1)];
      }
    }
    return nodes;
  }

  List<Object> _dropSeparator(List<Object> run) {
    if (run.isNotEmpty && run.last is String) {
      final String last = run.last as String;
      if (last.endsWith('\n')) {
        return <Object>[
          ...run.take(run.length - 1),
          last.substring(0, last.length - 1),
        ];
      }
    }
    return run;
  }

  ShapeNode table(_Element table) {
    final List<_Element> rows = <_Element>[];
    for (final Object child in table.children) {
      if (_isBlank(child)) {
        continue;
      }
      if (child is _Element &&
          (child.name == 'thead' || child.name == 'tbody')) {
        for (final Object row in child.children) {
          if (_isBlank(row)) {
            continue;
          }
          if (row is! _Element || row.name != 'tr') {
            throw UnsupportedError('table section child that is not <tr>');
          }
          rows.add(row);
        }
      } else if (child is _Element && child.name == 'tr') {
        rows.add(child);
      } else {
        throw UnsupportedError('unexpected table child');
      }
    }
    final List<List<_Element>> cells = <List<_Element>>[
      for (final _Element row in rows)
        <_Element>[
          for (final Object cell in row.children)
            if (!_isBlank(cell))
              if (cell is _Element && (cell.name == 'th' || cell.name == 'td'))
                cell
              else
                throw UnsupportedError('row child that is not a cell'),
        ],
    ];
    final List<String> alignments = cells.isEmpty
        ? const <String>[]
        : <String>[
            for (final _Element cell in cells.first)
              switch (cell.attributes['align']) {
                'left' => 'left',
                'center' => 'centre',
                'right' => 'right',
                _ => 'none',
              },
          ];
    return ShapeNode(
      'table',
      attributes: <String, String>{'alignment': alignments.join(',')},
      children: <ShapeNode>[
        for (final List<_Element> row in cells)
          ShapeNode(
            'tableRow',
            children: <ShapeNode>[
              for (final _Element cell in row)
                ShapeNode('tableCell', children: inlines(cell.children)),
            ],
          ),
      ],
    );
  }

  List<ShapeNode> inlines(List<Object> nodes) =>
      _normaliseInlines(_rawInlines(nodes));

  List<ShapeNode> _rawInlines(List<Object> nodes) {
    final List<ShapeNode> out = <ShapeNode>[];
    for (int i = 0; i < nodes.length; i++) {
      final Object node = nodes[i];
      if (node is String) {
        final bool afterBreak =
            i > 0 &&
            nodes[i - 1] is _Element &&
            (nodes[i - 1] as _Element).name == 'br';
        final String text = afterBreak && node.startsWith('\n')
            ? node.substring(1)
            : node;
        final List<String> lines = text.split('\n');
        for (int l = 0; l < lines.length; l++) {
          if (l > 0) {
            out.add(ShapeNode('softBreak'));
          }
          out.add(ShapeNode('text', text: lines[l]));
        }
        continue;
      }
      final _Element element = node as _Element;
      switch (element.name) {
        case 'em':
          out.add(
            ShapeNode('emphasis', children: _rawInlines(element.children)),
          );
        case 'strong':
          out.add(ShapeNode('strong', children: _rawInlines(element.children)));
        case 'del':
          out.add(
            ShapeNode('strikethrough', children: _rawInlines(element.children)),
          );
        case 'code':
          out.add(
            ShapeNode('codeSpan', text: _codeSpanText(_textContent(element))),
          );
        case 'br':
          out.add(ShapeNode('hardBreak'));
        case 'a':
          out.add(
            ShapeNode(
              'link',
              attributes: _linkAttributes(
                element.attributes['href'] ?? '',
                element.attributes['title'],
              ),
              children: _rawInlines(element.children),
            ),
          );
        default:
          throw UnsupportedError('unexpected inline <${element.name}>');
      }
    }
    return out;
  }
}

Map<String, String> _linkAttributes(String href, String? title) =>
    <String, String>{
      'href': percentDecode(href),
      if (title != null && title.isNotEmpty) 'title': percentDecode(title),
    };

List<MdRange> _collectMarkers(MdTree tree) {
  final List<MdRange> ranges = <MdRange>[];
  void visit(MdNode node) {
    ranges.addAll(node.markerRanges);
    node.children.forEach(visit);
  }

  tree.blocks.forEach(visit);
  ranges.sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
  return List<MdRange>.unmodifiable(ranges);
}

final class _TreeShaper {
  _TreeShaper(this.source, MdTree tree)
    : lines = MdSourceLines.split(source),
      markers = _collectMarkers(tree);

  final String source;
  final MdSourceLines lines;
  final List<MdRange> markers;

  String visible(int start, int end) {
    final StringBuffer buffer = StringBuffer();
    int position = start;
    for (final MdRange marker in markers) {
      if (marker.end <= position || marker.start >= end) {
        continue;
      }
      if (marker.start > position) {
        buffer.write(source.substring(position, marker.start));
      }
      position = marker.end;
    }
    if (position < end) {
      buffer.write(source.substring(position, end));
    }
    return buffer.toString();
  }

  String visibleRange(MdRange range) => visible(range.start, range.end);

  List<ShapeNode> blocks(List<MdBlock> blocks) => <ShapeNode>[
    for (final MdBlock block in blocks)
      if (block.kind != MdBlockKind.blankLine) this.block(block),
  ];

  ShapeNode block(MdBlock block) {
    final MdBlockData? data = block.data;
    switch (block.kind) {
      case MdBlockKind.heading:
        return ShapeNode(
          'heading',
          attributes: <String, String>{
            'level': '${(data! as MdHeadingData).level}',
          },
          children: inlines(block.inlines),
        );
      case MdBlockKind.thematicBreak:
        return ShapeNode('thematicBreak');
      case MdBlockKind.fencedCode:
        return codeBlock(block, data! as MdFenceData);
      case MdBlockKind.paragraph:
        return ShapeNode('paragraph', children: inlines(block.inlines));
      case MdBlockKind.blockQuote:
        return ShapeNode('blockQuote', children: blocks(block.blocks));
      case MdBlockKind.bulletList:
        return ShapeNode(
          'bulletList',
          attributes: <String, String>{
            'tight': '${(data! as MdBulletListData).isTight}',
          },
          children: blocks(block.blocks),
        );
      case MdBlockKind.orderedList:
        final MdOrderedListData ordered = data! as MdOrderedListData;
        return ShapeNode(
          'orderedList',
          attributes: <String, String>{
            'start': '${ordered.start}',
            'tight': '${ordered.isTight}',
          },
          children: blocks(block.blocks),
        );
      case MdBlockKind.listItem:
        return ShapeNode(
          'listItem',
          attributes: <String, String>{
            'task': (data! as MdListItemData).taskState.name,
          },
          children: blocks(block.blocks),
        );
      case MdBlockKind.table:
        return table(block);
      case MdBlockKind.tableRow || MdBlockKind.tableCell:
        throw StateError('table part outside a table');
      case MdBlockKind.photoLine:
        return ShapeNode('photoLine');
      case MdBlockKind.blankLine:
        throw StateError('blank lines are skipped');
    }
  }

  ShapeNode codeBlock(MdBlock block, MdFenceData data) {
    final MdRange range = block.sourceRange;
    final int opening = lines.lineIndexAt(range.start);
    final List<MdSourceLine> code = <MdSourceLine>[
      for (final MdSourceLine line in lines.lines.skip(opening + 1))
        if (line.start <= range.end) line,
    ];
    final List<MdSourceLine> withoutClosing = data.isClosed && code.isNotEmpty
        ? code.sublist(0, code.length - 1)
        : code;
    final MdSourceLine last = lines.lines.last;
    final bool endsInBreak = last.start == last.end && lines.lines.length > 1;
    final List<MdSourceLine> kept = <MdSourceLine>[
      for (final MdSourceLine line in withoutClosing)
        if (!(endsInBreak && identical(line, last))) line,
    ];
    final String text = kept
        .map(
          (MdSourceLine line) =>
              '${visible(line.start < range.start ? range.start : line.start, line.end > range.end ? range.end : line.end)}\n',
        )
        .join();
    final String info = data.info.trim().split(RegExp('[ \t]+')).first;
    return ShapeNode(
      'codeBlock',
      attributes: <String, String>{'info': info},
      text: text,
    );
  }

  ShapeNode table(MdBlock table) {
    final List<MdBlock> rows = table.blocks;
    final List<MdBlock> headerCells = rows.isEmpty
        ? const <MdBlock>[]
        : rows.first.blocks;
    final int columns = headerCells.length;
    final List<String> alignments = <String>[
      for (final MdBlock cell in headerCells)
        (cell.data! as MdTableCellData).alignment.name,
    ];
    return ShapeNode(
      'table',
      attributes: <String, String>{'alignment': alignments.join(',')},
      children: <ShapeNode>[
        for (final MdBlock row in rows)
          ShapeNode(
            'tableRow',
            children: <ShapeNode>[
              for (int c = 0; c < columns; c++)
                c < row.blocks.length
                    ? ShapeNode(
                        'tableCell',
                        children: inlines(row.blocks[c].inlines),
                      )
                    : ShapeNode('tableCell'),
            ],
          ),
      ],
    );
  }

  List<ShapeNode> inlines(List<MdInline> nodes) =>
      _normaliseInlines(_rawInlines(nodes));

  List<ShapeNode> _rawInlines(List<MdInline> nodes) => <ShapeNode>[
    for (final MdInline node in nodes) inline(node),
  ];

  ShapeNode inline(MdInline node) {
    final MdInlineData? data = node.data;
    switch (node.kind) {
      case MdInlineKind.text:
        return ShapeNode('text', text: visibleRange(node.sourceRange));
      case MdInlineKind.escape:
        return ShapeNode('text', text: visibleRange(node.contentRange));
      case MdInlineKind.softBreak:
        return ShapeNode('softBreak');
      case MdInlineKind.hardBreak:
        return ShapeNode('hardBreak');
      case MdInlineKind.codeSpan:
        return ShapeNode(
          'codeSpan',
          text: _codeSpanText(visibleRange(node.contentRange)),
        );
      case MdInlineKind.emphasis:
        return ShapeNode('emphasis', children: _rawInlines(node.children));
      case MdInlineKind.strong:
        return ShapeNode('strong', children: _rawInlines(node.children));
      case MdInlineKind.strikethrough:
        return ShapeNode('strikethrough', children: _rawInlines(node.children));
      case MdInlineKind.highlight:
        return ShapeNode('highlight', children: _rawInlines(node.children));
      case MdInlineKind.link:
        final MdLinkData link = data! as MdLinkData;
        return ShapeNode(
          'link',
          attributes: _linkAttributes(link.destination, link.title),
          children: _rawInlines(node.children),
        );
      case MdInlineKind.autolink:
        final MdAutolinkData autolink = data! as MdAutolinkData;
        return ShapeNode(
          'link',
          attributes: _linkAttributes(
            autolink.kind == MdAutolinkKind.email
                ? 'mailto:${autolink.target}'
                : autolink.target,
            null,
          ),
          children: <ShapeNode>[ShapeNode('text', text: autolink.target)],
        );
    }
  }
}
