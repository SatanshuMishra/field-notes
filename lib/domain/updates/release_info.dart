import 'package:field_notes/domain/updates/app_version.dart';
import 'package:flutter/foundation.dart';

const String releaseSumsName = 'SHA256SUMS.txt';
const String releaseSignatureName = 'SHA256SUMS.txt.sig';

final class ReleaseNoteGroup {
  ReleaseNoteGroup({required this.title, required List<String> items})
    : items = List<String>.unmodifiable(items);

  final String title;
  final List<String> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseNoteGroup &&
          title == other.title &&
          listEquals(items, other.items);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(items));

  @override
  String toString() => 'ReleaseNoteGroup(title: $title, items: $items)';
}

final class ReleaseNotes {
  ReleaseNotes({required this.intro, required List<ReleaseNoteGroup> groups})
    : groups = List<ReleaseNoteGroup>.unmodifiable(groups);

  const ReleaseNotes._empty() : intro = '', groups = const <ReleaseNoteGroup>[];

  static const ReleaseNotes empty = ReleaseNotes._empty();

  final String intro;
  final List<ReleaseNoteGroup> groups;

  bool get isEmpty => intro.isEmpty && groups.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseNotes &&
          intro == other.intro &&
          listEquals(groups, other.groups);

  @override
  int get hashCode => Object.hash(intro, Object.hashAll(groups));

  @override
  String toString() => 'ReleaseNotes(intro: $intro, groups: $groups)';
}

final class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final Uri url;
  final int size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseAsset &&
          name == other.name &&
          url == other.url &&
          size == other.size;

  @override
  int get hashCode => Object.hash(name, url, size);

  @override
  String toString() => 'ReleaseAsset(name: $name, url: $url, size: $size)';
}

final class ReleaseInfo {
  ReleaseInfo({
    required this.version,
    required this.tag,
    required DateTime publishedAt,
    required this.notes,
    required this.pageUrl,
    required List<ReleaseAsset> assets,
  }) : publishedAt = publishedAt.toUtc(),
       assets = List<ReleaseAsset>.unmodifiable(assets);

  final AppVersion version;
  final String tag;
  final DateTime publishedAt;
  final ReleaseNotes notes;
  final Uri pageUrl;
  final List<ReleaseAsset> assets;

  ReleaseAsset? asset(String name) {
    for (final ReleaseAsset candidate in assets) {
      if (candidate.name == name) {
        return candidate;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version.toString(),
    'tag': tag,
    'publishedAt': publishedAt.toIso8601String(),
    'notes': <String, Object?>{
      'intro': notes.intro,
      'groups': <Object?>[
        for (final ReleaseNoteGroup group in notes.groups)
          <String, Object?>{'title': group.title, 'items': group.items},
      ],
    },
    'pageUrl': pageUrl.toString(),
    'assets': <Object?>[
      for (final ReleaseAsset asset in assets)
        <String, Object?>{
          'name': asset.name,
          'url': asset.url.toString(),
          'size': asset.size,
        },
    ],
  };

  static ReleaseInfo? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final Object? versionText = json['version'];
    final Object? tag = json['tag'];
    final Object? publishedText = json['publishedAt'];
    if (versionText is! String ||
        tag is! String ||
        tag.isEmpty ||
        publishedText is! String) {
      return null;
    }
    final AppVersion? version = AppVersion.tryParse(versionText);
    final DateTime? publishedAt = DateTime.tryParse(publishedText);
    final Uri? pageUrl = _absoluteUri(json['pageUrl']);
    final ReleaseNotes? notes = _notesFromJson(json['notes']);
    final List<ReleaseAsset>? assets = _listFromJson(
      json['assets'],
      _assetFromJson,
    );
    if (version == null ||
        publishedAt == null ||
        pageUrl == null ||
        notes == null ||
        assets == null) {
      return null;
    }
    return ReleaseInfo(
      version: version,
      tag: tag,
      publishedAt: publishedAt,
      notes: notes,
      pageUrl: pageUrl,
      assets: assets,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseInfo &&
          version == other.version &&
          tag == other.tag &&
          publishedAt == other.publishedAt &&
          notes == other.notes &&
          pageUrl == other.pageUrl &&
          listEquals(assets, other.assets);

  @override
  int get hashCode => Object.hash(
    version,
    tag,
    publishedAt,
    notes,
    pageUrl,
    Object.hashAll(assets),
  );

  @override
  String toString() =>
      'ReleaseInfo(version: $version, tag: $tag, '
      'publishedAt: ${publishedAt.toIso8601String()}, pageUrl: $pageUrl, '
      'assets: $assets)';
}

String releaseFileVersion(ReleaseInfo release) =>
    release.tag.startsWith('v') ? release.tag.substring(1) : release.tag;

String? platformAssetName(TargetPlatform platform, ReleaseInfo release) {
  final String version = releaseFileVersion(release);
  return switch (platform) {
    TargetPlatform.macOS => 'field-notes-$version-macos.dmg',
    TargetPlatform.windows => 'field-notes-$version-windows-x64-setup.exe',
    TargetPlatform.android => 'field-notes-$version-android.apk',
    TargetPlatform.iOS ||
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => null,
  };
}

Uri? _absoluteUri(Object? value) {
  if (value is! String) {
    return null;
  }
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  return uri;
}

List<T>? _listFromJson<T>(Object? json, T? Function(Object?) read) {
  if (json is! List) {
    return null;
  }
  final List<T?> values = <T?>[for (final Object? item in json) read(item)];
  if (values.contains(null)) {
    return null;
  }
  return values.whereType<T>().toList();
}

String? _stringFromJson(Object? json) => json is String ? json : null;

ReleaseNotes? _notesFromJson(Object? json) {
  if (json is! Map) {
    return null;
  }
  final Object? intro = json['intro'];
  final List<ReleaseNoteGroup>? groups = _listFromJson(
    json['groups'],
    _groupFromJson,
  );
  if (intro is! String || groups == null) {
    return null;
  }
  return ReleaseNotes(intro: intro, groups: groups);
}

ReleaseNoteGroup? _groupFromJson(Object? json) {
  if (json is! Map) {
    return null;
  }
  final Object? title = json['title'];
  final List<String>? items = _listFromJson(json['items'], _stringFromJson);
  if (title is! String || items == null) {
    return null;
  }
  return ReleaseNoteGroup(title: title, items: items);
}

ReleaseAsset? _assetFromJson(Object? json) {
  if (json is! Map) {
    return null;
  }
  final Object? name = json['name'];
  final Uri? url = _absoluteUri(json['url']);
  final Object? size = json['size'];
  if (name is! String ||
      name.isEmpty ||
      url == null ||
      size is! int ||
      size < 0) {
    return null;
  }
  return ReleaseAsset(name: name, url: url, size: size);
}
