import 'dart:convert';

import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/data/updates/github_release_source.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const Duration _parseBudget = Duration(milliseconds: 500);
const Duration _lookupBudget = Duration(seconds: 2);
const int _runs = 2;
const int _largeBody = 900 * 1024;

String _fill(String unit, int bytes) => unit * (bytes ~/ unit.length);

final List<(String, String)> _hostile = <(String, String)>[
  ('open brackets, 20 KB', _fill('[', 20 * 1024)),
  ('open brackets', _fill('[', _largeBody)),
  ('image openers', _fill('![', _largeBody)),
  ('unclosed links', _fill('[a](', _largeBody)),
  ('open tags', _fill('<a', _largeBody)),
  ('open comments', _fill('<!--', _largeBody)),
  ('lone stars', _fill('*a ', _largeBody)),
  ('double stars', _fill('**a ', _largeBody)),
  ('lone underscores', _fill('_a ', _largeBody)),
  ('double underscores', _fill('__a ', _largeBody)),
  ('backticks', _fill('`a', _largeBody)),
  ('one long item', '### New\n- ${_fill('[', _largeBody)}'),
  ('many items', '### New\n${_fill('- [x\n', _largeBody)}'),
  ('many groups', _fill('### [\n- [\n', _largeBody)),
  (
    'many long items',
    _fill('### [g\n${'- ${'[' * 1900}\n' * 40}', _largeBody),
  ),
  ('many long paragraphs', _fill('${'[' * 1900}\n\n', _largeBody)),
  ('many long titles', _fill('### ${'[' * 1900}\n- a\n', _largeBody)),
];

void _expectCapped(ReleaseNotes notes, String name) {
  expect(
    notes.intro.runes.length,
    lessThanOrEqualTo(releaseNotesIntroLimit),
    reason: name,
  );
  expect(
    notes.groups.length,
    lessThanOrEqualTo(releaseNotesGroupLimit),
    reason: name,
  );
  for (final ReleaseNoteGroup group in notes.groups) {
    expect(
      group.items.length,
      lessThanOrEqualTo(releaseNotesItemsPerGroup),
      reason: name,
    );
    expect(
      group.title.runes.length,
      lessThanOrEqualTo(releaseNotesItemLimit),
      reason: name,
    );
    for (final String item in group.items) {
      expect(
        item.runes.length,
        lessThanOrEqualTo(releaseNotesItemLimit),
        reason: name,
      );
    }
  }
}

String _releaseJson(String body) => jsonEncode(<String, Object?>{
  'tag_name': 'v1.2.0',
  'name': 'Field Notes 1.2.0',
  'draft': false,
  'prerelease': false,
  'published_at': '2026-10-09T15:30:00Z',
  'html_url':
      'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.2.0',
  'body': body,
  'assets': <Object?>[],
});

void main() {
  test('hostile release notes parse within half a second', () {
    for (final (String name, String body) in _hostile) {
      for (int run = 0; run < _runs; run++) {
        final Stopwatch watch = Stopwatch()..start();
        final ReleaseNotes notes = parseReleaseNotes(body);
        watch.stop();
        expect(
          watch.elapsed,
          lessThan(_parseBudget),
          reason: '$name, run ${run + 1}',
        );
        _expectCapped(notes, name);
      }
    }
  });

  test('a hostile release body cannot hold the lookup past two seconds', () async {
    for (final (String name, String body) in <(String, String)>[
      _hostile.first,
      _hostile[1],
      _hostile[5],
      _hostile[14],
    ]) {
      for (int run = 0; run < _runs; run++) {
        final GitHubReleaseSource source = GitHubReleaseSource(
          client: MockClient(
            (http.Request request) async => http.Response(
              _releaseJson(body),
              200,
              headers: <String, String>{
                'content-type': 'application/json; charset=utf-8',
              },
            ),
          ),
          clock: () => DateTime.utc(2026, 10, 11, 9),
        );
        final Stopwatch watch = Stopwatch()..start();
        final ReleaseLookup lookup = await source.latest();
        watch.stop();
        expect(
          watch.elapsed,
          lessThan(_lookupBudget),
          reason: '$name, run ${run + 1}',
        );
        expect(lookup, isA<ReleaseFound>(), reason: '$name, run ${run + 1}');
      }
    }
  });

  test('ordinary release notes keep their plain text', () {
    final ReleaseNotes notes = parseReleaseNotes('''
Settings has a **new** look.

### New
- An About page with the [version](https://github.com/SatanshuMishra/field-notes).
- Checks for updates
  once a day.
### Fixed
- <em>Faster</em> start with `code` and _care_.
''');
    expect(notes.intro, 'Settings has a new look.');
    expect(notes.groups.map((ReleaseNoteGroup group) => group.title), <String>[
      'New',
      'Fixed',
    ]);
    expect(notes.groups.first.items, <String>[
      'An About page with the version.',
      'Checks for updates once a day.',
    ]);
    expect(notes.groups.last.items, <String>[
      'Faster start with code and care.',
    ]);
  });
}
