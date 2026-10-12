import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bundled_changelog.g.dart';

const String bundledChangelogAsset = 'CHANGELOG.md';

@Riverpod(keepAlive: true)
Future<String> bundledChangelog(Ref ref) {
  return rootBundle.loadString(bundledChangelogAsset);
}

@Riverpod(keepAlive: true)
Future<ChangelogSection?> installedReleaseNotes(Ref ref) async {
  final InstalledApp installed = await ref.watch(installedAppProvider.future);
  final AppVersion? version = AppVersion.tryParse(installed.version);
  if (version == null) {
    return null;
  }
  final String changelog = await ref.watch(bundledChangelogProvider.future);
  return changelogSection(changelog, version);
}
