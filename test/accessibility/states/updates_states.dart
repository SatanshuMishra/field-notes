import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/data/updates/bundled_changelog.dart';
import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/data/updates/update_record_store.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/settings/sections/about_section.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show shellOverrides;
import '../../features/settings/support/fake_settings_repository.dart';
import '../../support/update_overrides.dart';
import '../support/a11y_state.dart';

const String _installedVersion = '1.4.2';
const String _newVersion = '2.4.0';
const String _openNew = 'open new notes';
const String _openInstalled = 'open installed notes';
final DateTime _checkedAt = DateTime(2026, 10, 10, 9);

final ReleaseInfo _release = ReleaseInfo(
  version: AppVersion.tryParse(_newVersion)!,
  tag: 'v$_newVersion',
  publishedAt: DateTime(2026, 10, 9, 12),
  notes: ReleaseNotes(
    intro: 'Logs now open the way they were made.',
    groups: <ReleaseNoteGroup>[
      ReleaseNoteGroup(
        title: 'New',
        items: <String>['Photos in a note open full screen.'],
      ),
      ReleaseNoteGroup(
        title: 'Fixed',
        items: <String>[
          'Portrait videos are no longer cropped.',
          'The daily reminder no longer arrives twice.',
        ],
      ),
    ],
  ),
  pageUrl: Uri.parse(
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v$_newVersion',
  ),
  assets: <ReleaseAsset>[
    ReleaseAsset(
      name: 'field-notes-$_newVersion-macos.dmg',
      url: Uri.parse('https://github.com/a/field-notes-$_newVersion-macos.dmg'),
      size: 38000000,
    ),
    ReleaseAsset(
      name: 'field-notes-$_newVersion-android.apk',
      url: Uri.parse(
        'https://github.com/a/field-notes-$_newVersion-android.apk',
      ),
      size: 41000000,
    ),
    ReleaseAsset(
      name: 'field-notes-$_newVersion-windows.msix',
      url: Uri.parse(
        'https://github.com/a/field-notes-$_newVersion-windows.msix',
      ),
      size: 52000000,
    ),
  ],
);

final class _FixedUpdates extends UpdateController {
  _FixedUpdates(this._status);

  final UpdateStatus _status;

  @override
  UpdateStatus build() => _status;

  @override
  Future<void> check() async {}

  @override
  Future<void> install() async {}
}

final class _PendingGreeting extends UpdateGreeting {
  @override
  String? build() => _newVersion;
}

final class _OfflineReleaseSource implements ReleaseSource {
  const _OfflineReleaseSource();

  @override
  Future<ReleaseLookup> latest() async =>
      const LookupFailed(LookupFailure.offline);
}

List<Override> _installedOverrides() => <Override>[
  settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  appSettingsProvider.overrideWith(
    (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
  ),
  installedAppProvider.overrideWith(
    (Ref ref) async => const InstalledApp(version: _installedVersion),
  ),
];

List<Override> _notesOverrides() => <Override>[
  ..._installedOverrides(),
  ...updateQuietOverrides(),
  updateControllerProvider.overrideWith(
    () => _FixedUpdates(UpdateAvailable(_release, _checkedAt)),
  ),
  updateRouteProvider.overrideWith(
    (Ref ref) async => InstallRoute.restartInPlace,
  ),
  installedReleaseNotesProvider.overrideWith(
    (Ref ref) async => ChangelogSection(
      notes: ReleaseNotes(
        intro: 'Settings are easier to find.',
        groups: <ReleaseNoteGroup>[
          ReleaseNoteGroup(
            title: 'Improved',
            items: <String>['Each settings section opens as its own page.'],
          ),
        ],
      ),
      date: DateTime(2026, 10, 1, 12),
    ),
  ),
];

List<Override> _offlineOverrides() => <Override>[
  ..._installedOverrides(),
  updateClockProvider.overrideWithValue(() => _checkedAt),
  updateRecordStoreProvider.overrideWithValue(
    MemoryUpdateRecordStore(const UpdateRecord()),
  ),
  releaseSourceProvider.overrideWithValue(const _OfflineReleaseSource()),
];

Widget _app(
  A11yVariant variant, {
  required List<Override> overrides,
  required Widget home,
}) => ProviderScope(
  key: UniqueKey(),
  retry: (int retryCount, Object error) => null,
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: variant.theme,
    builder: variant.scaleText,
    home: home,
  ),
);

class _NotesLauncher extends ConsumerWidget {
  const _NotesLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.page,
      body: Column(
        children: <Widget>[
          TextButton(
            onPressed: () => showUpdateNotes(context, ref, newVersion: true),
            child: const Text(_openNew),
          ),
          TextButton(
            onPressed: () => showUpdateNotes(context, ref, newVersion: false),
            child: const Text(_openInstalled),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpNotes(
  WidgetTester tester,
  A11yVariant variant,
  String which,
) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    _app(variant, overrides: _notesOverrides(), home: const _NotesLauncher()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(which));
  await tester.pumpAndSettle();
}

Future<void> _pumpGreeting(WidgetTester tester, A11yVariant variant) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    _app(
      variant,
      overrides: <Override>[
        ...shellOverrides(),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        installedAppProvider.overrideWith(
          (Ref ref) async => const InstalledApp(version: _newVersion),
        ),
        updateGreetingProvider.overrideWith(_PendingGreeting.new),
      ],
      home: const AppShell(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpCheckFailed(WidgetTester tester, A11yVariant variant) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    _app(
      variant,
      overrides: _offlineOverrides(),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: context.colors.page,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AboutSection(onFeedback: (String _) {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(checkForUpdatesLabel));
  await tester.pumpAndSettle();
}

final Finder _notesSurface = find.byWidgetPredicate(
  (Widget widget) =>
      widget.key == updateNotesPanelKey || widget.key == updateNotesSheetKey,
  description: 'the update notes panel or sheet',
);

final List<A11yState> updatesStates = <A11yState>[
  A11yState(
    id: 'u1-update-notes-new',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpNotes(tester, variant, _openNew),
    proof: <A11yProof>[
      A11yProof(_notesSurface),
      A11yProof(find.byKey(updateNotesActionKey)),
      A11yProof(find.text('Portrait videos are no longer cropped.')),
    ],
  ),
  A11yState(
    id: 'u2-update-notes-installed',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpNotes(tester, variant, _openInstalled),
    proof: <A11yProof>[
      A11yProof(_notesSurface),
      A11yProof(find.text('Each settings section opens as its own page.')),
    ],
  ),
  A11yState(
    id: 'u3-update-greeting',
    pump: _pumpGreeting,
    proof: <A11yProof>[
      A11yProof(find.byType(AppShell)),
      A11yProof(find.text(updatedGreeting(_newVersion))),
    ],
  ),
  A11yState(
    id: 'u4-update-error-offline',
    pump: _pumpCheckFailed,
    proof: <A11yProof>[
      A11yProof(find.byType(AboutSection)),
      A11yProof(
        find.textContaining(checkFailureText(LookupFailure.offline, null)),
      ),
    ],
  ),
];
