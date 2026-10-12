import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'installed_app_provider.g.dart';

class InstalledApp {
  const InstalledApp({required this.version, this.installerStore});

  final String version;
  final String? installerStore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledApp &&
          version == other.version &&
          installerStore == other.installerStore;

  @override
  int get hashCode => Object.hash(version, installerStore);

  @override
  String toString() =>
      'InstalledApp(version: $version, installerStore: $installerStore)';
}

@Riverpod(keepAlive: true)
Future<InstalledApp> installedApp(Ref ref) async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  return InstalledApp(
    version: info.version,
    installerStore: info.installerStore,
  );
}
