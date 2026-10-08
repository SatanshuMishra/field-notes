import 'dart:async';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/sync/ui/add_device_sheet.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sections/data_section.dart';
import 'sections/journal_section.dart';
import 'sections/performance_section.dart';
import 'sections/reminders_sound_section.dart';
import 'sections/sync_storage_section.dart';
import 'spell_check_availability.dart';
import 'widgets/settings_notice.dart';
import 'widgets/settings_phone_pages.dart';
import 'widgets/settings_tabs.dart';

const Key settingsTabContentKey = ValueKey<String>('settings-tab-content');

const double _ringRoom = 6;
const double _pagePadding = 20;
const double _sectionGap = 16;
const double _sidebarHeaderGap = 18;
const double _railRuleGap = 24;
const double _ruleWidth = 1.5;
const double _contentRightPadding = 28;

const double _phoneSideInset = 14;
const double _phoneHeaderGap = 6;
const double _phoneTitleGap = 12;
const double _phoneListEndGap = 12;
const double _backPillLeft = 12;
const double _backPillLift = 86;
const double _backPillClearance = 12;

sealed class _PhonePage {
  const _PhonePage();
}

final class _ListPage extends _PhonePage {
  const _ListPage();
}

final class _SectionPage extends _PhonePage {
  const _SectionPage(this.tab);

  final SettingsTab tab;
}

final class _DevicesPage extends _PhonePage {
  const _DevicesPage();
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _notice;
  SettingsTab _tab = SettingsTab.journal;
  _PhonePage _page = const _ListPage();

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

  void _showPage(_PhonePage page) {
    if (!mounted) {
      return;
    }
    setState(() => _page = page);
    _scrollToTop();
  }

  void _back() {
    _showPage(switch (_page) {
      _DevicesPage() => const _SectionPage(SettingsTab.syncStorage),
      _SectionPage() || _ListPage() => const _ListPage(),
    });
  }

  void _onPhonePop(bool didPop, Object? result) {
    if (didPop || _page is _ListPage) {
      return;
    }
    scheduleMicrotask(_turnShellBackIntoPageBack);
  }

  void _turnShellBackIntoPageBack() {
    if (!mounted ||
        ref.read(shellNavigationProvider) == ShellDestination.settings) {
      return;
    }
    _back();
    ref
        .read(shellNavigationProvider.notifier)
        .select(ShellDestination.settings);
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
      padding: const EdgeInsets.fromLTRB(_pagePadding, _pagePadding, 0, 0),
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
                const SizedBox(width: _railRuleGap),
                Padding(
                  padding: const EdgeInsets.only(top: _ringRoom),
                  child: DashedDivider(
                    axis: Axis.vertical,
                    thickness: _ruleWidth,
                    color: context.colors.ink25,
                  ),
                ),
                const SizedBox(width: _railRuleGap - _ringRoom),
                Expanded(
                  child: _buildTabContent(
                    settings,
                    const EdgeInsets.fromLTRB(
                      _ringRoom,
                      _ringRoom,
                      _contentRightPadding,
                      _pagePadding,
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
    final _PhonePage page = _page;
    final double gestureBar = MediaQuery.viewPaddingOf(context).bottom;
    final String? backLabel = switch (page) {
      _ListPage() => null,
      _SectionPage() => settingsListTitle,
      _DevicesPage() => SettingsTab.syncStorage.label,
    };
    final double endRoom = backLabel == null
        ? gestureBar + phoneBottomBarZone + _phoneListEndGap
        : gestureBar +
              _backPillLift +
              settingsBackPillHeight +
              _backPillClearance;
    return PopScope<Object?>(
      canPop: page is _ListPage,
      onPopInvokedWithResult: _onPhonePop,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _buildPhoneContent(
              settings,
              page,
              EdgeInsets.fromLTRB(
                _phoneSideInset,
                MediaQuery.paddingOf(context).top + _phoneHeaderGap,
                _phoneSideInset,
                endRoom,
              ),
            ),
          ),
          if (backLabel != null)
            Positioned(
              left: _backPillLeft,
              bottom: gestureBar + _backPillLift,
              child: FocusTraversalGroup(
                child: SettingsBackPill(label: backLabel, onPressed: _back),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneContent(
    AppSettings settings,
    _PhonePage page,
    EdgeInsets padding,
  ) {
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ...switch (page) {
              _ListPage() => <Widget>[
                SettingsSectionList(
                  onOpen: (SettingsTab tab) {
                    _showPage(_SectionPage(tab));
                  },
                ),
                const SizedBox(height: _phoneTitleGap),
              ],
              _SectionPage(:final SettingsTab tab) => <Widget>[
                SettingsPageHeading(title: tab.label),
                const SizedBox(height: _phoneTitleGap),
              ],
              _DevicesPage() => const <Widget>[
                SettingsPageHeading(title: devicesTitle),
                SizedBox(height: _phoneTitleGap),
              ],
            },
            _buildTabColumn(settings, page is _SectionPage ? page.tab : null),
            if (page is _DevicesPage) _DevicesCard(onFeedback: _showNotice),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(AppSettings settings, EdgeInsets padding) {
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: padding,
        child: _buildTabColumn(settings, _tab),
      ),
    );
  }

  Widget _buildTabColumn(AppSettings settings, SettingsTab? shown) {
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
            visible: tab == shown,
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
      SettingsTab.journal => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          JournalSection(
            settings: settings,
            onFeedback: _showNotice,
            spellCheckAvailability: spellCheckAvailability,
          ),
          SizedBox(
            height:
                resolveShellLayout(Theme.of(context).platform) ==
                    ShellLayout.sidebar
                ? settingsSidebarSectionGap
                : _sectionGap,
          ),
          PerformanceSection(settings: settings, onFeedback: _showNotice),
        ],
      ),
      SettingsTab.syncStorage => SyncStorageSection(
        settings: settings,
        onFeedback: _showNotice,
        onManageDevices: () => _showPage(const _DevicesPage()),
      ),
      SettingsTab.remindersSound => RemindersSoundSection(
        settings: settings,
        onFeedback: _showNotice,
      ),
      SettingsTab.data => DataSection(onFeedback: _showNotice),
    };
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.onFeedback});

  final DeviceFeedback onFeedback;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DeviceList(onFeedback: onFeedback),
          const SizedBox(height: 12),
          const DashedDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SettingsFieldRow(
              label: addDeviceTitle,
              description: addDeviceCaption,
              control: StickerButton(
                label: showCodeLabel,
                variant: StickerButtonVariant.secondary,
                padTapTarget: true,
                onPressed: () => showAddDeviceSheet(context),
              ),
            ),
          ),
        ],
      ),
    );
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
        Text(settingsListEyebrow, style: kicker),
        Semantics(
          header: true,
          child: Text(settingsListTitle, style: context.textStyles.titleSerif),
        ),
      ],
    );
  }
}
