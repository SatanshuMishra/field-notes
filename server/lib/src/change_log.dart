import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'database.dart';

const int defaultPullLimit = 500;
const int maxPullLimit = 500;
const int maxRecordKeyLength = 128;

final RegExp _recordKeyPattern = RegExp(r'^[A-Za-z0-9_-]+$');

final class PushOutcome {
  const PushOutcome({required this.response, required this.acceptedSeq});

  final PushResponse response;
  final int? acceptedSeq;
}

final class PullQuery {
  const PullQuery({required this.after, required this.limit});

  factory PullQuery.parse(Map<String, String> query) {
    final int after = _parse(query[SyncRoutes.afterQuery], 0);
    final int limit = _parse(query[SyncRoutes.limitQuery], defaultPullLimit);
    if (after < 0 || limit < 1) {
      throw const RelayException(SyncErrorCode.badRequest);
    }
    return PullQuery(
      after: after,
      limit: limit > maxPullLimit ? maxPullLimit : limit,
    );
  }

  final int after;
  final int limit;

  static int _parse(String? value, int fallback) {
    if (value == null || value.isEmpty) {
      return fallback;
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null) {
      throw const RelayException(SyncErrorCode.badRequest);
    }
    return parsed;
  }
}

void _validate(RecordPush change) {
  if (!isSyncId(change.changeId) ||
      change.recordKey.isEmpty ||
      change.recordKey.length > maxRecordKeyLength ||
      !_recordKeyPattern.hasMatch(change.recordKey) ||
      change.epoch < 1 ||
      change.baseSeq < 0) {
    throw const RelayException(SyncErrorCode.badRequest, 'Invalid record');
  }
}

final class ChangeLog {
  ChangeLog(this._database, this._clock);

  final RelayDatabase _database;
  final DateTime Function() _clock;

  PushOutcome push(Caller caller, PushRequest request) {
    request.changes.forEach(_validate);
    final int now = toMillis(_clock());
    return _database.transaction(() {
      final int currentEpoch = _currentEpoch(caller.accountId);
      int lastSeq = latestSeq(caller.accountId);
      int? acceptedSeq;
      final List<RecordPushResult> results = <RecordPushResult>[];
      for (final RecordPush change in request.changes) {
        final Row? duplicate = _database.selectOne(
          'SELECT seq FROM change_ids WHERE account_id = ? AND change_id = ?',
          <Object?>[caller.accountId, change.changeId],
        );
        if (duplicate != null) {
          results.add(
            RecordPushResult(
              changeId: change.changeId,
              status: PushStatus.duplicate,
              seq: duplicate['seq'] as int,
            ),
          );
          continue;
        }
        if (change.epoch != currentEpoch) {
          results.add(
            RecordPushResult(
              changeId: change.changeId,
              status: PushStatus.staleEpoch,
            ),
          );
          continue;
        }
        final RecordState? stored = _state(caller.accountId, change.recordKey);
        final bool matches = stored == null
            ? change.baseSeq == 0
            : stored.seq == change.baseSeq;
        if (!matches) {
          results.add(
            RecordPushResult(
              changeId: change.changeId,
              status: PushStatus.stale,
              current: caller.kind == CallerKind.session ? stored : null,
            ),
          );
          continue;
        }
        lastSeq += 1;
        _database.execute(
          'INSERT INTO records (account_id, record_key, seq, epoch, envelope, '
          'change_id, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT (account_id, record_key) DO UPDATE SET '
          'seq = excluded.seq, epoch = excluded.epoch, '
          'envelope = excluded.envelope, change_id = excluded.change_id, '
          'updated_at = excluded.updated_at',
          <Object?>[
            caller.accountId,
            change.recordKey,
            lastSeq,
            change.epoch,
            change.envelope,
            change.changeId,
            now,
          ],
        );
        _database.execute(
          'INSERT INTO change_ids (account_id, change_id, seq) VALUES (?, ?, ?)',
          <Object?>[caller.accountId, change.changeId, lastSeq],
        );
        _database.execute(
          'INSERT INTO account_seqs (account_id, last_seq) VALUES (?, ?) '
          'ON CONFLICT (account_id) DO UPDATE SET last_seq = excluded.last_seq',
          <Object?>[caller.accountId, lastSeq],
        );
        acceptedSeq = lastSeq;
        results.add(
          RecordPushResult(
            changeId: change.changeId,
            status: PushStatus.accepted,
            seq: lastSeq,
          ),
        );
      }
      return PushOutcome(
        response: PushResponse(results: results),
        acceptedSeq: acceptedSeq,
      );
    });
  }

  PullResponse pull(String accountId, PullQuery query) => _database.read(() {
    final List<RecordState> states = <RecordState>[
      for (final Row row in _database.select(
        'SELECT record_key, seq, epoch, envelope FROM records '
        'WHERE account_id = ? AND seq > ? ORDER BY seq LIMIT ?',
        <Object?>[accountId, query.after, query.limit],
      ))
        _toState(row),
    ];
    final int lastReturned = states.isEmpty ? query.after : states.last.seq;
    final int remaining = _database.count(
      'SELECT count(*) FROM records WHERE account_id = ? AND seq > ?',
      <Object?>[accountId, lastReturned],
    );
    return PullResponse(
      states: states,
      latestSeq: latestSeq(accountId),
      hasMore: remaining > 0,
      remaining: remaining,
      currentEpoch: _currentEpoch(accountId),
      generation: _database.generation(),
    );
  });

  int latestSeq(String accountId) =>
      _database.selectOne(
            'SELECT last_seq FROM account_seqs WHERE account_id = ?',
            <Object?>[accountId],
          )?['last_seq']
          as int? ??
      0;

  int _currentEpoch(String accountId) {
    final Row? row = _database.selectOne(
      'SELECT current_epoch FROM accounts WHERE id = ?',
      <Object?>[accountId],
    );
    if (row == null) {
      throw const RelayException(SyncErrorCode.journalErased);
    }
    return row['current_epoch'] as int;
  }

  RecordState? _state(String accountId, String recordKey) {
    final Row? row = _database.selectOne(
      'SELECT record_key, seq, epoch, envelope FROM records '
      'WHERE account_id = ? AND record_key = ?',
      <Object?>[accountId, recordKey],
    );
    return row == null ? null : _toState(row);
  }

  static RecordState _toState(Row row) => RecordState(
    recordKey: row['record_key'] as String,
    seq: row['seq'] as int,
    epoch: row['epoch'] as int,
    envelope: row['envelope'] as Uint8List,
  );
}
