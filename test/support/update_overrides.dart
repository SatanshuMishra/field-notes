import 'package:field_notes/data/updates/download_page_installer.dart';
import 'package:field_notes/data/updates/update_record_store.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final DateTime updateQuietNow = DateTime(2026, 7, 20, 9);

final class _QuietReleaseSource implements ReleaseSource {
  const _QuietReleaseSource();

  @override
  Future<ReleaseLookup> latest() async => const NoRelease();
}

Future<bool> _openedQuietly(Uri link) async => true;

List<Override> updateQuietOverrides() => <Override>[
  updateClockProvider.overrideWithValue(() => updateQuietNow),
  updateRecordStoreProvider.overrideWithValue(
    MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: updateQuietNow)),
  ),
  releaseSourceProvider.overrideWithValue(const _QuietReleaseSource()),
  updateInstallerProvider.overrideWith(
    (Ref ref) async => const DownloadPageInstaller(openLink: _openedQuietly),
  ),
];
