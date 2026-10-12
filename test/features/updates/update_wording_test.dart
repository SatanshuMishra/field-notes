import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('last checked times read as people say them', () {
    final DateTime now = DateTime(2026, 10, 11, 15, 30);
    final Map<DateTime, String> cases = <DateTime, String>{
      now: 'just now',
      now.subtract(const Duration(seconds: 59)): 'just now',
      now.add(const Duration(minutes: 5)): 'just now',
      now.subtract(const Duration(minutes: 1)): '1 minute ago',
      now.subtract(const Duration(seconds: 119)): '1 minute ago',
      now.subtract(const Duration(minutes: 2)): '2 minutes ago',
      now.subtract(const Duration(minutes: 59, seconds: 59)): '59 minutes ago',
      now.subtract(const Duration(hours: 1)): 'today, 2:30 pm',
      DateTime(2026, 10, 11, 9, 14): 'today, 9:14 am',
      DateTime(2026, 10, 11, 0, 5): 'today, 12:05 am',
      DateTime(2026, 10, 11, 12): 'today, 12:00 pm',
      DateTime(2026, 10, 10, 9, 14): 'yesterday, 9:14 am',
      DateTime(2026, 10, 10, 23, 59): 'yesterday, 11:59 pm',
      DateTime(2026, 10, 10): 'yesterday, 12:00 am',
      DateTime(2026, 10, 9, 23, 59): 'October 9',
      DateTime(2026, 1, 1): 'January 1',
      DateTime(2025, 10, 9, 9, 14): 'October 9, 2025',
    };
    for (final MapEntry<DateTime, String> sample in cases.entries) {
      expect(
        lastCheckedTime(sample.key, now),
        sample.value,
        reason: '${sample.key}',
      );
    }
    expect(
      lastCheckedTime(DateTime(2026, 10, 31, 23), DateTime(2026, 11, 1, 0, 30)),
      'yesterday, 11:00 pm',
    );
    expect(
      lastCheckedTime(DateTime(2025, 12, 31, 9, 14), DateTime(2026, 1, 1, 8)),
      'yesterday, 9:14 am',
    );
    expect(
      lastCheckedTime(DateTime(2025, 12, 30, 9), DateTime(2026, 1, 1, 8)),
      'December 30, 2025',
    );
    expect(
      lastCheckedLine(DateTime(2026, 10, 11, 9, 14), now),
      'Last checked today, 9:14 am',
    );
    expect(lastCheckedLine(now, now), 'Last checked just now');
  });

  test('sizes and progress round as the design shows them', () {
    final Map<int, String> sizes = <int, String>{
      0: '0 KB',
      499: '0 KB',
      500: '1 KB',
      850000: '850 KB',
      999499: '999 KB',
      999500: '1 MB',
      1000000: '1 MB',
      1499999: '1 MB',
      1500000: '2 MB',
      38000000: '38 MB',
      38400000: '38 MB',
      41700000: '42 MB',
    };
    for (final MapEntry<int, String> sample in sizes.entries) {
      expect(sizeText(sample.key), sample.value, reason: '${sample.key}');
    }

    final Map<double, String> percents = <double, String>{
      0: '0%',
      0.004: '0%',
      0.29: '29%',
      0.5: '50%',
      0.57: '57%',
      0.999: '99%',
      1: '100%',
      -0.1: '0%',
      1.2: '100%',
    };
    for (final MapEntry<double, String> sample in percents.entries) {
      expect(percentText(sample.key), sample.value, reason: '${sample.key}');
    }

    expect(progressText(0.42, 38000000), '42% of 38 MB');
    expect(progressText(0.42, null), '42%');
    expect(downloadingNote(null, 38000000), 'Downloading…');
    expect(downloadingNote(0.42, 38000000), 'Downloading · 42% of 38 MB');
    expect(downloadingNote(0.42, null), 'Downloading · 42%');
    expect(downloadSizeSuffix(38000000), ' · 38 MB download');
    expect(downloadSizeSuffix(850000), ' · 850 KB download');
  });

  test('failures say what happened and what to do', () {
    expect(
      installFailureText(InstallFailure.network),
      'The download stopped. Nothing was installed.',
    );
    expect(
      installFailureText(InstallFailure.verification),
      'The download didn’t pass its safety check, so nothing was installed.',
    );
    expect(
      installFailureText(InstallFailure.permission),
      'Allow Field Notes to install updates, then try again.',
    );
    expect(
      installFailureText(InstallFailure.notReady),
      'This update isn’t ready to install yet. Try again in a few minutes.',
    );
    expect(
      installFailureText(InstallFailure.installer),
      'The update couldn’t be installed. Your journal is unchanged.',
    );

    expect(
      checkFailureText(null, DateTime(2026, 10, 11, 9, 14)),
      'GitHub is busy. Try again after 9:14 am.',
    );
    expect(
      checkFailureText(LookupFailure.offline, DateTime(2026, 10, 11, 13, 5)),
      'GitHub is busy. Try again after 1:05 pm.',
    );
    expect(
      checkFailureText(LookupFailure.offline, null),
      'Couldn’t check for updates. Check your connection and try again.',
    );
    expect(
      checkFailureText(LookupFailure.badResponse, null),
      'Couldn’t read the update information. Try again later.',
    );
    expect(
      checkFailureText(null, null),
      'Couldn’t read the update information. Try again later.',
    );
  });

  test('each install route has its action, note and available line', () {
    expect(routeAction(InstallRoute.restartInPlace), 'Update & restart');
    expect(routeAction(InstallRoute.systemInstaller), 'Download & install');
    expect(routeAction(InstallRoute.googlePlay), 'Open Google Play');
    expect(routeAction(InstallRoute.downloadPage), 'Open download page');

    expect(
      routeNote(InstallRoute.restartInPlace, phone: false),
      'Field Notes saves your journal and any open draft, then restarts. '
      'It takes a few seconds.',
    );
    expect(
      routeNote(InstallRoute.restartInPlace, phone: true),
      'Your journal and any open draft are saved first. Field Notes '
      'restarts in a few seconds.',
    );
    for (final bool phone in <bool>[false, true]) {
      expect(
        routeNote(InstallRoute.systemInstaller, phone: phone),
        'Field Notes downloads the update, then Android asks you to install '
        'it. Open Field Notes again from the notification when it finishes.',
      );
      expect(
        routeNote(InstallRoute.googlePlay, phone: phone),
        'Google Play delivers this update. It can take a few days to reach '
        'your phone.',
      );
      expect(
        routeNote(InstallRoute.downloadPage, phone: phone),
        'This copy of Field Notes can’t update itself. The download page '
        'opens in your browser.',
      );
    }

    expect(
      routeAvailableLine(InstallRoute.restartInPlace),
      'Read the changelog, then restart to update. Your journal is saved '
      'first.',
    );
    expect(
      routeAvailableLine(InstallRoute.systemInstaller),
      'Read the changelog, then install it.',
    );
    expect(
      routeAvailableLine(InstallRoute.googlePlay),
      'Read the changelog, then update from Google Play when it’s offered '
      'there.',
    );
    expect(
      routeAvailableLine(InstallRoute.downloadPage),
      'Read the changelog, then download it.',
    );
  });

  test('every update screen string has its one wording', () {
    expect(updatesTitle, 'Updates');
    expect(notCheckedYet, 'Not checked yet');
    expect(checkingTitle, 'Checking for updates…');
    expect(checkingDescription, 'This takes a moment.');
    expect(upToDateTitle, 'Field Notes is up to date');
    expect(availableTitle('1.3.0'), 'Version 1.3.0 is available');
    expect(downloadingTitle('1.3.0'), 'Downloading version 1.3.0…');
    expect(downloadingUnknown, 'Downloading…');
    expect(checkFailedTitle, 'Couldn’t check for updates');

    expect(phoneCheckingLine, 'Looking for a new version…');
    expect(phoneReadyLine('1.3.0'), 'Version 1.3.0 is ready to install');
    expect(
      phoneUpToDateLine('today, 9:14 am'),
      'Up to date · checked today, 9:14 am',
    );

    expect(checkForUpdatesLabel, 'Check for updates');
    expect(checkingLabel, 'Checking…');
    expect(readChangelogLabel, 'Read changelog');
    expect(updateNowLabel, 'Update now…');
    expect(phoneUpdateLabel('1.3.0'), 'Update to 1.3.0…');
    expect(checkAutomaticallyLabel, 'Check automatically');
    expect(
      checkAutomaticallyDescription,
      'Once a day. Nothing installs until you choose.',
    );
    expect(releaseNotesLabel, 'Release notes');
    expect(releaseNotesDescription('1.2.0'), 'What changed in version 1.2.0');
    expect(readNotesLabel, 'Read notes');

    expect(updateAvailableKicker, 'update available');
    expect(releaseNotesKicker, 'release notes');
    expect(notesTitle('1.3.0'), 'Field Notes 1.3.0');
    expect(releasedLine(DateTime(2026, 10, 9)), 'Released October 9, 2026');
    expect(
      releasedLine(DateTime(2026, 1, 31, 23)),
      'Released January 31, 2026',
    );
    expect(noNotesText('1.2.0'), 'No notes for version 1.2.0 yet.');
    expect(laterLabel, 'Later');
    expect(closeLabel, 'Close');
    expect(closeTooltip, 'Close (Esc)');

    expect(restartingTitle, 'Restarting Field Notes');
    expect(openingVersionLine('1.3.0'), 'opening version 1.3.0…');

    expect(updateAvailableLabel, 'Update available');
    expect(versionLine('1.3.0'), 'Version 1.3.0');
    expect(
      railTooltip('1.3.0'),
      'Field Notes 1.3.0 is available. Read the changelog and update.',
    );
    expect(railSemanticsLabel('1.3.0'), 'Update available, version 1.3.0');
    expect(gearBadgeSuffix, ', update available');
    expect(bannerTitle('1.3.0'), 'Update available: 1.3.0');
    expect(bannerSubtitle, 'Read the changelog, then update');
    expect(aboutRowReadySummary('1.3.0'), 'Version 1.3.0 is ready');
    expect(updatedGreeting('1.3.0'), 'Updated to Field Notes 1.3.0');
  });
}
