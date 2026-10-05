import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/data/sync/erase/device_unlink_service.dart';
import 'package:field_notes/data/sync/erase/journal_erase_service.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _deleteAllTitle = 'Delete everything?';
const String _deleteAllMessage =
    'This erases every entry, photo, and mood on this device. '
    'It cannot be undone.';
const String _keepLabel = 'Keep my journal';
const String _deleteLabel = 'Delete everything';

const String syncDeleteTitle = 'Delete your journal';
const String removeFromThisDeviceLabel = 'Remove from this device';
const String removeFromThisDeviceMessage =
    'Erases the journal, keys and media here. Your other devices and your '
    'server keep everything.';
const String deleteJournalEverywhereLabel = 'Delete journal everywhere';
const String deleteJournalEverywhereMessage =
    "Erases it from your server and from every device the next time they "
    "connect. This can't be undone.";
const String deleteEverywhereConfirmLabel =
    'Type "delete" to confirm deleting everywhere';
const String deleteEverywhereLabel = 'Delete everywhere';
const String deleteEverywhereWord = 'delete';

const Key removeFromThisDeviceKey = ValueKey<String>('sync-delete-remove');
const Key deleteEverywhereKey = ValueKey<String>('sync-delete-everywhere');

Future<bool> _syncOn(BuildContext context) async {
  final ProviderContainer? container = context
      .findAncestorWidgetOfExactType<UncontrolledProviderScope>()
      ?.container;
  if (container == null) {
    return false;
  }
  final ProviderSubscription<Future<bool>> enabled = container
      .listen<Future<bool>>(
        syncEnabledProvider.future,
        (Future<bool>? _, Future<bool> next) {},
      );
  try {
    return await enabled.read();
  } finally {
    enabled.close();
  }
}

Future<bool> confirmDeleteAll(BuildContext context) async {
  final bool syncOn = await _syncOn(context);
  if (!context.mounted) {
    return false;
  }
  if (syncOn) {
    await showSyncDeleteAll(context);
    return false;
  }
  if (resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar) {
    return showConfirmDialog(
      context,
      title: _deleteAllTitle,
      message: _deleteAllMessage,
      confirmLabel: _deleteLabel,
      cancelLabel: _keepLabel,
      danger: true,
    );
  }
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => const DeleteAllConfirmDialog(),
  );
  return confirmed ?? false;
}

Future<void> showSyncDeleteAll(BuildContext context) => showSyncFlow<void>(
  context,
  builder: (BuildContext dialogContext) => const SyncDeleteAllDialog(),
);

class DeleteAllConfirmDialog extends StatelessWidget {
  const DeleteAllConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StickerCard(
            surface: context.colors.cardBright,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_deleteAllTitle, style: textStyles.titleSerif),
                const SizedBox(height: 8),
                Text(_deleteAllMessage, style: textStyles.bodySans),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    StickerButton(
                      label: _keepLabel,
                      variant: StickerButtonVariant.secondary,
                      padTapTarget: true,
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      label: _deleteLabel,
                      variant: StickerButtonVariant.danger,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SyncDeleteAllDialog extends ConsumerStatefulWidget {
  const SyncDeleteAllDialog({super.key});

  @override
  ConsumerState<SyncDeleteAllDialog> createState() =>
      _SyncDeleteAllDialogState();
}

class _SyncDeleteAllDialogState extends ConsumerState<SyncDeleteAllDialog> {
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _typedDelete =>
      _confirm.text.trim().toLowerCase() == deleteEverywhereWord;

  Future<void> _removeHere() => _run(() async {
    final DeviceUnlinkService unlink = await ref.read(
      deviceUnlinkServiceProvider.future,
    );
    try {
      await unlink.removeThisDevice();
      return null;
    } on DeviceUnlinkException catch (error) {
      return error.message;
    }
  });

  Future<void> _deleteEverywhere() => _run(() async {
    final JournalEraseService erase = await ref.read(
      journalEraseServiceProvider.future,
    );
    try {
      await erase.eraseEverywhere();
      return null;
    } on JournalEraseException catch (error) {
      return error.message;
    }
  });

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? failure = await action();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    return PopScope<void>(
      canPop: !_busy,
      child: SyncFlowFrame(
        title: syncDeleteTitle,
        content: <Widget>[
          _SyncDeleteChoice(
            title: removeFromThisDeviceLabel,
            message: removeFromThisDeviceMessage,
          ),
          _SyncDeleteChoice(
            title: deleteJournalEverywhereLabel,
            message: deleteJournalEverywhereMessage,
          ),
          SyncFlowField(
            label: deleteEverywhereConfirmLabel,
            controller: _confirm,
            enabled: !_busy,
            onChanged: (String _) => setState(() => _error = null),
          ),
          if (error != null) SyncFlowError(message: error),
        ],
        actions: <SyncFlowAction>[
          SyncFlowAction(
            label: syncCancelLabel,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          SyncFlowAction(
            key: removeFromThisDeviceKey,
            label: removeFromThisDeviceLabel,
            onPressed: _busy ? null : _removeHere,
          ),
          SyncFlowAction(
            key: deleteEverywhereKey,
            label: deleteEverywhereLabel,
            danger: true,
            onPressed: _busy || !_typedDelete ? null : _deleteEverywhere,
          ),
        ],
      ),
    );
  }
}

class _SyncDeleteChoice extends StatelessWidget {
  const _SyncDeleteChoice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: context.textStyles.labelSans),
          const SizedBox(height: 2),
          Text(message, style: syncFlowHintStyle(context)),
        ],
      ),
    );
  }
}
