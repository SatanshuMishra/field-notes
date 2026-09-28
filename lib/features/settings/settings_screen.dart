import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sections/data_section.dart';
import 'sections/journal_section.dart';
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
const double _bottomBarHeaderGap = 10;
const double _chipsContentGap = 6;
const double _compactKickerSize = 14;

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
      color: Palette.page,
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
        surface: Palette.cardBright,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Your settings could not be loaded.',
              style: TypographyTokens.bodySans,
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
          const _SettingsHeader(kicker: TypographyTokens.pageEyebrowAccent),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _pagePadding,
            _pagePadding,
            _pagePadding,
            0,
          ),
          child: _SettingsHeader(
            kicker: TypographyTokens.pageEyebrowAccent.copyWith(
              fontSize: _compactKickerSize,
            ),
          ),
        ),
        const SizedBox(height: _bottomBarHeaderGap),
        FocusTraversalGroup(
          child: SettingsTabChips(
            key: settingsTabChipsKey,
            selected: _tab,
            onSelected: _selectTab,
            padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
          ),
        ),
        Expanded(
          child: _buildTabContent(
            settings,
            const EdgeInsets.fromLTRB(
              _pagePadding,
              _chipsContentGap,
              _pagePadding,
              _pagePadding,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(AppSettings settings, EdgeInsets padding) {
    final String? notice = _notice;
    final SpellCheckAvailability spellCheckAvailability =
        ref.watch(spellCheckAvailabilityProvider).value ??
        SpellCheckAvailability.available;
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: padding,
        child: Column(
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
        ),
      ),
    );
  }

  Widget _buildTabBody(
    SettingsTab tab,
    AppSettings settings,
    SpellCheckAvailability spellCheckAvailability,
  ) {
    return switch (tab) {
      SettingsTab.syncStorage => SyncStorageSection(
        storageMode: ref.watch(settingsRepositoryProvider).storageMode,
      ),
      SettingsTab.remindersSound => RemindersSoundSection(
        settings: settings,
        onFeedback: _showNotice,
      ),
      SettingsTab.journal => JournalSection(
        settings: settings,
        onFeedback: _showNotice,
        spellCheckAvailability: spellCheckAvailability,
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
          child: Text('Settings', style: TypographyTokens.titleSerif),
        ),
      ],
    );
  }
}
