import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const String sandboxDocumentsSubdir = 'documents';
const String sandboxSupportSubdir = 'support';
const String sandboxLibrarySubdir = 'library';
const String sandboxCacheSubdir = 'cache';
const String sandboxTemporarySubdir = 'temporary';
const String sandboxDownloadsSubdir = 'downloads';
const String sandboxExternalStorageSubdir = 'external-storage';
const String sandboxExternalCacheSubdir = 'external-cache';

class SandboxPathProvider extends PathProviderPlatform {
  SandboxPathProvider(this.root) {
    if (!p.isAbsolute(root.path)) {
      throw ArgumentError.value(
        root.path,
        'root',
        'sandbox path provider root must be an absolute path',
      );
    }
  }

  final Directory root;

  Directory get documentsDirectory => _materialize(sandboxDocumentsSubdir);

  Directory get supportDirectory => _materialize(sandboxSupportSubdir);

  Directory get libraryDirectory => _materialize(sandboxLibrarySubdir);

  Directory get cacheDirectory => _materialize(sandboxCacheSubdir);

  Directory get temporaryDirectory => _materialize(sandboxTemporarySubdir);

  Directory get downloadsDirectory => _materialize(sandboxDownloadsSubdir);

  Directory get externalStorageDirectory =>
      _materialize(sandboxExternalStorageSubdir);

  Directory get externalCacheDirectory =>
      _materialize(sandboxExternalCacheSubdir);

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      documentsDirectory.path;

  @override
  Future<String?> getApplicationSupportPath() async => supportDirectory.path;

  @override
  Future<String?> getLibraryPath() async => libraryDirectory.path;

  @override
  Future<String?> getApplicationCachePath() async => cacheDirectory.path;

  @override
  Future<String?> getTemporaryPath() async => temporaryDirectory.path;

  @override
  Future<String?> getDownloadsPath() async => downloadsDirectory.path;

  @override
  Future<String?> getExternalStoragePath() async =>
      externalStorageDirectory.path;

  @override
  Future<List<String>?> getExternalCachePaths() async =>
      <String>[externalCacheDirectory.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    final Directory directory = type == null
        ? externalStorageDirectory
        : _materialize(p.join(sandboxExternalStorageSubdir, type.name));
    return <String>[directory.path];
  }

  Directory _materialize(String relativePath) {
    final Directory directory = Directory(p.join(root.path, relativePath));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}

class SandboxPathProviderInstallation {
  const SandboxPathProviderInstallation({
    required this.provider,
    required this.previous,
  });

  final SandboxPathProvider provider;
  final PathProviderPlatform previous;

  Directory get documentsDirectory => provider.documentsDirectory;
}

SandboxPathProviderInstallation installSandboxPathProvider(Directory root) {
  final PathProviderPlatform previous = PathProviderPlatform.instance;
  final SandboxPathProvider provider = SandboxPathProvider(root);
  PathProviderPlatform.instance = provider;
  return SandboxPathProviderInstallation(
    provider: provider,
    previous: previous,
  );
}

void restorePathProviderPlatform(
  SandboxPathProviderInstallation installation,
) {
  PathProviderPlatform.instance = installation.previous;
}
