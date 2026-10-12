import 'package:field_notes/state/installed_app_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void _mockPackage({required String version, String? installerStore}) {
  PackageInfo.setMockInitialValues(
    appName: 'Field Notes',
    packageName: 'dev.satanshumishra.field_notes',
    version: version,
    buildNumber: '7',
    buildSignature: '',
    installerStore: installerStore,
  );
}

Future<InstalledApp> _readInstalled() async {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(installedAppProvider.future);
}

void main() {
  test('the installed app reports its version and installer', () async {
    _mockPackage(version: '1.2.0', installerStore: 'com.android.vending');
    final InstalledApp fromPlay = await _readInstalled();
    expect(fromPlay.version, '1.2.0');
    expect(fromPlay.installerStore, 'com.android.vending');
    expect(
      fromPlay,
      const InstalledApp(
        version: '1.2.0',
        installerStore: 'com.android.vending',
      ),
    );

    _mockPackage(version: '1.4.2');
    final InstalledApp sideloaded = await _readInstalled();
    expect(sideloaded.version, '1.4.2');
    expect(sideloaded.installerStore, isNull);
    expect(sideloaded, const InstalledApp(version: '1.4.2'));
    expect(sideloaded.hashCode, const InstalledApp(version: '1.4.2').hashCode);
    expect(sideloaded, isNot(fromPlay));
  });
}
