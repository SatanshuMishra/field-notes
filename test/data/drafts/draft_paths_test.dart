import 'package:field_notes/data/database/ids.dart';
import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String key = '01arz3ndektsv4rrffq69g5fav';

  test('relPathForDraft places the key under drafts/ with a .md extension',
      () {
    expect(relPathForDraft(key), 'drafts/$key.md');
    expect(draftFileName(key), '$key.md');
    expect(draftsSubdir, 'drafts');
  });

  test('a freshly minted id is a valid draft key', () {
    final String minted = newId();
    expect(minted.length, draftKeyLength);
    expect(isDraftKey(minted), isTrue);
    expect(isDraftKey(minted.toUpperCase()), isTrue);
  });

  test('a new-note key for a calendar date is a valid draft key', () {
    expect(newNoteDraftKey('2026-09-21'), 'new-2026-09-21');
    expect(isDraftKey('new-2026-09-21'), isTrue);
    expect(relPathForDraft('new-2026-09-21'), 'drafts/new-2026-09-21.md');
    const List<String> notDates = <String>[
      '2026-9-21',
      '../2026-09-21',
      '2026-09-21/x',
      '',
    ];
    for (final String candidate in notDates) {
      expect(
        () => newNoteDraftKey(candidate),
        throwsArgumentError,
        reason: candidate,
      );
    }
  });

  test('keys with separators, traversal or the wrong length are rejected', () {
    const List<String> rejected = <String>[
      '',
      '..',
      '../01arz3ndektsv4rrffq69g5f',
      '01arz3ndektsv4rrffq69g5fa/',
      '01arz3ndektsv4rrffq69g5fa.',
      r'01arz3ndektsv4rrffq69g5fa\',
      '01arz3ndektsv4rrffq69g5fa',
      '01arz3ndektsv4rrffq69g5favx',
      '01arz3ndektsv4rrffq69g5fai',
      '01arz3ndektsv4rrffq69g5fal',
      '01arz3ndektsv4rrffq69g5fao',
      '01arz3ndektsv4rrffq69g5fau',
      'new-2026-09-20-note-draft-x',
    ];
    for (final String candidate in rejected) {
      expect(isDraftKey(candidate), isFalse, reason: candidate);
      expect(
        () => relPathForDraft(candidate),
        throwsArgumentError,
        reason: candidate,
      );
    }
  });
}
