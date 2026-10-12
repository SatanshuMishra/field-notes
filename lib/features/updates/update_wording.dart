import 'package:field_notes/domain/updates/updates.dart';

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const int _bytesPerKilobyte = 1000;
const int _bytesPerMegabyte = 1000 * 1000;

String _clockTime(DateTime at) {
  final DateTime local = at.toLocal();
  final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final String minute = local.minute.toString().padLeft(2, '0');
  final String period = local.hour < 12 ? 'am' : 'pm';
  return '$hour:$minute $period';
}

String _monthDay(DateTime local) => '${_months[local.month - 1]} ${local.day}';

String _calendarDate(DateTime local) => '${_monthDay(local)}, ${local.year}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String lastCheckedTime(DateTime at, DateTime now) {
  final Duration since = now.difference(at);
  if (since < const Duration(minutes: 1)) {
    return 'just now';
  }
  if (since < const Duration(hours: 1)) {
    final int minutes = since.inMinutes;
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  }
  final DateTime local = at.toLocal();
  final DateTime today = now.toLocal();
  if (_sameDay(local, today)) {
    return 'today, ${_clockTime(local)}';
  }
  final DateTime yesterday = DateTime(today.year, today.month, today.day - 1);
  if (_sameDay(local, yesterday)) {
    return 'yesterday, ${_clockTime(local)}';
  }
  if (local.year == today.year) {
    return _monthDay(local);
  }
  return _calendarDate(local);
}

String sizeText(int bytes) {
  if (bytes >= _bytesPerMegabyte) {
    return '${(bytes / _bytesPerMegabyte).round()} MB';
  }
  final int kilobytes = (bytes / _bytesPerKilobyte).round();
  if (kilobytes >= _bytesPerKilobyte) {
    return '1 MB';
  }
  return '$kilobytes KB';
}

String percentText(double fraction) {
  final int percent = (fraction * 100 + 1e-9).floor().clamp(0, 100);
  return '$percent%';
}

String progressText(double fraction, int? bytes) => bytes == null
    ? percentText(fraction)
    : '${percentText(fraction)} of ${sizeText(bytes)}';

String installFailureText(InstallFailure failure) => switch (failure) {
  InstallFailure.network => 'The download stopped. Nothing was installed.',
  InstallFailure.verification =>
    'The download didn’t pass its safety check, so nothing was installed.',
  InstallFailure.permission =>
    'Allow Field Notes to install updates, then try again.',
  InstallFailure.notReady =>
    'This update isn’t ready to install yet. Try again in a few minutes.',
  InstallFailure.installer =>
    'The update couldn’t be installed. Your journal is unchanged.',
};

String checkFailureText(LookupFailure? reason, DateTime? retryAfter) {
  if (retryAfter != null) {
    return 'GitHub is busy. Try again after ${_clockTime(retryAfter)}.';
  }
  return switch (reason) {
    LookupFailure.offline =>
      'Couldn’t check for updates. Check your connection and try again.',
    LookupFailure.badResponse ||
    null => 'Couldn’t read the update information. Try again later.',
  };
}

String routeAction(InstallRoute route) => switch (route) {
  InstallRoute.restartInPlace => 'Update & restart',
  InstallRoute.systemInstaller => 'Download & install',
  InstallRoute.googlePlay => 'Open Google Play',
  InstallRoute.downloadPage => 'Open download page',
};

String routeNote(InstallRoute route, {required bool phone}) => switch (route) {
  InstallRoute.restartInPlace when phone =>
    'Your journal and any open draft are saved first. Field Notes restarts '
        'in a few seconds.',
  InstallRoute.restartInPlace =>
    'Field Notes saves your journal and any open draft, then restarts. It '
        'takes a few seconds.',
  InstallRoute.systemInstaller =>
    'Field Notes downloads the update, then Android asks you to install it. '
        'Open Field Notes again from the notification when it finishes.',
  InstallRoute.googlePlay =>
    'Google Play delivers this update. It can take a few days to reach your '
        'phone.',
  InstallRoute.downloadPage =>
    'This copy of Field Notes can’t update itself. The download page opens '
        'in your browser.',
};

String routeAvailableLine(InstallRoute route) => switch (route) {
  InstallRoute.restartInPlace =>
    'Read the changelog, then restart to update. Your journal is saved first.',
  InstallRoute.systemInstaller => 'Read the changelog, then install it.',
  InstallRoute.googlePlay =>
    'Read the changelog, then update from Google Play when it’s offered '
        'there.',
  InstallRoute.downloadPage => 'Read the changelog, then download it.',
};

const String updatesTitle = 'Updates';
const String notCheckedYet = 'Not checked yet';

String lastCheckedLine(DateTime at, DateTime now) =>
    'Last checked ${lastCheckedTime(at, now)}';

const String checkingTitle = 'Checking for updates…';
const String checkingDescription = 'This takes a moment.';
const String upToDateTitle = 'Field Notes is up to date';

String availableTitle(String version) => 'Version $version is available';

String downloadingTitle(String version) => 'Downloading version $version…';

const String downloadingUnknown = 'Downloading…';
const String checkFailedTitle = 'Couldn’t check for updates';

const String phoneCheckingLine = 'Looking for a new version…';

String phoneReadyLine(String version) => 'Version $version is ready to install';

String phoneUpToDateLine(String time) => 'Up to date · checked $time';

const String checkForUpdatesLabel = 'Check for updates';
const String checkingLabel = 'Checking…';
const String readChangelogLabel = 'Read changelog';
const String updateNowLabel = 'Update now…';

String phoneUpdateLabel(String version) => 'Update to $version…';

const String checkAutomaticallyLabel = 'Check automatically';
const String checkAutomaticallyDescription =
    'Once a day. Nothing installs until you choose.';
const String releaseNotesLabel = 'Release notes';

String releaseNotesDescription(String version) =>
    'What changed in version $version';

const String readNotesLabel = 'Read notes';

const String updateAvailableKicker = 'update available';
const String releaseNotesKicker = 'release notes';

String notesTitle(String version) => 'Field Notes $version';

String releasedLine(DateTime date) =>
    'Released ${_calendarDate(date.toLocal())}';

String downloadSizeSuffix(int bytes) => ' · ${sizeText(bytes)} download';

String noNotesText(String version) => 'No notes for version $version yet.';

const String laterLabel = 'Later';
const String closeLabel = 'Close';
const String closeTooltip = 'Close (Esc)';

String downloadingNote(double? fraction, int? bytes) => fraction == null
    ? downloadingUnknown
    : 'Downloading · ${progressText(fraction, bytes)}';

const String restartingTitle = 'Restarting Field Notes';

String openingVersionLine(String version) => 'opening version $version…';

const String updateAvailableLabel = 'Update available';

String versionLine(String version) => 'Version $version';

String railTooltip(String version) =>
    'Field Notes $version is available. Read the changelog and update.';

String railSemanticsLabel(String version) =>
    'Update available, version $version';

const String gearBadgeSuffix = ', update available';

String bannerTitle(String version) => 'Update available: $version';

const String bannerSubtitle = 'Read the changelog, then update';

String aboutRowReadySummary(String version) => 'Version $version is ready';

String updatedGreeting(String version) => 'Updated to Field Notes $version';
