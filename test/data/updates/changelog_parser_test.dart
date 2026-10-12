import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter_test/flutter_test.dart';

const String _releaseBody = '''
Field Notes 1.2.0 gives **Settings** a fresh look.
It also checks for _updates_ by itself.

A second paragraph with a [changelog link](https://github.com/SatanshuMishra/field-notes) and `inline code`.
<!-- a hidden comment -->
![screenshot](https://github.com/SatanshuMishra/field-notes/raw/main/shot.png)

### New
- An **About** page with the *version*.
- Check for updates
  once a day,
    without asking.
* A star item with <b>bold</b> HTML and <img src="x.png"> an image tag.
- Keeps snake_case like field_notes_app and sums like 2 * 3 * 4.

### Fixed
- A __fixed__ bug.
A stray paragraph line that belongs to no item.
  - and an indented line after it that continues nothing.
- Second fix.

## Installing
Download field-notes-1.2.0-macos.dmg and open it.
### Not a group
- Not an item.
''';

String _repeat(String text, int times) =>
    List<String>.filled(times, text).join();

void main() {
  test('release notes keep the intro, groups and items as plain text', () {
    final ReleaseNotes notes = parseReleaseNotes(_releaseBody);
    expect(
      notes.intro,
      'Field Notes 1.2.0 gives Settings a fresh look. It also checks for '
      'updates by itself.\n\nA second paragraph with a changelog link and '
      'inline code.',
    );
    expect(notes.groups, <ReleaseNoteGroup>[
      ReleaseNoteGroup(
        title: 'New',
        items: <String>[
          'An About page with the version.',
          'Check for updates once a day, without asking.',
          'A star item with bold HTML and an image tag.',
          'Keeps snake_case like field_notes_app and sums like 2 * 3 * 4.',
        ],
      ),
      ReleaseNoteGroup(
        title: 'Fixed',
        items: <String>['A fixed bug.', 'Second fix.'],
      ),
    ]);
    expect(parseReleaseNotes(_releaseBody.replaceAll('\n', '\r\n')), notes);

    expect(parseReleaseNotes(''), ReleaseNotes.empty);
    expect(parseReleaseNotes('').isEmpty, isTrue);
    expect(
      parseReleaseNotes('## Installing\n\n- Download the DMG.\n'),
      ReleaseNotes.empty,
    );
    expect(
      parseReleaseNotes('### Fixed\n- Only a group.\n'),
      ReleaseNotes(
        intro: '',
        groups: <ReleaseNoteGroup>[
          ReleaseNoteGroup(title: 'Fixed', items: <String>['Only a group.']),
        ],
      ),
    );
    expect(
      parseReleaseNotes('Only an intro with **no** groups.\n\n## Later\n'),
      ReleaseNotes(
        intro: 'Only an intro with no groups.',
        groups: const <ReleaseNoteGroup>[],
      ),
    );

    final String longIntro = parseReleaseNotes(_repeat('a ', 1500)).intro;
    expect(longIntro.length, 2000);
    expect(longIntro.endsWith('…'), isTrue);
    expect(
      longIntro.substring(0, 1999),
      _repeat('a ', 1000).substring(0, 1999),
    );

    final StringBuffer manyGroups = StringBuffer();
    for (int group = 1; group <= 13; group++) {
      manyGroups
        ..writeln('### Group $group')
        ..writeln('- Item of group $group.');
    }
    final ReleaseNotes capped = parseReleaseNotes(manyGroups.toString());
    expect(capped.groups, hasLength(12));
    expect(capped.groups.map((ReleaseNoteGroup group) => group.title), <String>[
      for (int group = 1; group <= 12; group++) 'Group $group',
    ]);

    final StringBuffer manyItems = StringBuffer()..writeln('### Fixed');
    for (int item = 1; item <= 41; item++) {
      manyItems.writeln('- Fix $item.');
    }
    final ReleaseNotes items = parseReleaseNotes(manyItems.toString());
    expect(items.groups.single.items, hasLength(40));
    expect(items.groups.single.items.last, 'Fix 40.');

    final String longItem = parseReleaseNotes(
      '### New\n- ${_repeat('b', 600)}\n',
    ).groups.single.items.single;
    expect(longItem.length, 500);
    expect(longItem, '${_repeat('b', 499)}…');
  });
}
