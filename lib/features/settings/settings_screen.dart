import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/sync/ui/add_device_sheet.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/settings_section_request.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sections/about_section.dart';
import 'sections/data_section.dart';
import 'sections/journal_section.dart';
import 'sections/performance_section.dart';
import 'sections/reminders_sound_section.dart';
import 'sections/sync_storage_section.dart';
import 'sections/voice_section.dart';
import 'spell_check_availability.dart';
import 'widgets/settings_notice.dart';
import 'widgets/settings_phone_pages.dart';
import 'widgets/settings_tabs.dart';

const Key settingsTabContentKey = ValueKey<String>('settings-tab-content');
const Key settingsContentTitleKey = ValueKey<String>('settings-content-title');
const Key settingsSidebarColumnKey = ValueKey<String>(
  'settings-sidebar-column',
);
const Key settingsContentColumnKey = ValueKey<String>(
  'settings-content-column',
);

const String settingsSidebarKicker = 'settings';

const double settingsContentMaxWidth = 680;
const double settingsContentTitleSize = 34;

const double _sectionGap = 16;
const double _desktopGroupGap = 15;
const EdgeInsets _sidebarColumnPadding = EdgeInsets.fromLTRB(24, 26, 14, 20);
const EdgeInsets _kickerPadding = EdgeInsets.symmetric(horizontal: 10);
const double _kickerGap = 6;
const double _ruleThickness = 1;
const EdgeInsets _contentPadding = EdgeInsets.fromLTRB(28, 26, 34, 34);
const EdgeInsets _contentTitlePadding = EdgeInsets.only(top: 17, bottom: 26);
const double _contentTitleHeight = 1;

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

  @override
  bool operator ==(Object other) => other is _ListPage;

  @override
  int get hashCode => (_ListPage).hashCode;
}

final class _SectionPage extends _PhonePage {
  const _SectionPage(this.tab);

  final SettingsTab tab;

  @override
  bool operator ==(Object other) => other is _SectionPage && other.tab == tab;

  @override
  int get hashCode => tab.hashCode;
}

final class _DevicesPage extends _PhonePage {
  const _DevicesPage();

  @override
  bool operator ==(Object other) => other is _DevicesPage;

  @override
  int get hashCode => (_DevicesPage).hashCode;
}

String _phonePageTitle(_PhonePage page) => switch (page) {
  _ListPage() => settingsListTitle,
  _SectionPage(:final SettingsTab tab) => tab.label,
  _DevicesPage() => devicesTitle,
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _phoneSectionsKey = GlobalKey();
  String? _notice;
  SettingsTab _tab = SettingsTab.journal;
  _PhonePage _page = const _ListPage();

  @override
  void initState() {
    super.initState();
    final SettingsTab? requested = ref.read(settingsSectionRequestProvider);
    if (requested != null) {
      _tab = requested;
      _page = _SectionPage(requested);
      scheduleMicrotask(_clearRequest);
    }
  }

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

  void _openRequested(SettingsTab? previous, SettingsTab? next) {
    if (next == null) {
      return;
    }
    _selectTab(next);
    _showPage(_SectionPage(next));
    scheduleMicrotask(_clearRequest);
  }

  void _clearRequest() {
    if (!mounted || ref.read(settingsSectionRequestProvider) == null) {
      return;
    }
    ref.read(settingsSectionRequestProvider.notifier).clear();
  }

  void _showPage(_PhonePage page) {
    if (!mounted) {
      return;
    }
    setState(() => _page = page);
    _scrollToTop();
  }

  _PhonePage _visiblePage({required bool syncOff}) => switch (_page) {
    _DevicesPage() when syncOff => const _SectionPage(SettingsTab.syncStorage),
    final _PhonePage page => page,
  };

  bool get _syncOff => ref.read(syncEnabledProvider).value == false;

  void _back() {
    _showPage(switch (_visiblePage(syncOff: _syncOff)) {
      _DevicesPage() => const _SectionPage(SettingsTab.syncStorage),
      _SectionPage() || _ListPage() => const _ListPage(),
    });
  }

  void _leaveDevicesWhenSyncStops(
    AsyncValue<bool>? previous,
    AsyncValue<bool> next,
  ) {
    if (next.value == false && _page is _DevicesPage) {
      _showPage(const _SectionPage(SettingsTab.syncStorage));
    }
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
    ref.listen<SettingsTab?>(settingsSectionRequestProvider, _openRequested);
    final AsyncValue<AppSettings> settings = ref.watch(appSettingsProvider);
    return settings.when(
      loading: _buildLoading,
      error: (Object error, StackTrace stackTrace) => _buildError(),
      data: _buildSections,
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
    final FieldNotesColors colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          key: settingsSidebarColumnKey,
          padding: _sidebarColumnPadding,
          child: SizedBox(
            width: settingsTabRailWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: _kickerPadding,
                  child: Text(
                    settingsSidebarKicker,
                    style: context.textStyles.pageEyebrowAccent.copyWith(
                      color: colors.accentInk,
                    ),
                  ),
                ),
                const SizedBox(height: _kickerGap),
                FocusTraversalGroup(
                  child: SettingsTabRail(
                    key: settingsTabRailKey,
                    selected: _tab,
                    onSelected: _selectTab,
                    marked: ref.watch(updateNoticeProvider) == null
                        ? const <SettingsTab>{}
                        : const <SettingsTab>{SettingsTab.about},
                  ),
                ),
              ],
            ),
          ),
        ),
        DashedDivider(
          axis: Axis.vertical,
          thickness: _ruleThickness,
          color: colors.ink22,
        ),
        Expanded(child: _buildTabContent(settings)),
      ],
    );
  }

  Widget _buildBottomBar(AppSettings settings) {
    ref.listen<AsyncValue<bool>>(
      syncEnabledProvider,
      _leaveDevicesWhenSyncStops,
    );
    final _PhonePage page = _visiblePage(
      syncOff: ref.watch(syncEnabledProvider).value == false,
    );
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
      child: Semantics(
        key: ValueKey<_PhonePage>(page),
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: _phonePageTitle(page),
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
      ),
    );
  }

  Widget _buildPhoneContent(
    AppSettings settings,
    _PhonePage page,
    EdgeInsets padding,
  ) {
    final bool list = page is _ListPage;
    return FocusTraversalGroup(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            SingleChildScrollView(
              controller: _scrollController,
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: list && constraints.hasBoundedHeight
                      ? math.max(0, constraints.maxHeight - padding.vertical)
                      : 0,
                ),
                child: Column(
                  mainAxisAlignment: list
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ...switch (page) {
                      _ListPage() => <Widget>[
                        SettingsSectionList(
                          onOpen: (SettingsTab tab) {
                            _showPage(_SectionPage(tab));
                          },
                        ),
                        if (_notice != null)
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
                    KeyedSubtree(
                      key: _phoneSectionsKey,
                      child: _buildTabColumn(
                        settings,
                        page is _SectionPage ? page.tab : null,
                      ),
                    ),
                    if (page is _DevicesPage)
                      _DevicesCard(onFeedback: _showNotice),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildTabContent(AppSettings settings) {
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: _contentPadding,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            key: settingsContentColumnKey,
            constraints: const BoxConstraints(
              maxWidth: settingsContentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: _contentTitlePadding,
                  child: Semantics(
                    header: true,
                    child: Text(
                      _tab.label,
                      key: settingsContentTitleKey,
                      style: context.textStyles.displaySerif.copyWith(
                        fontSize: settingsContentTitleSize,
                        fontWeight: FontWeight.w500,
                        height: _contentTitleHeight,
                      ),
                    ),
                  ),
                ),
                _buildTabColumn(settings, _tab),
              ],
            ),
          ),
        ),
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
        for (final SettingsTab tab in settingsTabsFor(
          syncAvailable: ref.watch(syncAvailableProvider),
        ))
          Visibility(
            key: ValueKey<SettingsTab>(tab),
            visible: tab == shown,
            maintainState: true,
            child: _buildTabBody(
              tab,
              settings,
              spellCheckAvailability,
              shown: tab == shown,
            ),
          ),
      ],
    );
  }

  Widget _buildTabBody(
    SettingsTab tab,
    AppSettings settings,
    SpellCheckAvailability spellCheckAvailability, {
    required bool shown,
  }) {
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
                ? _desktopGroupGap
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
      SettingsTab.voice => VoiceSection(
        settings: settings,
        onFeedback: _showNotice,
        active: shown,
      ),
      SettingsTab.data => DataSection(onFeedback: _showNotice),
      SettingsTab.about => AboutSection(onFeedback: _showNotice),
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
