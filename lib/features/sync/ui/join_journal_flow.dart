import 'dart:async';

import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'comparison_number.dart';
import 'join_scan_page.dart';
import 'join_window.dart';
import 'mac_code_scanner.dart';
import 'pairing_word_fields.dart';
import 'qr_frame_decoder.dart';
import 'start_sync_flow.dart';
import 'sync_flow_page.dart';

const String joinTitle = 'Join my journal';
const String joinScanKicker = 'join my journal';
const String joinScanMessage =
    'Point the camera at the code on your other device.';
const String typeWordsInsteadLabel = 'Type the 8 words instead';
const String joinTypeTitle = 'Type the 8 words';
const String joinScanTitle = 'Scan the code';
const String joinScanHelp = "Hold your other device up to this Mac's camera.";
const String joinTypeHelp =
    "They're under the code on your other device. Paste all 8 at once if you "
    'like.';
const String joinServerHint =
    'Leave it empty if your other device uses the usual server.';
const String joinOrLabel = 'or';
const String joinAllWordsInLabel = 'All 8 words in';
const String joinLabel = 'Join';
const String joinBackLabel = 'Back';
const String joinWaitingTitle = 'Waiting for your other device';
const String joinWaitingMessage =
    'Check that your other device shows this number, then choose "Add" there.';
const String joinCheckingTitle = 'Checking the code';
const String joinJournalTitle = 'Is this your journal?';
const String joinJournalNameLabel = 'Journal';
const String joinCameraLabel = 'Camera view for scanning the code';
const String joinDeclineLabel = "Don't join";

const Key joinConfirmKey = ValueKey<String>('join-confirm');
const Key typeWordsInsteadKey = ValueKey<String>('join-type-words');
const Key joinServerConfirmKey = ValueKey<String>('join-server-confirm');
const Key joinJournalConfirmKey = ValueKey<String>('join-journal-confirm');
const Key joinScanFrameKey = ValueKey<String>('join-scan-frame');
const Key joinScanColumnKey = ValueKey<String>('join-scan-column');
const Key joinTypeColumnKey = ValueKey<String>('join-type-column');
const Key joinWordsCountKey = ValueKey<String>('join-words-count');

String joinWordsCountLabel(int filled) => filled >= pairingWordCount
    ? joinAllWordsInLabel
    : '$filled of $pairingWordCount';

String joinServerTitle(Uri server) => 'Join ${server.host}?';

String joinServerMessage({required bool phone}) =>
    'Everything on this ${phone ? 'phone' : 'device'} will be added to the '
    'journal on this server. Only join a server you set up.';

String joinJournalMessage({required bool phone}) =>
    'Your server keeps this journal under the name below. Everything on this '
    '${phone ? 'phone' : 'device'} will go into it, so join only if the name '
    'is yours.';

String joinUnnamedJournalMessage({required bool phone}) =>
    "Your server didn't name this journal. Everything on this "
    '${phone ? 'phone' : 'device'} will go into it, so join only if the code '
    'came from your own device.';

String joinAddressMismatchMessage(Uri code, Uri typed) =>
    'That code is for ${code.host}, not ${typed.host}.';

String shownServerAddress(Uri server) => Uri(
  scheme: server.scheme,
  host: server.host,
  port: server.hasPort ? server.port : null,
  path: server.path,
).toString();

const double _labelGap = 6;

typedef PairingJoin = Future<void> Function(
  String code, {
  required JournalConfirmation confirmJournal,
  Uri? relayUrl,
  bool Function() cancelled,
  void Function(String comparison) onComparison,
});

bool get joinCanScan => defaultTargetPlatform == TargetPlatform.android;

bool _relayDeclined(SyncSetupException error) => switch (error) {
  PairingTaken() => true,
  SyncSetupException(cause: RelayRejected(code: final SyncErrorCode code)) =>
    code != SyncErrorCode.tooManyRequests,
  _ => false,
};

String? pairingCodeIn(Iterable<String?> values) {
  for (final String? value in values) {
    if (value != null &&
        value.trim().toLowerCase().startsWith('$pairingScheme:')) {
      return value;
    }
  }
  return null;
}

Future<void> joinJournal(BuildContext context, WidgetRef ref) async {
  final bool? joined = await showSyncFlow<bool>(
    context,
    builder: (BuildContext flowContext) => const JoinJournalFlow(),
  );
  if (joined == true && context.mounted) {
    await afterSyncTurnedOn(context, ref);
  }
}

enum _JoinStage { scan, type, confirm, checking, journal, waiting }

class JoinJournalFlow extends ConsumerStatefulWidget {
  const JoinJournalFlow({super.key, this.join, this.macCamera, this.macDecode});

  final PairingJoin? join;
  final MacScannerCamera? macCamera;
  final QrFrameDecode? macDecode;

  @override
  ConsumerState<JoinJournalFlow> createState() => _JoinJournalFlowState();
}

class _JoinJournalFlowState extends ConsumerState<JoinJournalFlow> {
  final List<TextEditingController> _words =
      List<TextEditingController>.unmodifiable(<TextEditingController>[
        for (int index = 0; index < pairingWordCount; index++)
          TextEditingController(),
      ]);
  final TextEditingController _address = TextEditingController();
  late _JoinStage _stage = joinCanScan ? _JoinStage.scan : _JoinStage.type;
  late _JoinStage _returnTo = _stage;
  String? _error;
  String? _refusedCode;
  String? _offeredCode;
  Uri? _offeredServer;
  bool _offeredScanned = false;
  String? _journalLabel;
  Completer<bool>? _journalAnswer;
  String? _comparison;
  bool _closing = false;

  bool get _joining =>
      _stage == _JoinStage.checking ||
      _stage == _JoinStage.journal ||
      _stage == _JoinStage.waiting;

  bool get _choosing => _stage == _JoinStage.scan || _stage == _JoinStage.type;

  List<String> get _typedWords => <String>[
    for (final TextEditingController word in _words) word.text,
  ];

  bool get _canJoin =>
      filledPairingWords(_words) == _words.length ||
      pairingCodeIn(_typedWords) != null;

  @override
  void dispose() {
    _closing = true;
    _settleJournal(false);
    for (final TextEditingController word in _words) {
      word.dispose();
    }
    _address.dispose();
    super.dispose();
  }

  void _scanned(Code code) =>
      _offerScanned(code.text, scanning: _stage == _JoinStage.scan);

  void _macScanned(String code) => _offerScanned(code, scanning: _choosing);

  void _offerScanned(String? text, {required bool scanning}) {
    if (!mounted || _closing || !scanning) {
      return;
    }
    final String? value = pairingCodeIn(<String?>[text]);
    if (value != null && value != _refusedCode) {
      _offer(value, scanned: true);
    }
  }

  void _offer(String code, {required bool scanned}) {
    final (Uri? server, String refusal) = _readPairing(code);
    if (server == null) {
      setState(() {
        _error = refusal;
        _refusedCode = scanned ? code : _refusedCode;
      });
      return;
    }
    setState(() {
      _returnTo = _stage;
      _stage = _JoinStage.confirm;
      _error = null;
      _offeredCode = code;
      _offeredServer = server;
      _offeredScanned = scanned;
    });
  }

  static Uri? _serverIn(String code) => _readPairing(code).$1;

  static (Uri?, String) _readPairing(String code) {
    try {
      return (PairingCode.parse(code).relayUrl, pairingRetryMessage);
    } on PlainHttpPairingCodeException {
      return (null, plainHttpPairingMessage);
    } on PairingCodeException {
      return (null, pairingRetryMessage);
    }
  }

  void _decline() => setState(() {
    _stage = _returnTo;
    _error = null;
    _refusedCode = _offeredScanned ? _offeredCode : _refusedCode;
  });

  void _showStage(_JoinStage stage) => setState(() {
    _stage = stage;
    _error = null;
    _refusedCode = null;
  });

  void _joinTyped() {
    final String address = _address.text.trim();
    final Uri? relayUrl = address.isEmpty ? null : parseServerAddress(address);
    if (address.isNotEmpty && relayUrl == null) {
      setState(() => _error = serverAddressRefusal(address));
      return;
    }
    final List<String> typed = _typedWords;
    final String? pasted = pairingCodeIn(typed);
    if (pasted == null) {
      _join(typed.join(' '), relayUrl, scanned: false);
      return;
    }
    final Uri? server = _serverIn(pasted);
    if (server != null && relayUrl != null && server.host != relayUrl.host) {
      setState(() => _error = joinAddressMismatchMessage(server, relayUrl));
      return;
    }
    _offer(pasted, scanned: false);
  }

  void _wordsChanged() => setState(() {});

  Future<void> _join(
    String code,
    Uri? relayUrl, {
    required bool scanned,
  }) async {
    if (_joining || _closing) {
      return;
    }
    setState(() {
      if (_stage != _JoinStage.confirm) {
        _returnTo = _stage;
      }
      _stage = _JoinStage.checking;
      _error = null;
      _comparison = null;
    });
    final PairingJoin join =
        widget.join ?? ref.read(pairingServiceProvider).join;
    try {
      await join(
        code,
        relayUrl: relayUrl,
        cancelled: () => _closing,
        confirmJournal: _askJournal,
        onComparison: _showComparison,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on PairingDeclined {
      _back(code, null, refused: scanned);
    } on SyncSetupException catch (error) {
      _back(code, error.message, refused: scanned && _relayDeclined(error));
    }
  }

  void _back(String code, String? error, {required bool refused}) {
    if (!mounted || _closing) {
      return;
    }
    setState(() {
      _stage = _returnTo;
      _error = error;
      _refusedCode = refused ? code : _refusedCode;
      _comparison = null;
    });
  }

  Future<bool> _askJournal(String? label) {
    if (!mounted || _closing) {
      return Future<bool>.value(false);
    }
    final Completer<bool> answer = Completer<bool>();
    setState(() {
      _stage = _JoinStage.journal;
      _journalLabel = label;
      _journalAnswer = answer;
    });
    return answer.future;
  }

  void _answerJournal(bool join) {
    if (_journalAnswer == null) {
      return;
    }
    setState(() => _stage = _JoinStage.checking);
    _settleJournal(join);
  }

  void _settleJournal(bool join) {
    final Completer<bool>? answer = _journalAnswer;
    _journalAnswer = null;
    if (answer != null && !answer.isCompleted) {
      answer.complete(join);
    }
  }

  void _showComparison(String comparison) {
    if (!mounted || _closing) {
      return;
    }
    setState(() {
      _comparison = comparison;
      _stage = _JoinStage.waiting;
    });
  }

  void _cancel() {
    _closing = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _JoinStage.scan ||
      _JoinStage.type when !syncFlowUsesSheet(context) => _window(),
      _JoinStage.scan => _scanStage(),
      _JoinStage.type => _typeStage(),
      _JoinStage.confirm => _confirmStage(),
      _JoinStage.checking => _checkingStage(),
      _JoinStage.journal => _journalStage(),
      _JoinStage.waiting => _waitingStage(),
    };
  }

  Widget _scanStage() {
    return JoinScanPage(
      onScan: _scanned,
      onCancel: _cancel,
      onTypeWords: () => _showStage(_JoinStage.type),
      error: _error,
    );
  }

  Widget _typeStage() {
    final String? error = _error;
    return SyncFlowPage(
      title: joinTypeTitle,
      onClose: _cancel,
      content: <Widget>[
        PairingWordFields(controllers: _words, onChanged: _wordsChanged),
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
          onPressed: _canJoin ? _joinTyped : null,
        ),
      ],
    );
  }

  Widget _window() {
    return JoinWindow(
      words: _words,
      address: _address,
      onCode: _macScanned,
      onCancel: _cancel,
      onWordsChanged: _wordsChanged,
      onJoin: _canJoin ? _joinTyped : null,
      error: _error,
      camera: widget.macCamera,
      decode: widget.macDecode,
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
          onPressed: () => _join(code, null, scanned: _offeredScanned),
        ),
      ],
    );
  }

  Widget _checkingStage() {
    return SyncFlowFrame(
      title: joinCheckingTitle,
      content: const <Widget>[
        Center(child: CrossHatchPlaceholder(width: 28, height: 28)),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(label: syncCancelLabel, onPressed: _cancel),
      ],
    );
  }

  Widget _journalStage() {
    final String? label = _journalLabel;
    final bool phone = syncFlowOnAndroid(context);
    return SyncFlowFrame(
      title: joinJournalTitle,
      message: label == null
          ? joinUnnamedJournalMessage(phone: phone)
          : joinJournalMessage(phone: phone),
      content: <Widget>[
        if (label != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(joinJournalNameLabel, style: context.textStyles.labelSans),
              const SizedBox(height: _labelGap),
              Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodySans,
              ),
            ],
          ),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(
          label: joinDeclineLabel,
          onPressed: () => _answerJournal(false),
        ),
        SyncFlowAction(
          key: joinJournalConfirmKey,
          label: joinLabel,
          primary: true,
          onPressed: () => _answerJournal(true),
        ),
      ],
    );
  }

  Widget _waitingStage() {
    final String? comparison = _comparison;
    return SyncFlowFrame(
      title: joinWaitingTitle,
      message: joinWaitingMessage,
      content: <Widget>[if (comparison != null) ComparisonNumber(comparison)],
      actions: <SyncFlowAction>[
        SyncFlowAction(label: syncCancelLabel, onPressed: _cancel),
      ],
    );
  }
}
