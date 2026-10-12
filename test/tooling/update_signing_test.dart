import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/updates/release_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

const String _openssl = '/opt/homebrew/opt/openssl@3/bin/openssl';
const String _dmgName = 'field-notes-1.2.0-macos.dmg';
const String _exeName = 'field-notes-1.2.0-windows-x64-setup.exe';
const String _apkName = 'field-notes-1.2.0-android.apk';
const String _dmgUrl =
    'https://github.com/SatanshuMishra/field-notes/releases/download/v1.2.0/'
    '$_dmgName';
const String _published = 'Mon, 12 Oct 2026 09:30:00 +0000';
const String _changelog =
    '# Changelog\n'
    '\n'
    '## [Unreleased]\n'
    '\n'
    '### New\n'
    '\n'
    '- Something still in the works.\n'
    '\n'
    '## [1.2.0] - 2026-10-12\n'
    '\n'
    '\n'
    'Updates now install from Settings.\n'
    '\n'
    '### New\n'
    '\n'
    '- An About page.\n'
    '\n'
    '### Fixed\n'
    '\n'
    '- A crash on launch.\n'
    '\n'
    '\n'
    '## [1.1.0]\n'
    '\n'
    '### Improved\n'
    '\n'
    '- Faster sync.\n';

String _tool(String path) => '${Directory.current.path}/tool/release/$path';

void _requireOpenssl() {
  if (!File(_openssl).existsSync()) {
    fail(
      'OpenSSL 3 is missing at $_openssl. The system openssl is LibreSSL and '
      'cannot sign with Ed25519; install OpenSSL 3 with brew install openssl@3.',
    );
  }
}

Directory _scratch() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'update_signing_test',
  );
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

ProcessResult _script(String path, List<String> arguments) {
  return Process.runSync(
    '/bin/bash',
    <String>[_tool(path), ...arguments],
    environment: <String, String>{'PATH': '/usr/bin:/bin', 'OPENSSL': _openssl},
    includeParentEnvironment: false,
  );
}

ProcessResult _openSsl(List<String> arguments) {
  final ProcessResult result = Process.runSync(
    _openssl,
    arguments,
    stdoutEncoding: null,
  );
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return result;
}

String _generateKey(Directory directory, String name) {
  final String path = '${directory.path}/$name.pem';
  _openSsl(<String>['genpkey', '-algorithm', 'ed25519', '-out', path]);
  return path;
}

Uint8List _publicKey(String pem) {
  final List<int> der =
      _openSsl(<String>['pkey', '-in', pem, '-pubout', '-outform', 'DER'])
              .stdout
          as List<int>;
  return Uint8List.fromList(der.sublist(der.length - updatePublicKeyBytes));
}

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 37 + seed) % 256);

void main() {
  test('release scripts sign files the app accepts', () async {
    _requireOpenssl();
    final Directory directory = _scratch();
    final String key = _generateKey(directory, 'update');
    final String otherKey = _generateKey(directory, 'other');
    final Uint8List publicKey = _publicKey(key);

    final Map<String, List<int>> installers = <String, List<int>>{
      _dmgName: _bytes(4099, 3),
      _exeName: _bytes(2048, 11),
      _apkName: _bytes(3072, 29),
    };
    for (final MapEntry<String, List<int>> installer in installers.entries) {
      File('${directory.path}/${installer.key}')
          .writeAsBytesSync(installer.value);
    }
    final File sums = File('${directory.path}/SHA256SUMS.txt')
      ..writeAsStringSync(
        <String>[
          for (final MapEntry<String, List<int>> installer
              in installers.entries)
            '${sha256.convert(installer.value)}  ${installer.key}\n',
        ].join(),
      );
    final List<int> sumsBytes = sums.readAsBytesSync();

    final ProcessResult signed = _script('sign_update.sh', <String>[
      key,
      sums.path,
    ]);
    expect(signed.exitCode, 0, reason: '${signed.stderr}');
    final String signature = signed.stdout as String;
    expect(signature, matches(RegExp(r'^[A-Za-z0-9+/]{86}==\n$')));
    expect(base64.decode(signature.trim()), hasLength(updateSignatureBytes));

    final ReleaseVerifier verifier = ReleaseVerifier(publicKey);
    expect(verifier.sumsAreSigned(sumsBytes, signature), isTrue);
    for (final MapEntry<String, List<int>> installer in installers.entries) {
      expect(
        await verifier.verify(
          sums: sumsBytes,
          signature: signature,
          fileName: installer.key,
          file: File('${directory.path}/${installer.key}'),
        ),
        isTrue,
        reason: '${installer.key} must verify',
      );
    }
    expect(
      ReleaseVerifier(_publicKey(otherKey)).sumsAreSigned(sumsBytes, signature),
      isFalse,
    );
    expect(verifier.sumsAreSigned(<int>[...sumsBytes, 10], signature), isFalse);

    final ProcessResult derived = Process.runSync(
      '/bin/bash',
      <String>[
        '-c',
        '"$_openssl" pkey -in "$key" -pubout -outform DER | tail -c 32 | base64',
      ],
      environment: <String, String>{'PATH': '/usr/bin:/bin'},
    );
    expect(derived.exitCode, 0, reason: '${derived.stderr}');
    final ReleaseVerifier? documented = ReleaseVerifier.fromBase64(
      derived.stdout as String,
    );
    expect(documented, isNotNull);
    expect(documented!.sumsAreSigned(sumsBytes, signature), isTrue);

    final String ecKey = '${directory.path}/ec.pem';
    _openSsl(<String>[
      'genpkey',
      '-algorithm',
      'EC',
      '-pkeyopt',
      'ec_paramgen_curve:P-256',
      '-out',
      ecKey,
    ]);
    final ProcessResult refused = _script('sign_update.sh', <String>[
      ecKey,
      sums.path,
    ]);
    expect(refused.exitCode, 1);
    expect(refused.stdout, isEmpty);
    expect(refused.stderr, contains('is not an Ed25519 private key'));

    final File dmg = File('${directory.path}/$_dmgName');
    final ProcessResult dmgSigned = _script('sign_update.sh', <String>[
      key,
      dmg.path,
    ]);
    expect(dmgSigned.exitCode, 0, reason: '${dmgSigned.stderr}');
    final String edSignature = (dmgSigned.stdout as String).trim();
    expect(verifier.sumsAreSigned(dmg.readAsBytesSync(), edSignature), isTrue);

    final ProcessResult appcast = _script('macos/make_appcast.sh', <String>[
      '1.2.0',
      '42',
      dmg.path,
      _dmgUrl,
      edSignature,
      _published,
    ]);
    expect(appcast.exitCode, 0, reason: '${appcast.stderr}');
    expect(
      appcast.stdout,
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<rss version="2.0" '
      'xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">\n'
      '  <channel>\n'
      '    <title>Field Notes</title>\n'
      '    <item>\n'
      '      <title>Version 1.2.0</title>\n'
      '      <pubDate>$_published</pubDate>\n'
      '      <sparkle:version>42</sparkle:version>\n'
      '      <sparkle:shortVersionString>1.2.0</sparkle:shortVersionString>\n'
      '      <sparkle:minimumSystemVersion>12.0'
      '</sparkle:minimumSystemVersion>\n'
      '      <enclosure url="$_dmgUrl" length="4099" '
      'type="application/octet-stream" '
      'sparkle:edSignature="$edSignature"/>\n'
      '    </item>\n'
      '  </channel>\n'
      '</rss>\n',
    );
    expect('<item>'.allMatches(appcast.stdout as String), hasLength(1));

    final ProcessResult escaped = _script('macos/make_appcast.sh', <String>[
      '1.2.0-rc.1&<b>',
      '"43"',
      dmg.path,
      'https://example.com/a?x=1&y=<2>',
      "sig'nature",
      'Mon, 12 Oct 2026 09:30:00 +0000 & "later"',
    ]);
    expect(escaped.exitCode, 0, reason: '${escaped.stderr}');
    final String escapedXml = escaped.stdout as String;
    expect(
      escapedXml,
      contains('<title>Version 1.2.0-rc.1&amp;&lt;b&gt;</title>'),
    );
    expect(
      escapedXml,
      contains('<sparkle:version>&quot;43&quot;</sparkle:version>'),
    );
    expect(
      escapedXml,
      contains(
        '<sparkle:shortVersionString>1.2.0-rc.1&amp;&lt;b&gt;'
        '</sparkle:shortVersionString>',
      ),
    );
    expect(
      escapedXml,
      contains(
        '<pubDate>Mon, 12 Oct 2026 09:30:00 +0000 &amp; '
        '&quot;later&quot;</pubDate>',
      ),
    );
    expect(
      escapedXml,
      contains(
        '<enclosure url="https://example.com/a?x=1&amp;y=&lt;2&gt;" '
        'length="4099" type="application/octet-stream" '
        'sparkle:edSignature="sig&apos;nature"/>',
      ),
    );

    final File changelog = File('${directory.path}/CHANGELOG.md')
      ..writeAsStringSync(_changelog);
    final ProcessResult section = _script('changelog_section.sh', <String>[
      '1.2.0',
      changelog.path,
    ]);
    expect(section.exitCode, 0, reason: '${section.stderr}');
    expect(
      section.stdout,
      'Updates now install from Settings.\n'
      '\n'
      '### New\n'
      '\n'
      '- An About page.\n'
      '\n'
      '### Fixed\n'
      '\n'
      '- A crash on launch.\n',
    );
    final ProcessResult undated = _script('changelog_section.sh', <String>[
      '1.1.0',
      changelog.path,
    ]);
    expect(undated.exitCode, 0, reason: '${undated.stderr}');
    expect(undated.stdout, '### Improved\n\n- Faster sync.\n');

    for (final String version in <String>['1.0.0', '1.2', '1.2.0-rc.1']) {
      final ProcessResult missing = _script('changelog_section.sh', <String>[
        version,
        changelog.path,
      ]);
      expect(missing.exitCode, 1, reason: '$version has no section');
      expect(missing.stdout, isEmpty);
      expect(
        missing.stderr,
        '::error::CHANGELOG.md has no section for $version.\n',
      );
    }
  });
}
