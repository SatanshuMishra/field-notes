import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'start_sync_flow.dart';

const String joinTitle = 'Join my journal';
const String joinScanMessage =
    'Point the camera at the code on your other device.';
const String typeWordsInsteadLabel = 'Type the 8 words instead';
const String joinWordsLabel = 'The 8 words';
const String joinLabel = 'Join';
const String joinBackLabel = 'Back';
const String joinWaitingTitle = 'Waiting for your other device';
const String joinWaitingMessage =
    'Choose "Add" on your other device to finish joining.';
const String joinCameraLabel = 'Camera view for scanning the code';

const Key joinConfirmKey = ValueKey<String>('join-confirm');
const Key typeWordsInsteadKey = ValueKey<String>('join-type-words');

const double _cameraHeight = 240;
const BorderRadius _cameraRadius = BorderRadius.all(Radius.circular(14));

Future<void> joinJournal(BuildContext context, WidgetRef ref) async {
  final bool? joined = await showSyncFlow<bool>(
    context,
    builder: (BuildContext flowContext) => const JoinJournalFlow(),
  );
  if (joined == true && context.mounted) {
    await afterSyncTurnedOn(context, ref);
  }
}

enum _JoinStage { scan, type, waiting }

class JoinJournalFlow extends ConsumerStatefulWidget {
  const JoinJournalFlow({super.key});

  @override
  ConsumerState<JoinJournalFlow> createState() => _JoinJournalFlowState();
}

class _JoinJournalFlowState extends ConsumerState<JoinJournalFlow> {
  final TextEditingController _words = TextEditingController();
  final TextEditingController _address = TextEditingController();
  _JoinStage _stage = _JoinStage.scan;
  _JoinStage _returnTo = _JoinStage.scan;
  String? _error;

  @override
  void dispose() {
    _words.dispose();
    _address.dispose();
    super.dispose();
  }

  void _scanned(BarcodeCapture capture) {
    if (_stage != _JoinStage.scan) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String? value = barcode.rawValue;
      if (value != null &&
          value.trim().toLowerCase().startsWith('$pairingScheme:')) {
        _join(value, null);
        return;
      }
    }
  }

  void _joinTyped() {
    final String address = _address.text.trim();
    final Uri? relayUrl = address.isEmpty ? null : parseServerAddress(address);
    if (address.isNotEmpty && relayUrl == null) {
      setState(() => _error = unreachableMessage);
      return;
    }
    _join(_words.text, relayUrl);
  }

  Future<void> _join(String code, Uri? relayUrl) async {
    setState(() {
      _returnTo = _stage;
      _stage = _JoinStage.waiting;
      _error = null;
    });
    try {
      await ref.read(pairingServiceProvider).join(code, relayUrl: relayUrl);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on SyncSetupException catch (error) {
      if (mounted) {
        setState(() {
          _stage = _returnTo;
          _error = error.message;
        });
      }
    }
  }

  void _cancel() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _JoinStage.scan => _scanStage(),
      _JoinStage.type => _typeStage(),
      _JoinStage.waiting => _waitingStage(),
    };
  }

  Widget _scanStage() {
    final String? error = _error;
    return SyncFlowFrame(
      title: joinTitle,
      message: joinScanMessage,
      content: <Widget>[
        Semantics(
          label: joinCameraLabel,
          image: true,
          child: ClipRRect(
            borderRadius: _cameraRadius,
            child: SizedBox(
              height: _cameraHeight,
              child: ColoredBox(
                color: context.colors.panelTop,
                child: MobileScanner(
                  onDetect: _scanned,
                  errorBuilder: (
                    BuildContext context,
                    MobileScannerException _,
                  ) => const CrossHatchPlaceholder(),
                ),
              ),
            ),
          ),
        ),
        if (error != null) SyncFlowError(message: error),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(label: syncCancelLabel, onPressed: _cancel),
        SyncFlowAction(
          key: typeWordsInsteadKey,
          label: typeWordsInsteadLabel,
          primary: true,
          onPressed: () => setState(() {
            _stage = _JoinStage.type;
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _typeStage() {
    final String? error = _error;
    return SyncFlowFrame(
      title: joinTitle,
      content: <Widget>[
        SyncFlowField(label: joinWordsLabel, controller: _words),
        SyncFlowField(
          label: serverAddressLabel,
          controller: _address,
          hintText: serverAddressHint,
          keyboardType: TextInputType.url,
        ),
        if (error != null) SyncFlowError(message: error),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(
          label: joinBackLabel,
          onPressed: () => setState(() {
            _stage = _JoinStage.scan;
            _error = null;
          }),
        ),
        SyncFlowAction(
          key: joinConfirmKey,
          label: joinLabel,
          primary: true,
          onPressed: _joinTyped,
        ),
      ],
    );
  }

  Widget _waitingStage() {
    return SyncFlowFrame(
      title: joinWaitingTitle,
      message: joinWaitingMessage,
      content: const <Widget>[
        Center(child: CrossHatchPlaceholder(width: 28, height: 28)),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(label: syncCancelLabel, onPressed: _cancel),
      ],
    );
  }
}
