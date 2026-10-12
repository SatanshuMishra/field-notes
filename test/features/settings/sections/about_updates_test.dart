import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/updates/bundled_changelog.dart';
import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/settings/sections/about_section.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../../support/update_overrides.dart';
import '../support/fake_settings_repository.dart';
import '../support/settings_harness.dart';

const Size _desktopWindow = Size(1140, 726);
const Size _phoneView = Size(384, 832);
const Size _noteView = Size(412, 869);
const double _phoneSide = 14;
const double _tolerance = 0.01;

final DateTime _now = updateQuietNow;

final ReleaseInfo _release = ReleaseInfo(
  version: AppVersion.tryParse('2.4.0')!,
  tag: 'v2.4.0',
  publishedAt: DateTime(2026, 7, 18, 12),
  notes: ReleaseNotes(
    intro: 'Settings are easier to find.',
    groups: <ReleaseNoteGroup>[
      ReleaseNoteGroup(title: 'New', items: <String>['An About page.']),
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
  int checks = 0;
  int installs = 0;

  @override
  UpdateStatus build() => _initial;

  @override
  Future<void> check() async {
    checks++;
  }

  @override
  Future<void> install() async {
    installs++;
  }
}

List<Override> _updateOverrides(_FixedUpdates updates, InstallRoute route) =>
    <Override>[
      installedAppProvider.overrideWith(
        (Ref ref) async => const InstalledApp(version: '1.4.2'),
      ),
      updateControllerProvider.overrideWith(() => updates),
      updateRouteProvider.overrideWith((Ref ref) async => route),
      installedReleaseNotesProvider.overrideWith(
        (Ref ref) async => ChangelogSection(
          notes: ReleaseNotes(
            intro: 'The first release.',
            groups: const <ReleaseNoteGroup>[],
          ),
          date: DateTime(2026, 7, 1, 12),
        ),
      ),
    ];

Future<void> _pumpAbout(
  WidgetTester tester, {
  required TargetPlatform platform,
  required _FixedUpdates updates,
  InstallRoute route = InstallRoute.restartInPlace,
  FakeSettingsRepository? repository,
  List<String>? notices,
  bool settle = true,
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
  final Widget about = AboutSection(
    onFeedback: (String message) => notices?.add(message),
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(
          repository ?? FakeSettingsRepository(),
        ),
        ...updateQuietOverrides(),
        ..._updateOverrides(updates, route),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Builder(
          builder: (BuildContext context) => ColoredBox(
            color: context.colors.page,
            child: SingleChildScrollView(
              padding: phone
                  ? const EdgeInsets.fromLTRB(_phoneSide, 60, _phoneSide, 60)
                  : const EdgeInsets.fromLTRB(28, 26, 34, 34),
              child: phone
                  ? about
                  : Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(width: 680, child: about),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpNotePage(WidgetTester tester, _FixedUpdates updates) async {
  tester.view.physicalSize = _noteView;
  tester.view.devicePixelRatio = 1;
  const FakeViewPadding padding = FakeViewPadding(top: 34, bottom: 24);
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ...shellOverrides(),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        settingsDataControllerProvider.overrideWith(
          (Ref ref) async => FakeSettingsDataController(),
        ),
        ..._updateOverrides(updates, InstallRoute.systemInstaller),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(settingsTabKey(SettingsTab.about)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _statusRow() => find.byKey(aboutStatusRowKey);

List<String> _statusPills(WidgetTester tester) => <String>[
  for (final SettingsActionButton button
      in tester.widgetList<SettingsActionButton>(
        find.descendant(
          of: _statusRow(),
          matching: find.byType(SettingsActionButton),
        ),
      ))
    button.label,
];

BoxDecoration _dot(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byKey(aboutStatusDotKey),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

void _expectDot(WidgetTester tester, Color colour, {required bool ring}) {
  final BoxDecoration dot = _dot(tester);
  expect(tester.getSize(find.byKey(aboutStatusDotKey)), const Size(8, 8));
  expect(dot.color?.toARGB32(), colour.toARGB32());
  if (ring) {
    expect(dot.boxShadow, hasLength(1));
    expect(dot.boxShadow!.single.spreadRadius, 3);
    expect(dot.boxShadow!.single.blurRadius, 0);
    expect(
      dot.boxShadow!.single.color.toARGB32(),
      Palette.coral.withValues(alpha: 0.18).toARGB32(),
    );
  } else {
    expect(dot.boxShadow, anyOf(isNull, isEmpty));
  }
}

final class _DesktopCase {
  const _DesktopCase({
    required this.name,
    required this.status,
    required this.title,
    required this.description,
    required this.tone,
    required this.pills,
    this.route = InstallRoute.restartInPlace,
    this.checking = false,
    this.progress,
  });

  final String name;
  final UpdateStatus status;
  final InstallRoute route;
  final String title;
  final String description;
  final AboutDotTone tone;
  final List<String> pills;
  final bool checking;
  final double? progress;
}

final List<_DesktopCase> _desktopCases = <_DesktopCase>[
  const _DesktopCase(
    name: 'idle, never checked',
    status: UpdateIdle(null),
    title: 'Updates',
    description: 'Not checked yet',
    tone: AboutDotTone.quiet,
    pills: <String>['Check for updates'],
  ),
  _DesktopCase(
    name: 'idle, checked before',
    status: UpdateIdle(_now.subtract(const Duration(minutes: 5))),
    title: 'Updates',
    description: 'Last checked 5 minutes ago',
    tone: AboutDotTone.quiet,
    pills: <String>['Check for updates'],
  ),
  _DesktopCase(
    name: 'checking',
    status: UpdateChecking(_now.subtract(const Duration(minutes: 5))),
    title: 'Checking for updates…',
    description: 'This takes a moment.',
    tone: AboutDotTone.quiet,
    pills: const <String>[],
    checking: true,
  ),
  _DesktopCase(
    name: 'up to date',
    status: UpdateCurrent(_now),
    title: 'Field Notes is up to date',
    description: 'Last checked just now',
    tone: AboutDotTone.current,
    pills: <String>['Check for updates'],
  ),
  _DesktopCase(
    name: 'available, restart in place',
    status: UpdateAvailable(_release, _now),
    title: 'Version 2.4.0 is available',
    description:
        'Read the changelog, then restart to update. Your journal is saved '
        'first.',
    tone: AboutDotTone.attention,
    pills: <String>['Read changelog', 'Update now…'],
  ),
  _DesktopCase(
    name: 'available, system installer',
    status: UpdateAvailable(_release, _now),
    route: InstallRoute.systemInstaller,
    title: 'Version 2.4.0 is available',
    description: 'Read the changelog, then install it.',
    tone: AboutDotTone.attention,
    pills: <String>['Read changelog', 'Update now…'],
  ),
  _DesktopCase(
    name: 'available, Google Play',
    status: UpdateAvailable(_release, _now),
    route: InstallRoute.googlePlay,
    title: 'Version 2.4.0 is available',
    description:
        'Read the changelog, then update from Google Play when it’s offered '
        'there.',
    tone: AboutDotTone.attention,
    pills: <String>['Read changelog', 'Update now…'],
  ),
  _DesktopCase(
    name: 'available, download page',
    status: UpdateAvailable(_release, _now),
    route: InstallRoute.downloadPage,
    title: 'Version 2.4.0 is available',
    description: 'Read the changelog, then download it.',
    tone: AboutDotTone.attention,
    pills: <String>['Read changelog', 'Update now…'],
  ),
  _DesktopCase(
    name: 'available after a failed install',
    status: UpdateAvailable(
      _release,
      _now,
      lastFailure: InstallFailure.network,
    ),
    title: 'Version 2.4.0 is available',
    description: 'The download stopped. Nothing was installed.',
    tone: AboutDotTone.attention,
    pills: <String>['Read changelog', 'Update now…'],
  ),
  _DesktopCase(
    name: 'downloading',
    status: UpdateDownloading(_release, 0.45),
    title: 'Downloading version 2.4.0…',
    description: '45% of 38 MB',
    tone: AboutDotTone.attention,
    pills: const <String>[],
    progress: 0.45,
  ),
  _DesktopCase(
    name: 'downloading, size unknown',
    status: UpdateDownloading(_release, null),
    title: 'Downloading version 2.4.0…',
    description: 'Downloading…',
    tone: AboutDotTone.attention,
    pills: const <String>[],
    progress: 0,
  ),
  _DesktopCase(
    name: 'check failed offline',
    status: UpdateCheckFailed(
      _now.subtract(const Duration(hours: 2)),
      LookupFailure.offline,
      null,
    ),
    title: 'Couldn’t check for updates',
    description:
        'Couldn’t check for updates. Check your connection and try again.',
    tone: AboutDotTone.quiet,
    pills: <String>['Check for updates'],
  ),
  _DesktopCase(
    name: 'rate limited',
    status: UpdateCheckFailed(null, null, DateTime(2026, 7, 20, 9, 45)),
    title: 'Couldn’t check for updates',
    description: 'GitHub is busy. Try again after 9:45 am.',
    tone: AboutDotTone.quiet,
    pills: <String>['Check for updates'],
  ),
];

final class _PhoneCase {
  const _PhoneCase({
    required this.name,
    required this.status,
    required this.line,
    this.button,
    this.buttonHeight,
  });

  final String name;
  final UpdateStatus status;
  final String line;
  final String? button;
  final double? buttonHeight;
}

final List<_PhoneCase> _phoneCases = <_PhoneCase>[
  const _PhoneCase(
    name: 'idle, never checked',
    status: UpdateIdle(null),
    line: 'Not checked yet',
    button: 'Check for updates',
    buttonHeight: 48,
  ),
  _PhoneCase(
    name: 'idle, checked before',
    status: UpdateIdle(_now.subtract(const Duration(minutes: 5))),
    line: 'Last checked 5 minutes ago',
    button: 'Check for updates',
    buttonHeight: 48,
  ),
  _PhoneCase(
    name: 'checking',
    status: UpdateChecking(_now),
    line: 'Looking for a new version…',
    button: 'Checking…',
    buttonHeight: 48,
  ),
  _PhoneCase(
    name: 'up to date',
    status: UpdateCurrent(_now),
    line: 'Up to date · checked just now',
    button: 'Check for updates',
    buttonHeight: 48,
  ),
  _PhoneCase(
    name: 'available',
    status: UpdateAvailable(_release, _now),
    line: 'Version 2.4.0 is ready to install',
    button: 'Update to 2.4.0…',
    buttonHeight: 52,
  ),
  _PhoneCase(
    name: 'downloading',
    status: UpdateDownloading(_release, 0.45),
    line: 'Downloading version 2.4.0…',
  ),
  _PhoneCase(
    name: 'check failed',
    status: UpdateCheckFailed(_now, LookupFailure.badResponse, null),
    line: 'Couldn’t read the update information. Try again later.',
    button: 'Check for updates',
    buttonHeight: 48,
  ),
];

void main() {
  testWidgets('the desktop About page shows each update state', (
    WidgetTester tester,
  ) async {
    final FieldNotesColors colors = FieldNotesColors.light;
    for (final _DesktopCase item in _desktopCases) {
      final _FixedUpdates updates = _FixedUpdates(item.status);
      await _pumpAbout(
        tester,
        platform: TargetPlatform.macOS,
        updates: updates,
        route: item.route,
        settle: !item.checking,
      );
      final String name = item.name;
      expect(tester.takeException(), isNull, reason: name);
      expect(find.text('updates'), findsOneWidget, reason: name);
      final Finder row = find.descendant(
        of: _statusRow(),
        matching: find.byType(SettingsFieldRow),
      );
      expect(row, findsOneWidget, reason: name);
      final SettingsFieldRow field = tester.widget<SettingsFieldRow>(row);
      expect(field.label, item.title, reason: name);
      expect(field.description, item.description, reason: name);
      expect(find.text(item.title), findsOneWidget, reason: name);
      expect(find.text(item.description), findsOneWidget, reason: name);
      switch (item.tone) {
        case AboutDotTone.attention:
          _expectDot(tester, Palette.coral, ring: true);
        case AboutDotTone.current:
          _expectDot(tester, colors.sage, ring: false);
        case AboutDotTone.quiet:
          _expectDot(tester, colors.muted, ring: false);
      }
      expect(_statusPills(tester), item.pills, reason: name);
      if (item.pills.contains('Update now…')) {
        expect(
          tester
              .widget<SettingsActionButton>(
                find.widgetWithText(SettingsActionButton, 'Update now…'),
              )
              .tone,
          SettingsActionTone.primary,
          reason: name,
        );
      }
      expect(
        find.byKey(aboutCheckingPillKey),
        item.checking ? findsOneWidget : findsNothing,
        reason: name,
      );
      final double? progress = item.progress;
      if (progress == null) {
        expect(find.byKey(aboutProgressKey), findsNothing, reason: name);
      } else {
        final Rect bar = tester.getRect(find.byKey(aboutProgressKey));
        expect(bar.width, closeTo(300, _tolerance), reason: name);
        expect(bar.height, closeTo(8, _tolerance), reason: name);
        final BoxDecoration frame =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byKey(aboutProgressKey),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(frame.color?.toARGB32(), colors.cardBright.toARGB32());
        expect((frame.border! as Border).top.width, 1.5);
        expect(frame.borderRadius, BorderRadius.circular(4));
        final Rect fill = tester.getRect(
          find.descendant(
            of: find.byKey(aboutProgressKey),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(fill.width, closeTo(300 * progress, 0.5), reason: name);
      }
      expect(
        tester.getSemantics(_statusRow()),
        isSemantics(isLiveRegion: true),
        reason: name,
      );
      if (item.pills.contains('Check for updates')) {
        await tester.tapAt(
          tester.getCenter(
            find.widgetWithText(SettingsActionButton, 'Check for updates'),
          ),
        );
        await tester.pump();
        expect(updates.checks, 1, reason: name);
      }
      if (item.checking) {
        expect(find.text('Checking…'), findsOneWidget);
        await tester.tap(find.byKey(aboutCheckingPillKey));
        await tester.pump();
        expect(updates.checks, 0, reason: name);
      }
    }

    final _FixedUpdates available = _FixedUpdates(
      UpdateAvailable(_release, _now),
    );
    await _pumpAbout(
      tester,
      platform: TargetPlatform.macOS,
      updates: available,
    );
    for (final String pill in <String>['Read changelog', 'Update now…']) {
      await tester.tapAt(
        tester.getCenter(find.widgetWithText(SettingsActionButton, pill)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(updateNotesPanelKey), findsOneWidget, reason: pill);
      expect(find.text('update available'), findsOneWidget, reason: pill);
      expect(find.text('Field Notes 2.4.0'), findsOneWidget, reason: pill);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(updateNotesPanelKey), findsNothing, reason: pill);
    }

    expect(find.text('Check automatically'), findsOneWidget);
    expect(
      find.text('Once a day. Nothing installs until you choose.'),
      findsOneWidget,
    );
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text('What changed in version 1.4.2'), findsOneWidget);
    await tester.tap(find.widgetWithText(SettingsActionButton, 'Read notes'));
    await tester.pumpAndSettle();
    expect(find.byKey(updateNotesPanelKey), findsOneWidget);
    expect(find.text('release notes'), findsOneWidget);
    expect(find.text('Field Notes 1.4.2'), findsOneWidget);
    expect(find.text('The first release.'), findsOneWidget);
    expect(find.byKey(updateNotesActionKey), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpAbout(
      tester,
      platform: TargetPlatform.macOS,
      updates: _FixedUpdates(UpdateCurrent(_now)),
      repository: repository,
    );
    final Finder toggle = find.byKey(aboutAutomaticToggleKey);
    expect(tester.widget<SettingsToggle>(toggle).value, isTrue);
    expect(
      tester.widget<SettingsToggle>(toggle).semanticLabel,
      'Check automatically',
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(repository.checkForUpdatesAutomaticallyWrites, <bool>[false]);

    final List<String> notices = <String>[];
    await _pumpAbout(
      tester,
      platform: TargetPlatform.macOS,
      updates: _FixedUpdates(UpdateCurrent(_now)),
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
      notices: notices,
    );
    await tester.tap(find.byKey(aboutAutomaticToggleKey));
    await tester.pumpAndSettle();
    expect(notices, <String>['Could not save your update check setting.']);
  });

  testWidgets('the phone About page shows each update state', (
    WidgetTester tester,
  ) async {
    final FieldNotesColors colors = FieldNotesColors.light;
    for (final _PhoneCase item in _phoneCases) {
      final _FixedUpdates updates = _FixedUpdates(item.status);
      final bool checking = item.status is UpdateChecking;
      await _pumpAbout(
        tester,
        platform: TargetPlatform.android,
        updates: updates,
        route: InstallRoute.systemInstaller,
        settle: !checking,
      );
      final String name = item.name;
      expect(tester.takeException(), isNull, reason: name);
      final Rect card = tester.getRect(find.byKey(aboutIdentityCardKey));
      final Finder line = find.text(item.line);
      expect(line, findsOneWidget, reason: name);
      final TextStyle? style = tester.widget<Text>(line).style;
      expect(style?.fontFamily, TypographyTokens.sans, reason: name);
      expect(style?.fontSize, 13, reason: name);
      expect(style?.fontWeight, FontWeight.w400, reason: name);
      expect(
        style?.color?.toARGB32(),
        colors.mutedDeep.toARGB32(),
        reason: name,
      );
      final Rect lineRect = tester.getRect(line);
      expect(lineRect.top, greaterThan(card.top), reason: name);
      expect(lineRect.bottom, lessThan(card.bottom), reason: name);
      expect(
        find.descendant(
          of: find.byKey(aboutStatusLineKey),
          matching: find.byKey(aboutStatusDotKey),
        ),
        findsOneWidget,
        reason: name,
      );
      expect(
        tester.getSemantics(find.byKey(aboutStatusLineKey)),
        isSemantics(isLiveRegion: true, label: item.line),
        reason: name,
      );
      final String? button = item.button;
      if (button == null) {
        expect(find.byKey(aboutUpdateButtonKey), findsNothing, reason: name);
        final Rect bar = tester.getRect(find.byKey(aboutProgressKey));
        expect(bar.height, closeTo(10, _tolerance), reason: name);
        expect(bar.width, closeTo(card.width - 32, _tolerance), reason: name);
      } else {
        final Finder control = find.byKey(aboutUpdateButtonKey);
        final Rect rect = tester.getRect(control);
        expect(
          rect.height,
          closeTo(item.buttonHeight!, _tolerance),
          reason: name,
        );
        expect(rect.width, closeTo(card.width - 32, _tolerance), reason: name);
        expect(
          rect.top - lineRect.bottom,
          closeTo(16, _tolerance),
          reason: name,
        );
        expect(
          find.descendant(of: control, matching: find.text(button)),
          findsOneWidget,
          reason: name,
        );
        expect(find.byKey(aboutProgressKey), findsNothing, reason: name);
      }
      expect(find.text('Check automatically'), findsOneWidget, reason: name);
      expect(find.text('Release notes'), findsOneWidget, reason: name);

      switch (item.status) {
        case UpdateIdle() || UpdateCurrent() || UpdateCheckFailed():
          await tester.tap(find.byKey(aboutUpdateButtonKey));
          await tester.pump();
          expect(updates.checks, 1, reason: name);
        case UpdateChecking():
          expect(
            tester
                .widget<Opacity>(
                  find
                      .ancestor(
                        of: find.byKey(aboutUpdateButtonKey),
                        matching: find.byType(Opacity),
                      )
                      .first,
                )
                .opacity,
            0.7,
          );
          expect(
            tester.getSemantics(find.byKey(aboutUpdateButtonKey)),
            isSemantics(isButton: true, isEnabled: false),
          );
          await tester.tap(find.byKey(aboutUpdateButtonKey));
          await tester.pump();
          expect(updates.checks, 0, reason: name);
        case UpdateAvailable():
          final BoxDecoration face =
              tester
                      .widget<Container>(
                        find.descendant(
                          of: find.byKey(aboutUpdateButtonKey),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration!
                  as BoxDecoration;
          expect(face.color?.toARGB32(), Palette.coral.toARGB32());
          expect(face.boxShadow!.single.offset, const Offset(2, 2));
          expect(
            tester
                .widget<Text>(find.text('Update to 2.4.0…'))
                .style
                ?.color
                ?.toARGB32(),
            Palette.onAccent.toARGB32(),
          );
          await tester.tap(find.byKey(aboutUpdateButtonKey));
          await tester.pumpAndSettle();
          expect(find.byKey(updateNotesSheetKey), findsOneWidget);
          expect(find.text('update available'), findsOneWidget);
          await tester.tap(find.byKey(updateNotesLaterKey));
          await tester.pumpAndSettle();
          expect(find.byKey(updateNotesSheetKey), findsNothing);
        case UpdateDownloading() || UpdateRestarting():
          break;
      }
    }

    await _pumpAbout(
      tester,
      platform: TargetPlatform.android,
      updates: _FixedUpdates(UpdateCurrent(_now)),
    );
    final Finder updatesCard = find.byKey(aboutUpdatesCardKey);
    expect(
      find.descendant(
        of: updatesCard,
        matching: find.text('Check automatically'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: updatesCard, matching: find.byType(SettingsToggle)),
      findsOneWidget,
    );
    final Finder notesRow = find.byKey(aboutReleaseNotesRowKey);
    expect(
      tester.getSize(notesRow).height,
      greaterThanOrEqualTo(68 - _tolerance),
    );
    expect(
      find.descendant(
        of: notesRow,
        matching: find.text('What changed in version 1.4.2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: notesRow, matching: find.byType(ChevronGlyph)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: updatesCard, matching: find.byType(DashedDivider)),
      findsOneWidget,
    );
    await tester.tap(notesRow);
    await tester.pumpAndSettle();
    expect(find.byKey(updateNotesSheetKey), findsOneWidget);
    expect(find.text('release notes'), findsOneWidget);
    expect(find.text('Field Notes 1.4.2'), findsOneWidget);
    expect(find.byKey(updateNotesActionKey), findsNothing);
    await tester.tap(find.byKey(updateNotesCloseKey));
    await tester.pumpAndSettle();
    expect(find.byKey(updateNotesSheetKey), findsNothing);
  });

  testWidgets('the phone About page fits the Note 10+ in every update state', (
    WidgetTester tester,
  ) async {
    final List<UpdateStatus> statuses = <UpdateStatus>[
      const UpdateIdle(null),
      UpdateIdle(_now.subtract(const Duration(days: 3))),
      UpdateChecking(_now),
      UpdateCurrent(_now),
      UpdateAvailable(_release, _now),
      UpdateAvailable(_release, _now, lastFailure: InstallFailure.permission),
      UpdateDownloading(_release, 0.45),
      UpdateDownloading(_release, null),
      UpdateCheckFailed(_now, LookupFailure.offline, null),
      UpdateCheckFailed(null, null, DateTime(2026, 7, 20, 9, 45)),
    ];
    for (final UpdateStatus status in statuses) {
      await _pumpNotePage(tester, _FixedUpdates(status));
      expect(tester.takeException(), isNull, reason: '$status');
      expect(find.byType(AboutSection), findsOneWidget, reason: '$status');
      expect(find.byType(SettingsBackPill), findsOneWidget, reason: '$status');
      final ScrollableState scroll = tester.state<ScrollableState>(
        find
            .ancestor(
              of: find.byType(AboutSection),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$status');
      final Rect identity = tester.getRect(find.byKey(aboutIdentityCardKey));
      expect(identity.left, greaterThanOrEqualTo(0), reason: '$status');
      expect(
        identity.right,
        lessThanOrEqualTo(_noteView.width),
        reason: '$status',
      );
      expect(
        tester.getRect(find.byKey(aboutLicenceKey)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(SettingsBackPill)).top),
        reason: '$status',
      );
    }
  });

  testWidgets(
    'the desktop About status row exposes its visible actions as buttons',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final _FixedUpdates current = _FixedUpdates(UpdateCurrent(_now));
      await _pumpAbout(
        tester,
        platform: TargetPlatform.macOS,
        updates: current,
      );
      final SemanticsNode row = tester.getSemantics(_statusRow());
      expect(row, isSemantics(isLiveRegion: true));
      expect(row.getSemanticsData().flagsCollection.isButton, isFalse);
      expect(find.text('Field Notes is up to date'), findsOneWidget);
      final Finder check = find.bySemanticsLabel('Check for updates');
      expect(check, findsOneWidget);
      final SemanticsNode checkNode = tester.getSemantics(check);
      expect(
        checkNode,
        isSemantics(
          label: 'Check for updates',
          isButton: true,
          hasTapAction: true,
        ),
      );
      checkNode.owner!.performAction(checkNode.id, SemanticsAction.tap);
      await tester.pump();
      expect(current.checks, 1);

      final _FixedUpdates available = _FixedUpdates(
        UpdateAvailable(_release, _now),
      );
      await _pumpAbout(
        tester,
        platform: TargetPlatform.macOS,
        updates: available,
      );
      expect(
        tester
            .getSemantics(_statusRow())
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isFalse,
      );
      for (final String action in <String>['Read changelog', 'Update now…']) {
        final Finder button = find.bySemanticsLabel(action);
        expect(button, findsOneWidget, reason: action);
        expect(
          tester.getSemantics(button),
          isSemantics(label: action, isButton: true, hasTapAction: true),
          reason: action,
        );
      }
      handle.dispose();
    },
  );
}
