import 'dart:async';

import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pairing_qr.dart';
import 'start_sync_flow.dart';

const String addDeviceTitle = 'Add a device';
const String addDeviceMessage =
    'On your other device, open Field Notes and choose "Join my journal", '
    'then scan this code.';
const String typeTheseWordsLabel = 'Or type these 8 words:';
const String addDeviceDoneLabel = 'Done';
const String addDeviceMessageForCandidate =
    'It will be able to read and change your whole journal. Only add a device '
    'you recognise.';
const String dontAddLabel = "Don't add";
const String addLabel = 'Add';
const String pairingWordSeparator = ' · ';

const Key addDeviceConfirmKey = ValueKey<String>('add-device-confirm');

String worksForLabel(Duration remaining) {
  final int seconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final String clock =
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  return 'Works for $clock more';
}

Future<void> showAddDeviceSheet(BuildContext context) => showSyncFlow<void>(
  context,
  builder: (BuildContext sheetContext) => const AddDeviceSheet(),
);

class AddDeviceSheet extends ConsumerStatefulWidget {
  const AddDeviceSheet({super.key, this.clock = _utcNow});

  final DateTime Function() clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  ConsumerState<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<AddDeviceSheet> {
  HostedPairing? _hosted;
  PairingCandidate? _candidate;
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  String? _error;
  bool _adding = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _closed = true;
    _ticker?.cancel();
    _hosted?.close();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final HostedPairing hosted = await ref
          .read(pairingServiceProvider)
          .open();
      if (_closed) {
        hosted.close();
        return;
      }
      setState(() {
        _hosted = hosted;
        _remaining = hosted.expiresAt.difference(widget.clock());
      });
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (Timer _) => _tick(),
      );
      unawaited(_awaitJoin(hosted));
    } on SyncSetupException catch (error) {
      if (!_closed) {
        setState(() => _error = error.message);
      }
    }
  }

  void _tick() {
    final HostedPairing? hosted = _hosted;
    if (hosted == null || _closed) {
      return;
    }
    final Duration remaining = hosted.expiresAt.difference(widget.clock());
    setState(() {
      _remaining = remaining;
      if (remaining <= Duration.zero && _candidate == null) {
        _error = pairingExpiredMessage;
      }
    });
    if (remaining <= Duration.zero) {
      _ticker?.cancel();
    }
  }

  Future<void> _awaitJoin(HostedPairing hosted) async {
    try {
      final PairingCandidate candidate = await hosted.waitForJoin();
      if (!_closed) {
        setState(() => _candidate = candidate);
      }
    } on SyncSetupException catch (error) {
      if (!_closed) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<void> _add(PairingCandidate candidate) async {
    final HostedPairing? hosted = _hosted;
    if (hosted == null || _adding) {
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await hosted.confirm(candidate);
      ref.invalidate(journalDevicesProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on SyncSetupException catch (error) {
      if (mounted) {
        setState(() {
          _adding = false;
          _error = error.message;
        });
      }
    }
  }

  void _done() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final PairingCandidate? candidate = _candidate;
    if (candidate != null) {
      return _candidateStage(candidate);
    }
    return _codeStage();
  }

  Widget _codeStage() {
    final HostedPairing? hosted = _hosted;
    final String? error = _error;
    final bool live = hosted != null && _remaining > Duration.zero;
    return SyncFlowFrame(
      title: addDeviceTitle,
      message: addDeviceMessage,
      content: <Widget>[
        if (hosted == null && error == null)
          const Center(child: CrossHatchPlaceholder(width: 28, height: 28)),
        if (hosted != null && live) ...<Widget>[
          Center(child: PairingQr(payload: hosted.code.qrPayload)),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(typeTheseWordsLabel, style: context.textStyles.labelSans),
              const SizedBox(height: 6),
              Text(
                hosted.code.words.join(pairingWordSeparator),
                style: context.textStyles.bodySans,
              ),
            ],
          ),
          Text(worksForLabel(_remaining), style: syncFlowHintStyle(context)),
        ],
        if (error != null) SyncFlowError(message: error),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(
          label: addDeviceDoneLabel,
          primary: true,
          onPressed: _done,
        ),
      ],
    );
  }

  Widget _candidateStage(PairingCandidate candidate) {
    final String? error = _error;
    return SyncFlowFrame(
      title: candidate.prompt,
      message: addDeviceMessageForCandidate,
      content: <Widget>[if (error != null) SyncFlowError(message: error)],
      actions: <SyncFlowAction>[
        SyncFlowAction(label: dontAddLabel, onPressed: _adding ? null : _done),
        SyncFlowAction(
          key: addDeviceConfirmKey,
          label: addLabel,
          primary: true,
          onPressed: _adding ? null : () => _add(candidate),
        ),
      ],
    );
  }
}
