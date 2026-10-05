final class SyncRoute {
  const SyncRoute(this.method, this.pattern);

  final String method;
  final String pattern;

  static final RegExp _parameter = RegExp(r'<(\w+)>');

  List<String> get parameterNames => <String>[
    for (final RegExpMatch match in _parameter.allMatches(pattern)) match[1]!,
  ];

  String path([Map<String, Object> parameters = const <String, Object>{}]) {
    final List<String> names = parameterNames;
    final List<String> unknown = <String>[
      for (final String key in parameters.keys)
        if (!names.contains(key)) key,
    ];
    if (unknown.isNotEmpty) {
      throw ArgumentError.value(
        unknown.join(', '),
        'parameters',
        'Not a parameter of $pattern',
      );
    }
    return pattern.replaceAllMapped(_parameter, (Match match) {
      final String name = match[1]!;
      final String value = '${parameters[name] ?? ''}';
      if (value.isEmpty) {
        throw ArgumentError.value(name, 'parameters', 'Missing for $pattern');
      }
      return Uri.encodeComponent(value);
    });
  }

  Uri uri(
    Uri baseUrl, {
    Map<String, Object> parameters = const <String, Object>{},
    Map<String, String> query = const <String, String>{},
  }) {
    final String basePath = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return Uri(
      scheme: baseUrl.scheme,
      userInfo: baseUrl.userInfo,
      host: baseUrl.host,
      port: baseUrl.hasPort ? baseUrl.port : null,
      path: '$basePath${path(parameters)}',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncRoute && other.method == method && other.pattern == pattern;

  @override
  int get hashCode => Object.hash(method, pattern);

  @override
  String toString() => '$method $pattern';
}

abstract final class SyncRoutes {
  static const String nameParameter = 'name';
  static const String uploadIdParameter = 'uploadId';
  static const String indexParameter = 'index';
  static const String mailboxIdParameter = 'mailboxId';
  static const String deviceIdParameter = 'deviceId';

  static const String afterQuery = 'after';
  static const String limitQuery = 'limit';

  static const SyncRoute redeemInvite = SyncRoute('POST', '/v1/invites/redeem');
  static const SyncRoute sessionChallenge = SyncRoute(
    'POST',
    '/v1/session/challenge',
  );
  static const SyncRoute session = SyncRoute('POST', '/v1/session');
  static const SyncRoute pushRecords = SyncRoute('POST', '/v1/records/push');
  static const SyncRoute pullRecords = SyncRoute('GET', '/v1/records');
  static const SyncRoute live = SyncRoute('GET', '/v1/live');
  static const SyncRoute blobExists = SyncRoute(
    'HEAD',
    '/v1/blobs/<$nameParameter>',
  );
  static const SyncRoute downloadBlob = SyncRoute(
    'GET',
    '/v1/blobs/<$nameParameter>',
  );
  static const SyncRoute uploadStatus = SyncRoute(
    'GET',
    '/v1/blobs/<$nameParameter>/uploads/<$uploadIdParameter>',
  );
  static const SyncRoute uploadPart = SyncRoute(
    'PUT',
    '/v1/blobs/<$nameParameter>/uploads/<$uploadIdParameter>'
        '/parts/<$indexParameter>',
  );
  static const SyncRoute reportUnusedBlobs = SyncRoute(
    'POST',
    '/v1/blobs/unused',
  );
  static const SyncRoute reportReferencedBlobs = SyncRoute(
    'POST',
    '/v1/blobs/referenced',
  );
  static const SyncRoute keys = SyncRoute('GET', '/v1/keys');
  static const SyncRoute openPairing = SyncRoute('POST', '/v1/pairing');
  static const SyncRoute joinPairing = SyncRoute(
    'POST',
    '/v1/pairing/<$mailboxIdParameter>/join',
  );
  static const SyncRoute pairingStatus = SyncRoute(
    'GET',
    '/v1/pairing/<$mailboxIdParameter>',
  );
  static const SyncRoute completePairing = SyncRoute(
    'POST',
    '/v1/pairing/<$mailboxIdParameter>/complete',
  );
  static const SyncRoute restoreChallenge = SyncRoute(
    'POST',
    '/v1/restore/challenge',
  );
  static const SyncRoute restore = SyncRoute('POST', '/v1/restore');
  static const SyncRoute registerRestoredDevice = SyncRoute(
    'POST',
    '/v1/restore/register',
  );
  static const SyncRoute devices = SyncRoute('GET', '/v1/devices');
  static const SyncRoute removeDevice = SyncRoute(
    'DELETE',
    '/v1/devices/<$deviceIdParameter>',
  );
  static const SyncRoute eraseJournal = SyncRoute('POST', '/v1/journal/erase');
  static const SyncRoute health = SyncRoute('GET', '/health');

  static const List<SyncRoute> all = <SyncRoute>[
    redeemInvite,
    sessionChallenge,
    session,
    pushRecords,
    pullRecords,
    live,
    blobExists,
    downloadBlob,
    uploadStatus,
    uploadPart,
    reportUnusedBlobs,
    reportReferencedBlobs,
    keys,
    openPairing,
    joinPairing,
    pairingStatus,
    completePairing,
    restoreChallenge,
    restore,
    registerRestoredDevice,
    devices,
    removeDevice,
    eraseJournal,
    health,
  ];
}

abstract final class SyncHeaders {
  static const String protocol = 'X-Sync-Protocol';
  static const String blobSize = 'X-Blob-Size';
  static const String partSize = 'X-Part-Size';
  static const String authorization = 'Authorization';
}

enum AuthScheme {
  session('Bearer'),
  uploadPass('Upload'),
  mailbox('Mailbox');

  const AuthScheme(this.wireName);

  final String wireName;

  String authorization(String token) => '$wireName $token';
}

final class AuthCredential {
  const AuthCredential(this.scheme, this.token);

  final AuthScheme scheme;
  final String token;

  static AuthCredential? parse(String? header) {
    if (header == null) {
      return null;
    }
    final String trimmed = header.trim();
    final int space = trimmed.indexOf(' ');
    if (space <= 0) {
      return null;
    }
    final String schemeName = trimmed.substring(0, space).toLowerCase();
    final String token = trimmed.substring(space + 1).trim();
    if (token.isEmpty || token.contains(RegExp(r'\s'))) {
      return null;
    }
    for (final AuthScheme scheme in AuthScheme.values) {
      if (scheme.wireName.toLowerCase() == schemeName) {
        return AuthCredential(scheme, token);
      }
    }
    return null;
  }

  String get authorization => scheme.authorization(token);

  @override
  bool operator ==(Object other) =>
      other is AuthCredential && other.scheme == scheme && other.token == token;

  @override
  int get hashCode => Object.hash(scheme, token);
}
