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
    );
  }

  static const String databaseVariable = 'RELAY_DATABASE';
  static const String mediaVariable = 'RELAY_MEDIA_DIR';
  static const String portVariable = 'RELAY_PORT';
  static const String minFreeVariable = 'RELAY_MIN_FREE_BYTES';

  static const String defaultDatabasePath = '/var/lib/relay/relay.sqlite3';
  static const String defaultMediaDirectory = '/srv/relay-media';
  static const int defaultPort = 8080;
  static const int defaultMinFreeBytes = 2 * 1024 * 1024 * 1024;

  final String databasePath;
  final String mediaDirectory;
  final int port;
  final int minFreeBytes;

  static String? _present(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
