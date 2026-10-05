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
    this.rateGlobalBurst = defaultRateGlobalBurst,
    this.rateGlobalPerSecond = defaultRateGlobalPerSecond,
    this.largeBodySlots = defaultLargeBodySlots,
    this.largeBodySlotsPerAccount = defaultLargeBodySlotsPerAccount,
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
    return RelayConfig(
      databasePath: _present(source[databaseVariable]) ?? defaultDatabasePath,
      mediaDirectory: _present(source[mediaVariable]) ?? defaultMediaDirectory,
      port: port,
      minFreeBytes: minFreeBytes,
      rateBurst: _count(source, rateBurstVariable, defaultRateBurst),
      ratePerSecond: _rate(source, ratePerSecondVariable, defaultRatePerSecond),
      rateGlobalBurst: _count(
        source,
        rateGlobalBurstVariable,
        defaultRateGlobalBurst,
      ),
      rateGlobalPerSecond: _rate(
        source,
        rateGlobalPerSecondVariable,
        defaultRateGlobalPerSecond,
      ),
      largeBodySlots: _count(
        source,
        largeBodySlotsVariable,
        defaultLargeBodySlots,
      ),
      largeBodySlotsPerAccount: _count(
        source,
        largeBodySlotsPerAccountVariable,
        defaultLargeBodySlotsPerAccount,
      ),
    );
  }

  static const String databaseVariable = 'RELAY_DATABASE';
  static const String mediaVariable = 'RELAY_MEDIA_DIR';
  static const String portVariable = 'RELAY_PORT';
  static const String minFreeVariable = 'RELAY_MIN_FREE_BYTES';
  static const String rateBurstVariable = 'RELAY_RATE_BURST';
  static const String ratePerSecondVariable = 'RELAY_RATE_PER_SECOND';
  static const String rateGlobalBurstVariable = 'RELAY_RATE_GLOBAL_BURST';
  static const String rateGlobalPerSecondVariable =
      'RELAY_RATE_GLOBAL_PER_SECOND';
  static const String largeBodySlotsVariable = 'RELAY_LARGE_BODY_SLOTS';
  static const String largeBodySlotsPerAccountVariable =
      'RELAY_LARGE_BODY_SLOTS_PER_ACCOUNT';

  static const String defaultDatabasePath = '/var/lib/relay/relay.sqlite3';
  static const String defaultMediaDirectory = '/srv/relay-media';
  static const int defaultPort = 8080;
  static const int defaultMinFreeBytes = 2 * 1024 * 1024 * 1024;
  static const int defaultRateBurst = 60;
  static const double defaultRatePerSecond = 1.0;
  static const int defaultRateGlobalBurst = 600;
  static const double defaultRateGlobalPerSecond = 20.0;
  static const int defaultLargeBodySlots = 8;
  static const int defaultLargeBodySlotsPerAccount = 4;

  final String databasePath;
  final String mediaDirectory;
  final int port;
  final int minFreeBytes;
  final int rateBurst;
  final double ratePerSecond;
  final int rateGlobalBurst;
  final double rateGlobalPerSecond;
  final int largeBodySlots;
  final int largeBodySlotsPerAccount;

  static String? _present(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int _count(Map<String, String> source, String variable, int fallback) {
    final String? text = _present(source[variable]);
    final int? value = text == null ? fallback : int.tryParse(text);
    if (value == null || value < 1) {
      throw ConfigException('$variable must be a whole number of at least 1');
    }
    return value;
  }

  static double _rate(
    Map<String, String> source,
    String variable,
    double fallback,
  ) {
    final String? text = _present(source[variable]);
    final double? value = text == null ? fallback : double.tryParse(text);
    if (value == null || !value.isFinite || value <= 0) {
      throw ConfigException('$variable must be a number above 0');
    }
    return value;
  }
}
