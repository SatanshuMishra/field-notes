import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
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

String settingsBackLabel(String label) => 'Back to $label';

const double _eyebrowSize = 15;
const double _titleSize = 30;
const double _titleHeight = 1.05;
const double _headingGap = 12;
const double _rowLabelSize = 15;
const double _summaryGap = 2;
const double _chevronGap = 12;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PageHeading(
          eyebrow: settingsListEyebrow,
          title: settingsListTitle,
        ),
        const SizedBox(height: _headingGap),
        StickerCard(
          padding: _listPadding,
          child: SyncClockRefresh(
            builder: (BuildContext context) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final SettingsTab tab in SettingsTab.values) ...<Widget>[
                  if (tab != SettingsTab.values.first) const DashedDivider(),
                  _SectionRow(
                    tab: tab,
                    summary: _summaryFor(tab, syncOn, status),
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

  String _summaryFor(SettingsTab tab, bool? syncOn, SyncStatus? status) =>
      switch (tab) {
        SettingsTab.journal => journalSummary,
        SettingsTab.syncStorage => switch (syncOn) {
          false => syncOffSummary,
          true => status?.label(DateTime.now().toUtc()) ?? '',
          null => '',
        },
        SettingsTab.remindersSound => remindersSoundSummary,
        SettingsTab.data => dataSummary,
      };
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.tab,
    required this.summary,
    required this.onPressed,
  });

  final SettingsTab tab;
  final String summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      key: settingsTabKey(tab),
      button: true,
      enabled: true,
      label: tab.label,
      hint: summary,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          includeFocusSemantics: false,
          borderRadius: Shapes.buttonBorderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: settingsSectionRowMinHeight,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tab.label,
                        style: context.textStyles.labelSans.copyWith(
                          fontSize: _rowLabelSize,
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
                ChevronGlyph(pointsBack: false, color: colors.muted),
              ],
            ),
          ),
        ),
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
    return Semantics(
      button: true,
      enabled: true,
      label: settingsBackLabel(label),
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          includeFocusSemantics: false,
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
      ),
    );
  }
}
