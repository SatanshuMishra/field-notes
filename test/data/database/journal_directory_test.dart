import 'package:field_notes/data/database/journal_directory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _DistinctPaths extends PathProviderPlatform {
  static const String documents = '/fake/documents';
  static const String support = '/fake/support';

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;

  @override
  Future<String?> getApplicationSupportPath() async => support;
}

void main() {
  late PathProviderPlatform previous;

  setUp(() {
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DistinctPaths();
  });

  tearDown(() {
    PathProviderPlatform.instance = previous;
  });

  test('Windows keeps the journal in the application support folder', () async {
    final directory = await journalDirectory(platform: TargetPlatform.windows);

    expect(directory.path, _DistinctPaths.support);
    expect(directory.path, isNot(_DistinctPaths.documents));
  });

  test('macOS and Android keep the documents folder', () async {
    final mac = await journalDirectory(platform: TargetPlatform.macOS);
    final android = await journalDirectory(platform: TargetPlatform.android);

    expect(mac.path, _DistinctPaths.documents);
    expect(android.path, _DistinctPaths.documents);
  });
}
