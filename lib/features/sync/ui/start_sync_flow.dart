import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recovery_phrase_check.dart';

const String startSyncTitle = 'Start syncing';
const String startSyncMessage =
    "Enter your server's address and the invite code you were given.";
const String serverAddressLabel = 'Server address';
const String serverAddressHint = 'https://sync.example.com';
const String inviteCodeLabel = 'Invite code';
const String syncCancelLabel = 'Cancel';
const String syncContinueLabel = 'Continue';
const String recoveryPhraseTitle = 'Your recovery phrase';
const String recoveryPhraseMessage =
    "Write these 12 words down and keep them somewhere safe. If you ever lose "
    "every device, they're the only way back into your journal. Nobody, "
    'including your server, can recover them for you.';
const String writtenDownLabel = "I've written them down";

const String backgroundUploadsTitle = 'Let uploads finish in the background';
const String backgroundUploadsMessage =
    "Your phone may pause apps it thinks you're not using. Set Field Notes' "
    'battery to Unrestricted so videos keep uploading after you close the app.';
const String notNowLabel = 'Not now';
const String openBatterySettingsLabel = 'Open battery settings';

const Key startSyncContinueKey = ValueKey<String>('start-sync-continue');
const Key writtenDownKey = ValueKey<String>('start-sync-written-down');

Key recoveryWordKey(int position) =>
    ValueKey<String>('recovery-word-$position');

const double _flowMaxWidth = 460;
const double _flowGap = 16;
const double _labelGap = 6;
const int _wordColumnsWide = 3;
const int _wordColumnsPhone = 2;
const double _wordGap = 8;
const double _flowButtonHeight = 48;
const double _flowButtonBorderWidth = 1.5;
const EdgeInsets _sheetBodyPadding = EdgeInsets.fromLTRB(20, 10, 20, 4);
const EdgeInsets _sheetFooterPadding = EdgeInsets.fromLTRB(12, 14, 12, 12);
const EdgeInsets _wordPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 8,
);
const BorderRadius _flowButtonRadius = BorderRadius.all(Radius.circular(14));
const TextStyle _flowButtonStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

bool syncFlowUsesSheet(BuildContext context) =>
    resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

bool syncFlowOnAndroid(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.android;

TextStyle syncFlowHintStyle(BuildContext context) =>
    context.textStyles.captionSans.copyWith(color: context.colors.muted);

Uri? parseServerAddress(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final Uri? parsed = Uri.tryParse(
    trimmed.contains('://') ? trimmed : 'https://$trimmed',
  );
  if (parsed == null || parsed.host.isEmpty) {
    return null;
  }
  return parsed;
}

Future<T?> showSyncFlow<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (syncFlowUsesSheet(context)) {
    return showPhoneSheet<T>(context, builder: builder);
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Palette.toolbarInk.withValues(alpha: 0.42),
    builder: (BuildContext dialogContext) =>
        DialogHost(child: Builder(builder: builder)),
  );
}

Future<void> startSync(BuildContext context, WidgetRef ref) async {
  final bool? started = await showSyncFlow<bool>(
    context,
    builder: (BuildContext flowContext) => const StartSyncFlow(),
  );
  if (started == true && context.mounted) {
    await afterSyncTurnedOn(context, ref);
  }
}

Future<void> afterSyncTurnedOn(BuildContext context, WidgetRef ref) async {
  if (!syncFlowOnAndroid(context)) {
    return;
  }
  await ref
      .read(reminderPermissionStatusProvider.notifier)
      .requestUnlessGranted();
  if (!context.mounted) {
    return;
  }
  final bool exempt;
  try {
    exempt = await ref.read(batterySettingsProvider).isExempt();
  } on Exception catch (error) {
    debugPrint('Battery state check failed: $error');
    return;
  }
  if (exempt || !context.mounted) {
    return;
  }
  await showBackgroundUploadsSheet(context, ref);
}

Future<void> showBackgroundUploadsSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final bool? open = await showSyncFlow<bool>(
    context,
    builder: (BuildContext sheetContext) => const BackgroundUploadsSheet(),
  );
  if (open == true) {
    await openBatterySettings(ref);
  }
}

Future<void> openBatterySettings(WidgetRef ref) async {
  try {
    await ref.read(batterySettingsProvider).open();
  } on Exception catch (error) {
    debugPrint('Battery settings failed to open: $error');
  }
  ref.invalidate(batteryExemptProvider);
}

class SyncFlowAction {
  const SyncFlowAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.danger = false,
    this.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;
  final Key? key;
}

class SyncFlowFrame extends StatelessWidget {
  const SyncFlowFrame({
    super.key,
    required this.title,
    this.message,
    this.content = const <Widget>[],
    required this.actions,
  });

  final String title;
  final String? message;
  final List<Widget> content;
  final List<SyncFlowAction> actions;

  @override
  Widget build(BuildContext context) {
    final bool sheet = syncFlowUsesSheet(context);
    final FieldNotesTextStyles textStyles = context.textStyles;
    final String? message = this.message;
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            style: sheet
                ? textStyles.headlineSerif.copyWith(fontSize: 20)
                : textStyles.titleSerif,
          ),
        ),
        if (message != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            message,
            style: textStyles.bodySans.copyWith(
              color: context.colors.mutedDeep,
            ),
          ),
        ],
        for (final Widget child in content) ...<Widget>[
          const SizedBox(height: _flowGap),
          child,
        ],
      ],
    );
    if (sheet) {
      return PhoneSheet(
        footerDirection: Axis.vertical,
        footerPadding: _sheetFooterPadding,
        actions: <Widget>[
          for (final SyncFlowAction action in actions.reversed)
            SyncFlowButton(action: action),
        ],
        child: Padding(padding: _sheetBodyPadding, child: body),
      );
    }
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _flowMaxWidth),
          child: SingleChildScrollView(
            child: StickerCard(
              surface: context.colors.cardBright,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  body,
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (final SyncFlowAction action in actions)
                        StickerButton(
                          key: action.key,
                          label: action.label,
                          variant: action.danger
                              ? StickerButtonVariant.danger
                              : action.primary
                              ? StickerButtonVariant.primary
                              : StickerButtonVariant.secondary,
                          padTapTarget: true,
                          onPressed: action.onPressed,
                        ),
                    ],
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

class SyncFlowButton extends StatelessWidget {
  const SyncFlowButton({super.key, required this.action});

  final SyncFlowAction action;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final VoidCallback? onPressed = action.onPressed;
    final bool emphasis = action.primary || action.danger;
    final Color background = action.danger
        ? Palette.danger
        : action.primary
        ? Palette.coral
        : colors.cardLight;
    return Semantics(
      key: action.key,
      button: true,
      enabled: onPressed != null,
      label: action.label,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: onPressed == null,
          onTap: onPressed,
          child: SizedBox(
            height: _flowButtonHeight,
            child: FocusRing(
              enabled: onPressed != null,
              onPressed: onPressed,
              borderRadius: _flowButtonRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(
                    color: colors.line,
                    width: _flowButtonBorderWidth,
                  ),
                  borderRadius: _flowButtonRadius,
                  boxShadow: emphasis ? context.shadows.emphasis : null,
                ),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _flowButtonStyle.copyWith(
                        color: emphasis ? Palette.onAccent : colors.ink,
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

class SyncFlowField extends StatelessWidget {
  const SyncFlowField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(label, style: context.textStyles.labelSans),
        ),
        const SizedBox(height: _labelGap),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _flowButtonHeight),
          child: SettingsTextField(
            controller: controller,
            hintText: hintText,
            keyboardType: keyboardType,
            enabled: enabled,
            onChanged: onChanged,
            semanticLabel: label,
          ),
        ),
      ],
    );
  }
}

class SyncFlowError extends StatelessWidget {
  const SyncFlowError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: context.textStyles.bodySans.copyWith(
          color: context.colors.dangerInk,
        ),
      ),
    );
  }
}

enum _StartStage { address, phrase, check }

class StartSyncFlow extends ConsumerStatefulWidget {
  const StartSyncFlow({super.key});

  @override
  ConsumerState<StartSyncFlow> createState() => _StartSyncFlowState();
}

class _StartSyncFlowState extends ConsumerState<StartSyncFlow> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _invite = TextEditingController();
  _StartStage _stage = _StartStage.address;
  PendingEnrolment? _pending;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) {
      return;
    }
    final Uri? address = parseServerAddress(_address.text);
    if (address == null) {
      setState(() => _error = unreachableMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PendingEnrolment pending = await ref
          .read(enrolmentServiceProvider)
          .start(relayUrl: address, inviteCode: _invite.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _pending = pending;
        _stage = _StartStage.phrase;
      });
    } on SyncSetupException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _close(bool started) => Navigator.of(context).pop(started);

  @override
  Widget build(BuildContext context) {
    final PendingEnrolment? pending = _pending;
    return PopScope<bool>(
      canPop: _stage == _StartStage.address,
      child: switch (_stage) {
        _StartStage.address => _addressStage(),
        _StartStage.phrase when pending != null => _phraseStage(pending),
        _StartStage.check when pending != null => RecoveryPhraseCheck(
          enrolment: pending,
          onBack: () => setState(() => _stage = _StartStage.phrase),
          onConfirmed: () => _close(true),
        ),
        _ => _addressStage(),
      },
    );
  }

  Widget _addressStage() {
    final String? error = _error;
    return SyncFlowFrame(
      title: startSyncTitle,
      message: startSyncMessage,
      content: <Widget>[
        SyncFlowField(
          label: serverAddressLabel,
          controller: _address,
          hintText: serverAddressHint,
          keyboardType: TextInputType.url,
          enabled: !_busy,
        ),
        SyncFlowField(
          label: inviteCodeLabel,
          controller: _invite,
          enabled: !_busy,
        ),
        if (error != null) SyncFlowError(message: error),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(
          label: syncCancelLabel,
          onPressed: _busy ? null : () => _close(false),
        ),
        SyncFlowAction(
          key: startSyncContinueKey,
          label: syncContinueLabel,
          primary: true,
          onPressed: _busy ? null : _continue,
        ),
      ],
    );
  }

  Widget _phraseStage(PendingEnrolment pending) {
    return SyncFlowFrame(
      title: recoveryPhraseTitle,
      message: recoveryPhraseMessage,
      content: <Widget>[RecoveryWordGrid(words: pending.words)],
      actions: <SyncFlowAction>[
        SyncFlowAction(
          key: writtenDownKey,
          label: writtenDownLabel,
          primary: true,
          onPressed: () => setState(() => _stage = _StartStage.check),
        ),
      ],
    );
  }
}

class RecoveryWordGrid extends StatelessWidget {
  const RecoveryWordGrid({super.key, required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final int columns = syncFlowUsesSheet(context)
        ? _wordColumnsPhone
        : _wordColumnsWide;
    final int rows = (words.length / columns).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int row = 0; row < rows; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: _wordGap),
          Row(
            children: <Widget>[
              for (int column = 0; column < columns; column++) ...<Widget>[
                if (column > 0) const SizedBox(width: _wordGap),
                Expanded(
                  child: row * columns + column < words.length
                      ? _RecoveryWord(
                          position: row * columns + column + 1,
                          word: words[row * columns + column],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _RecoveryWord extends StatelessWidget {
  const _RecoveryWord({required this.position, required this.word});

  final int position;
  final String word;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardLight,
          border: Border.all(color: colors.line, width: Shapes.outlineWidth),
          borderRadius: Shapes.buttonBorderRadius,
        ),
        child: Padding(
          padding: _wordPadding,
          child: Row(
            children: <Widget>[
              Text(
                '$position',
                style: context.textStyles.captionSans.copyWith(
                  color: colors.muted,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  word,
                  key: recoveryWordKey(position),
                  style: context.textStyles.bodySans,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackgroundUploadsSheet extends StatelessWidget {
  const BackgroundUploadsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncFlowFrame(
      title: backgroundUploadsTitle,
      message: backgroundUploadsMessage,
      actions: <SyncFlowAction>[
        SyncFlowAction(
          label: notNowLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SyncFlowAction(
          label: openBatterySettingsLabel,
          primary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
