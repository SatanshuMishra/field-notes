import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:sync_protocol/sync_protocol.dart';

final class RelayFixture {
  RelayFixture._({
    required this.root,
    required this.config,
    required this.migrationsDirectory,
  });

  static Future<RelayFixture> start({
    String? databasePath,
    String? mediaDirectory,
    int rateBurst = RelayConfig.defaultRateBurst,
    double ratePerSecond = RelayConfig.defaultRatePerSecond,
    int rateGlobalBurst = RelayConfig.defaultRateGlobalBurst,
    double rateGlobalPerSecond = RelayConfig.defaultRateGlobalPerSecond,
    int minFreeBytes = 0,
  }) async {
    HttpOverrides.global = null;
    final Directory root = await Directory.systemTemp.createTemp(
      'relay_fixture_',
    );
    final RelayFixture fixture = RelayFixture._(
      root: root,
      config: RelayConfig(
        databasePath: databasePath ?? p.join(root.path, 'relay.sqlite3'),
        mediaDirectory: mediaDirectory ?? p.join(root.path, 'media'),
        port: 0,
        minFreeBytes: minFreeBytes,
        rateBurst: rateBurst,
        ratePerSecond: ratePerSecond,
        rateGlobalBurst: rateGlobalBurst,
        rateGlobalPerSecond: rateGlobalPerSecond,
      ),
      migrationsDirectory: _migrationsDirectory(),
    );
    await fixture.boot();
    return fixture;
  }

  final Directory root;
  final RelayConfig config;
  final String migrationsDirectory;
  final List<String> logLines = <String>[];
  Duration _offset = Duration.zero;
  RelayServer? _server;

  DateTime now() => DateTime.now().toUtc().add(_offset);

  void advance(Duration duration) {
    _offset += duration;
  }

  bool get running => _server != null;

  RelayApp get app => _server!.app;

  int get port => _server!.port;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:$port');

  String get databasePath => config.databasePath;

  String get mediaDirectory => config.mediaDirectory;

  Future<void> boot() async {
    final RelayApp app = await RelayApp.open(
      config: config,
      migrationsDirectory: migrationsDirectory,
      clock: now,
      logSink: logLines.add,
    );
    _server = await RelayServer.serve(
      app,
      address: InternetAddress.loopbackIPv4,
      port: 0,
      tickInterval: null,
    );
  }

  Future<void> stop() async {
    final RelayServer? server = _server;
    _server = null;
    await server?.close();
  }

  Future<void> restart() async {
    await stop();
    await boot();
  }

  Future<void> tick() => app.tick();

  Future<void> dispose() async {
    await stop();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  String createInvite([String note = 'Test journal']) =>
      app.accounts.createInvite(note).code;

  String accountOf(String deviceId) =>
      app.database.selectOne(
            'SELECT account_id FROM devices WHERE id = ?',
            <Object?>[deviceId],
          )!['account_id']
          as String;

  int currentEpoch(String accountId) =>
      app.database.selectOne(
            'SELECT current_epoch FROM accounts WHERE id = ?',
            <Object?>[accountId],
          )!['current_epoch']
          as int;

  int activeDevices(String accountId) => app.database.count(
    "SELECT count(*) FROM devices WHERE account_id = ? AND status = 'active'",
    <Object?>[accountId],
  );

  bool isActiveDevice(String deviceId) =>
      app.database.count(
        "SELECT count(*) FROM devices WHERE id = ? AND status = 'active'",
        <Object?>[deviceId],
      ) ==
      1;

  void insertDevice(String accountId, DeviceRegistration device) {
    final int millis = now().millisecondsSinceEpoch;
    app.database.execute(
      'INSERT INTO devices (id, account_id, sign_public_key, box_public_key, '
      'certificate, encrypted_name, status, created_at, last_seen_at) '
      "VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?)",
      <Object?>[
        device.deviceId,
        accountId,
        device.signPublicKey,
        device.boxPublicKey,
        device.certificate,
        device.encryptedName,
        millis,
        millis,
      ],
    );
  }

  void insertRotation(
    String accountId,
    EpochRotation rotation, {
    bool makeCurrent = true,
  }) {
    app.database.transaction(() {
      app.database.execute(
        'INSERT INTO epoch_rotations (account_id, epoch, signer_device_id, '
        'signature) VALUES (?, ?, ?, NULL)',
        <Object?>[accountId, rotation.epoch, rotation.signerDeviceId],
      );
      for (final EpochKeyDelivery delivery in rotation.deliveries) {
        app.database.execute(
          'INSERT INTO epoch_deliveries (account_id, epoch, recipient, '
          'sealed, signature) VALUES (?, ?, ?, ?, ?)',
          <Object?>[
            accountId,
            rotation.epoch,
            delivery.recipient,
            delivery.sealed,
            delivery.signature,
          ],
        );
      }
      if (makeCurrent) {
        app.database.execute(
          'UPDATE accounts SET current_epoch = ? WHERE id = ?',
          <Object?>[rotation.epoch, accountId],
        );
      }
    });
  }

  static String _migrationsDirectory() {
    final String packaged = defaultMigrationsDirectory();
    if (Directory(packaged).existsSync()) {
      return packaged;
    }
    return p.join(Directory.current.path, 'server', 'migrations');
  }
}
