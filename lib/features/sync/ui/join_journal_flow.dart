import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

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
const String joinDeclineLabel = "Don't join";

const Key joinConfirmKey = ValueKey<String>('join-confirm');
const Key typeWordsInsteadKey = ValueKey<String>('join-type-words');
const Key joinServerConfirmKey = ValueKey<String>('join-server-confirm');

String joinServerTitle(Uri server) => 'Join ${server.host}?';

String joinServerMessage({required bool phone}) =>
    'Everything on this ${phone ? 'phone' : 'device'} will be added to the '
    'journal on this server. Only join a server you set up.';

String shownServerAddress(Uri server) => Uri(
  scheme: server.scheme,
  host: server.host,
  port: server.hasPort ? server.port : null,
  path: server.path,
).toString();

const double _cameraHeight = 240;
const double _labelGap = 6;
const double _scanArea = 0.9;
const Duration _scanPause = Duration(milliseconds: 100);

typedef PairingJoin = Future<void> Function(String code, {Uri? relayUrl});

bool get joinCanScan => defaultTargetPlatform == TargetPlatform.android;

String? pairingCodeIn(Iterable<String?> values) {
  for (final String? value in values) {
    if (value != null &&
        value.trim().toLowerCase().startsWith('$pairingScheme:')) {
      return value;
    }
  }
  return null;
}

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

enum _JoinStage { scan, type, confirm, waiting }

class JoinJournalFlow extends ConsumerStatefulWidget {
  const JoinJournalFlow({super.key, this.join});

  final PairingJoin? join;

  @override
  ConsumerState<JoinJournalFlow> createState() => _JoinJournalFlowState();
}

class _JoinJournalFlowState extends ConsumerState<JoinJournalFlow> {
  final TextEditingController _words = TextEditingController();
  final TextEditingController _address = TextEditingController();
  late _JoinStage _stage = joinCanScan ? _JoinStage.scan : _JoinStage.type;
  late _JoinStage _returnTo = _stage;
  String? _error;
  String? _refusedCode;
  String? _offeredCode;
  Uri? _offeredServer;
  bool _closing = false;

  @override
  void dispose() {
    _words.dispose();
    _address.dispose();
    super.dispose();
  }

  void _scanned(Code code) {
    if (!mounted || _closing || _stage != _JoinStage.scan) {
      return;
    }
    final String? value = pairingCodeIn(<String?>[code.text]);
    if (value != null && value != _refusedCode) {
      _offer(value);
    }
  }

  void _offer(String code) {
    final Uri? server = _serverIn(code);
    if (server == null) {
      setState(() {
        _error = pairingRetryMessage;
        _refusedCode = _stage == _JoinStage.scan ? code : null;
      });
      return;
    }
    setState(() {
      _returnTo = _stage;
      _stage = _JoinStage.confirm;
      _error = null;
      _offeredCode = code;
      _offeredServer = server;
    });
  }

  static Uri? _serverIn(String code) {
    try {
      return PairingCode.parse(code).relayUrl;
    } on PairingCodeException {
      return null;
    }
  }

  void _decline() => setState(() {
    _stage = _returnTo;
    _error = null;
    _refusedCode = _returnTo == _JoinStage.scan ? _offeredCode : null;
  });

  void _showStage(_JoinStage stage) => setState(() {
    _stage = stage;
    _error = null;
    _refusedCode = null;
  });

  void _joinTyped() {
    final String? pasted = pairingCodeIn(<String?>[_words.text]);
    if (pasted != null) {
      _offer(pasted);
      return;
    }
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
      if (_stage != _JoinStage.confirm) {
        _returnTo = _stage;
      }
      _stage = _JoinStage.waiting;
      _error = null;
    });
    final PairingJoin join =
        widget.join ?? ref.read(pairingServiceProvider).join;
    try {
      await join(code, relayUrl: relayUrl);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on SyncSetupException catch (error) {
      if (mounted) {
        setState(() {
          _stage = _returnTo;
          _error = error.message;
          _refusedCode = _returnTo == _JoinStage.scan ? code : null;
        });
      }
    }
  }

  void _cancel() {
    _closing = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _JoinStage.scan => _scanStage(),
      _JoinStage.type => _typeStage(),
      _JoinStage.confirm => _confirmStage(),
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
                child: ReaderWidget(
                  onScan: _scanned,
                  codeFormat: Format.qrCode,
                  tryHarder: true,
                  cropPercent: _scanArea,
                  scanDelay: _scanPause,
                  showScannerOverlay: false,
                  showFlashlight: false,
                  showToggleCamera: false,
                  showGallery: false,
                  allowPinchZoom: false,
                  loading: const CrossHatchPlaceholder(),
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
          onPressed: () => _showStage(_JoinStage.type),
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
        if (joinCanScan)
          SyncFlowAction(
            label: joinBackLabel,
            onPressed: () => _showStage(_JoinStage.scan),
          )
        else
          SyncFlowAction(label: syncCancelLabel, onPressed: _cancel),
        SyncFlowAction(
          key: joinConfirmKey,
          label: joinLabel,
          primary: true,
          onPressed: _joinTyped,
        ),
      ],
    );
  }

  Widget _confirmStage() {
    final Uri server = _offeredServer!;
    final String code = _offeredCode!;
    return SyncFlowFrame(
      title: joinServerTitle(server),
      message: joinServerMessage(phone: syncFlowOnAndroid(context)),
      content: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(serverAddressLabel, style: context.textStyles.labelSans),
            const SizedBox(height: _labelGap),
            Text(
              shownServerAddress(server),
              style: context.textStyles.bodySans,
            ),
          ],
        ),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(label: joinDeclineLabel, onPressed: _decline),
        SyncFlowAction(
          key: joinServerConfirmKey,
          label: joinLabel,
          primary: true,
          onPressed: () => _join(code, null),
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
