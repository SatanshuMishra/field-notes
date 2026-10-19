import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sections/sync_storage_section.dart';
import 'settings_tabs.dart';

const String settingsListEyebrow = 'preferences';
const String settingsListTitle = 'Settings';
const String settingsPageEyebrow = 'settings';

const String journalSummary = 'Appearance, text size, calendar, spell check';
const String syncOffSummary = 'Only on this phone';
const String remindersSoundSummary = 'Daily nudge, reflection prompt, sound';
const String dataSummary = 'Export, reclaim space, delete';

const double settingsSectionRowMinHeight = 68;
const double settingsBackPillHeight = 48;
const double settingsSectionTileSize = 42;
const double settingsSectionIconSize = 20;

String settingsBackLabel(String label) => 'Back to $label';

String aboutSummary(String? version) =>
    version == null ? '' : 'Version $version';

ValueKey<String> settingsSectionTileKey(SettingsTab tab) =>
    ValueKey<String>('settings-section-tile-${tab.name}');

ValueKey<String> settingsSectionMarkKey(SettingsTab tab) =>
    ValueKey<String>('settings-section-mark-${tab.name}');

const Key settingsUpdateBannerKey = ValueKey<String>('settings-update-banner');
const Key settingsUpdateBannerTileKey = ValueKey<String>(
  'settings-update-banner-tile',
);

const double settingsUpdateBannerMinHeight = 68;
const double settingsUpdateBannerTileSize = 40;
const double settingsUpdateBannerIconSize = 18;
const double settingsUpdateBannerGap = 14;
const double settingsSectionMarkSize = 9;

const double _eyebrowSize = 15;
const double _titleSize = 30;
const double _titleHeight = 1.05;
const double _headingGap = 12;
const double _rowLabelSize = 15;
const double _summaryGap = 3;
const double _chevronGap = 12;
const double _tileGap = 12;
const double _tileRadius = 12;
const double _markRing = 3;
const double _markRingOpacity = 0.18;
const double _bannerRadius = 16;
const double _bannerShadowOffset = 3;
const double _bannerShadowOpacity = 0.35;
const double _bannerTileFillOpacity = 0.10;
const double _bannerTileBorderOpacity = 0.45;
const double _bannerTitleSize = 14;
const EdgeInsets _bannerPadding = EdgeInsets.fromLTRB(14, 12, 12, 12);
const double _pillChevronGap = 4;

const EdgeInsets _headingPadding = EdgeInsets.symmetric(horizontal: 2);
const EdgeInsets _listPadding = EdgeInsets.symmetric(horizontal: 16);
const EdgeInsets _pillPadding = EdgeInsets.only(left: 12, right: 18);

const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(settingsBackPillHeight / 2),
);

class SettingsSectionList extends ConsumerWidget {
  const SettingsSectionList({super.key, required this.onOpen});

  final ValueChanged<SettingsTab> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool? syncOn = ref.watch(syncEnabledProvider).value;
    final SyncStatus? status = syncOn == true
        ? ref.watch(syncStatusProvider).value
        : null;
    final String? version = ref.watch(installedAppProvider).value?.version;
    final ReleaseInfo? update = ref.watch(updateNoticeProvider);
    final InputProfile profile =
        (ref.watch(appSettingsProvider).value ?? AppSettings.defaults)
            .inputProfile;
    final List<SettingsTab> tabs = settingsTabsFor(
      syncAvailable: ref.watch(syncAvailableProvider),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PageHeading(
          eyebrow: settingsListEyebrow,
          title: settingsListTitle,
        ),
        const SizedBox(height: _headingGap),
        if (update != null) ...<Widget>[
          _UpdateBanner(
            version: update.version.toString(),
            onPressed: () => showUpdateNotes(context, ref, newVersion: true),
          ),
          const SizedBox(height: settingsUpdateBannerGap),
        ],
        StickerCard(
          padding: _listPadding,
          child: SyncClockRefresh(
            builder: (BuildContext context) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final SettingsTab tab in tabs) ...<Widget>[
                  if (tab != tabs.first) const DashedDivider(),
                  _SectionRow(
                    tab: tab,
                    summary: tab == SettingsTab.about && update != null
                        ? aboutRowReadySummary(update.version.toString())
                        : _summaryFor(tab, syncOn, status, version, profile),
                    marked: tab == SettingsTab.about && update != null,
                    onPressed: () => onOpen(tab),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _summaryFor(
    SettingsTab tab,
    bool? syncOn,
    SyncStatus? status,
    String? version,
    InputProfile profile,
  ) => switch (tab) {
    SettingsTab.journal => journalSummary,
    SettingsTab.syncStorage => switch (syncOn) {
      false => syncOffSummary,
      true => status?.label(DateTime.now().toUtc()) ?? '',
      null => '',
    },
    SettingsTab.remindersSound => remindersSoundSummary,
    SettingsTab.voice => profile.label,
    SettingsTab.data => dataSummary,
    SettingsTab.about => aboutSummary(version),
  };
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.tab,
    required this.summary,
    required this.onPressed,
    this.marked = false,
  });

  final SettingsTab tab;
  final String summary;
  final VoidCallback onPressed;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Pressable(
      includeFocusSemantics: false,
      key: settingsTabKey(tab),
      label: tab.label,
      hint: summary,
      onPressed: onPressed,
      borderRadius: Shapes.buttonBorderRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: settingsSectionRowMinHeight,
        ),
        child: Row(
          children: <Widget>[
            _SectionTile(tab: tab),
            const SizedBox(width: _tileGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tab.label,
                    style: context.textStyles.labelSans.copyWith(
                      fontSize: _rowLabelSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: _summaryGap),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.captionSans,
                  ),
                ],
              ),
            ),
            const SizedBox(width: _chevronGap),
            if (marked) ...<Widget>[
              _Mark(markKey: settingsSectionMarkKey(tab)),
              const SizedBox(width: _chevronGap),
            ],
            ChevronGlyph(pointsBack: false, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.markKey});

  final Key markKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: markKey,
      width: settingsSectionMarkSize,
      height: settingsSectionMarkSize,
      decoration: BoxDecoration(
        color: Palette.coral,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Palette.coral.withValues(alpha: _markRingOpacity),
            spreadRadius: _markRing,
          ),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.version, required this.onPressed});

  final String version;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(_bannerRadius),
    );
    final String title = bannerTitle(version);
    return Pressable(
      includeFocusSemantics: false,
      label: title,
      hint: bannerSubtitle,
      onPressed: onPressed,
      borderRadius: radius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => HoverFill(
        hovered: hovered,
        borderRadius: radius,
        child: Container(
          key: settingsUpdateBannerKey,
          constraints: const BoxConstraints(
            minHeight: settingsUpdateBannerMinHeight,
          ),
          padding: _bannerPadding,
          decoration: BoxDecoration(
            color: colors.cardBright,
            border: Border.all(color: colors.line, width: Shapes.outlineWidth),
            borderRadius: radius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Palette.coral.withValues(alpha: _bannerShadowOpacity),
                offset: const Offset(_bannerShadowOffset, _bannerShadowOffset),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                key: settingsUpdateBannerTileKey,
                width: settingsUpdateBannerTileSize,
                height: settingsUpdateBannerTileSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Palette.coral.withValues(
                    alpha: _bannerTileFillOpacity,
                  ),
                  border: Border.all(
                    color: Palette.coral.withValues(
                      alpha: _bannerTileBorderOpacity,
                    ),
                    width: Shapes.outlineWidth,
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_tileRadius),
                  ),
                ),
                child: SettingsIcon(
                  SettingsGlyph.download,
                  size: settingsUpdateBannerIconSize,
                  color: colors.accentInk,
                ),
              ),
              const SizedBox(width: _tileGap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.labelSans.copyWith(
                        fontSize: _bannerTitleSize,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: _summaryGap),
                    Text(
                      bannerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.captionSans.copyWith(
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _chevronGap),
              ChevronGlyph(pointsBack: false, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.tab});

  final SettingsTab tab;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Container(
      key: settingsSectionTileKey(tab),
      width: settingsSectionTileSize,
      height: settingsSectionTileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.cardBright,
        border: Border.all(color: colors.line, width: Shapes.outlineWidth),
        borderRadius: const BorderRadius.all(Radius.circular(_tileRadius)),
      ),
      child: SettingsIcon(
        tab.glyph,
        size: settingsSectionIconSize,
        color: colors.ink,
      ),
    );
  }
}

class SettingsPageHeading extends StatelessWidget {
  const SettingsPageHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _PageHeading(eyebrow: settingsPageEyebrow, title: title);
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Padding(
      padding: _headingPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            style: textStyles.pageEyebrowAccent.copyWith(
              fontSize: _eyebrowSize,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: textStyles.displaySerif.copyWith(
                fontSize: _titleSize,
                height: _titleHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsBackPill extends StatelessWidget {
  const SettingsBackPill({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Pressable(
      includeFocusSemantics: false,
      label: settingsBackLabel(label),
      onPressed: onPressed,
      shape: HoverShape.pill,
      borderRadius: _pillRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => HoverFill(
        hovered: hovered,
        shape: HoverShape.pill,
        borderRadius: _pillRadius,
        child: GlassSurface(
          tone: GlassTone.paper,
          borderRadius: _pillRadius,
          grouped: true,
          padding: _pillPadding,
          child: SizedBox(
            height: settingsBackPillHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ChevronGlyph(pointsBack: true, color: colors.ink),
                const SizedBox(width: _pillChevronGap),
                Text(label, maxLines: 1, style: context.textStyles.labelSans),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
