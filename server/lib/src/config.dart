import 'dart:io';

final class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class RelayConfig {
  const RelayConfig({
    required this.databasePath,
    required this.mediaDirectory,
    this.port = defaultPort,
    this.minFreeBytes = defaultMinFreeBytes,
    this.rateBurst = defaultRateBurst,
    this.ratePerSecond = defaultRatePerSecond,
  });

  factory RelayConfig.fromEnvironment([Map<String, String>? environment]) {
    final Map<String, String> source = environment ?? Platform.environment;
    final String? portText = _present(source[portVariable]);
    final int? port = portText == null ? defaultPort : int.tryParse(portText);
    if (port == null || port < 0 || port > 65535) {
      throw const ConfigException('$portVariable must be a port number');
    }
    final String? minFreeText = _present(source[minFreeVariable]);
    final int? minFreeBytes = minFreeText == null
        ? defaultMinFreeBytes
        : int.tryParse(minFreeText);
    if (minFreeBytes == null || minFreeBytes < 0) {
      throw const ConfigException('$minFreeVariable must be a byte count');
    }
    final String? burstText = _present(source[rateBurstVariable]);
    final int? rateBurst = burstText == null
        ? defaultRateBurst
        : int.tryParse(burstText);
    if (rateBurst == null || rateBurst < 1) {
      throw const ConfigException(
        '$rateBurstVariable must be a whole number of at least 1',
      );
    }
    final String? rateText = _present(source[ratePerSecondVariable]);
    final double? ratePerSecond = rateText == null
        ? defaultRatePerSecond
        : double.tryParse(rateText);
    if (ratePerSecond == null ||
        !ratePerSecond.isFinite ||
        ratePerSecond <= 0) {
      throw const ConfigException(
        '$ratePerSecondVariable must be a number above 0',
      );
    }
    return RelayConfig(
      databasePath: _present(source[databaseVariable]) ?? defaultDatabasePath,
      mediaDirectory: _present(source[mediaVariable]) ?? defaultMediaDirectory,
      port: port,
      minFreeBytes: minFreeBytes,
      rateBurst: rateBurst,
      ratePerSecond: ratePerSecond,
    );
  }

  static const String databaseVariable = 'RELAY_DATABASE';
  static const String mediaVariable = 'RELAY_MEDIA_DIR';
  static const String portVariable = 'RELAY_PORT';
  static const String minFreeVariable = 'RELAY_MIN_FREE_BYTES';
  static const String rateBurstVariable = 'RELAY_RATE_BURST';
  static const String ratePerSecondVariable = 'RELAY_RATE_PER_SECOND';

  static const String defaultDatabasePath = '/var/lib/relay/relay.sqlite3';
  static const String defaultMediaDirectory = '/srv/relay-media';
  static const int defaultPort = 8080;
  static const int defaultMinFreeBytes = 2 * 1024 * 1024 * 1024;
  static const int defaultRateBurst = 60;
  static const double defaultRatePerSecond = 1.0;

  final String databasePath;
  final String mediaDirectory;
  final int port;
  final int minFreeBytes;
  final int rateBurst;
  final double ratePerSecond;

  static String? _present(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
