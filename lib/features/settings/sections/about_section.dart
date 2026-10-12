import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/data/links/link_opener.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';
import '../settings_feedback.dart';
import '../settings_providers.dart';

const String aboutAppName = 'Field Notes';
const String aboutTagline = 'A journal of days';
const String aboutVersionUnavailable = 'Version unavailable';
const String aboutUpdatesGroupLabel = 'updates';
const String aboutAuthorGroupLabel = 'author';
const String aboutAuthorName = 'Satanshu Mishra';
const String aboutAuthorDescription = 'Designed and built Field Notes.';
const String aboutWebsiteLabel = 'Website';
const String aboutGitHubLabel = 'GitHub';
const String aboutLicenceLine =
    '© 2026 Satanshu Mishra · Licensed under the Apache License 2.0';

final Uri aboutWebsiteLink = Uri.parse('https://www.satanshu.tech');
final Uri aboutGitHubLink = Uri.parse(
  'https://github.com/SatanshuMishra/field-notes',
);

const Key aboutIdentityCardKey = ValueKey<String>('about-identity-card');
const Key aboutAuthorCardKey = ValueKey<String>('about-author-card');
const Key aboutLicenceKey = ValueKey<String>('about-licence');
const Key aboutStatusRowKey = ValueKey<String>('about-status-row');
const Key aboutStatusDotKey = ValueKey<String>('about-status-dot');
const Key aboutStatusLineKey = ValueKey<String>('about-status-line');
const Key aboutProgressKey = ValueKey<String>('about-progress');
const Key aboutUpdateButtonKey = ValueKey<String>('about-update-button');
const Key aboutCheckingPillKey = ValueKey<String>('about-checking-pill');
const Key aboutUpdatesCardKey = ValueKey<String>('about-updates-card');
const Key aboutAutomaticToggleKey = ValueKey<String>('about-automatic-toggle');
const Key aboutReleaseNotesRowKey = ValueKey<String>('about-release-notes');

const double aboutDesktopLogoSize = 52;
const double aboutPhoneLogoSize = 60;
const double aboutPhoneLinkButtonHeight = 48;
const double aboutPhoneCheckButtonHeight = 48;
const double aboutPhoneUpdateButtonHeight = 52;
const double aboutPhoneReleaseNotesHeight = 68;
const double aboutStatusDotSize = 8;
const double aboutStatusRingWidth = 3;
const double aboutStatusRingOpacity = 0.18;
const double aboutDesktopProgressMaxWidth = 300;
const double aboutDesktopProgressHeight = 8;
const double aboutPhoneProgressHeight = 10;
const double aboutCheckingOpacity = 0.7;

const double _cardShadowOffset = 3;
const double _cardShadowOpacity = 0.2;
const double _nameSize = 22;
const double _desktopNameHeight = 1.15;
const double _phoneNameHeight = 1.2;
const double _taglineSize = 12.5;

const EdgeInsets _desktopCardPadding = EdgeInsets.symmetric(
  vertical: 18,
  horizontal: 20,
);
const double _desktopCardGap = 16;
const double _desktopGroupsGap = 15;
const double _desktopLicenceGap = 10;
const double _desktopPillGap = 8;
const EdgeInsets _checkingPillPadding = EdgeInsets.symmetric(
  horizontal: 12 + Shapes.outlineWidth,
  vertical: 5 + Shapes.outlineWidth,
);
const double _checkingPillMinHeight = 24;
const double _checkingPillFont = 12;
const double _desktopPulseDot = 6;
const double _pulseGap = 6;

const EdgeInsets _phoneCardPadding = EdgeInsets.fromLTRB(16, 22, 16, 16);
const double _phoneBlockGap = 14;
const double _phoneLogoGap = 8;
const double _phoneTaglineGap = 2;
const double _phoneStatusGap = 6;
const double _phoneStatusSize = 13;
const double _phoneStatusDotGap = 8;
const double _phoneButtonTopGap = 16;
const double _phonePulseDot = 7;
const EdgeInsets _phoneUpdatesPadding = EdgeInsets.symmetric(
  vertical: 4,
  horizontal: 16,
);
const double _phoneUpdatesRowPadding = 12;
const double _phoneNavGap = 12;
const double _phoneNavDescriptionGap = 2;
const EdgeInsets _phoneAuthorPadding = EdgeInsets.all(16);
const double _phoneAuthorGap = 14;
const EdgeInsets _phoneLabelPadding = EdgeInsets.symmetric(horizontal: 2);
const double _phoneAuthorNameSize = 15;
const double _phoneDescriptionHeight = 1.5;
const double _phoneButtonGap = 8;
const double _phoneButtonRadius = 14;
const double _phoneButtonLabelSize = 14;
const double _phoneUpdateLabelSize = 15;

const Duration _pulsePeriod = Duration(milliseconds: 900);
const double _pulseLow = 0.35;

String aboutVersionText(String? version) =>
    version == null ? aboutVersionUnavailable : 'Version $version';

String aboutTaglineLine(String? version) =>
    '$aboutTagline · ${aboutVersionText(version)}';

String aboutIdentityLabel(String? version) =>
    '$aboutAppName, a journal of days, '
    '${version == null ? 'version unavailable' : 'version $version'}';

String aboutLinkFailedMessage(Uri link) {
  final String address = link.toString();
  final String bare = address.replaceFirst(RegExp('^https://'), '');
  return "Couldn't open $address. Find it at $bare.";
}

List<BoxShadow> aboutCardShadow(FieldNotesColors colors) => <BoxShadow>[
  BoxShadow(
    color: colors.shadow.withValues(alpha: _cardShadowOpacity),
    offset: const Offset(_cardShadowOffset, _cardShadowOffset),
  ),
];

enum AboutDotTone { attention, current, quiet }

final class _UpdateView {
  const _UpdateView({
    required this.title,
    required this.description,
    required this.phoneLine,
    required this.tone,
    required this.release,
    required this.fraction,
    required this.downloading,
  });

  final String title;
  final String description;
  final String phoneLine;
  final AboutDotTone tone;
  final ReleaseInfo? release;
  final double? fraction;
  final bool downloading;
}

int? _assetSize(ReleaseInfo release, TargetPlatform platform) {
  final String? name = platformAssetName(platform, release);
  return name == null ? null : release.asset(name)?.size;
}

String _lastChecked(DateTime? at, DateTime now) =>
    at == null ? notCheckedYet : lastCheckedLine(at, now);

_UpdateView _updateView(
  UpdateStatus status, {
  required InstallRoute? route,
  required DateTime now,
  required TargetPlatform platform,
}) {
  return switch (status) {
    UpdateIdle(:final DateTime? lastChecked) => _UpdateView(
      title: updatesTitle,
      description: _lastChecked(lastChecked, now),
      phoneLine: _lastChecked(lastChecked, now),
      tone: AboutDotTone.quiet,
      release: null,
      fraction: null,
      downloading: false,
    ),
    UpdateChecking() => const _UpdateView(
      title: checkingTitle,
      description: checkingDescription,
      phoneLine: phoneCheckingLine,
      tone: AboutDotTone.quiet,
      release: null,
      fraction: null,
      downloading: false,
    ),
    UpdateCurrent(:final DateTime checkedAt) => _UpdateView(
      title: upToDateTitle,
      description: lastCheckedLine(checkedAt, now),
      phoneLine: phoneUpToDateLine(lastCheckedTime(checkedAt, now)),
      tone: AboutDotTone.current,
      release: null,
      fraction: null,
      downloading: false,
    ),
    UpdateAvailable(
      :final ReleaseInfo release,
      :final InstallFailure? lastFailure,
    ) =>
      _UpdateView(
        title: availableTitle(release.version.toString()),
        description: lastFailure != null
            ? installFailureText(lastFailure)
            : route == null
            ? ''
            : routeAvailableLine(route),
        phoneLine: phoneReadyLine(release.version.toString()),
        tone: AboutDotTone.attention,
        release: release,
        fraction: null,
        downloading: false,
      ),
    UpdateDownloading(:final ReleaseInfo release, :final double? fraction) =>
      _UpdateView(
        title: downloadingTitle(release.version.toString()),
        description: fraction == null
            ? downloadingUnknown
            : progressText(fraction, _assetSize(release, platform)),
        phoneLine: downloadingTitle(release.version.toString()),
        tone: AboutDotTone.attention,
        release: release,
        fraction: fraction,
        downloading: true,
      ),
    UpdateRestarting(:final ReleaseInfo release) => _UpdateView(
      title: downloadingTitle(release.version.toString()),
      description: progressText(1, _assetSize(release, platform)),
      phoneLine: downloadingTitle(release.version.toString()),
      tone: AboutDotTone.attention,
      release: release,
      fraction: 1,
      downloading: true,
    ),
    UpdateCheckFailed(
      :final LookupFailure? reason,
      :final DateTime? retryAfter,
    ) =>
      _UpdateView(
        title: checkFailedTitle,
        description: checkFailureText(reason, retryAfter),
        phoneLine: checkFailureText(reason, retryAfter),
        tone: AboutDotTone.quiet,
        release: null,
        fraction: null,
        downloading: false,
      ),
  };
}

class AboutSection extends ConsumerWidget {
  const AboutSection({
    super.key,
    required this.onFeedback,
    this.openLink = openInBrowser,
  });

  final SettingsFeedbackSink onFeedback;
  final LinkOpener openLink;

  Future<void> _open(Uri link) async {
    bool opened;
    try {
      opened = await openLink(link);
    } catch (error) {
      debugPrint('Opening $link failed: $error');
      opened = false;
    }
    if (!opened) {
      onFeedback(aboutLinkFailedMessage(link));
    }
  }

  Future<void> _setAutomatic(WidgetRef ref, bool value) async {
    final SettingsWriteResult result = await ref
        .read(settingsControllerProvider)
        .setCheckForUpdatesAutomatically(value);
    if (result is SettingsWriteFailed) {
      onFeedback(result.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? version = ref.watch(installedAppProvider).value?.version;
    final TargetPlatform platform = Theme.of(context).platform;
    final UpdateStatus status = ref.watch(updateControllerProvider);
    final InstallRoute? route = ref.watch(updateRouteProvider).value;
    final DateTime now = ref.watch(updateClockProvider)();
    final bool automatic =
        ref.watch(appSettingsProvider).value?.checkForUpdatesAutomatically ??
        AppSettings.defaults.checkForUpdatesAutomatically;
    final _UpdateView view = _updateView(
      status,
      route: route,
      now: now,
      platform: platform,
    );
    final _AboutActions actions = _AboutActions(
      check: () => ref.read(updateControllerProvider.notifier).check(),
      openNew: () => showUpdateNotes(context, ref, newVersion: true),
      openInstalled: () => showUpdateNotes(context, ref, newVersion: false),
      setAutomatic: (bool value) => _setAutomatic(ref, value),
    );
    return switch (resolveShellLayout(platform)) {
      ShellLayout.sidebar => _buildDesktop(
        context,
        version: version,
        status: status,
        view: view,
        automatic: automatic,
        actions: actions,
      ),
      ShellLayout.bottomBar => _buildPhone(
        context,
        version: version,
        status: status,
        view: view,
        automatic: automatic,
        actions: actions,
      ),
    };
  }

  Widget _buildDesktop(
    BuildContext context, {
    required String? version,
    required UpdateStatus status,
    required _UpdateView view,
    required bool automatic,
    required _AboutActions actions,
  }) {
    final Widget control = switch (status) {
      UpdateIdle() ||
      UpdateCurrent() ||
      UpdateCheckFailed() => SettingsActionButton(
        label: checkForUpdatesLabel,
        onPressed: actions.check,
      ),
      UpdateChecking() => const _CheckingPill(),
      UpdateAvailable() => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: SettingsActionButton(
              label: readChangelogLabel,
              onPressed: actions.openNew,
            ),
          ),
          const SizedBox(width: _desktopPillGap),
          Flexible(
            child: SettingsActionButton(
              label: updateNowLabel,
              tone: SettingsActionTone.primary,
              onPressed: actions.openNew,
            ),
          ),
        ],
      ),
      UpdateDownloading() || UpdateRestarting() => const SizedBox.shrink(),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _IdentityCard(version: version, phone: false),
        const SizedBox(height: _desktopGroupsGap),
        SettingsSection.grouped(
          groups: <SettingsGroup>[
            SettingsGroup(
              label: aboutUpdatesGroupLabel,
              rows: <Widget>[
                Semantics(
                  key: aboutStatusRowKey,
                  container: true,
                  liveRegion: true,
                  child: SettingsFieldRow(
                    label: view.title,
                    description: view.description,
                    marker: _StatusDot(tone: view.tone),
                    below: view.downloading
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: aboutDesktopProgressMaxWidth,
                              ),
                              child: UpdateProgressBar(
                                key: aboutProgressKey,
                                fraction: view.fraction,
                                height: aboutDesktopProgressHeight,
                              ),
                            ),
                          )
                        : null,
                    control: control,
                  ),
                ),
                _AutomaticRow(automatic: automatic, actions: actions),
                SettingsFieldRow(
                  key: aboutReleaseNotesRowKey,
                  label: releaseNotesLabel,
                  description: version == null
                      ? null
                      : releaseNotesDescription(version),
                  control: SettingsActionButton(
                    label: readNotesLabel,
                    onPressed: actions.openInstalled,
                  ),
                ),
              ],
            ),
            SettingsGroup(
              label: aboutAuthorGroupLabel,
              rows: <Widget>[
                SettingsFieldRow(
                  label: aboutAuthorName,
                  description: aboutAuthorDescription,
                  control: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: SettingsActionButton(
                          label: aboutWebsiteLabel,
                          onPressed: () => _open(aboutWebsiteLink),
                        ),
                      ),
                      const SizedBox(width: _desktopPillGap),
                      Flexible(
                        child: SettingsActionButton(
                          label: aboutGitHubLabel,
                          onPressed: () => _open(aboutGitHubLink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: _desktopLicenceGap),
        Text(
          aboutLicenceLine,
          key: aboutLicenceKey,
          style: context.textStyles.captionSans.copyWith(
            color: context.colors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildPhone(
    BuildContext context, {
    required String? version,
    required UpdateStatus status,
    required _UpdateView view,
    required bool automatic,
    required _AboutActions actions,
  }) {
    final FieldNotesColors colors = context.colors;
    final Widget update = switch (status) {
      UpdateIdle() || UpdateCurrent() || UpdateCheckFailed() => _PhoneButton(
        key: aboutUpdateButtonKey,
        label: checkForUpdatesLabel,
        height: aboutPhoneCheckButtonHeight,
        primary: false,
        onPressed: actions.check,
      ),
      UpdateChecking() => const Opacity(
        opacity: aboutCheckingOpacity,
        child: _PhoneButton(
          key: aboutUpdateButtonKey,
          label: checkingLabel,
          height: aboutPhoneCheckButtonHeight,
          primary: false,
          pulsing: true,
          onPressed: null,
        ),
      ),
      UpdateAvailable(:final ReleaseInfo release) => _PhoneButton(
        key: aboutUpdateButtonKey,
        label: phoneUpdateLabel(release.version.toString()),
        height: aboutPhoneUpdateButtonHeight,
        primary: true,
        onPressed: actions.openNew,
      ),
      UpdateDownloading() || UpdateRestarting() => UpdateProgressBar(
        key: aboutProgressKey,
        fraction: view.fraction,
        height: aboutPhoneProgressHeight,
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _IdentityCard(
          version: version,
          phone: true,
          status: _PhoneStatus(view: view, update: update),
        ),
        const SizedBox(height: _phoneBlockGap),
        StickerCard(
          key: aboutUpdatesCardKey,
          padding: _phoneUpdatesPadding,
          shadow: aboutCardShadow(colors),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _phoneUpdatesRowPadding,
                ),
                child: _AutomaticRow(automatic: automatic, actions: actions),
              ),
              const DashedDivider(),
              _PhoneNavRow(
                key: aboutReleaseNotesRowKey,
                label: releaseNotesLabel,
                description: version == null
                    ? ''
                    : releaseNotesDescription(version),
                onPressed: actions.openInstalled,
              ),
            ],
          ),
        ),
        const SizedBox(height: _phoneBlockGap),
        Padding(
          padding: _phoneLabelPadding,
          child: Text(
            aboutAuthorGroupLabel,
            style: context.textStyles.sectionHeaderAccent.copyWith(
              color: colors.sage,
            ),
          ),
        ),
        StickerCard(
          key: aboutAuthorCardKey,
          padding: _phoneAuthorPadding,
          shadow: aboutCardShadow(colors),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MergeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      aboutAuthorName,
                      style: context.textStyles.labelSans.copyWith(
                        fontSize: _phoneAuthorNameSize,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      aboutAuthorDescription,
                      style: context.textStyles.captionSans.copyWith(
                        height: _phoneDescriptionHeight,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _phoneAuthorGap),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _PhoneLinkButton(
                      label: aboutWebsiteLabel,
                      onPressed: () => _open(aboutWebsiteLink),
                    ),
                  ),
                  const SizedBox(width: _phoneButtonGap),
                  Expanded(
                    child: _PhoneLinkButton(
                      label: aboutGitHubLabel,
                      onPressed: () => _open(aboutGitHubLink),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: _phoneBlockGap),
        Text(
          aboutLicenceLine,
          key: aboutLicenceKey,
          textAlign: TextAlign.center,
          style: context.textStyles.captionSans.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

final class _AboutActions {
  const _AboutActions({
    required this.check,
    required this.openNew,
    required this.openInstalled,
    required this.setAutomatic,
  });

  final VoidCallback check;
  final VoidCallback openNew;
  final VoidCallback openInstalled;
  final ValueChanged<bool> setAutomatic;
}

class _AutomaticRow extends StatelessWidget {
  const _AutomaticRow({required this.automatic, required this.actions});

  final bool automatic;
  final _AboutActions actions;

  @override
  Widget build(BuildContext context) {
    return SettingsFieldRow(
      label: checkAutomaticallyLabel,
      description: checkAutomaticallyDescription,
      control: SettingsToggle(
        key: aboutAutomaticToggleKey,
        semanticLabel: checkAutomaticallyLabel,
        value: automatic,
        onChanged: actions.setAutomatic,
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.version,
    required this.phone,
    this.status,
  });

  final String? version;
  final bool phone;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final TextStyle nameStyle = context.textStyles.headlineSerif.copyWith(
      fontSize: _nameSize,
      fontWeight: FontWeight.w500,
      height: phone ? _phoneNameHeight : _desktopNameHeight,
      color: colors.ink,
    );
    final TextStyle taglineStyle = context.textStyles.captionSans.copyWith(
      fontSize: _taglineSize,
      fontWeight: FontWeight.w400,
      color: colors.muted,
    );
    final Widget name = Text(aboutAppName, style: nameStyle);
    final Widget tagline = Text(
      aboutTaglineLine(version),
      textAlign: phone ? TextAlign.center : TextAlign.start,
      style: taglineStyle,
    );
    final Widget identity = Semantics(
      container: true,
      label: aboutIdentityLabel(version),
      child: ExcludeSemantics(
        child: phone
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const FlowerBloom(
                    kind: FlowerKind.peony,
                    size: aboutPhoneLogoSize,
                  ),
                  const SizedBox(height: _phoneLogoGap),
                  name,
                  const SizedBox(height: _phoneTaglineGap),
                  tagline,
                ],
              )
            : Row(
                children: <Widget>[
                  const FlowerBloom(
                    kind: FlowerKind.peony,
                    size: aboutDesktopLogoSize,
                  ),
                  const SizedBox(width: _desktopCardGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[name, tagline],
                    ),
                  ),
                ],
              ),
      ),
    );
    final Widget? status = this.status;
    return StickerCard(
      key: aboutIdentityCardKey,
      padding: phone ? _phoneCardPadding : _desktopCardPadding,
      shadow: aboutCardShadow(colors),
      child: status == null
          ? identity
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[identity, status],
            ),
    );
  }
}

class _PhoneStatus extends StatelessWidget {
  const _PhoneStatus({required this.view, required this.update});

  final _UpdateView view;
  final Widget update;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: _phoneStatusGap),
        Semantics(
          key: aboutStatusLineKey,
          container: true,
          liveRegion: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _StatusDot(tone: view.tone),
              const SizedBox(width: _phoneStatusDotGap),
              Flexible(
                child: Text(
                  view.phoneLine,
                  textAlign: TextAlign.center,
                  style: context.textStyles.captionSans.copyWith(
                    fontSize: _phoneStatusSize,
                    fontWeight: FontWeight.w400,
                    color: context.colors.mutedDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _phoneButtonTopGap),
        update,
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.tone});

  final AboutDotTone tone;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox.square(
        key: aboutStatusDotKey,
        dimension: aboutStatusDotSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: switch (tone) {
              AboutDotTone.attention => Palette.coral,
              AboutDotTone.current => colors.sage,
              AboutDotTone.quiet => colors.muted,
            },
            shape: BoxShape.circle,
            boxShadow: tone == AboutDotTone.attention
                ? <BoxShadow>[
                    BoxShadow(
                      color: Palette.coral.withValues(
                        alpha: aboutStatusRingOpacity,
                      ),
                      spreadRadius: aboutStatusRingWidth,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.size});

  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulsePeriod,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color muted = context.colors.muted;
    return FadeTransition(
      opacity: Tween<double>(begin: _pulseLow, end: 1).animate(_pulse),
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _CheckingPill extends StatelessWidget {
  const _CheckingPill();

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      button: true,
      enabled: false,
      label: checkingLabel,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _checkingPillMinHeight),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DecoratedBox(
            key: aboutCheckingPillKey,
            decoration: BoxDecoration(
              border: Border.all(
                color: colors.muted,
                width: Shapes.outlineWidth,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(Shapes.radiusPill),
              ),
            ),
            child: Padding(
              padding: _checkingPillPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _PulsingDot(size: _desktopPulseDot),
                  const SizedBox(width: _pulseGap),
                  Flexible(
                    child: Text(
                      checkingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.labelSans.copyWith(
                        fontSize: _checkingPillFont,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneButton extends StatelessWidget {
  const _PhoneButton({
    super.key,
    required this.label,
    required this.height,
    required this.primary,
    required this.onPressed,
    this.pulsing = false,
  });

  final String label;
  final double height;
  final bool primary;
  final bool pulsing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final bool enabled = onPressed != null;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(_phoneButtonRadius),
    );
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textStyles.buttonSans.copyWith(
        fontSize: _phoneUpdateLabelSize,
        color: primary ? Palette.onAccent : colors.ink,
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: FocusRing(
          enabled: enabled,
          onPressed: onPressed,
          includeFocusSemantics: false,
          borderRadius: radius,
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: _phoneButtonGap),
            decoration: BoxDecoration(
              color: primary ? Palette.coral : colors.cardBright,
              border: Border.all(
                color: colors.line,
                width: Shapes.outlineWidth,
              ),
              borderRadius: radius,
              boxShadow: primary ? shadows.emphasis : null,
            ),
            child: pulsing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _PulsingDot(size: _phonePulseDot),
                      const SizedBox(width: _pulseGap),
                      Flexible(child: text),
                    ],
                  )
                : text,
          ),
        ),
      ),
    );
  }
}

class _PhoneNavRow extends StatelessWidget {
  const _PhoneNavRow({
    super.key,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final String label;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      button: true,
      enabled: true,
      label: label,
      hint: description,
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
              minHeight: aboutPhoneReleaseNotesHeight,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label, style: context.textStyles.labelSans),
                      if (description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: _phoneNavDescriptionGap),
                        Text(
                          description,
                          style: context.textStyles.captionSans.copyWith(
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: _phoneNavGap),
                ChevronGlyph(pointsBack: false, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneLinkButton extends StatelessWidget {
  const _PhoneLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(_phoneButtonRadius),
    );
    return Semantics(
      button: true,
      enabled: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          includeFocusSemantics: false,
          borderRadius: radius,
          child: Container(
            height: aboutPhoneLinkButtonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.cardBright,
              border: Border.all(
                color: colors.line,
                width: Shapes.outlineWidth,
              ),
              borderRadius: radius,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.labelSans.copyWith(
                fontSize: _phoneButtonLabelSize,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
