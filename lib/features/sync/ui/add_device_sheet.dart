import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'comparison_number.dart';
import 'pairing_qr.dart';
import 'start_sync_flow.dart';
import 'sync_flow_page.dart';

const String addDeviceKicker = 'sync';
const String addDeviceTitle = 'Add a device';
const String addDeviceMessage =
    'On your other device, open Field Notes and choose "Join my journal", '
    'then scan this code.';
const String typeTheseWordsLabel = 'Or type these 8 words:';
const String addDeviceDoneLabel = 'Done';
const String addDeviceMessageForCandidate =
    'Add it only if it shows this same number and you recognise it. It will '
    'be able to read and change your whole journal.';
const String addDeviceCandidateTitle = 'Add this device?';
const String addDeviceNameLabel = 'Device';
const String dontAddLabel = "Don't add";
const String addLabel = 'Add';
const String pairingWordSeparator = ' · ';

const Key addDeviceConfirmKey = ValueKey<String>('add-device-confirm');
const Key addDevicePanelKey = ValueKey<String>('add-device-panel');

Key addDeviceWordKey(int position) =>
    ValueKey<String>('add-device-word-$position');

const double _phoneCodeSide = 268;
const double _macCodeSide = 300;
const double _codeQuietZones = 24;
const double _loadingSide = 28;
const double _wordsLabelGap = 6;
const double _macPanelMaxWidth = 820;
const double _macPanelMargin = 48;
const double _macColumnGap = 28;
const double _macScrimAlpha = 0.42;
const double _macKickerGap = 2;
const double _macMessageGap = 8;
const double _macSectionGap = 18;
const double _macWordsLabelGap = 10;
const double _macWordRowGap = 8;
const double _macWordNumberWidth = 20;
const double _macWordNumberGap = 8;
const double _macWordSize = 18;
const double _macDoneGap = 20;
const int _macWordsPerColumn = 4;
const EdgeInsets _macPanelPadding = EdgeInsets.all(28);

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

  HostedPairing? get _shown {
    final HostedPairing? hosted = _hosted;
    return hosted != null && _remaining > Duration.zero ? hosted : null;
  }

  bool get _loading => _hosted == null && _error == null;

  @override
  Widget build(BuildContext context) {
    final PairingCandidate? candidate = _candidate;
    if (candidate != null) {
      return _candidateStage(candidate);
    }
    if (syncFlowUsesSheet(context)) {
      return _phoneCodeStage();
    }
    return _MacCodePanel(
      pairing: _shown,
      remaining: _remaining,
      loading: _loading,
      error: _error,
      onDone: _done,
    );
  }

  Widget _phoneCodeStage() {
    final HostedPairing? shown = _shown;
    final String? error = _error;
    return SyncFlowPage(
      kicker: addDeviceKicker,
      title: addDeviceTitle,
      message: addDeviceMessage,
      content: <Widget>[
        if (_loading)
          const Center(
            child: CrossHatchPlaceholder(
              width: _loadingSide,
              height: _loadingSide,
            ),
          ),
        if (shown != null) ...<Widget>[
          Center(
            child: PairingQr(
              payload: shown.code.qrPayload,
              size: _phoneCodeSide + _codeQuietZones,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(typeTheseWordsLabel, style: context.textStyles.labelSans),
              const SizedBox(height: _wordsLabelGap),
              Text(
                shown.code.words.join(pairingWordSeparator),
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
      title: addDeviceCandidateTitle,
      message: addDeviceMessageForCandidate,
      content: <Widget>[
        ComparisonNumber(candidate.comparison),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(addDeviceNameLabel, style: context.textStyles.labelSans),
            const SizedBox(height: 6),
            Text(
              candidate.deviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.bodySans,
            ),
          ],
        ),
        if (error != null) SyncFlowError(message: error),
      ],
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

class _MacCodePanel extends StatelessWidget {
  const _MacCodePanel({
    required this.pairing,
    required this.remaining,
    required this.loading,
    required this.error,
    required this.onDone,
  });

  final HostedPairing? pairing;
  final Duration remaining;
  final bool loading;
  final String? error;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    final HostedPairing? pairing = this.pairing;
    final String? error = this.error;
    final double width = math.max(
      0,
      math.min(
        _macPanelMaxWidth,
        MediaQuery.sizeOf(context).width - _macPanelMargin,
      ),
    );
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: _MacPanelScrim()),
        SafeArea(
          child: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: StickerCard(
                  key: addDevicePanelKey,
                  surface: context.colors.cardBright,
                  padding: _macPanelPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox.square(
                        dimension: _macCodeSide + _codeQuietZones,
                        child: pairing != null
                            ? PairingQr(
                                payload: pairing.code.qrPayload,
                                size: _macCodeSide + _codeQuietZones,
                              )
                            : loading
                            ? const Center(
                                child: CrossHatchPlaceholder(
                                  width: _loadingSide,
                                  height: _loadingSide,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: _macColumnGap),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _macCodeSide + _codeQuietZones,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    addDeviceKicker,
                                    style: textStyles.pageEyebrowAccent,
                                  ),
                                  const SizedBox(height: _macKickerGap),
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      addDeviceTitle,
                                      style: textStyles.titleSerif,
                                    ),
                                  ),
                                  const SizedBox(height: _macMessageGap),
                                  Text(
                                    addDeviceMessage,
                                    style: textStyles.bodySans.copyWith(
                                      color: context.colors.mutedDeep,
                                    ),
                                  ),
                                  if (pairing != null) ...<Widget>[
                                    const SizedBox(height: _macSectionGap),
                                    Text(
                                      typeTheseWordsLabel,
                                      style: textStyles.labelSans,
                                    ),
                                    const SizedBox(height: _macWordsLabelGap),
                                    _NumberedWords(words: pairing.code.words),
                                    const SizedBox(height: _macSectionGap),
                                    Text(
                                      worksForLabel(remaining),
                                      style: syncFlowHintStyle(context),
                                    ),
                                  ],
                                  if (error != null) ...<Widget>[
                                    const SizedBox(height: _macSectionGap),
                                    SyncFlowError(message: error),
                                  ],
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: _macDoneGap,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: StickerButton(
                                    label: addDeviceDoneLabel,
                                    padTapTarget: true,
                                    onPressed: onDone,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberedWords extends StatelessWidget {
  const _NumberedWords({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final int columns = (words.length / _macWordsPerColumn).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int column = 0; column < columns; column++) ...<Widget>[
          if (column > 0) const SizedBox(width: _macColumnGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  int index = column * _macWordsPerColumn;
                  index <
                      math.min(words.length, (column + 1) * _macWordsPerColumn);
                  index++
                ) ...<Widget>[
                  if (index > column * _macWordsPerColumn)
                    const SizedBox(height: _macWordRowGap),
                  _NumberedWord(position: index + 1, word: words[index]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NumberedWord extends StatelessWidget {
  const _NumberedWord({required this.position, required this.word});

  final int position;
  final String word;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return MergeSemantics(
      key: addDeviceWordKey(position),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(
            width: _macWordNumberWidth,
            child: Text('$position', style: textStyles.captionSans),
          ),
          const SizedBox(width: _macWordNumberGap),
          Flexible(
            child: Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyles.sectionSerif.copyWith(fontSize: _macWordSize),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacPanelScrim extends StatelessWidget {
  const _MacPanelScrim();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () => Navigator.maybePop(context),
      child: ColoredBox(
        color: Palette.toolbarInk.withValues(alpha: _macScrimAlpha),
      ),
    );
  }
}
