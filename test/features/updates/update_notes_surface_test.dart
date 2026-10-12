import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/updates/bundled_changelog.dart';
import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/ui/update_restart_splash.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/update_overrides.dart';
import '../settings/support/fake_settings_repository.dart';

const Size _desktopWindow = Size(1140, 768);
const Size _phoneView = Size(384, 832);
const String _openNew = 'open new notes';
const String _openInstalled = 'open installed notes';
const double _tolerance = 0.01;

final ReleaseInfo _release = ReleaseInfo(
  version: AppVersion.tryParse('2.4.0')!,
  tag: 'v2.4.0',
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
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v2.4.0',
  ),
  assets: <ReleaseAsset>[
    ReleaseAsset(
      name: 'field-notes-2.4.0-macos.dmg',
      url: Uri.parse('https://github.com/a/field-notes-2.4.0-macos.dmg'),
      size: 38000000,
    ),
    ReleaseAsset(
      name: 'field-notes-2.4.0-android.apk',
      url: Uri.parse('https://github.com/a/field-notes-2.4.0-android.apk'),
      size: 41000000,
    ),
  ],
);

final class _FixedUpdates extends UpdateController {
  _FixedUpdates(this._initial);

  final UpdateStatus _initial;
  int installs = 0;

  @override
  UpdateStatus build() => _initial;

  @override
  Future<void> check() async {}

  @override
  Future<void> install() async {
    installs++;
  }

  void emit(UpdateStatus status) => state = status;
}

List<Override> _overrides({
  required _FixedUpdates updates,
  InstallRoute route = InstallRoute.restartInPlace,
  ReleaseNotes? installedNotes,
}) => <Override>[
  settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  ...updateQuietOverrides(),
  installedAppProvider.overrideWith(
    (Ref ref) async => const InstalledApp(version: '1.4.2'),
  ),
  updateControllerProvider.overrideWith(() => updates),
  updateRouteProvider.overrideWith((Ref ref) async => route),
  installedReleaseNotesProvider.overrideWith(
    (Ref ref) async => ChangelogSection(
      notes:
          installedNotes ??
          ReleaseNotes(
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

Future<void> _pumpHost(
  WidgetTester tester, {
  required TargetPlatform platform,
  required _FixedUpdates updates,
  InstallRoute route = InstallRoute.restartInPlace,
  ReleaseNotes? installedNotes,
}) async {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phoneView : _desktopWindow;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    const FakeViewPadding padding = FakeViewPadding(top: 34, bottom: 24);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(
        updates: updates,
        route: route,
        installedNotes: installedNotes,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) =>
              Scaffold(
                body: Column(
                  children: <Widget>[
                    TextButton(
                      onPressed: () =>
                          showUpdateNotes(context, ref, newVersion: true),
                      child: const Text(_openNew),
                    ),
                    TextButton(
                      onPressed: () =>
                          showUpdateNotes(context, ref, newVersion: false),
                      child: const Text(_openInstalled),
                    ),
                  ],
                ),
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String which) async {
  await tester.tap(find.text(which));
  await tester.pumpAndSettle();
}

TextStyle? _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style;

void _expectText(
  WidgetTester tester,
  String text, {
  required String family,
  required double size,
  FontWeight? weight,
  Color? color,
  double? height,
}) {
  final TextStyle? style = _style(tester, text);
  expect(style?.fontFamily, family, reason: text);
  expect(style?.fontSize, size, reason: text);
  if (weight != null) {
    expect(style?.fontWeight, weight, reason: text);
  }
  if (color != null) {
    expect(style?.color?.toARGB32(), color.toARGB32(), reason: text);
  }
  if (height != null) {
    expect(style?.height, height, reason: text);
  }
}

void _expectTile(WidgetTester tester, double size) {
  final Finder tile = find.byKey(updateNotesTileKey);
  expect(tester.getSize(tile), Size(size, size));
  final BoxDecoration face =
      tester.widget<Container>(tile).decoration! as BoxDecoration;
  expect(
    face.color?.toARGB32(),
    Palette.coral.withValues(alpha: 0.10).toARGB32(),
  );
  final Border border = face.border! as Border;
  expect(border.top.width, 1.5);
  expect(
    border.top.color.toARGB32(),
    Palette.coral.withValues(alpha: 0.45).toARGB32(),
  );
  expect(face.borderRadius, BorderRadius.circular(12));
  final SettingsIcon icon = tester.widget<SettingsIcon>(
    find.descendant(of: tile, matching: find.byType(SettingsIcon)),
  );
  expect(icon.glyph, SettingsGlyph.download);
  expect(icon.size, 22);
}

String _routeNote(InstallRoute route, {required bool phone}) => switch (route) {
  InstallRoute.restartInPlace when phone =>
    'Your journal and any open draft are saved first. Field Notes '
        'restarts in a few seconds.',
  InstallRoute.restartInPlace =>
    'Field Notes saves your journal and any open draft, then restarts. '
        'It takes a few seconds.',
  InstallRoute.systemInstaller =>
    'Field Notes downloads the update, then Android asks you to install '
        'it. Open Field Notes again from the notification when it '
        'finishes.',
  InstallRoute.googlePlay =>
    'Google Play delivers this update. It can take a few days to reach '
        'your phone.',
  InstallRoute.downloadPage =>
    'This copy of Field Notes can’t update itself. The download page '
        'opens in your browser.',
};

const Map<InstallRoute, String> _actions = <InstallRoute, String>{
  InstallRoute.restartInPlace: 'Update & restart',
  InstallRoute.systemInstaller: 'Download & install',
  InstallRoute.googlePlay: 'Open Google Play',
  InstallRoute.downloadPage: 'Open download page',
};

void main() {
  testWidgets(
    'the notes panel and sheet show the release and the right action',
    (WidgetTester tester) async {
      final FieldNotesColors colors = FieldNotesColors.light;
      _FixedUpdates updates = _FixedUpdates(
        UpdateAvailable(_release, DateTime(2026, 10, 10)),
      );
      await _pumpHost(tester, platform: TargetPlatform.macOS, updates: updates);
      await _open(tester, _openNew);

      final Finder panel = find.byKey(updateNotesPanelKey);
      expect(panel, findsOneWidget);
      final Rect panelRect = tester.getRect(panel);
      expect(panelRect.width, closeTo(660, _tolerance));
      expect(
        panelRect.center.dx,
        closeTo(_desktopWindow.width / 2, _tolerance),
      );
      expect(panelRect.height, lessThanOrEqualTo(_desktopWindow.height - 64));
      final BoxDecoration panelFace =
          tester.widget<DecoratedBox>(panel).decoration as BoxDecoration;
      expect(panelFace.color?.toARGB32(), colors.cardWarm.toARGB32());
      expect((panelFace.border! as Border).top.width, 2);
      expect(panelFace.borderRadius, BorderRadius.circular(18));
      _expectTile(tester, 48);
      _expectText(
        tester,
        'update available',
        family: TypographyTokens.accent,
        size: 16,
        color: colors.accentInk,
      );
      _expectText(
        tester,
        'Field Notes 2.4.0',
        family: TypographyTokens.serif,
        size: 26,
        weight: FontWeight.w500,
      );
      _expectText(
        tester,
        'Released October 9, 2026 · 38 MB download',
        family: TypographyTokens.sans,
        size: 12,
        color: colors.muted,
      );
      _expectText(
        tester,
        'Logs now open the way they were made.',
        family: TypographyTokens.serif,
        size: 16,
        weight: FontWeight.w400,
        height: 1.6,
      );
      _expectText(
        tester,
        'Fixed',
        family: TypographyTokens.accent,
        size: 19,
        weight: FontWeight.w600,
        color: colors.sage,
      );
      _expectText(
        tester,
        'Portrait videos are no longer cropped.',
        family: TypographyTokens.sans,
        size: 14,
        weight: FontWeight.w400,
        height: 1.55,
      );
      expect(
        find.descendant(of: panel, matching: find.byType(DashedDivider)),
        findsNWidgets(2),
      );
      final Finder close = find.byKey(updateNotesCloseKey);
      expect(tester.getSize(close), const Size(36, 36));
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Tooltip && widget.message == 'Close (Esc)',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(updateNotesNoteKey)).data,
        _routeNote(InstallRoute.restartInPlace, phone: false),
      );
      expect(
        find.descendant(
          of: find.byKey(updateNotesActionKey),
          matching: find.text('Update & restart'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(updateNotesLaterKey),
          matching: find.text('Later'),
        ),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(updates.installs, 1);
      expect(panel, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      await _open(tester, _openNew);
      await tester.tap(find.byKey(updateNotesLaterKey));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(updates.installs, 1);

      await _open(tester, _openNew);
      await tester.tap(find.byKey(updateNotesActionKey));
      await tester.pump();
      expect(updates.installs, 2);
      updates.emit(UpdateDownloading(_release, 0.45));
      await tester.pump();
      expect(panel, findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(updateNotesNoteKey)).data,
        'Downloading · 45% of 38 MB',
      );
      expect(find.byKey(updateNotesProgressKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(updateNotesProgressKey)).height,
        closeTo(10, _tolerance),
      );
      expect(
        tester
            .widget<StickerButton>(find.byKey(updateNotesActionKey))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<StickerButton>(find.byKey(updateNotesLaterKey)).onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(updates.installs, 2);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await tester.tap(find.byKey(updateNotesCloseKey));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      updates.emit(
        UpdateAvailable(
          _release,
          DateTime(2026, 10, 10),
          lastFailure: InstallFailure.verification,
        ),
      );
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(updateNotesNoteKey)).data,
        'The download didn’t pass its safety check, so nothing was installed.',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      for (final InstallRoute route in InstallRoute.values) {
        updates = _FixedUpdates(
          UpdateAvailable(_release, DateTime(2026, 10, 10)),
        );
        await _pumpHost(
          tester,
          platform: TargetPlatform.macOS,
          updates: updates,
          route: route,
        );
        await _open(tester, _openNew);
        expect(
          tester.widget<Text>(find.byKey(updateNotesNoteKey)).data,
          _routeNote(route, phone: false),
          reason: route.name,
        );
        expect(
          find.descendant(
            of: find.byKey(updateNotesActionKey),
            matching: find.text(_actions[route]!),
          ),
          findsOneWidget,
          reason: route.name,
        );
        expect(
          find.text(
            route == InstallRoute.googlePlay
                ? 'Released October 9, 2026'
                : 'Released October 9, 2026 · 38 MB download',
          ),
          findsOneWidget,
          reason: route.name,
        );
      }

      updates = _FixedUpdates(UpdateCurrent(DateTime(2026, 10, 10)));
      await _pumpHost(tester, platform: TargetPlatform.macOS, updates: updates);
      await _open(tester, _openInstalled);
      expect(panel, findsOneWidget);
      expect(find.text('release notes'), findsOneWidget);
      expect(find.text('Field Notes 1.4.2'), findsOneWidget);
      expect(find.text('Released October 1, 2026'), findsOneWidget);
      expect(
        find.text('Each settings section opens as its own page.'),
        findsOneWidget,
      );
      expect(find.byKey(updateNotesActionKey), findsNothing);
      expect(find.byKey(updateNotesLaterKey), findsNothing);
      expect(find.byKey(updateNotesCloseKey), findsOneWidget);
      await tester.tap(find.byKey(updateNotesCloseKey));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      await _pumpHost(
        tester,
        platform: TargetPlatform.macOS,
        updates: _FixedUpdates(UpdateCurrent(DateTime(2026, 10, 10))),
        installedNotes: ReleaseNotes.empty,
      );
      await _open(tester, _openInstalled);
      expect(find.text('No notes for version 1.4.2 yet.'), findsOneWidget);

      updates = _FixedUpdates(
        UpdateAvailable(_release, DateTime(2026, 10, 10)),
      );
      await _pumpHost(
        tester,
        platform: TargetPlatform.android,
        updates: updates,
        route: InstallRoute.systemInstaller,
      );
      await _open(tester, _openNew);
      final Finder sheet = find.byKey(updateNotesSheetKey);
      expect(sheet, findsOneWidget);
      expect(find.byKey(phoneSheetGrabberKey), findsOneWidget);
      _expectTile(tester, 44);
      _expectText(
        tester,
        'update available',
        family: TypographyTokens.accent,
        size: 15,
      );
      _expectText(
        tester,
        'Field Notes 2.4.0',
        family: TypographyTokens.serif,
        size: 22,
      );
      expect(
        find.text('Released October 9, 2026 · 41 MB download'),
        findsOneWidget,
      );
      _expectText(
        tester,
        'Logs now open the way they were made.',
        family: TypographyTokens.serif,
        size: 15,
        height: 1.55,
      );
      expect(
        tester.widget<Text>(find.byKey(updateNotesNoteKey)).data,
        _routeNote(InstallRoute.systemInstaller, phone: true),
      );
      expect(
        tester.getSize(find.byKey(updateNotesActionKey)).height,
        closeTo(52, _tolerance),
      );
      expect(
        tester.getSize(find.byKey(updateNotesLaterKey)).height,
        closeTo(48, _tolerance),
      );
      expect(
        find.descendant(
          of: find.byKey(updateNotesActionKey),
          matching: find.text('Download & install'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(updateNotesActionKey));
      await tester.pump();
      expect(updates.installs, 1);
      updates.emit(UpdateDownloading(_release, null));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(updateNotesNoteKey)).data,
        'Downloading…',
      );
      await tester.tap(find.byKey(updateNotesLaterKey));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      updates.emit(UpdateAvailable(_release, DateTime(2026, 10, 10)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(updateNotesLaterKey));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);

      await _open(tester, _openInstalled);
      expect(sheet, findsOneWidget);
      expect(find.text('release notes'), findsOneWidget);
      expect(find.byKey(updateNotesActionKey), findsNothing);
      expect(find.byKey(updateNotesLaterKey), findsNothing);
      expect(
        tester.getSize(find.byKey(updateNotesCloseKey)).height,
        closeTo(48, _tolerance),
      );
      expect(
        find.descendant(
          of: find.byKey(updateNotesCloseKey),
          matching: find.text('Close'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(updateNotesCloseKey));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    },
  );

  testWidgets('the restart splash names the new version', (
    WidgetTester tester,
  ) async {
    Future<void> pumpSplash(UpdateStatus status) async {
      tester.view.physicalSize = _desktopWindow;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: _overrides(updates: _FixedUpdates(status)),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: fieldNotesTheme(platform: TargetPlatform.macOS),
            home: const Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(child: Text('journal underneath')),
                UpdateRestartSplash(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpSplash(UpdateRestarting(_release));
    final Finder splash = find.byKey(updateRestartSplashKey);
    expect(splash, findsOneWidget);
    expect(tester.getRect(splash), Offset.zero & _desktopWindow);
    expect(find.text('Restarting Field Notes'), findsOneWidget);
    expect(find.text('opening version 2.4.0…'), findsOneWidget);
    final TextStyle? title = _style(tester, 'Restarting Field Notes');
    expect(title?.fontFamily, TypographyTokens.serif);
    expect(title?.fontSize, 24);
    expect(title?.fontWeight, FontWeight.w500);
    final TextStyle? line = _style(tester, 'opening version 2.4.0…');
    expect(line?.fontFamily, TypographyTokens.accent);
    expect(line?.fontSize, 17);
    expect(line?.fontWeight, FontWeight.w600);
    expect(
      line?.color?.toARGB32(),
      FieldNotesColors.light.accentInk.toARGB32(),
    );
    final Finder logo = find.descendant(
      of: splash,
      matching: find.byType(FlowerBloom),
    );
    expect(tester.widget<FlowerBloom>(logo).size, 84);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Restarting Field Notes'), findsOneWidget);
    await tester.tap(find.text('journal underneath'), warnIfMissed: false);

    for (final UpdateStatus status in <UpdateStatus>[
      const UpdateIdle(null),
      UpdateCurrent(DateTime(2026, 10, 10)),
      UpdateAvailable(_release, DateTime(2026, 10, 10)),
      UpdateDownloading(_release, 0.5),
    ]) {
      await pumpSplash(status);
      expect(splash, findsNothing, reason: '$status');
      expect(
        find.text('Restarting Field Notes'),
        findsNothing,
        reason: '$status',
      );
      expect(
        find.text('journal underneath'),
        findsOneWidget,
        reason: '$status',
      );
    }
  });
}
