import 'dart:convert';

import 'package:field_notes/domain/updates/updates.dart';

const int releaseNotesIntroLimit = 2000;
const int releaseNotesGroupLimit = 12;
const int releaseNotesItemsPerGroup = 40;
const int releaseNotesItemLimit = 500;

const String _ellipsis = '…';

const int _closeBracket = 0x5D;
const int _closeParen = 0x29;
const int _closeAngle = 0x3E;
const int _backtick = 0x60;

const List<String Function(String)> _markupPasses = <String Function(String)>[
  _withoutComments,
  _withoutImages,
  _linksAsText,
  _withoutTags,
  _codeAsText,
  _strongAsText,
  _emphasisAsText,
  _strongUnderscoreAsText,
  _underscoreAsText,
];

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _indented = RegExp(r'^ {2,}\S');
final RegExp _sectionHeading = RegExp(r'^## \[([^\]]+)\](.*)$');
final RegExp _sectionDate = RegExp(r'^ - (\d{4})-(\d{2})-(\d{2})\s*$');

class ChangelogSection {
  const ChangelogSection({required this.notes, this.date});

  final ReleaseNotes notes;
  final DateTime? date;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangelogSection && notes == other.notes && date == other.date;

  @override
  int get hashCode => Object.hash(notes, date);

  @override
  String toString() => 'ChangelogSection(notes: $notes, date: $date)';
}

ReleaseNotes parseReleaseNotes(String markdown) {
  final List<String> introParagraphs = <String>[];
  final List<String> paragraph = <String>[];
  final List<_GroupDraft> groups = <_GroupDraft>[];
  List<String>? openItem;

  void closeParagraph() {
    if (paragraph.isEmpty) {
      return;
    }
    final String text = plainReleaseText(paragraph.join(' '));
    if (text.isNotEmpty) {
      introParagraphs.add(text);
    }
    paragraph.clear();
  }

  for (final String line in const LineSplitter().convert(markdown)) {
    if (line.startsWith('## ')) {
      break;
    }
    if (line.startsWith('### ')) {
      closeParagraph();
      openItem = null;
      groups.add(_GroupDraft(line.substring(4)));
      continue;
    }
    if (groups.isEmpty) {
      if (line.trim().isEmpty) {
        closeParagraph();
      } else {
        paragraph.add(line.trim());
      }
      continue;
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      final List<String> item = <String>[line.substring(2)];
      groups.last.items.add(item);
      openItem = item;
      continue;
    }
    if (openItem != null && _indented.hasMatch(line)) {
      openItem.add(line.trim());
      continue;
    }
    openItem = null;
  }
  closeParagraph();

  final List<ReleaseNoteGroup> kept = <ReleaseNoteGroup>[];
  for (final _GroupDraft draft in groups) {
    if (kept.length == releaseNotesGroupLimit) {
      break;
    }
    final List<String> items = <String>[];
    for (final List<String> parts in draft.items) {
      if (items.length == releaseNotesItemsPerGroup) {
        break;
      }
      final String text = _capped(
        plainReleaseText(parts.join(' ')),
        releaseNotesItemLimit,
      );
      if (text.isNotEmpty) {
        items.add(text);
      }
    }
    final String title = _capped(
      plainReleaseText(draft.title),
      releaseNotesItemLimit,
    );
    if (items.isEmpty) {
      continue;
    }
    kept.add(ReleaseNoteGroup(title: title, items: items));
  }

  final String intro = _capped(
    introParagraphs.join('\n\n'),
    releaseNotesIntroLimit,
  );
  if (intro.isEmpty && kept.isEmpty) {
    return ReleaseNotes.empty;
  }
  return ReleaseNotes(intro: intro, groups: kept);
}

ChangelogSection? changelogSection(String changelog, AppVersion version) {
  final List<String> lines = const LineSplitter().convert(changelog);
  for (int index = 0; index < lines.length; index++) {
    final RegExpMatch? heading = _sectionHeading.firstMatch(lines[index]);
    if (heading == null) {
      continue;
    }
    final AppVersion? found = AppVersion.tryParse(heading.group(1)!.trim());
    if (found != version) {
      continue;
    }
    return ChangelogSection(
      notes: parseReleaseNotes(lines.skip(index + 1).join('\n')),
      date: _date(heading.group(2)!),
    );
  }
  return null;
}

String plainReleaseText(String text) {
  final String plain = _markupPasses.fold(
    text,
    (String current, String Function(String) pass) => pass(current),
  );
  return plain.replaceAll(_whitespace, ' ').trim();
}

typedef _Replacement = ({int start, int end, String text});

String _replaced(String text, _Replacement? Function(int from) next) {
  final StringBuffer replaced = StringBuffer();
  int kept = 0;
  for (_Replacement? match = next(0); match != null; match = next(match.end)) {
    replaced
      ..write(text.substring(kept, match.start))
      ..write(match.text);
    kept = match.end;
  }
  replaced.write(text.substring(kept));
  return replaced.toString();
}

String _withoutComments(String text) => _replaced(text, (int from) {
  final int open = text.indexOf('<!--', from);
  final int close = open < 0 ? -1 : text.indexOf('-->', open + 4);
  return close < 0 ? null : (start: open, end: close + 3, text: ' ');
});

String _withoutImages(String text) =>
    _bracketed(text, '![', (String label) => ' ');

String _linksAsText(String text) =>
    _bracketed(text, '[', (String label) => label);

String _bracketed(
  String text,
  String opener,
  String Function(String label) replacement,
) {
  final _Seeker labelEnd = _Seeker(
    text,
    (int index) => text.codeUnitAt(index) == _closeBracket,
  );
  final _Seeker targetEnd = _Seeker(
    text,
    (int index) => text.codeUnitAt(index) == _closeParen,
  );
  return _replaced(text, (int from) {
    for (
      int open = text.indexOf(opener, from);
      open >= 0;
      open = text.indexOf(opener, open + 1)
    ) {
      final int label = open + opener.length;
      final int close = labelEnd.from(label);
      if (close == text.length) {
        return null;
      }
      if (!text.startsWith('(', close + 1)) {
        continue;
      }
      final int end = targetEnd.from(close + 2);
      if (end == text.length) {
        return null;
      }
      return (
        start: open,
        end: end + 1,
        text: replacement(text.substring(label, close)),
      );
    }
    return null;
  });
}

String _withoutTags(String text) {
  final _Seeker tagEnd = _Seeker(
    text,
    (int index) => text.codeUnitAt(index) == _closeAngle,
  );
  return _replaced(text, (int from) {
    for (
      int open = text.indexOf('<', from);
      open >= 0;
      open = text.indexOf('<', open + 1)
    ) {
      final int name = text.startsWith('/', open + 1) ? open + 2 : open + 1;
      if (name < text.length && _isAsciiLetter(text.codeUnitAt(name))) {
        final int close = tagEnd.from(name + 1);
        return close == text.length
            ? null
            : (start: open, end: close + 1, text: ' ');
      }
    }
    return null;
  });
}

String _codeAsText(String text) => _replaced(text, (int from) {
  final int open = text.indexOf('`', from);
  if (open < 0) {
    return null;
  }
  final int content = _backtickRunEnd(text, open);
  final int close = text.indexOf('`', content);
  if (close >= 0) {
    return (
      start: open,
      end: _backtickRunEnd(text, close),
      text: text.substring(content, close),
    );
  }
  return content - open > 1 ? (start: open, end: content, text: '') : null;
});

int _backtickRunEnd(String text, int start) {
  int end = start;
  while (end < text.length && text.codeUnitAt(end) == _backtick) {
    end++;
  }
  return end;
}

String _strongAsText(String text) =>
    _delimitedAsText(text, '**', wordBounded: false);

String _emphasisAsText(String text) =>
    _delimitedAsText(text, '*', wordBounded: false);

String _strongUnderscoreAsText(String text) =>
    _delimitedAsText(text, '__', wordBounded: true);

String _underscoreAsText(String text) =>
    _delimitedAsText(text, '_', wordBounded: true);

String _delimitedAsText(String text, String mark, {required bool wordBounded}) {
  bool atWordEdge(int index) =>
      !wordBounded ||
      index < 0 ||
      index >= text.length ||
      !_isAsciiWordUnit(text.codeUnitAt(index));
  final _Seeker closer = _Seeker(
    text,
    (int index) =>
        text.startsWith(mark, index) &&
        !_isSpace(text.codeUnitAt(index - 1)) &&
        atWordEdge(index + mark.length),
  );
  final _Seeker lineBreak = _Seeker(
    text,
    (int index) => _isLineBreak(text.codeUnitAt(index)),
  );
  return _replaced(text, (int from) {
    for (
      int open = text.indexOf(mark, from);
      open >= 0;
      open = text.indexOf(mark, open + 1)
    ) {
      final int content = open + mark.length;
      if (!atWordEdge(open - 1) ||
          content == text.length ||
          _isSpace(text.codeUnitAt(content))) {
        continue;
      }
      final int close = closer.from(content + 1);
      if (close == text.length) {
        return null;
      }
      if (close < lineBreak.from(content)) {
        return (
          start: open,
          end: close + mark.length,
          text: text.substring(content, close),
        );
      }
    }
    return null;
  });
}

bool _isSpace(int unit) =>
    (unit >= 0x09 && unit <= 0x0D) ||
    unit == 0x20 ||
    unit == 0xA0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200A) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202F ||
    unit == 0x205F ||
    unit == 0x3000 ||
    unit == 0xFEFF;

bool _isLineBreak(int unit) =>
    unit == 0x0A || unit == 0x0D || unit == 0x2028 || unit == 0x2029;

bool _isAsciiLetter(int unit) =>
    (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);

bool _isAsciiWordUnit(int unit) =>
    _isAsciiLetter(unit) || (unit >= 0x30 && unit <= 0x39);

String _capped(String text, int limit) {
  final List<int> runes = text.runes.toList();
  if (runes.length <= limit) {
    return text;
  }
  final String kept = String.fromCharCodes(runes.take(limit - 1)).trimRight();
  return '$kept$_ellipsis';
}

DateTime? _date(String suffix) {
  final RegExpMatch? match = _sectionDate.firstMatch(suffix);
  if (match == null) {
    return null;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  final DateTime date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

final class _GroupDraft {
  _GroupDraft(this.title);

  final String title;
  final List<List<String>> items = <List<String>>[];
}

final class _Seeker {
  _Seeker(this._text, this._matches);

  final String _text;
  final bool Function(int index) _matches;
  int _start = 0;
  int _found = -1;

  int from(int start) {
    if (start >= _start && _found >= start) {
      return _found;
    }
    int index = start;
    while (index < _text.length && !_matches(index)) {
      index++;
    }
    _start = start;
    _found = index;
    return index;
  }
}
