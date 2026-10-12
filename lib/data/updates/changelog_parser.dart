import 'dart:convert';

import 'package:field_notes/domain/updates/updates.dart';

const int releaseNotesIntroLimit = 2000;
const int releaseNotesGroupLimit = 12;
const int releaseNotesItemsPerGroup = 40;
const int releaseNotesItemLimit = 500;

const String _ellipsis = '…';

final RegExp _comment = RegExp(r'<!--[\s\S]*?-->');
final RegExp _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
final RegExp _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final RegExp _tag = RegExp(r'</?[A-Za-z][^>]*>');
final RegExp _code = RegExp(r'`+([^`]*)`+');
final RegExp _strong = RegExp(r'\*\*(?!\s)(.+?)(?<!\s)\*\*');
final RegExp _emphasis = RegExp(r'\*(?!\s)(.+?)(?<!\s)\*');
final RegExp _strongUnderscore = RegExp(
  r'(?<![A-Za-z0-9])__(?!\s)(.+?)(?<!\s)__(?![A-Za-z0-9])',
);
final RegExp _underscore = RegExp(
  r'(?<![A-Za-z0-9])_(?!\s)(.+?)(?<!\s)_(?![A-Za-z0-9])',
);
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
  final String plain = text
      .replaceAll(_comment, ' ')
      .replaceAll(_image, ' ')
      .replaceAllMapped(_link, (Match match) => match.group(1)!)
      .replaceAll(_tag, ' ')
      .replaceAllMapped(_code, (Match match) => match.group(1)!)
      .replaceAllMapped(_strong, (Match match) => match.group(1)!)
      .replaceAllMapped(_emphasis, (Match match) => match.group(1)!)
      .replaceAllMapped(_strongUnderscore, (Match match) => match.group(1)!)
      .replaceAllMapped(_underscore, (Match match) => match.group(1)!);
  return plain.replaceAll(_whitespace, ' ').trim();
}

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
