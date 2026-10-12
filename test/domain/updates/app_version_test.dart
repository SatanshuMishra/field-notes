import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter_test/flutter_test.dart';

AppVersion parsed(String text) {
  final AppVersion? version = AppVersion.tryParse(text);
  expect(version, isNotNull, reason: '$text should parse');
  return version!;
}

void main() {
  test('versions compare by SemVer precedence', () {
    const Map<String, String> valid = <String, String>{
      'v1.2.3': '1.2.3',
      '1.2.3': '1.2.3',
      '0.0.0': '0.0.0',
      '10.20.30': '10.20.30',
      '1.0.0-rc.1': '1.0.0-rc.1',
      'v1.0.0-rc.2': '1.0.0-rc.2',
      '1.0.0-alpha.0.x-y': '1.0.0-alpha.0.x-y',
      '1.0.0-0A.is.legal': '1.0.0-0A.is.legal',
      '1.0.0+build.7': '1.0.0',
      'v1.0.0-beta+exp.sha.5114f85': '1.0.0-beta',
      '2.0.0+0007': '2.0.0',
    };
    for (final MapEntry<String, String> entry in valid.entries) {
      expect(
        AppVersion.tryParse(entry.key)?.toString(),
        entry.value,
        reason: entry.key,
      );
    }

    const List<String> malformed = <String>[
      '1.2',
      '01.2.3',
      'latest',
      '',
      'v',
      '1',
      '1.2.3.4',
      '1.02.3',
      '1.2.03',
      'V1.2.3',
      'vv1.2.3',
      ' 1.2.3',
      '1.2.3 ',
      '-1.2.3',
      '1.2.3-',
      '1.2.3-01',
      '1.2.3-rc..1',
      '1.2.3-rc_1',
      '1.2.3+',
      '1.2.3+build..1',
      'release-1.2.3',
      '99999999999999999999.0.0',
    ];
    for (final String text in malformed) {
      expect(AppVersion.tryParse(text), isNull, reason: text);
    }

    expect(parsed('v1.2.3'), parsed('1.2.3'));
    expect(parsed('v1.2.3').hashCode, parsed('1.2.3').hashCode);
    expect(parsed('v1.2.3').compareTo(parsed('1.2.3')), 0);
    expect(parsed('v1.2.3').isNewerThan(parsed('1.2.3')), isFalse);
    expect(parsed('1.2.3').isNewerThan(parsed('v1.2.3')), isFalse);

    expect(parsed('1.0.0+build.2'), parsed('1.0.0+build.1'));
    expect(parsed('1.0.0+build.2'), parsed('1.0.0'));
    expect(parsed('1.0.0+build.2').hashCode, parsed('1.0.0').hashCode);
    expect(parsed('1.0.0+build.2').compareTo(parsed('1.0.0+build.1')), 0);
    expect(
      parsed('1.0.0+build.2').isNewerThan(parsed('1.0.0+build.1')),
      isFalse,
    );

    expect(parsed('1.10.0').isNewerThan(parsed('1.9.0')), isTrue);
    expect(parsed('1.9.0').isNewerThan(parsed('1.10.0')), isFalse);
    expect(parsed('1.0.0').isNewerThan(parsed('1.0.0-rc.2')), isTrue);
    expect(parsed('1.0.0-rc.2').isNewerThan(parsed('1.0.0')), isFalse);
    expect(parsed('1.0.0-rc.2').isNewerThan(parsed('1.0.0-rc.1')), isTrue);
    expect(parsed('1.0.0-rc.1').isNewerThan(parsed('1.0.0-rc.2')), isFalse);

    const List<String> ascending = <String>[
      '0.0.1',
      '0.1.0',
      '0.9.9',
      '1.0.0-0',
      '1.0.0-9',
      '1.0.0-10',
      '1.0.0-99999999999999999999',
      '1.0.0-B',
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0-rc.2',
      '1.0.0',
      '1.0.1',
      '1.1.0',
      '1.9.0',
      '1.10.0',
      '2.0.0-rc.1',
      '2.0.0',
      '10.0.0',
    ];
    for (int lower = 0; lower < ascending.length; lower++) {
      for (int higher = 0; higher < ascending.length; higher++) {
        final AppVersion a = parsed(ascending[lower]);
        final AppVersion b = parsed(ascending[higher]);
        final String pair = '${ascending[lower]} vs ${ascending[higher]}';
        expect(a.compareTo(b).sign, (lower - higher).sign, reason: pair);
        expect(a.isNewerThan(b), lower > higher, reason: pair);
        expect(a == b, lower == higher, reason: pair);
      }
    }

    final List<AppVersion> shuffled = <AppVersion>[
      for (final String text in ascending.reversed) parsed(text),
    ]..sort();
    expect(<String>[
      for (final AppVersion version in shuffled) version.toString(),
    ], ascending);
  });

  test('a version keeps its parts and prints its canonical form', () {
    final AppVersion version = parsed('v2.4.0-rc.3+sha.9f1c');

    expect(version.major, 2);
    expect(version.minor, 4);
    expect(version.patch, 0);
    expect(version.prerelease, <String>['rc', '3']);
    expect(version.toString(), '2.4.0-rc.3');
    expect(parsed('v2.4.0').toString(), '2.4.0');
  });

  test('a version cannot be changed after it is made', () {
    final List<String> identifiers = <String>['beta', '2'];
    final AppVersion version = AppVersion(
      major: 1,
      minor: 0,
      patch: 0,
      prerelease: identifiers,
    );
    identifiers.add('extra');

    expect(version.prerelease, <String>['beta', '2']);
    expect(() => version.prerelease.add('x'), throwsUnsupportedError);
    expect(
      () => parsed('1.0.0-rc.1').prerelease.add('x'),
      throwsUnsupportedError,
    );
    expect(version, parsed('1.0.0-beta.2'));
  });
}
