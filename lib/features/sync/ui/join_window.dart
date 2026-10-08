import 'dart:math' as math;

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'join_journal_flow.dart';
import 'join_scan_page.dart';
import 'mac_code_scanner.dart';
import 'pairing_word_fields.dart';
import 'qr_frame_decoder.dart';
import 'start_sync_flow.dart';

const double joinWindowColumnGap = 28;
const double joinWindowSideInset = 32;
const double joinWindowFrameShare = 0.62;
const double joinWindowFrameMax = 300;
const double joinWindowPreviewRadius = 18;
const double joinWindowPreviewBorder = 2;
const double joinWindowDividerWidth = 1.5;

const double _headerTop = 12;
const double _headerBottom = 20;
const double _bodyBottom = 32;
const double _helpGap = 6;
const double _sectionGap = 16;
const double _serverGap = 18;
const double _errorGap = 12;
const double _footerGap = 20;
const double _counterGap = 16;
const double _orPadding = 8;
const BorderRadius _previewRadius = BorderRadius.all(
  Radius.circular(joinWindowPreviewRadius),
);

class JoinWindow extends StatelessWidget {
  const JoinWindow({
    super.key,
    required this.words,
    required this.address,
    required this.onCode,
    required this.onCancel,
    required this.onWordsChanged,
    this.onJoin,
    this.error,
    this.camera,
    this.decode,
  });

  final List<TextEditingController> words;
  final TextEditingController address;
  final ValueChanged<String> onCode;
  final VoidCallback onCancel;
  final VoidCallback onWordsChanged;
  final VoidCallback? onJoin;
  final String? error;
  final MacScannerCamera? camera;
  final QrFrameDecode? decode;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (DismissIntent intent) {
            onCancel();
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const WindowDragBand(),
            Expanded(
              child: ColoredBox(
                color: context.colors.page,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _header(context),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        joinWindowSideInset,
        _headerTop,
        joinWindowSideInset,
        _headerBottom,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: StickerButton(
              label: syncCancelLabel,
              variant: StickerButtonVariant.secondary,
              padTapTarget: true,
              onPressed: onCancel,
            ),
          ),
          Semantics(
            header: true,
            child: Text(joinTitle, style: context.textStyles.titleSerif),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        joinWindowSideInset,
        0,
        joinWindowSideInset,
        _bodyBottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _ScanColumn(
              key: joinScanColumnKey,
              onCode: onCode,
              camera: camera,
              decode: decode,
            ),
          ),
          const SizedBox(width: joinWindowColumnGap),
          const _OrDivider(),
          const SizedBox(width: joinWindowColumnGap),
          Expanded(
            child: _TypeColumn(
              key: joinTypeColumnKey,
              words: words,
              address: address,
              onWordsChanged: onWordsChanged,
              onJoin: onJoin,
              error: error,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _helpStyle(BuildContext context) =>
    context.textStyles.bodySans.copyWith(color: context.colors.muted);

class _ScanColumn extends StatelessWidget {
  const _ScanColumn({
    super.key,
    required this.onCode,
    required this.camera,
    required this.decode,
  });

  final ValueChanged<String> onCode;
  final MacScannerCamera? camera;
  final QrFrameDecode? decode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(joinScanTitle, style: context.textStyles.headlineSerif),
        ),
        const SizedBox(height: _helpGap),
        Text(joinScanHelp, style: _helpStyle(context)),
        const SizedBox(height: _sectionGap),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                _preview(context, constraints),
          ),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context, BoxConstraints constraints) {
    final double side = math.min(
      math.min(
        constraints.maxHeight * joinWindowFrameShare,
        joinWindowFrameMax,
      ),
      constraints.maxWidth,
    );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: context.colors.ink,
          width: joinWindowPreviewBorder,
        ),
        borderRadius: _previewRadius,
      ),
      child: ClipRRect(
        borderRadius: _previewRadius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MacCodeScanner(
              onCode: onCode,
              camera: camera,
              decode: decode ?? decodeQrFrame,
            ),
            Center(
              child: SizedBox.square(
                dimension: side,
                child: const JoinScanBrackets(key: joinScanFrameKey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        const DashedDivider(
          axis: Axis.vertical,
          thickness: joinWindowDividerWidth,
        ),
        ColoredBox(
          color: context.colors.page,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _orPadding),
            child: Text(joinOrLabel, style: context.textStyles.captionSans),
          ),
        ),
      ],
    );
  }
}

class _TypeColumn extends StatelessWidget {
  const _TypeColumn({
    super.key,
    required this.words,
    required this.address,
    required this.onWordsChanged,
    required this.onJoin,
    required this.error,
  });

  final List<TextEditingController> words;
  final TextEditingController address;
  final VoidCallback onWordsChanged;
  final VoidCallback? onJoin;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: SingleChildScrollView(child: _fields(context))),
        _footer(context),
      ],
    );
  }

  Widget _fields(BuildContext context) {
    final String? error = this.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(joinTypeTitle, style: context.textStyles.headlineSerif),
        ),
        const SizedBox(height: _helpGap),
        Text(joinTypeHelp, style: _helpStyle(context)),
        const SizedBox(height: _sectionGap),
        _ReturnJoins(
          fields: <TextEditingController>[...words, address],
          onJoin: onJoin,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PairingWordFields(
                controllers: words,
                onChanged: onWordsChanged,
                onSubmitted: onJoin,
              ),
              const SizedBox(height: _serverGap),
              SyncFlowField(
                label: serverAddressLabel,
                controller: address,
                hintText: joinServerHint,
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: _errorGap),
          SyncFlowError(message: error),
        ],
      ],
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _footerGap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            joinWordsCountLabel(filledPairingWords(words)),
            key: joinWordsCountKey,
            style: context.textStyles.labelSans.copyWith(
              color: context.colors.muted,
            ),
          ),
          const SizedBox(width: _counterGap),
          StickerButton(
            key: joinConfirmKey,
            label: joinLabel,
            padTapTarget: true,
            onPressed: onJoin,
          ),
        ],
      ),
    );
  }
}

class _ReturnJoins extends StatelessWidget {
  const _ReturnJoins({
    required this.fields,
    required this.onJoin,
    required this.child,
  });

  final List<TextEditingController> fields;
  final VoidCallback? onJoin;
  final Widget child;

  bool get _composing => fields.any(
    (TextEditingController field) =>
        field.value.composing.isValid && !field.value.composing.isCollapsed,
  );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final VoidCallback? onJoin = this.onJoin;
    final bool returned =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (onJoin == null || event is! KeyDownEvent || !returned || _composing) {
      return KeyEventResult.ignored;
    }
    onJoin();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }
}
