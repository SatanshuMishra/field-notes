import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/updates/release_verifier.dart';
import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const Set<String> releaseDownloadHosts = <String>{
  'github.com',
  'release-assets.githubusercontent.com',
  'objects.githubusercontent.com',
};

const int releaseSumsCap = 64 * 1024;
const int releaseInstallerCap = 512 * 1024 * 1024;
const int releaseRedirectLimit = 5;
const Duration releaseDownloadTimeout = Duration(seconds: 30);

const Set<int> _redirectStatuses = <int>{301, 302, 303, 307, 308};

bool isReleaseDownloadUrl(Uri url) =>
    url.scheme == 'https' &&
    url.userInfo.isEmpty &&
    url.port == 443 &&
    releaseDownloadHosts.contains(url.host);

sealed class DownloadOutcome {
  const DownloadOutcome();
}

final class DownloadVerified extends DownloadOutcome {
  const DownloadVerified(this.file);

  final File file;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadVerified && file.path == other.file.path;

  @override
  int get hashCode => Object.hash(DownloadVerified, file.path);

  @override
  String toString() => 'DownloadVerified(${file.path})';
}

final class DownloadFailed extends DownloadOutcome {
  const DownloadFailed(this.failure);

  final InstallFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadFailed && failure == other.failure;

  @override
  int get hashCode => Object.hash(DownloadFailed, failure);

  @override
  String toString() => 'DownloadFailed($failure)';
}

final class _DownloadStopped implements Exception {
  const _DownloadStopped(this.reason);

  final String reason;

  @override
  String toString() => 'Download stopped: $reason';
}

final class ReleaseDownloader {
  ReleaseDownloader({
    required this._client,
    required this._verifier,
    this.progressInterval = const Duration(milliseconds: 100),
    this.timeout = releaseDownloadTimeout,
  });

  final Duration progressInterval;
  final Duration timeout;
  final http.Client _client;
  final ReleaseVerifier _verifier;

  Future<DownloadOutcome> downloadVerified({
    required ReleaseInfo release,
    required String assetName,
    required Directory into,
    required void Function(InstallEvent event) onEvent,
  }) async {
    final ReleaseAsset? asset = _isPlainFileName(assetName)
        ? release.asset(assetName)
        : null;
    final ReleaseAsset? sums = release.asset(releaseSumsName);
    final ReleaseAsset? signature = release.asset(releaseSignatureName);
    if (asset == null || sums == null || signature == null) {
      return const DownloadFailed(InstallFailure.notReady);
    }
    final File file = File(p.join(into.path, assetName));
    try {
      final DownloadOutcome outcome = await _fetchVerified(
        asset: asset,
        sums: sums,
        signature: signature,
        file: file,
        onEvent: onEvent,
      );
      if (outcome is DownloadFailed) {
        await _remove(file);
      }
      return outcome;
    } catch (_) {
      await _remove(file);
      rethrow;
    }
  }

  Future<DownloadOutcome> _fetchVerified({
    required ReleaseAsset asset,
    required ReleaseAsset sums,
    required ReleaseAsset signature,
    required File file,
    required void Function(InstallEvent event) onEvent,
  }) async {
    final Uint8List sumsBytes;
    final Uint8List signatureBytes;
    try {
      sumsBytes = await _readWhole(sums.url);
      signatureBytes = await _readWhole(signature.url);
      await _streamInto(asset.url, file, onEvent);
    } on Exception {
      return const DownloadFailed(InstallFailure.network);
    }
    onEvent(const InstallVerifying());
    final bool verified = await _verifier.verify(
      sums: sumsBytes,
      signature: utf8.decode(signatureBytes, allowMalformed: true),
      fileName: asset.name,
      file: file,
    );
    return verified
        ? DownloadVerified(file)
        : const DownloadFailed(InstallFailure.verification);
  }

  static bool _isPlainFileName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains(r'\');

  Future<http.StreamedResponse> _open(Uri first) async {
    Uri url = first;
    for (int hop = 0; ; hop++) {
      if (!isReleaseDownloadUrl(url)) {
        throw _DownloadStopped('$url is not a release download address');
      }
      final http.Request request = http.Request('GET', url)
        ..followRedirects = false;
      final http.StreamedResponse response = await _client
          .send(request)
          .timeout(timeout);
      if (!_redirectStatuses.contains(response.statusCode)) {
        if (response.statusCode != HttpStatus.ok) {
          await _discard(response);
          throw _DownloadStopped('$url answered ${response.statusCode}');
        }
        return response;
      }
      await _discard(response);
      final String? location = response.headers['location'];
      if (hop >= releaseRedirectLimit || location == null) {
        throw _DownloadStopped('$url redirected too often or nowhere');
      }
      url = url.resolve(location);
    }
  }

  Future<Uint8List> _readWhole(Uri url) async {
    final http.StreamedResponse response = await _open(url);
    final int? length = response.contentLength;
    if (length != null && length > releaseSumsCap) {
      await _discard(response);
      throw _DownloadStopped('$url is larger than $releaseSumsCap bytes');
    }
    final BytesBuilder received = BytesBuilder(copy: false);
    await for (final List<int> chunk in response.stream.timeout(timeout)) {
      if (received.length + chunk.length > releaseSumsCap) {
        throw _DownloadStopped('$url is larger than $releaseSumsCap bytes');
      }
      received.add(chunk);
    }
    return received.takeBytes();
  }

  Future<void> _streamInto(
    Uri url,
    File file,
    void Function(InstallEvent event) onEvent,
  ) async {
    final http.StreamedResponse response = await _open(url);
    final int? total = response.contentLength;
    if (total != null && total > releaseInstallerCap) {
      await _discard(response);
      throw _DownloadStopped('$url is larger than $releaseInstallerCap bytes');
    }
    final Stopwatch clock = Stopwatch()..start();
    Duration? lastReport;
    int reported = -1;
    int received = 0;
    final IOSink sink = file.openWrite();
    try {
      await for (final List<int> chunk in response.stream.timeout(timeout)) {
        if (received + chunk.length > releaseInstallerCap) {
          throw _DownloadStopped(
            '$url is larger than $releaseInstallerCap bytes',
          );
        }
        sink.add(chunk);
        received += chunk.length;
        final Duration now = clock.elapsed;
        if (lastReport == null || now - lastReport >= progressInterval) {
          lastReport = now;
          reported = received;
          onEvent(InstallDownloading(received, total));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (total != null && received != total) {
      throw _DownloadStopped('$url ended after $received of $total bytes');
    }
    if (reported != received) {
      onEvent(InstallDownloading(received, total));
    }
  }

  static Future<void> _discard(http.StreamedResponse response) async {
    await response.stream.listen(null).cancel();
  }

  static Future<void> _remove(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }
}
