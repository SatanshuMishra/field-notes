import 'dart:math' as math;

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sections/data_section.dart';
import 'sections/journal_section.dart';
import 'sections/performance_section.dart';
import 'sections/reminders_sound_section.dart';
import 'sections/sync_storage_section.dart';
import 'spell_check_availability.dart';
import 'widgets/settings_notice.dart';
import 'widgets/settings_tabs.dart';

const Key settingsTabContentKey = ValueKey<String>('settings-tab-content');

const double _contentMaxWidth = 600;
const double _railContentGap = 24;
const double _ringRoom = 6;
const double _pagePadding = 20;
const double _sectionGap = 16;
const double _sidebarHeaderGap = 18;

const double _phoneSideInset = 14;
const double _phoneHeaderGap = 6;
const double _phoneTabsRoom = 56;
const double _phoneTabsLift = 2;
const double _phoneTabsSideInset = 12;
const double _phoneTitleGap = 12;
const double _phoneEyebrowSize = 15;
const double _phoneTitleSize = 30;
const double _phoneTitleHeight = 1.05;

const EdgeInsets _phoneHeadingPadding = EdgeInsets.symmetric(horizontal: 2);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _notice;
  SettingsTab _tab = SettingsTab.syncStorage;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _notice = message);
    _scrollToTop();
  }

  void _dismissNotice() {
    if (!mounted) {
      return;
    }
    setState(() => _notice = null);
  }

  void _selectTab(SettingsTab tab) {
    if (!mounted || tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSettings> settings = ref.watch(appSettingsProvider);
    return ColoredBox(
      color: context.colors.page,
      child: settings.when(
        loading: _buildLoading,
        error: (Object error, StackTrace stackTrace) => _buildError(),
        data: _buildSections,
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CrossHatchPlaceholder(width: 28, height: 28));
  }

  Widget _buildError() {
    return Center(
      child: StickerCard(
        surface: context.colors.cardBright,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Your settings could not be loaded.',
              style: context.textStyles.bodySans,
            ),
            const SizedBox(height: 16),
            StickerButton(
              label: 'Try again',
              variant: StickerButtonVariant.secondary,
              onPressed: () => ref.invalidate(appSettingsProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSections(AppSettings settings) {
    return switch (resolveShellLayout(Theme.of(context).platform)) {
      ShellLayout.sidebar => _buildSidebar(settings),
      ShellLayout.bottomBar => _buildBottomBar(settings),
    };
  }

  Widget _buildSidebar(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _pagePadding,
        _pagePadding,
        _pagePadding - _ringRoom,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SettingsHeader(kicker: context.textStyles.pageEyebrowAccent),
          const SizedBox(height: _sidebarHeaderGap - _ringRoom),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: _ringRoom),
                  child: FocusTraversalGroup(
                    child: SettingsTabRail(
                      key: settingsTabRailKey,
                      selected: _tab,
                      onSelected: _selectTab,
                    ),
                  ),
                ),
                const SizedBox(width: _railContentGap - _ringRoom),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth + _ringRoom * 2,
                    ),
                    child: _buildTabContent(
                      settings,
                      const EdgeInsets.fromLTRB(
                        _ringRoom,
                        _ringRoom,
                        _ringRoom,
                        _pagePadding,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppSettings settings) {
    final double barZone =
        MediaQuery.viewPaddingOf(context).bottom + phoneBottomBarZone;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: _buildPhoneContent(
            settings,
            EdgeInsets.fromLTRB(
              _phoneSideInset,
              MediaQuery.paddingOf(context).top + _phoneHeaderGap,
              _phoneSideInset,
              barZone + _phoneTabsRoom,
            ),
          ),
        ),
        Positioned(
          left: _phoneTabsSideInset,
          right: _phoneTabsSideInset,
          bottom: barZone + _phoneTabsLift - settingsTabChipsOverhang,
          child: Center(
            child: FocusTraversalGroup(
              child: SettingsTabChips(
                key: settingsTabChipsKey,
                selected: _tab,
                onSelected: _selectTab,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneContent(AppSettings settings, EdgeInsets padding) {
    return FocusTraversalGroup(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - padding.vertical,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _PhoneSettingsHeading(tab: _tab),
                  const SizedBox(height: _phoneTitleGap),
                  _buildTabColumn(settings),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabContent(AppSettings settings, EdgeInsets padding) {
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: padding,
        child: _buildTabColumn(settings),
      ),
    );
  }

  Widget _buildTabColumn(AppSettings settings) {
    final String? notice = _notice;
    final SpellCheckAvailability spellCheckAvailability =
        ref.watch(spellCheckAvailabilityProvider).value ??
        SpellCheckAvailability.available;
    return Column(
      key: settingsTabContentKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (notice != null) ...<Widget>[
          SettingsNotice(message: notice, onDismiss: _dismissNotice),
          const SizedBox(height: _sectionGap),
        ],
        for (final SettingsTab tab in SettingsTab.values)
          Visibility(
            key: ValueKey<SettingsTab>(tab),
            visible: tab == _tab,
            maintainState: true,
            child: _buildTabBody(tab, settings, spellCheckAvailability),
          ),
      ],
    );
  }

  Widget _buildTabBody(
    SettingsTab tab,
    AppSettings settings,
    SpellCheckAvailability spellCheckAvailability,
  ) {
    return switch (tab) {
      SettingsTab.syncStorage => SyncStorageSection(
        settings: settings,
        onFeedback: _showNotice,
      ),
      SettingsTab.remindersSound => RemindersSoundSection(
        settings: settings,
        onFeedback: _showNotice,
      ),
      SettingsTab.journal => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          JournalSection(
            settings: settings,
            onFeedback: _showNotice,
            spellCheckAvailability: spellCheckAvailability,
          ),
          const SizedBox(height: _sectionGap),
          PerformanceSection(settings: settings, onFeedback: _showNotice),
        ],
      ),
      SettingsTab.data => DataSection(onFeedback: _showNotice),
    };
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.kicker});

  final TextStyle kicker;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('preferences', style: kicker),
        Semantics(
          header: true,
          child: Text('Settings', style: context.textStyles.titleSerif),
        ),
      ],
    );
  }
}

class _PhoneSettingsHeading extends StatelessWidget {
  const _PhoneSettingsHeading({required this.tab});

  final SettingsTab tab;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Padding(
      padding: _phoneHeadingPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'preferences',
            style: textStyles.pageEyebrowAccent.copyWith(
              fontSize: _phoneEyebrowSize,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              tab.label,
              style: textStyles.displaySerif.copyWith(
                fontSize: _phoneTitleSize,
                height: _phoneTitleHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
