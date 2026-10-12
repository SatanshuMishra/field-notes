import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the privacy policy explains update checks', () {
    final String text = File('docs/privacy.md').readAsStringSync();

    expect(text, contains('## Update checks'));
    expect(
      text.indexOf('## What stays on your device'),
      lessThan(text.indexOf('## Update checks')),
    );

    final String section = text.substring(
      text.indexOf('## Update checks'),
      text.indexOf('## Sync (optional)'),
    );
    for (final String phrase in <String>[
      'api.github.com',
      'GitHub, Inc.',
      'once a day',
      'Check automatically',
      'Settings > About',
      'Check for updates',
      'no journal data',
      'internet address',
      'GitHub\'s servers',
      'Google Play',
      'Nothing installs until you choose to update',
      'https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement',
    ]) {
      expect(section, contains(phrase));
    }

    expect(
      text,
      contains(
        'Field Notes checks GitHub for new versions, which you can turn off.',
      ),
    );
    expect(
      text,
      contains('no ads, no analytics, no crash reporting and no tracking'),
    );
    expect(text, contains('Effective 11 October 2026.'));
  });
}
