import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:http/http.dart' as http;

final Uri latestReleaseUrl = Uri.parse(
  'https://api.github.com/repos/SatanshuMishra/field-notes/releases/latest',
);

const Map<String, String> latestReleaseHeaders = <String, String>{
  'Accept': 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'FieldNotes',
};

const Duration releaseLookupTimeout = Duration(seconds: 20);
const int releaseLookupBodyCap = 1024 * 1024;
const Duration releaseLookupDefaultWait = Duration(seconds: 60);

final class _BodyTooLarge implements Exception {
  const _BodyTooLarge();
}

final class GitHubReleaseSource implements ReleaseSource {
  GitHubReleaseSource({required this._client, this._clock = DateTime.now});

  final http.Client _client;
  final DateTime Function() _clock;

  @override
  Future<ReleaseLookup> latest() async {
    try {
      return await _lookup().timeout(releaseLookupTimeout);
    } on TimeoutException {
      return const LookupFailed(LookupFailure.offline);
    } on IOException {
      return const LookupFailed(LookupFailure.offline);
    } on http.ClientException {
      return const LookupFailed(LookupFailure.offline);
    } on _BodyTooLarge {
      return const LookupFailed(LookupFailure.badResponse);
    }
  }

  Future<ReleaseLookup> _lookup() async {
    final http.Request request = http.Request('GET', latestReleaseUrl)
      ..headers.addAll(latestReleaseHeaders);
    final http.StreamedResponse response = await _client.send(request);
    final int status = response.statusCode;
    if (status == HttpStatus.ok) {
      final Uint8List body = await _readCapped(response);
      return _found(body);
    }
    await response.stream.listen(null).cancel();
    if (status == HttpStatus.notFound) {
      return const NoRelease();
    }
    if (status == HttpStatus.forbidden ||
        status == HttpStatus.tooManyRequests) {
      return LookupRateLimited(_retryAfter(response.headers));
    }
    return const LookupFailed(LookupFailure.badResponse);
  }

  Future<Uint8List> _readCapped(http.StreamedResponse response) async {
    final int? length = response.contentLength;
    if (length != null && length > releaseLookupBodyCap) {
      await response.stream.listen(null).cancel();
      throw const _BodyTooLarge();
    }
    final BytesBuilder received = BytesBuilder(copy: false);
    final Completer<Uint8List> done = Completer<Uint8List>();
    late final StreamSubscription<List<int>> subscription;
    subscription = response.stream.listen(
      (List<int> chunk) {
        if (received.length + chunk.length > releaseLookupBodyCap) {
          unawaited(subscription.cancel());
          if (!done.isCompleted) {
            done.completeError(const _BodyTooLarge());
          }
          return;
        }
        received.add(chunk);
      },
      onError: (Object error, StackTrace stack) {
        unawaited(subscription.cancel());
        if (!done.isCompleted) {
          done.completeError(error, stack);
        }
      },
      onDone: () {
        if (!done.isCompleted) {
          done.complete(received.takeBytes());
        }
      },
      cancelOnError: true,
    );
    return done.future;
  }

  DateTime _retryAfter(Map<String, String> headers) {
    final DateTime now = _clock().toUtc();
    if (headers['x-ratelimit-remaining']?.trim() == '0') {
      final int? reset = int.tryParse(
        headers['x-ratelimit-reset']?.trim() ?? '',
      );
      if (reset != null && reset >= 0) {
        return DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true);
      }
    }
    final int? seconds = int.tryParse(headers['retry-after']?.trim() ?? '');
    if (seconds != null && seconds >= 0) {
      return now.add(Duration(seconds: seconds));
    }
    return now.add(releaseLookupDefaultWait);
  }

  ReleaseLookup _found(Uint8List body) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(body));
    } on FormatException {
      return const LookupFailed(LookupFailure.badResponse);
    }
    final ReleaseInfo? release = _release(json);
    if (release == null) {
      return const LookupFailed(LookupFailure.badResponse);
    }
    return ReleaseFound(release);
  }

  static ReleaseInfo? _release(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    if (json['draft'] != false || json['prerelease'] != false) {
      return null;
    }
    final Object? tag = json['tag_name'];
    final Object? published = json['published_at'];
    final Object? body = json['body'];
    final Object? assets = json['assets'];
    if (tag is! String ||
        published is! String ||
        (body != null && body is! String) ||
        assets is! List<Object?>) {
      return null;
    }
    final AppVersion? version = AppVersion.tryParse(tag);
    final DateTime? publishedAt = DateTime.tryParse(published);
    final Uri? pageUrl = _githubUrl(json['html_url']);
    if (version == null || publishedAt == null || pageUrl == null) {
      return null;
    }
    return ReleaseInfo(
      version: version,
      tag: tag,
      publishedAt: publishedAt,
      notes: parseReleaseNotes(body is String ? body : ''),
      pageUrl: pageUrl,
      assets: <ReleaseAsset>[
        for (final Object? asset in assets) ?_asset(asset),
      ],
    );
  }

  static ReleaseAsset? _asset(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? name = json['name'];
    final Object? size = json['size'];
    final Uri? url = _githubUrl(json['browser_download_url']);
    if (name is! String || name.isEmpty || size is! int || size < 0) {
      return null;
    }
    if (url == null) {
      return null;
    }
    return ReleaseAsset(name: name, url: url, size: size);
  }

  static Uri? _githubUrl(Object? value) {
    if (value is! String) {
      return null;
    }
    final Uri? url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        url.userInfo.isNotEmpty ||
        url.port != 443) {
      return null;
    }
    return url;
  }
}
