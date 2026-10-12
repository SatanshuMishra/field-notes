import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/data/updates/bundled_changelog.dart';
import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Key updateNotesPanelKey = ValueKey<String>('update-notes-panel');
const Key updateNotesSheetKey = ValueKey<String>('update-notes-sheet');
const Key updateNotesTileKey = ValueKey<String>('update-notes-tile');
const Key updateNotesNoteKey = ValueKey<String>('update-notes-note');
const Key updateNotesProgressKey = ValueKey<String>('update-notes-progress');
const Key updateNotesFooterKey = ValueKey<String>('update-notes-footer');
const Key updateNotesCloseKey = ValueKey<String>('update-notes-close');
const Key updateNotesActionKey = ValueKey<String>('update-notes-action');
const Key updateNotesLaterKey = ValueKey<String>('update-notes-later');

const double updateNotesPanelMaxWidth = 660;
const double updateNotesPanelSideRoom = 80;
const double updateNotesPanelHeightRoom = 64;
const double updateNotesDesktopTile = 48;
const double updateNotesPhoneTile = 44;
const double updateNotesCloseSize = 36;
const double updateNotesPhoneActionHeight = 52;
const double updateNotesPhoneSecondaryHeight = 48;
const double updateNotesProgressHeight = 10;

const double _scrimAlpha = 0.42;
const double _panelBorder = 2;
const double _panelRadius = 18;
const double _tileRadius = 12;
const double _tileFillAlpha = 0.10;
const double _tileBorderAlpha = 0.45;
const double _tileIcon = 22;
const double _tileGap = 16;
const double _desktopKicker = 16;
const double _phoneKicker = 15;
const double _desktopTitle = 26;
const double _phoneTitle = 22;
const double _titleHeight = 1.15;
const double _metaSize = 12;
const double _metaGap = 2;
const double _desktopIntroSize = 16;
const double _desktopIntroHeight = 1.6;
const double _phoneIntroSize = 15;
const double _phoneIntroHeight = 1.55;
const int _introCharacters = 60;
const double _groupTitleSize = 19;
const int _itemCharacters = 64;
const double _itemSize = 14;
const double _itemHeight = 1.55;
const double _itemDot = 6;
const double _itemDotGap = 10;
const double _itemGap = 6;
const double _groupGap = 16;
const double _groupTitleGap = 4;
const double _introGap = 18;
const double _footerRuleThickness = 1;
const double _footerNoteSize = 12;
const double _footerButtonGap = 12;
const double _noteProgressGap = 6;
const double _phoneButtonRadius = 14;
const double _phoneButtonLabel = 15;
const double _closeIcon = 18;

const EdgeInsets _desktopHeaderPadding = EdgeInsets.fromLTRB(28, 24, 20, 14);
const EdgeInsets _desktopRulePadding = EdgeInsets.symmetric(horizontal: 28);
const EdgeInsets _desktopNotesPadding = EdgeInsets.fromLTRB(28, 20, 28, 24);
const EdgeInsets _desktopFooterPadding = EdgeInsets.fromLTRB(28, 14, 24, 16);
const EdgeInsets _phoneHeaderPadding = EdgeInsets.fromLTRB(20, 10, 20, 12);
const EdgeInsets _phoneRulePadding = EdgeInsets.symmetric(horizontal: 20);
const EdgeInsets _phoneNotesPadding = EdgeInsets.fromLTRB(20, 16, 20, 16);
const EdgeInsets _phoneNotePadding = EdgeInsets.fromLTRB(20, 10, 20, 0);
const EdgeInsets _phoneFooterPadding = EdgeInsets.fromLTRB(12, 10, 12, 12);

ReleaseInfo? _releaseOf(UpdateStatus status) => switch (status) {
  UpdateAvailable(:final ReleaseInfo release) => release,
  UpdateDownloading(:final ReleaseInfo release) => release,
  UpdateRestarting(:final ReleaseInfo release) => release,
  UpdateIdle() ||
  UpdateChecking() ||
  UpdateCurrent() ||
  UpdateCheckFailed() => null,
};

int? _downloadSize(ReleaseInfo release, TargetPlatform platform) {
  final String? name = platformAssetName(platform, release);
  return name == null ? null : release.asset(name)?.size;
}

double _characters(BuildContext context, TextStyle style, int count) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: '0',
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
  )..layout();
  final double width = painter.width * count;
  painter.dispose();
  return width;
}

Future<void> showUpdateNotes(
  BuildContext context,
  WidgetRef ref, {
  required bool newVersion,
}) async {
  final ReleaseInfo? release = _releaseOf(ref.read(updateControllerProvider));
  if (newVersion && release == null) {
    return;
  }
  final bool phone =
      resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;
  if (phone) {
    await showPhoneSheet<void>(
      context,
      builder: (BuildContext sheetContext) =>
          UpdateNotesSheet(newVersion: newVersion, release: release),
    );
    return;
  }
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: closeLabel,
    barrierColor: Palette.toolbarInk.withValues(alpha: _scrimAlpha),
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => DialogHost(
          child: UpdateNotesPanel(newVersion: newVersion, release: release),
        ),
  );
}

class _NotesContent {
  const _NotesContent({
    required this.kicker,
    required this.version,
    required this.meta,
    required this.notes,
  });

  final String kicker;
  final String version;
  final String meta;
  final ReleaseNotes? notes;
}

_NotesContent _content(
  WidgetRef ref, {
  required bool newVersion,
  required ReleaseInfo? release,
  required TargetPlatform platform,
}) {
  if (newVersion) {
    final ReleaseInfo shown =
        _releaseOf(ref.watch(updateControllerProvider)) ?? release!;
    final InstallRoute? route = ref.watch(updateRouteProvider).value;
    final int? size = route == InstallRoute.googlePlay
        ? null
        : _downloadSize(shown, platform);
    return _NotesContent(
      kicker: updateAvailableKicker,
      version: shown.version.toString(),
      meta:
          '${releasedLine(shown.publishedAt)}'
          '${size == null ? '' : downloadSizeSuffix(size)}',
      notes: shown.notes,
    );
  }
  final String version = ref.watch(installedAppProvider).value?.version ?? '';
  final AsyncValue<ChangelogSection?> section = ref.watch(
    installedReleaseNotesProvider,
  );
  final DateTime? date = section.value?.date;
  return _NotesContent(
    kicker: releaseNotesKicker,
    version: version,
    meta: date == null ? '' : releasedLine(date),
    notes: section.hasValue
        ? section.value?.notes ?? ReleaseNotes.empty
        : section.hasError
        ? ReleaseNotes.empty
        : null,
  );
}

class _Footing {
  const _Footing({
    required this.route,
    required this.downloading,
    required this.note,
    required this.fraction,
  });

  final InstallRoute? route;
  final bool downloading;
  final String note;
  final double? fraction;
}

_Footing _footing(
  WidgetRef ref, {
  required ReleaseInfo? release,
  required bool phone,
  required TargetPlatform platform,
}) {
  final UpdateStatus status = ref.watch(updateControllerProvider);
  final InstallRoute? route = ref.watch(updateRouteProvider).value;
  final ReleaseInfo? shown = _releaseOf(status) ?? release;
  final int? size = shown == null ? null : _downloadSize(shown, platform);
  return switch (status) {
    UpdateDownloading(:final double? fraction) => _Footing(
      route: route,
      downloading: true,
      note: downloadingNote(fraction, size),
      fraction: fraction ?? 0,
    ),
    UpdateAvailable(:final InstallFailure lastFailure?) => _Footing(
      route: route,
      downloading: false,
      note: installFailureText(lastFailure),
      fraction: null,
    ),
    _ => _Footing(
      route: route,
      downloading: false,
      note: route == null ? '' : routeNote(route, phone: phone),
      fraction: null,
    ),
  };
}

class UpdateProgressBar extends StatelessWidget {
  const UpdateProgressBar({
    super.key,
    required this.fraction,
    this.height = updateNotesProgressHeight,
  });

  final double? fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final BorderRadius radius = BorderRadius.all(Radius.circular(height / 2));
    final double filled = (fraction ?? 0).clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardBright,
            border: Border.all(color: colors.line, width: Shapes.outlineWidth),
            borderRadius: radius,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: filled,
                heightFactor: 1,
                child: const ColoredBox(color: Palette.coral),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpdateNotesPanel extends ConsumerWidget {
  const UpdateNotesPanel({super.key, required this.newVersion, this.release});

  final bool newVersion;
  final ReleaseInfo? release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FieldNotesColors colors = context.colors;
    final TargetPlatform platform = Theme.of(context).platform;
    final _NotesContent content = _content(
      ref,
      newVersion: newVersion,
      release: release,
      platform: platform,
    );
    final _Footing? footing = newVersion
        ? _footing(ref, release: release, phone: false, platform: platform)
        : null;
    final bool locked = footing?.downloading ?? false;
    final InstallRoute? route = footing?.route;
    void close() {
      if (!locked) {
        Navigator.of(context).maybePop();
      }
    }

    void act() {
      if (!locked && route != null) {
        ref.read(updateControllerProvider.notifier).install();
      }
    }

    final Size window = MediaQuery.sizeOf(context);
    final double width = math.max(
      0,
      math.min(
        updateNotesPanelMaxWidth,
        window.width - updateNotesPanelSideRoom,
      ),
    );
    final double maxHeight = math.max(
      0,
      window.height - updateNotesPanelHeightRoom,
    );
    return PopScope<Object?>(
      canPop: !locked,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): close,
          if (newVersion) ...<ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter): act,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): act,
          },
        },
        child: Focus(
          autofocus: true,
          skipTraversal: true,
          child: Center(
            child: SizedBox(
              width: width,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Semantics(
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: notesTitle(content.version),
                  child: DecoratedBox(
                    key: updateNotesPanelKey,
                    decoration: BoxDecoration(
                      color: colors.cardWarm,
                      border: Border.all(
                        color: colors.line,
                        width: _panelBorder,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(_panelRadius),
                      ),
                      boxShadow: context.shadows.hero,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(_panelRadius - _panelBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: _desktopHeaderPadding,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: _NotesHeader(
                                    content: content,
                                    phone: false,
                                  ),
                                ),
                                _CloseButton(onPressed: locked ? null : close),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: _desktopRulePadding,
                            child: DashedDivider(),
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: _desktopNotesPadding,
                              child: _NotesBody(content: content, phone: false),
                            ),
                          ),
                          if (footing != null)
                            _DesktopFooter(
                              footing: footing,
                              onLater: locked ? null : close,
                              onAct: locked || route == null ? null : act,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpdateNotesSheet extends ConsumerWidget {
  const UpdateNotesSheet({super.key, required this.newVersion, this.release});

  final bool newVersion;
  final ReleaseInfo? release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TargetPlatform platform = Theme.of(context).platform;
    final _NotesContent content = _content(
      ref,
      newVersion: newVersion,
      release: release,
      platform: platform,
    );
    final _Footing? footing = newVersion
        ? _footing(ref, release: release, phone: true, platform: platform)
        : null;
    final bool locked = footing?.downloading ?? false;
    final InstallRoute? route = footing?.route;
    void close() {
      if (!locked) {
        Navigator.of(context).maybePop();
      }
    }

    return PopScope<Object?>(
      canPop: !locked,
      child: PhoneSheet(
        key: updateNotesSheetKey,
        header: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: _phoneHeaderPadding,
              child: _NotesHeader(content: content, phone: true),
            ),
            const Padding(padding: _phoneRulePadding, child: DashedDivider()),
          ],
        ),
        aboveFooter: footing == null
            ? null
            : Padding(
                key: updateNotesFooterKey,
                padding: _phoneNotePadding,
                child: _FooterNote(footing: footing),
              ),
        footerDirection: Axis.vertical,
        footerPadding: _phoneFooterPadding,
        actions: footing == null
            ? <Widget>[
                _SheetButton(
                  key: updateNotesCloseKey,
                  label: closeLabel,
                  height: updateNotesPhoneSecondaryHeight,
                  primary: false,
                  onPressed: close,
                ),
              ]
            : <Widget>[
                _SheetButton(
                  key: updateNotesActionKey,
                  label: route == null ? '' : routeAction(route),
                  height: updateNotesPhoneActionHeight,
                  primary: true,
                  onPressed: locked || route == null
                      ? null
                      : () => ref
                            .read(updateControllerProvider.notifier)
                            .install(),
                ),
                _SheetButton(
                  key: updateNotesLaterKey,
                  label: laterLabel,
                  height: updateNotesPhoneSecondaryHeight,
                  primary: false,
                  onPressed: locked ? null : close,
                ),
              ],
        child: Padding(
          padding: _phoneNotesPadding,
          child: _NotesBody(content: content, phone: true),
        ),
      ),
    );
  }
}

class _NotesHeader extends StatelessWidget {
  const _NotesHeader({required this.content, required this.phone});

  final _NotesContent content;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final double tile = phone ? updateNotesPhoneTile : updateNotesDesktopTile;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          key: updateNotesTileKey,
          width: tile,
          height: tile,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.coral.withValues(alpha: _tileFillAlpha),
            border: Border.all(
              color: Palette.coral.withValues(alpha: _tileBorderAlpha),
              width: Shapes.outlineWidth,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(_tileRadius)),
          ),
          child: SettingsIcon(
            SettingsGlyph.download,
            size: _tileIcon,
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
                content.kicker,
                style: context.textStyles.pageEyebrowAccent.copyWith(
                  fontSize: phone ? _phoneKicker : _desktopKicker,
                  color: colors.accentInk,
                ),
              ),
              Semantics(
                header: true,
                child: Text(
                  notesTitle(content.version),
                  style: context.textStyles.headlineSerif.copyWith(
                    fontSize: phone ? _phoneTitle : _desktopTitle,
                    fontWeight: FontWeight.w500,
                    height: _titleHeight,
                    color: colors.ink,
                  ),
                ),
              ),
              if (content.meta.isNotEmpty) ...<Widget>[
                const SizedBox(height: _metaGap),
                Text(
                  content.meta,
                  style: context.textStyles.captionSans.copyWith(
                    fontSize: _metaSize,
                    color: colors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NotesBody extends StatelessWidget {
  const _NotesBody({required this.content, required this.phone});

  final _NotesContent content;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final ReleaseNotes? notes = content.notes;
    if (notes == null) {
      return const SizedBox.shrink();
    }
    final TextStyle introStyle = context.textStyles.bodySerif.copyWith(
      fontSize: phone ? _phoneIntroSize : _desktopIntroSize,
      fontWeight: FontWeight.w400,
      height: phone ? _phoneIntroHeight : _desktopIntroHeight,
      color: colors.ink,
    );
    final TextStyle groupStyle = context.textStyles.sectionHeaderAccent
        .copyWith(fontSize: _groupTitleSize, color: colors.sage);
    final TextStyle itemStyle = context.textStyles.bodySans.copyWith(
      fontSize: _itemSize,
      fontWeight: FontWeight.w400,
      height: _itemHeight,
      color: colors.ink,
    );
    if (notes.isEmpty) {
      return Text(noNotesText(content.version), style: introStyle);
    }
    final double introWidth = _characters(
      context,
      introStyle,
      _introCharacters,
    );
    final double itemWidth = _characters(context, itemStyle, _itemCharacters);
    final double dotTop = math.max(
      0,
      (_itemSize * _itemHeight * MediaQuery.textScalerOf(context).scale(1) -
              _itemDot) /
          2,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (notes.intro.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: introWidth),
            child: Text(notes.intro, style: introStyle),
          ),
        for (int index = 0; index < notes.groups.length; index++) ...<Widget>[
          SizedBox(
            height: index == 0
                ? (notes.intro.isEmpty ? 0 : _introGap)
                : _groupGap,
          ),
          Text(notes.groups[index].title, style: groupStyle),
          const SizedBox(height: _groupTitleGap),
          for (final String item in notes.groups[index].items)
            Padding(
              padding: const EdgeInsets.only(bottom: _itemGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: dotTop),
                    child: const SizedBox.square(
                      dimension: _itemDot,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Palette.coral,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _itemDotGap),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: itemWidth),
                      child: Text(item, style: itemStyle),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.footing});

  final _Footing footing;

  @override
  Widget build(BuildContext context) {
    final double? fraction = footing.fraction;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            footing.note,
            key: updateNotesNoteKey,
            style: context.textStyles.captionSans.copyWith(
              fontSize: _footerNoteSize,
              color: context.colors.muted,
            ),
          ),
          if (footing.downloading) ...<Widget>[
            const SizedBox(height: _noteProgressGap),
            UpdateProgressBar(key: updateNotesProgressKey, fraction: fraction),
          ],
        ],
      ),
    );
  }
}

class _DesktopFooter extends StatelessWidget {
  const _DesktopFooter({
    required this.footing,
    required this.onLater,
    required this.onAct,
  });

  final _Footing footing;
  final VoidCallback? onLater;
  final VoidCallback? onAct;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final InstallRoute? route = footing.route;
    return ColoredBox(
      key: updateNotesFooterKey,
      color: colors.panelTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DashedDivider(thickness: _footerRuleThickness, color: colors.ink22),
          Padding(
            padding: _desktopFooterPadding,
            child: Row(
              children: <Widget>[
                Expanded(child: _FooterNote(footing: footing)),
                const SizedBox(width: _footerButtonGap),
                StickerButton(
                  key: updateNotesLaterKey,
                  label: laterLabel,
                  variant: StickerButtonVariant.secondary,
                  onPressed: onLater,
                ),
                const SizedBox(width: _footerButtonGap),
                StickerButton(
                  key: updateNotesActionKey,
                  label: route == null ? '' : routeAction(route),
                  onPressed: onAct,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(updateNotesCloseSize / 2),
    );
    return Tooltip(
      message: closeTooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: closeLabel,
        excludeSemantics: true,
        onTap: onPressed,
        child: GestureDetector(
          key: updateNotesCloseKey,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPressed,
          child: FocusRing(
            enabled: enabled,
            onPressed: onPressed,
            includeFocusSemantics: false,
            borderRadius: radius,
            child: SizedBox.square(
              dimension: updateNotesCloseSize,
              child: Opacity(
                opacity: enabled ? 1 : 0.5,
                child: Icon(
                  Icons.close_rounded,
                  size: _closeIcon,
                  color: context.colors.mutedDeep,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    super.key,
    required this.label,
    required this.height,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final double height;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final bool enabled = onPressed != null;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(_phoneButtonRadius),
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
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary ? Palette.coral : colors.cardBright,
                border: Border.all(
                  color: colors.line,
                  width: Shapes.outlineWidth,
                ),
                borderRadius: radius,
                boxShadow: primary ? shadows.emphasis : null,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.buttonSans.copyWith(
                  fontSize: _phoneButtonLabel,
                  color: primary ? Palette.onAccent : colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
