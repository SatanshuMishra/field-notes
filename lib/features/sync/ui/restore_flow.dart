import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'start_sync_flow.dart';
import 'sync_flow_page.dart';

const String restoreTitle = 'Restore your journal';
const String restoreWordsLabel = 'Your 12 words';
const String restoreHint =
    "Capitals and extra spaces are fine. A word that isn't on the list is "
    'caught before anything is sent.';
const String restoreLabel = 'Restore';

const Key restoreConfirmKey = ValueKey<String>('restore-confirm');

Future<void> restoreJournal(BuildContext context, WidgetRef ref) async {
  final bool? restored = await showSyncFlow<bool>(
    context,
    builder: (BuildContext flowContext) => const RestoreFlow(),
  );
  if (restored == true && context.mounted) {
    await afterSyncTurnedOn(context, ref);
  }
}

class RestoreFlow extends ConsumerStatefulWidget {
  const RestoreFlow({super.key});

  @override
  ConsumerState<RestoreFlow> createState() => _RestoreFlowState();
}

class _RestoreFlowState extends ConsumerState<RestoreFlow> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _words = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _words.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
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
      await ref
          .read(restoreServiceProvider)
          .restore(relayUrl: address, phrase: _words.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
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

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    return PopScope<bool>(
      canPop: !_busy,
      child: SyncTaskFrame(
        title: restoreTitle,
        content: <Widget>[
          SyncFlowField(
            label: serverAddressLabel,
            controller: _address,
            hintText: serverAddressHint,
            keyboardType: TextInputType.url,
            enabled: !_busy,
          ),
          SyncFlowField(
            label: restoreWordsLabel,
            controller: _words,
            enabled: !_busy,
          ),
          Text(restoreHint, style: syncFlowHintStyle(context)),
          if (error != null) SyncFlowError(message: error),
        ],
        actions: <SyncFlowAction>[
          SyncFlowAction(
            label: syncCancelLabel,
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          ),
          SyncFlowAction(
            key: restoreConfirmKey,
            label: restoreLabel,
            primary: true,
            onPressed: _busy ? null : _restore,
          ),
        ],
      ),
    );
  }
}
