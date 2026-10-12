import 'package:field_notes/data/links/link_opener.dart';
import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:flutter/services.dart';

final class DownloadPageInstaller implements UpdateInstaller {
  const DownloadPageInstaller({this._openLink = openInBrowser});

  final LinkOpener _openLink;

  @override
  InstallRoute get route => InstallRoute.downloadPage;

  @override
  Stream<InstallEvent> install(ReleaseInfo release) async* {
    yield await _open(release.pageUrl)
        ? const InstallHandedOff()
        : const InstallFailed(InstallFailure.installer);
  }

  Future<bool> _open(Uri page) async {
    try {
      return await _openLink(page);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
