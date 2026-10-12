import 'package:field_notes/data/updates/android_update_installers.dart';
import 'package:field_notes/data/updates/download_page_installer.dart';
import 'package:field_notes/data/updates/github_release_source.dart';
import 'package:field_notes/data/updates/macos_update_installer.dart';
import 'package:field_notes/data/updates/release_download.dart';
import 'package:field_notes/data/updates/release_verifier.dart';
import 'package:field_notes/data/updates/windows_update_installer.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_providers.g.dart';

const String googlePlayInstallerStore = 'com.android.vending';

@Riverpod(keepAlive: true)
http.Client updateHttpClient(Ref ref) {
  final http.Client client = http.Client();
  ref.onDispose(client.close);
  return client;
}

@Riverpod(keepAlive: true)
DateTime Function() updateClock(Ref ref) => DateTime.now;

@Riverpod(keepAlive: true)
ReleaseSource releaseSource(Ref ref) {
  return GitHubReleaseSource(
    client: ref.watch(updateHttpClientProvider),
    clock: ref.watch(updateClockProvider),
  );
}

@Riverpod(keepAlive: true)
Future<UpdateInstaller> updateInstaller(Ref ref) async {
  final ReleaseVerifier? verifier = ReleaseVerifier.fromBase64(
    updatePublicKeyBase64,
  );
  ReleaseDownloader downloader(ReleaseVerifier verifier) => ReleaseDownloader(
    client: ref.watch(updateHttpClientProvider),
    verifier: verifier,
  );
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      return verifier == null
          ? const DownloadPageInstaller()
          : const MacUpdateInstaller();
    case TargetPlatform.windows:
      return verifier == null
          ? const DownloadPageInstaller()
          : WindowsUpdateInstaller(downloader: downloader(verifier));
    case TargetPlatform.android:
      if (await _installerStore(ref) == googlePlayInstallerStore) {
        return const GooglePlayInstaller();
      }
      if (verifier != null && await androidCanSelfUpdate()) {
        return ApkUpdateInstaller(downloader: downloader(verifier));
      }
      return const DownloadPageInstaller();
    case TargetPlatform.iOS || TargetPlatform.linux || TargetPlatform.fuchsia:
      return const DownloadPageInstaller();
  }
}

Future<String?> _installerStore(Ref ref) async {
  try {
    final InstalledApp installed = await ref.watch(installedAppProvider.future);
    return installed.installerStore;
  } on Exception catch (error) {
    debugPrint('The installer store could not be read: $error');
    return null;
  }
}

@Riverpod(keepAlive: true)
Future<InstallRoute> updateRoute(Ref ref) async {
  final UpdateInstaller installer = await ref.watch(
    updateInstallerProvider.future,
  );
  return installer.route;
}

@Riverpod(keepAlive: true)
ReleaseInfo? updateNotice(Ref ref) {
  final UpdateStatus status = ref.watch(updateControllerProvider);
  final InstallRoute? route = ref.watch(updateRouteProvider).value;
  if (status is! UpdateAvailable ||
      route == null ||
      route == InstallRoute.googlePlay) {
    return null;
  }
  return status.release;
}
