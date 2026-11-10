import 'package:flutter/material.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/immersive/let_go_panel.dart';

const String composerDiscardTitle = letGoTitle;
const String composerDiscardMessage = letGoMessage;
const String composerKeepEditingLabel = letGoKeepGoingLabel;
const String composerDiscardLabel = letGoConfirmLabel;
const String editDiscardTitle = 'Discard your edits?';
const String editDiscardMessage = 'Your note stays as it was.';
const String editKeepEditingLabel = 'Keep editing';
const String editDiscardLabel = 'Discard edits';
const Key composerKeepEditingKey = ValueKey<String>('composer-keep-editing');
const Key composerDiscardKey = ValueKey<String>('composer-discard');

typedef ComposerGuardBuilder = Widget Function(
  BuildContext context,
  VoidCallback requestClose,
);

Future<bool> _askToDiscard(BuildContext context, {required bool editing}) {
  return showConfirmDialog(
    context,
    title: editing ? editDiscardTitle : composerDiscardTitle,
    message: editing ? editDiscardMessage : composerDiscardMessage,
    confirmLabel: editing ? editDiscardLabel : composerDiscardLabel,
    cancelLabel: editing ? editKeepEditingLabel : composerKeepEditingLabel,
    danger: true,
    confirmKey: composerDiscardKey,
    cancelKey: composerKeepEditingKey,
  );
}

Future<bool> confirmDiscardRestoredDraft(BuildContext context) {
  final _ComposerGuardState? guard = context
      .findAncestorStateOfType<_ComposerGuardState>();
  return guard == null
      ? _askToDiscard(context, editing: false)
      : guard._confirmDiscardRestoredDraft();
}

class ComposerGuard extends StatefulWidget {
  const ComposerGuard({
    super.key,
    required this.isDirty,
    required this.onDiscard,
    required this.builder,
    this.popResult,
    this.locked = false,
    this.onClose,
  });

  final ValueGetter<bool> isDirty;
  final Future<void> Function() onDiscard;
  final ComposerGuardBuilder builder;
  final Object? popResult;
  final bool locked;
  final ValueChanged<Object?>? onClose;

  @override
  State<ComposerGuard> createState() => _ComposerGuardState();
}

class _ComposerGuardState extends State<ComposerGuard> {
  bool _confirming = false;
  FocusNode? _lastFocus;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_trackFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_trackFocus);
    super.dispose();
  }

  void _trackFocus() {
    final FocusNode? focused = FocusManager.instance.primaryFocus;
    final BuildContext? focusedContext = focused?.context;
    if (focusedContext == null || !focusedContext.mounted) {
      return;
    }
    final _ComposerGuardState? owner = focusedContext
        .findAncestorStateOfType<_ComposerGuardState>();
    if (identical(owner, this)) {
      _lastFocus = focused;
    }
  }

  void _resumeEditing() {
    final FocusNode? node = _lastFocus;
    final bool attached = node?.context?.mounted ?? false;
    if (node != null && attached && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  Future<void> _requestClose() async {
    if (widget.locked || _confirming) {
      return;
    }
    if (!widget.isDirty()) {
      await _discardAndPop();
      return;
    }
    if (await _confirmDiscard()) {
      await _discardAndPop();
    }
  }

  bool get _editingSavedNote => widget.popResult == false;

  Future<bool> _confirmDiscard() async {
    _confirming = true;
    final bool discard = await _askToDiscard(
      context,
      editing: _editingSavedNote,
    );
    _confirming = false;
    if (!mounted) {
      return false;
    }
    if (!discard) {
      _resumeEditing();
    }
    return discard;
  }

  Future<bool> _confirmDiscardRestoredDraft() async {
    final bool discard = await _confirmDiscard();
    if (discard) {
      _resumeEditing();
    }
    return discard;
  }

  Future<void> _discardAndPop() async {
    final Future<void> discarding = widget.onDiscard();
    final ValueChanged<Object?>? onClose = widget.onClose;
    if (onClose == null) {
      Navigator.of(context).pop(widget.popResult);
    } else {
      onClose(widget.popResult);
    }
    await discarding;
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    _requestClose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: widget.builder(context, _requestClose),
    );
  }
}
