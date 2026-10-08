import 'dart:math' as math;

import 'package:field_notes/app/shell/system_bars.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'join_journal_flow.dart';
import 'start_sync_flow.dart';

const double joinScanFrameShare = 0.76;
const double joinScanFrameMax = 300;
const double joinScanFrameCentre = 0.45;
const double joinScanControlsLift = 22;
const double joinScanControlExtent = 48;

const double _sideInset = 20;
const double _headerInset = 24;
const double _headerTop = 16;
const double _kickerGap = 4;
const double _messageSize = 22;
const double _messageHeight = 1.25;
const double _controlGap = 12;
const double _cancelLabelGap = 4;
const double _cancelGlyph = 16;
const double _pillGlyph = 16;
const double _pillGlyphGap = 8;
const double _pillPadding = 16;
const double _errorGap = 16;
const double _topShade = 180;
const double _bottomShade = 220;
const double _shadeAlpha = 0.72;
const double _bracketStroke = 3;
const double _bracketArmShare = 0.16;
const Duration _scanPause = Duration(milliseconds: 100);
const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(joinScanControlExtent / 2),
);
const BorderRadius _errorRadius = BorderRadius.all(Radius.circular(16));
const EdgeInsets _errorPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 12,
);

class JoinScanPage extends StatelessWidget {
  const JoinScanPage({
    super.key,
    required this.onScan,
    required this.onCancel,
    required this.onTypeWords,
    this.error,
  });

  final ValueChanged<Code> onScan;
  final VoidCallback onCancel;
  final VoidCallback onTypeWords;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkBackdropSystemBars,
      child: ColoredBox(
        color: Palette.mediaBlack,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              _stage(context, constraints.biggest),
        ),
      ),
    );
  }

  Widget _stage(BuildContext context, Size size) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final String? error = this.error;
    final double side = math.min(
      size.width * joinScanFrameShare,
      joinScanFrameMax,
    );
    final Rect frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * joinScanFrameCentre),
      width: side,
      height: side,
    );
    final double controlsTop =
        size.height -
        padding.bottom -
        joinScanControlsLift -
        joinScanControlExtent;
    final double spare = size.height - side;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Semantics(
            label: joinCameraLabel,
            image: true,
            child: ReaderWidget(
              onScan: onScan,
              codeFormat: Format.qrCode,
              tryHarder: true,
              cropPercent: side / size.shortestSide,
              verticalCropOffset: spare > 0
                  ? (frame.center.dy - size.height / 2) / (spare / 2)
                  : 0,
              scanDelay: _scanPause,
              showScannerOverlay: false,
              showFlashlight: false,
              showToggleCamera: false,
              showGallery: false,
              allowPinchZoom: false,
              loading: const CrossHatchPlaceholder(
                variant: CrossHatchVariant.viewport,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: padding.top + _topShade,
          child: const _Shade(begin: Alignment.topCenter),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: padding.bottom + _bottomShade,
          child: const _Shade(begin: Alignment.bottomCenter),
        ),
        Positioned.fromRect(
          rect: frame,
          child: const JoinScanBrackets(key: joinScanFrameKey),
        ),
        Positioned(
          top: padding.top + _headerTop,
          left: _headerInset,
          right: _headerInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                joinScanKicker,
                style: TypographyTokens.pageEyebrowAccent.copyWith(
                  color: Palette.mediaInk,
                ),
              ),
              const SizedBox(height: _kickerGap),
              Semantics(
                header: true,
                child: Text(
                  joinScanMessage,
                  style: TypographyTokens.headlineSerif.copyWith(
                    fontSize: _messageSize,
                    height: _messageHeight,
                    color: Palette.mediaInk,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Positioned(
            left: _sideInset,
            right: _sideInset,
            bottom: size.height - controlsTop + _errorGap,
            child: _ScanError(message: error),
          ),
        Positioned(
          top: controlsTop,
          left: _sideInset,
          right: _sideInset,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CancelControl(onCancel: onCancel),
              const SizedBox(width: _controlGap),
              Expanded(child: _TypeWordsPill(onPressed: onTypeWords)),
            ],
          ),
        ),
      ],
    );
  }
}

class JoinScanBrackets extends StatelessWidget {
  const JoinScanBrackets({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: JoinBracketsPainter(color: Palette.mediaInk),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class JoinBracketsPainter extends CustomPainter {
  const JoinBracketsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double inset = _bracketStroke / 2;
    final double arm = size.shortestSide * _bracketArmShare;
    final double left = inset;
    final double top = inset;
    final double right = size.width - inset;
    final double bottom = size.height - inset;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path corners = Path()
      ..moveTo(left, top + arm)
      ..lineTo(left, top)
      ..lineTo(left + arm, top)
      ..moveTo(right - arm, top)
      ..lineTo(right, top)
      ..lineTo(right, top + arm)
      ..moveTo(right, bottom - arm)
      ..lineTo(right, bottom)
      ..lineTo(right - arm, bottom)
      ..moveTo(left + arm, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - arm);
    canvas.drawPath(corners, stroke);
  }

  @override
  bool shouldRepaint(JoinBracketsPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Shade extends StatelessWidget {
  const _Shade({required this.begin});

  final Alignment begin;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: Alignment(begin.x, -begin.y),
            colors: <Color>[
              Palette.mediaBlack.withValues(alpha: _shadeAlpha),
              Palette.mediaBlack.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      tone: GlassTone.media,
      borderRadius: _errorRadius,
      padding: _errorPadding,
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: TypographyTokens.bodySans.copyWith(color: Palette.mediaInk),
        ),
      ),
    );
  }
}

class _CancelControl extends StatelessWidget {
  const _CancelControl({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GlassCircleButton(
          tone: GlassTone.media,
          face: joinScanControlExtent,
          label: syncCancelLabel,
          glyph: const IconStickerGlyphIcon(
            glyph: IconStickerGlyph.close,
            color: Palette.mediaInk,
            size: _cancelGlyph,
          ),
          onPressed: onCancel,
        ),
        const SizedBox(height: _cancelLabelGap),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onCancel,
          child: ExcludeSemantics(
            child: Text(
              syncCancelLabel,
              style: TypographyTokens.captureLabelSans.copyWith(
                color: Palette.mediaInk,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeWordsPill extends StatelessWidget {
  const _TypeWordsPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: typeWordsInsteadKey,
      button: true,
      label: typeWordsInsteadLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          surface: FocusRingSurface.dark,
          borderRadius: _pillRadius,
          child: ExcludeSemantics(
            child: GlassSurface(
              tone: GlassTone.media,
              borderRadius: _pillRadius,
              child: SizedBox(
                height: joinScanControlExtent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _pillPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const IconStickerGlyphIcon(
                        glyph: IconStickerGlyph.edit,
                        color: Palette.mediaInk,
                        size: _pillGlyph,
                      ),
                      const SizedBox(width: _pillGlyphGap),
                      Flexible(
                        child: Text(
                          typeWordsInsteadLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypographyTokens.buttonSans.copyWith(
                            color: Palette.mediaInk,
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
      ),
    );
  }
}
