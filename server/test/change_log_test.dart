import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<SignedIn> enrolAndSignIn({String note = 'Journal'}) async {
    final TestAccount account = await harness.enrol(note: note);
    return harness.signIn(account.firstDevice);
  }

  int recordCount(String accountId) => harness.database.count(
    'SELECT count(*) FROM records WHERE account_id = ?',
    <Object?>[accountId],
  );

  test("another account's records cannot be read or written", () async {
    final TestAccount mine = await harness.enrol(note: 'Mine');
    final TestAccount theirs = await harness.enrol(note: 'Theirs');
    final SignedIn me = await harness.signIn(mine.firstDevice);
    final SignedIn them = await harness.signIn(theirs.firstDevice);
    final PushResponse first = await harness.push(me.session, <RecordPush>[
      harness.record('shared-key', envelope: bytes('mine v1')),
    ]);
    expect(first.results.single.status, PushStatus.accepted);
    expect(first.results.single.seq, 1);

    final PullResponse theirPull = await harness.pull(them.session);

    expect(theirPull.states, isEmpty);
    expect(theirPull.latestSeq, 0);
    expect(theirPull.remaining, 0);

    final PushResponse overwrite = await harness.push(
      them.session,
      <RecordPush>[
        harness.record('shared-key', baseSeq: 1, envelope: bytes('theirs')),
      ],
    );

    expect(overwrite.results.single.status, PushStatus.stale);
    expect(overwrite.results.single.current, isNull);

    final PushResponse ownCopy = await harness.push(them.session, <RecordPush>[
      harness.record('shared-key', envelope: bytes('theirs')),
    ]);
    expect(ownCopy.results.single.status, PushStatus.accepted);

    final PullResponse myPull = await harness.pull(me.session);
    expect(myPull.states.single.envelope, bytes('mine v1'));
    expect(myPull.states.single.seq, 1);
    expect(myPull.latestSeq, 1);
    expect(
      (await harness.pull(them.session)).states.single.envelope,
      bytes('theirs'),
    );
    final Row stored = harness.database.selectOne(
      'SELECT envelope, seq FROM records WHERE account_id = ? AND record_key = ?',
      <Object?>[mine.accountId, 'shared-key'],
    )!;
    expect(stored['envelope'], bytes('mine v1'));
    expect(stored['seq'], 1);
    expect(recordCount(mine.accountId), 1);
  });

  test('a retried push is stored once', () async {
    final SignedIn me = await enrolAndSignIn();
    final RecordPush change = harness.record(
      'note-1',
      envelope: bytes('first'),
    );

    final PushResponse first = await harness.push(me.session, <RecordPush>[
      change,
    ]);
    final PushResponse retried = await harness.push(me.session, <RecordPush>[
      change,
    ]);
    final PushResponse altered = await harness.push(me.session, <RecordPush>[
      harness.record(
        'note-1',
        baseSeq: 1,
        changeId: change.changeId,
        envelope: bytes('altered'),
      ),
    ]);

    expect(
      first.results.single,
      RecordPushResult(
        changeId: change.changeId,
        status: PushStatus.accepted,
        seq: 1,
      ),
    );
    expect(
      retried.results.single,
      RecordPushResult(
        changeId: change.changeId,
        status: PushStatus.duplicate,
        seq: 1,
      ),
    );
    expect(altered.results.single.status, PushStatus.duplicate);
    expect(altered.results.single.seq, 1);
    final PullResponse pulled = await harness.pull(me.session);
    expect(pulled.states, hasLength(1));
    expect(pulled.states.single.envelope, bytes('first'));
    expect(pulled.latestSeq, 1);
    expect(harness.database.count('SELECT count(*) FROM records'), 1);
    expect(harness.database.count('SELECT count(*) FROM change_ids'), 1);
    expect(harness.database.count('SELECT max(last_seq) FROM account_seqs'), 1);
  });

  test('a stale push is rejected with the current state', () async {
    final SignedIn me = await enrolAndSignIn();
    await harness.push(me.session, <RecordPush>[
      harness.record('note-1', envelope: bytes('v1')),
    ]);
    await harness.push(me.session, <RecordPush>[
      harness.record('note-1', baseSeq: 1, envelope: bytes('v2')),
    ]);

    final PushResponse stale = await harness.push(me.session, <RecordPush>[
      harness.record('note-1', baseSeq: 1, envelope: bytes('late edit')),
    ]);

    final RecordPushResult result = stale.results.single;
    expect(result.status, PushStatus.stale);
    expect(result.seq, isNull);
    expect(
      result.current,
      RecordState(recordKey: 'note-1', seq: 2, epoch: 1, envelope: bytes('v2')),
    );
    final PullResponse pulled = await harness.pull(me.session);
    expect(pulled.latestSeq, 2);
    expect(pulled.states.single.envelope, bytes('v2'));

    final PushResponse merged = await harness.push(me.session, <RecordPush>[
      harness.record('note-1', baseSeq: 2, envelope: bytes('merged')),
    ]);
    expect(merged.results.single.status, PushStatus.accepted);
    expect(merged.results.single.seq, 3);
  });

  test(
    'a pull returns only the latest state per record above the cursor',
    () async {
      final SignedIn me = await enrolAndSignIn();
      for (int version = 1; version <= 3; version++) {
        final PushResponse pushed = await harness.push(me.session, <RecordPush>[
          harness.record(
            'note-1',
            baseSeq: version - 1,
            envelope: bytes('v$version'),
          ),
        ]);
        expect(pushed.results.single.seq, version);
      }

      final PullResponse fromStart = await harness.pull(me.session);

      expect(fromStart.states, <RecordState>[
        RecordState(
          recordKey: 'note-1',
          seq: 3,
          epoch: 1,
          envelope: bytes('v3'),
        ),
      ]);

      await harness.push(me.session, <RecordPush>[harness.record('note-2')]);
      final PullResponse fromCursor = await harness.pull(me.session, after: 3);
      final PullResponse beforeLast = await harness.pull(me.session, after: 2);

      expect(
        fromCursor.states.map((RecordState state) => state.recordKey),
        <String>['note-2'],
      );
      expect(beforeLast.states.map((RecordState state) => state.seq), <int>[
        3,
        4,
      ]);
      expect(harness.database.count('SELECT count(*) FROM records'), 2);
    },
  );

  test('a push under an old epoch is refused with stale_epoch', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice second = harness.addDevice(account);
    final TestDevice third = harness.addDevice(account);
    final SignedIn remover = await harness.signIn(account.firstDevice);
    final SignedIn writer = await harness.signIn(second);
    await harness.push(writer.session, <RecordPush>[
      harness.record('note-1', envelope: bytes('v1')),
    ]);
    final http.Response removed = await harness.removeDevice(
      remover,
      third.deviceId,
      harness.rotation(
        signer: account.firstDevice,
        epoch: 2,
        recipients: <String>[
          account.firstDevice.recipient,
          second.recipient,
          EpochKeyDelivery.recoveryRecipient,
        ],
      ),
    );
    expect(removed.statusCode, HttpStatus.noContent);

    final PushResponse old = await harness.push(writer.session, <RecordPush>[
      harness.record('note-1', baseSeq: 1, envelope: bytes('v2')),
      harness.record('note-2'),
    ]);

    for (final RecordPushResult result in old.results) {
      expect(result.status, PushStatus.staleEpoch);
      expect(result.seq, isNull);
      expect(result.current, isNull);
    }
    final PullResponse pulled = await harness.pull(writer.session);
    expect(pulled.currentEpoch, 2);
    expect(pulled.latestSeq, 1);
    expect(pulled.states.single.envelope, bytes('v1'));
    expect(recordCount(account.accountId), 1);

    final PushResponse current = await harness.push(
      writer.session,
      <RecordPush>[
        harness.record('note-1', baseSeq: 1, epoch: 2, envelope: bytes('v2')),
      ],
    );
    expect(current.results.single.status, PushStatus.accepted);
    expect(current.results.single.seq, 2);
  });

  test('a pull reports how many states remain', () async {
    final SignedIn me = await enrolAndSignIn();
    await harness.push(me.session, <RecordPush>[
      for (int index = 0; index < 5; index++) harness.record('note-$index'),
    ]);

    final PullResponse first = await harness.pull(me.session, limit: 2);
    final PullResponse second = await harness.pull(
      me.session,
      after: first.states.last.seq,
      limit: 2,
    );
    final PullResponse last = await harness.pull(
      me.session,
      after: second.states.last.seq,
      limit: 2,
    );

    expect(first.states.map((RecordState state) => state.seq), <int>[1, 2]);
    expect(first.remaining, 3);
    expect(first.hasMore, isTrue);
    expect(second.states.map((RecordState state) => state.seq), <int>[3, 4]);
    expect(second.remaining, 1);
    expect(second.hasMore, isTrue);
    expect(last.states.map((RecordState state) => state.seq), <int>[5]);
    expect(last.remaining, 0);
    expect(last.hasMore, isFalse);
    final PullResponse capped = await harness.pull(me.session, limit: 501);
    expect(capped.states, hasLength(5));
    expect(capped.remaining, 0);
  });

  test(
    "latestSeq is the account's highest sequence number on every page",
    () async {
      final SignedIn empty = await enrolAndSignIn(note: 'Empty');
      final PullResponse nothing = await harness.pull(empty.session);
      expect(nothing.states, isEmpty);
      expect(nothing.latestSeq, 0);

      final SignedIn me = await enrolAndSignIn();
      await harness.push(me.session, <RecordPush>[
        for (int index = 0; index < 5; index++) harness.record('note-$index'),
      ]);
      await harness.push(me.session, <RecordPush>[
        harness.record('note-0', baseSeq: 1),
      ]);

      final List<PullResponse> pages = <PullResponse>[
        await harness.pull(me.session, limit: 2),
        await harness.pull(me.session, after: 3, limit: 2),
        await harness.pull(me.session, after: 5, limit: 2),
        await harness.pull(me.session, after: 6, limit: 2),
      ];

      expect(
        pages.map(
          (PullResponse page) => <int>[
            for (final RecordState state in page.states) state.seq,
          ],
        ),
        <List<int>>[
          <int>[2, 3],
          <int>[4, 5],
          <int>[6],
          <int>[],
        ],
      );
      for (final PullResponse page in pages) {
        expect(page.latestSeq, 6);
      }
      expect(pages.last.remaining, 0);
      expect(pages.last.hasMore, isFalse);
    },
  );

  test('a push above the current epoch is refused', () async {
    final SignedIn me = await enrolAndSignIn();

    final PushResponse ahead = await harness.push(me.session, <RecordPush>[
      harness.record('note-1', epoch: 2),
    ]);

    expect(ahead.results.single.status, PushStatus.staleEpoch);
    expect(ahead.results.single.seq, isNull);
    expect(harness.database.count('SELECT count(*) FROM records'), 0);
    expect((await harness.pull(me.session)).latestSeq, 0);

    final PushResponse current = await harness.push(me.session, <RecordPush>[
      harness.record('note-1'),
    ]);
    expect(current.results.single.status, PushStatus.accepted);
    expect(current.results.single.seq, 1);
  });
}
