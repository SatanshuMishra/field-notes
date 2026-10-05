import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'accounts.dart';
import 'auth.dart';
import 'config.dart';
import 'database.dart';
import 'devices.dart';

const int exitOk = 0;
const int exitFailure = 1;
const int exitUsage = 64;

const String adminUsage = '''
Usage:
  relay                                   start the relay
  relay invite create --note <text>       create an invite and print its code
  relay invite list                       list invites
  relay invite revoke <invite-id>         revoke an unused invite
  relay account list                      list accounts
  relay account suspend <account-id>      refuse every call from an account
  relay account resume <account-id>       accept an account's calls again
  relay account delete <account-id>       erase an account and its data
  relay mark-restored                     run after restoring the relay's data
  relay snapshot-db --to <file>           write a checked copy of the database
  relay verify-copy --db <file> --media <dir> --manifest <file>
''';

final class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.note,
    required this.status,
    required this.deviceCount,
    required this.bytesStored,
    required this.lastSeen,
  });

  final String id;
  final String note;
  final String status;
  final int deviceCount;
  final int bytesStored;
  final DateTime? lastSeen;
}

final class RelayAdmin {
  RelayAdmin._(this._database, this._mediaDirectory, this.clock)
    : _accounts = Accounts(_database, clock);

  factory RelayAdmin.open(RelayConfig config, {DateTime Function()? clock}) =>
      RelayAdmin._(
        RelayDatabase.open(config.databasePath, create: false),
        config.mediaDirectory,
        clock ?? (() => DateTime.now().toUtc()),
      );

  final RelayDatabase _database;
  final String _mediaDirectory;
  final DateTime Function() clock;
  final Accounts _accounts;

  CreatedInvite createInvite(String note) => _accounts.createInvite(note);

  List<InviteSummary> listInvites() => _accounts.listInvites();

  bool revokeInvite(String id) => _accounts.revokeInvite(id);

  List<AccountSummary> listAccounts() => <AccountSummary>[
    for (final Row row in _database.select(
      'SELECT a.id AS id, a.note AS note, a.status AS status, '
      '(SELECT count(*) FROM devices d WHERE d.account_id = a.id '
      'AND d.status = ?) AS devices, '
      '(SELECT coalesce(sum(b.size), 0) FROM blobs b '
      'WHERE b.account_id = a.id) + '
      '(SELECT coalesce(sum(length(r.envelope)), 0) FROM records r '
      'WHERE r.account_id = a.id) AS bytes, '
      '(SELECT max(d.last_seen_at) FROM devices d '
      'WHERE d.account_id = a.id) AS last_seen '
      'FROM accounts a ORDER BY a.created_at, a.rowid',
      <Object?>[DeviceStatus.active.storedName],
    ))
      AccountSummary(
        id: row['id'] as String,
        note: row['note'] as String,
        status: row['status'] as String,
        deviceCount: row['devices'] as int,
        bytesStored: row['bytes'] as int,
        lastSeen: row['last_seen'] is int
            ? fromMillis(row['last_seen'] as int)
            : null,
      ),
  ];

  bool suspendAccount(String id) =>
      _accounts.setStatus(id, AccountStatus.suspended);

  bool resumeAccount(String id) =>
      _accounts.setStatus(id, AccountStatus.active);

  bool deleteAccount(String id) => _database.transaction(() {
    if (_database.count('SELECT count(*) FROM accounts WHERE id = ?', <Object?>[
          id,
        ]) ==
        0) {
      return false;
    }
    eraseAccountData(_database, _mediaDirectory, id);
    _database.execute('DELETE FROM accounts WHERE id = ?', <Object?>[id]);
    return true;
  });

  String markRestored() {
    final String generation = encodeBase64Url(randomBytes(16));
    _database.transaction(() {
      _database.execute(
        'INSERT INTO relay_meta (key, value) VALUES (?, ?) '
        'ON CONFLICT (key) DO UPDATE SET value = excluded.value',
        <Object?>[RelayDatabase.generationKey, decodeBase64Url(generation)],
      );
      _database.execute('DELETE FROM sessions');
    });
    return generation;
  }

  void close() => _database.close();
}

String markRestored(RelayConfig config) {
  final RelayAdmin admin = RelayAdmin.open(config);
  try {
    return admin.markRestored();
  } finally {
    admin.close();
  }
}

String _cell(String value) => value.replaceAll(RegExp(r'[\t\r\n]'), ' ');

String _time(DateTime? time) => time?.toUtc().toIso8601String() ?? '-';

int runAdminCommand(
  List<String> arguments, {
  required RelayConfig config,
  required StringSink out,
  required StringSink err,
  DateTime Function()? clock,
}) {
  if (arguments.isEmpty) {
    err.write(adminUsage);
    return exitUsage;
  }
  final RelayAdmin admin;
  try {
    admin = RelayAdmin.open(config, clock: clock);
  } on Object catch (error) {
    err.writeln('Cannot open ${config.databasePath}: $error');
    return exitFailure;
  }
  try {
    return _dispatch(admin, arguments, out, err);
  } finally {
    admin.close();
  }
}

int _dispatch(
  RelayAdmin admin,
  List<String> arguments,
  StringSink out,
  StringSink err,
) {
  final String command = arguments.first;
  final List<String> rest = arguments.sublist(1);
  switch (command) {
    case 'invite':
      return _invite(admin, rest, out, err);
    case 'account':
      return _account(admin, rest, out, err);
    case 'mark-restored':
      if (rest.isNotEmpty) {
        err.write(adminUsage);
        return exitUsage;
      }
      final String generation = admin.markRestored();
      out.writeln('generation\t$generation');
      out.writeln('Every session and upload pass has ended.');
      return exitOk;
    default:
      err.write(adminUsage);
      return exitUsage;
  }
}

int _invite(
  RelayAdmin admin,
  List<String> arguments,
  StringSink out,
  StringSink err,
) {
  final String? action = arguments.isEmpty ? null : arguments.first;
  final List<String> rest = arguments.isEmpty
      ? const <String>[]
      : arguments.sublist(1);
  switch (action) {
    case 'create':
      final String? note = optionValue(rest, '--note');
      if (note == null) {
        err.write(adminUsage);
        return exitUsage;
      }
      final CreatedInvite invite = admin.createInvite(note);
      out.writeln('id\t${invite.id}');
      out.writeln('code\t${invite.code}');
      out.writeln('expires\t${_time(invite.expiresAt)}');
      return exitOk;
    case 'list':
      final DateTime now = admin.clock();
      out.writeln('id\tnote\tcreated\texpires\tstate');
      for (final InviteSummary invite in admin.listInvites()) {
        out.writeln(
          <String>[
            invite.id,
            _cell(invite.note),
            _time(invite.createdAt),
            _time(invite.expiresAt),
            invite.stateAt(now).label,
          ].join('\t'),
        );
      }
      return exitOk;
    case 'revoke':
      if (rest.length != 1) {
        err.write(adminUsage);
        return exitUsage;
      }
      if (!admin.revokeInvite(rest.single)) {
        err.writeln('No unused invite ${rest.single}');
        return exitFailure;
      }
      out.writeln('revoked\t${rest.single}');
      return exitOk;
    default:
      err.write(adminUsage);
      return exitUsage;
  }
}

int _account(
  RelayAdmin admin,
  List<String> arguments,
  StringSink out,
  StringSink err,
) {
  final String? action = arguments.isEmpty ? null : arguments.first;
  final List<String> rest = arguments.isEmpty
      ? const <String>[]
      : arguments.sublist(1);
  if (action == 'list') {
    out.writeln('id\tnote\tstatus\tdevices\tbytes\tlast_seen');
    for (final AccountSummary account in admin.listAccounts()) {
      out.writeln(
        <String>[
          account.id,
          _cell(account.note),
          account.status,
          '${account.deviceCount}',
          '${account.bytesStored}',
          _time(account.lastSeen),
        ].join('\t'),
      );
    }
    return exitOk;
  }
  if (rest.length != 1) {
    err.write(adminUsage);
    return exitUsage;
  }
  final String id = rest.single;
  final (bool Function(String id), String)? operation = switch (action) {
    'suspend' => (admin.suspendAccount, 'suspended'),
    'resume' => (admin.resumeAccount, 'resumed'),
    'delete' => (admin.deleteAccount, 'deleted'),
    _ => null,
  };
  if (operation == null) {
    err.write(adminUsage);
    return exitUsage;
  }
  final (bool Function(String id) apply, String done) = operation;
  if (!apply(id)) {
    err.writeln('No account $id that can be $done');
    return exitFailure;
  }
  out.writeln('$done\t$id');
  return exitOk;
}

String? optionValue(List<String> arguments, String name) {
  for (int index = 0; index < arguments.length; index++) {
    final String argument = arguments[index];
    if (argument == name && index + 1 < arguments.length) {
      return arguments[index + 1];
    }
    if (argument.startsWith('$name=')) {
      return argument.substring(name.length + 1);
    }
  }
  return null;
}
