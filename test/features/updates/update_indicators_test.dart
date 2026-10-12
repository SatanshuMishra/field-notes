import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/updates/bundled_changelog.dart';
import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/ui/update_rail_chip.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../settings/support/settings_harness.dart';

const Size _desktopWindow = Size(1440, 900);
const Size _phoneView = Size(384, 832);
const double _tolerance = 0.01;

const Key _settingsButton = ValueKey<String>('settings-button');
const Key _gearButton = ValueKey<String>('gear-button');

final DateTime _checkedAt = DateTime(2026, 7, 20, 9);

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

  @override
  UpdateStatus build() => _initial;

  @override
  Future<void> check() async {}

  @override
  Future<void> install() async {}
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required TargetPlatform platform,
  required UpdateStatus status,
  required InstallRoute route,
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
      overrides: <Override>[
        ...shellOverrides(),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        settingsDataControllerProvider.overrideWith(
          (Ref ref) async => FakeSettingsDataController(),
        ),
        installedAppProvider.overrideWith(
          (Ref ref) async => const InstalledApp(version: '1.4.2'),
        ),
        updateControllerProvider.overrideWith(() => _FixedUpdates(status)),
        updateRouteProvider.overrideWith((Ref ref) async => route),
        installedReleaseNotesProvider.overrideWith(
          (Ref ref) async => const ChangelogSection(notes: ReleaseNotes.empty),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester, {required bool phone}) async {
  await tester.tap(find.byKey(phone ? _gearButton : _settingsButton));
  await tester.pumpAndSettle();
}

BoxDecoration _decoration(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;

void _expectRingedDot(WidgetTester tester, Finder dot, {required double size}) {
  expect(dot, findsOneWidget);
  expect(tester.getSize(dot), Size(size, size));
  final BoxDecoration face = _decoration(tester, dot);
  expect(face.color?.toARGB32(), Palette.coral.toARGB32());
  expect(face.shape, BoxShape.circle);
  expect(face.boxShadow, hasLength(1));
  expect(face.boxShadow!.single.spreadRadius, 3);
  expect(
    face.boxShadow!.single.color.toARGB32(),
    Palette.coral.withValues(alpha: 0.18).toARGB32(),
  );
}

void _expectGearBadge(WidgetTester tester, Rect anchor) {
  final Finder badge = find.byKey(settingsBadgeKey);
  expect(badge, findsOneWidget);
  final Rect rect = tester.getRect(badge);
  expect(rect.size, const Size(10, 10));
  expect(rect.top, closeTo(anchor.top - 4, _tolerance));
  expect(rect.right, closeTo(anchor.right + 4, _tolerance));
  final BoxDecoration face = _decoration(tester, badge);
  expect(face.color?.toARGB32(), Palette.coral.toARGB32());
  final Border border = face.border! as Border;
  expect(border.top.width, 2);
  expect(border.top.color.toARGB32(), FieldNotesColors.light.page.toARGB32());
}

void main() {
  testWidgets(
    'an available update shows on the rail, the gear and the settings list',
    (WidgetTester tester) async {
      final FieldNotesColors colors = FieldNotesColors.light;
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpShell(
        tester,
        platform: TargetPlatform.macOS,
        status: UpdateAvailable(_release, _checkedAt),
        route: InstallRoute.restartInPlace,
      );

      final Finder chip = find.byType(UpdateRailChip);
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: find.byType(SidebarShell), matching: chip),
        findsOneWidget,
      );
      final Finder title = find.descendant(
        of: chip,
        matching: find.text('Update available'),
      );
      final Finder version = find.descendant(
        of: chip,
        matching: find.text('Version 2.4.0'),
      );
      expect(title, findsOneWidget);
      expect(version, findsOneWidget);
      final TextStyle? titleStyle = tester.widget<Text>(title).style;
      expect(titleStyle?.fontFamily, TypographyTokens.sans);
      expect(titleStyle?.fontSize, 12.5);
      expect(titleStyle?.fontWeight, FontWeight.w600);
      expect(titleStyle?.color?.toARGB32(), colors.accentInk.toARGB32());
      final TextStyle? versionStyle = tester.widget<Text>(version).style;
      expect(versionStyle?.fontSize, 10.5);
      expect(versionStyle?.fontWeight, FontWeight.w400);
      expect(versionStyle?.color?.toARGB32(), colors.muted.toARGB32());
      final SettingsIcon icon = tester.widget<SettingsIcon>(
        find.descendant(of: chip, matching: find.byType(SettingsIcon)),
      );
      expect(icon.glyph, SettingsGlyph.download);
      expect(icon.size, 16);
      expect(icon.color.toARGB32(), colors.accentInk.toARGB32());
      final Finder face = find.byKey(updateRailChipKey);
      final BoxDecoration fill =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: face,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(
        fill.color?.toARGB32(),
        Palette.coral.withValues(alpha: 0.07).toARGB32(),
      );
      expect(fill.borderRadius, BorderRadius.circular(12));
      final Rect streak = tester.getRect(
        find.descendant(
          of: find.byType(SidebarShell),
          matching: find.byType(StreakPill),
        ),
      );
      expect(streak.top - tester.getRect(chip).bottom, closeTo(8, _tolerance));
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Tooltip &&
              widget.message ==
                  'Field Notes 2.4.0 is available. Read the changelog and '
                      'update.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(face),
        isSemantics(
          label: 'Update available, version 2.4.0',
          isButton: true,
          hasTapAction: true,
        ),
      );

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(face));
      await tester.pump();
      final BoxDecoration hovered =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: face,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(
        hovered.color?.toARGB32(),
        Palette.coral.withValues(alpha: 0.16).toARGB32(),
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();

      _expectGearBadge(tester, tester.getRect(find.byKey(_settingsButton)));
      expect(
        find.bySemanticsLabel('Settings, update available'),
        findsOneWidget,
      );

      await tester.tap(face);
      await tester.pumpAndSettle();
      expect(find.byKey(updateNotesPanelKey), findsOneWidget);
      expect(find.text('Field Notes 2.4.0'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(updateNotesPanelKey), findsNothing);

      await tester.tap(find.byKey(sidebarToggleKey));
      await tester.pumpAndSettle();
      expect(chip, findsOneWidget);
      expect(find.text('Update available'), findsNothing);
      expect(find.text('Version 2.4.0'), findsNothing);
      expect(tester.getSize(face), const Size(40, 40));
      expect(
        tester.getCenter(face).dx,
        closeTo(tester.getCenter(find.byKey(sidebarRailKey)).dx, 0.5),
      );
      expect(
        find.descendant(of: chip, matching: find.byType(SettingsIcon)),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Tooltip &&
              widget.message ==
                  'Field Notes 2.4.0 is available. Read the changelog and '
                      'update.',
        ),
        findsOneWidget,
      );
      _expectGearBadge(tester, tester.getRect(find.byKey(_settingsButton)));
      await tester.tap(find.byKey(sidebarToggleKey));
      await tester.pumpAndSettle();

      await _openSettings(tester, phone: false);
      _expectRingedDot(
        tester,
        find.byKey(settingsTabMarkKey(SettingsTab.about)),
        size: 8,
      );
      final Rect aboutFace = tester.getRect(
        find.byKey(settingsTabFaceKey(SettingsTab.about)),
      );
      final Rect mark = tester.getRect(
        find.byKey(settingsTabMarkKey(SettingsTab.about)),
      );
      expect(mark.right, lessThanOrEqualTo(aboutFace.right));
      expect(
        mark.left,
        greaterThan(
          tester
              .getRect(
                find.descendant(
                  of: find.byKey(settingsTabKey(SettingsTab.about)),
                  matching: find.text('About'),
                ),
              )
              .left,
        ),
      );
      for (final SettingsTab tab in SettingsTab.values) {
        if (tab != SettingsTab.about) {
          expect(find.byKey(settingsTabMarkKey(tab)), findsNothing);
        }
      }
      semantics.dispose();

      await _pumpShell(
        tester,
        platform: TargetPlatform.macOS,
        status: UpdateCurrent(_checkedAt),
        route: InstallRoute.restartInPlace,
      );
      expect(find.byType(UpdateRailChip), findsNothing);
      expect(find.text('Update available'), findsNothing);
      expect(find.byKey(settingsBadgeKey), findsNothing);
      await _openSettings(tester, phone: false);
      expect(find.byKey(settingsTabMarkKey(SettingsTab.about)), findsNothing);
    },
  );

  testWidgets('an available update shows on the phone gear and settings list', (
    WidgetTester tester,
  ) async {
    final FieldNotesColors colors = FieldNotesColors.light;
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpShell(
      tester,
      platform: TargetPlatform.android,
      status: UpdateAvailable(_release, _checkedAt),
      route: InstallRoute.systemInstaller,
    );
    _expectGearBadge(
      tester,
      tester.getRect(
        find.descendant(
          of: find.byKey(_gearButton),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Settings, update available'), findsOneWidget);

    await _openSettings(tester, phone: true);
    final Finder banner = find.byKey(settingsUpdateBannerKey);
    expect(banner, findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.text('Update available: 2.4.0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: banner,
        matching: find.text('Read the changelog, then update'),
      ),
      findsOneWidget,
    );
    final TextStyle? bannerTitle = tester
        .widget<Text>(find.text('Update available: 2.4.0'))
        .style;
    expect(bannerTitle?.fontFamily, TypographyTokens.sans);
    expect(bannerTitle?.fontSize, 14);
    expect(bannerTitle?.fontWeight, FontWeight.w600);
    final TextStyle? bannerLine = tester
        .widget<Text>(find.text('Read the changelog, then update'))
        .style;
    expect(bannerLine?.fontSize, 12);
    expect(bannerLine?.fontWeight, FontWeight.w400);
    expect(bannerLine?.color?.toARGB32(), colors.muted.toARGB32());
    final Rect bannerRect = tester.getRect(banner);
    expect(bannerRect.height, greaterThanOrEqualTo(68 - _tolerance));
    final BoxDecoration bannerFace = _decoration(tester, banner);
    expect(bannerFace.color?.toARGB32(), colors.cardBright.toARGB32());
    expect((bannerFace.border! as Border).top.width, 1.5);
    expect(bannerFace.borderRadius, BorderRadius.circular(16));
    expect(bannerFace.boxShadow!.single.offset, const Offset(3, 3));
    expect(
      bannerFace.boxShadow!.single.color.toARGB32(),
      Palette.coral.withValues(alpha: 0.35).toARGB32(),
    );
    final Finder tile = find.byKey(settingsUpdateBannerTileKey);
    expect(tester.getSize(tile), const Size(40, 40));
    final BoxDecoration tileFace = _decoration(tester, tile);
    expect(
      tileFace.color?.toARGB32(),
      Palette.coral.withValues(alpha: 0.10).toARGB32(),
    );
    expect(
      (tileFace.border! as Border).top.color.toARGB32(),
      Palette.coral.withValues(alpha: 0.45).toARGB32(),
    );
    final SettingsIcon bannerIcon = tester.widget<SettingsIcon>(
      find.descendant(of: tile, matching: find.byType(SettingsIcon)),
    );
    expect(bannerIcon.glyph, SettingsGlyph.download);
    expect(bannerIcon.size, 18);
    expect(
      find.descendant(of: banner, matching: find.byType(ChevronGlyph)),
      findsOneWidget,
    );
    final Rect card = tester.getRect(
      find.descendant(
        of: find.byType(SettingsSectionList),
        matching: find.byType(StickerCard),
      ),
    );
    expect(card.top - bannerRect.bottom, closeTo(14, _tolerance));
    expect(
      tester.getSemantics(banner),
      isSemantics(
        label: 'Update available: 2.4.0',
        hint: 'Read the changelog, then update',
        isButton: true,
        hasTapAction: true,
      ),
    );
    final Finder aboutRow = find.byKey(settingsTabKey(SettingsTab.about));
    expect(
      find.descendant(
        of: aboutRow,
        matching: find.text('Version 2.4.0 is ready'),
      ),
      findsOneWidget,
    );
    final Finder mark = find.byKey(settingsSectionMarkKey(SettingsTab.about));
    _expectRingedDot(tester, mark, size: 9);
    expect(
      tester.getRect(mark).right,
      lessThan(
        tester
            .getRect(
              find.descendant(
                of: aboutRow,
                matching: find.byType(ChevronGlyph),
              ),
            )
            .left,
      ),
    );
    semantics.dispose();

    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(find.byKey(updateNotesSheetKey), findsOneWidget);
    expect(find.text('update available'), findsOneWidget);
    await tester.tap(find.byKey(updateNotesLaterKey));
    await tester.pumpAndSettle();
    expect(find.byKey(updateNotesSheetKey), findsNothing);

    for (final UpdateStatus status in <UpdateStatus>[
      UpdateCurrent(_checkedAt),
      UpdateDownloading(_release, 0.4),
    ]) {
      await _pumpShell(
        tester,
        platform: TargetPlatform.android,
        status: status,
        route: InstallRoute.systemInstaller,
      );
      expect(find.byKey(settingsBadgeKey), findsNothing, reason: '$status');
      expect(
        find.bySemanticsLabel('Settings'),
        findsWidgets,
        reason: '$status',
      );
      await _openSettings(tester, phone: true);
      expect(
        find.byKey(settingsUpdateBannerKey),
        findsNothing,
        reason: '$status',
      );
      expect(
        find.byKey(settingsSectionMarkKey(SettingsTab.about)),
        findsNothing,
        reason: '$status',
      );
      expect(
        find.descendant(
          of: find.byKey(settingsTabKey(SettingsTab.about)),
          matching: find.text('Version 1.4.2'),
        ),
        findsOneWidget,
        reason: '$status',
      );
    }
  });

  testWidgets('a Google Play copy shows no update indicators', (
    WidgetTester tester,
  ) async {
    await _pumpShell(
      tester,
      platform: TargetPlatform.android,
      status: UpdateAvailable(_release, _checkedAt),
      route: InstallRoute.googlePlay,
    );
    expect(find.byKey(settingsBadgeKey), findsNothing);
    expect(find.text('Settings, update available'), findsNothing);

    await _openSettings(tester, phone: true);
    expect(find.byKey(settingsUpdateBannerKey), findsNothing);
    expect(find.text('Update available: 2.4.0'), findsNothing);
    expect(find.byKey(settingsSectionMarkKey(SettingsTab.about)), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(settingsTabKey(SettingsTab.about)),
        matching: find.text('Version 1.4.2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(settingsTabKey(SettingsTab.about)));
    await tester.pumpAndSettle();
    expect(find.text('Version 2.4.0 is ready to install'), findsOneWidget);
    expect(find.byKey(settingsBadgeKey), findsNothing);
  });
}
