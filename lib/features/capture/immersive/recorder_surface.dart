import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';

import 'stage_phase.dart';

enum RecorderArrangement { voice, video }

const Key recorderLeaveKey = ValueKey<String>('recorder-leave');
const Key recorderTopBandKey = ValueKey<String>('recorder-top-band');

const String recorderLeaveLabel = 'Leave';

const Color recorderStageColor = Color(0xFF1C1713);

const double recorderTrafficLightsClearance =
    shellTitleBarPadding + windowButtonsSlotWidth;

const Color _chromeInk = Color(0xFFB7A58C);
const Color _leaveGlyphInk = Color(0xCCFFFFFF);
const Color _leaveGlyphInkBottomBar = Color(0xBFFFFFFF);
const Color _lockInk = Color(0xB3FFFFFF);

const double _minTapTarget = 48;
const double _bandHeight = _minTapTarget;
const double _sidebarBandInset = 18;
const double _bottomBarBandInset = 8;
const double _bottomBarBandTop = 4;
const double _privacyShare = 0.5;
const double _privacyGap = 7;
const double _sidebarChromeSize = 12;
const double _bottomBarChromeSize = 10;
const double _sidebarLockSize = 13;
const double _bottomBarLockSize = 11;
const double _lockStroke = 2;
const double _lockViewBox = 24;
const double _sidebarLeaveGlyph = 13;
const double _bottomBarLeaveGlyph = 18;
const double _leaveGap = 7;
const EdgeInsets _leavePadding = EdgeInsets.fromLTRB(9, 7, 12, 7);
const BorderRadius _leaveRadius = BorderRadius.all(Radius.circular(10));
const double _disabledOpacity = 0.5;

const double _voiceQuestionGapSidebar = 60;
const double _voiceQuestionGapBottomBar = 22;
const double _videoQuestionGapSidebar = 34;
const double _videoQuestionGapBottomBar = 10;
const double _sidebarQuestionMaxWidth = 720;
const double _sidebarQuestionGutter = 40;
const double _bottomBarQuestionGutter = 26;
const double _sidebarStatusGutter = 30;
const double _bottomBarStatusGutter = 28;
const double _videoStatusGutter = 20;

const double _voiceActionsHeight = 118;
const double _videoActionsHeightSidebar = 128;
const double _videoActionsHeightBottomBar = 124;
const double _sidebarActionsGutter = 18;
const double _bottomBarActionsGutter = 16;
const double _voiceActionsFootBottomBar = 26;
const double _videoActionsFootSidebar = 10;
const double _videoActionsFootBottomBar = 22;

const BoxDecoration _sidebarGlow = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, 0.2),
    radius: 1,
    colors: <Color>[Color(0x2BC76A54), Color(0x00C76A54)],
    stops: <double>[0, 0.72],
    transform: _EllipseToBox(
      focus: Alignment(0, 0.2),
      widthShare: 0.58,
      heightShare: 0.58,
    ),
  ),
);

const BoxDecoration _bottomBarGlow = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, 0.16),
    radius: 1,
    colors: <Color>[Color(0x2EC76A54), Color(0x00C76A54)],
    stops: <double>[0, 0.72],
    transform: _EllipseToBox(
      focus: Alignment(0, 0.16),
      widthShare: 0.85,
      heightShare: 0.48,
    ),
  ),
);

const BoxDecoration _veil = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xCC14100C),
      Color(0x0014100C),
      Color(0x0014100C),
      Color(0xE014100C),
    ],
    stops: <double>[0, 0.34, 0.58, 1],
  ),
);

class RecorderSurface extends StatelessWidget {
  const RecorderSurface({
    super.key,
    required this.privacyLine,
    required this.onLeave,
    this.arrangement = RecorderArrangement.voice,
    this.glow = true,
    this.background,
    this.trailing,
    this.question,
    this.centre,
    this.status,
    this.actions,
    this.leaveKey = recorderLeaveKey,
  });

  final String privacyLine;
  final VoidCallback? onLeave;
  final RecorderArrangement arrangement;
  final bool glow;
  final Widget? background;
  final Widget? trailing;
  final Widget? question;
  final Widget? centre;
  final Widget? status;
  final Widget? actions;
  final Key leaveKey;

  @override
  Widget build(BuildContext context) {
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    final Widget stage = _Stage(surface: this, sidebar: sidebar);
    if (sidebar) {
      return stage;
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: stage,
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.surface, required this.sidebar});

  final RecorderSurface surface;
  final bool sidebar;

  bool get _voice => surface.arrangement == RecorderArrangement.voice;

  @override
  Widget build(BuildContext context) {
    final Widget? background = surface.background;
    return ColoredBox(
      color: recorderStageColor,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (background != null) ...<Widget>[
            background,
            const DecoratedBox(decoration: _veil),
          ],
          if (surface.glow)
            DecoratedBox(decoration: sidebar ? _sidebarGlow : _bottomBarGlow),
          Column(
            children: <Widget>[
              _band(context),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                  child: _body(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _band(BuildContext context) {
    final Widget row = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Row(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: sidebar
                        ? recorderTrafficLightsClearance - _sidebarBandInset
                        : 0,
                  ),
                  child: _leave(),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * _privacyShare,
              ),
              child: _privacy(),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: surface.trailing,
              ),
            ),
          ],
        );
      },
    );
    if (!sidebar) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          _bottomBarBandInset,
          MediaQuery.paddingOf(context).top + _bottomBarBandTop,
          _bottomBarBandInset,
          0,
        ),
        child: SizedBox(height: _bandHeight, child: row),
      );
    }
    return SizedBox(
      height: _bandHeight,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            key: recorderTopBandKey,
            behavior: HitTestBehavior.opaque,
            onPanStart: (DragStartDetails _) => unawaited(startWindowDrag()),
            onDoubleTap: () => unawaited(runTitlebarDoubleClick()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sidebarBandInset),
            child: row,
          ),
        ],
      ),
    );
  }

  Widget _leave() {
    final VoidCallback? onLeave = surface.onLeave;
    final bool enabled = onLeave != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: recorderLeaveLabel,
      child: GestureDetector(
        key: surface.leaveKey,
        behavior: HitTestBehavior.opaque,
        onTap: onLeave,
        child: FocusRing(
          enabled: enabled,
          onPressed: onLeave,
          surface: FocusRingSurface.dark,
          borderRadius: _leaveRadius,
          child: Opacity(
            opacity: enabled ? 1.0 : _disabledOpacity,
            child: ExcludeSemantics(
              child: sidebar ? _leaveText() : _leaveGlyph(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leaveText() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minTapTarget,
        minHeight: _minTapTarget,
      ),
      child: const Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Padding(
          padding: _leavePadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconStickerGlyphIcon(
                glyph: IconStickerGlyph.close,
                color: _leaveGlyphInk,
                size: _sidebarLeaveGlyph,
              ),
              SizedBox(width: _leaveGap),
              Text(
                recorderLeaveLabel,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: _sidebarChromeSize,
                  fontWeight: FontWeight.w500,
                  color: _chromeInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leaveGlyph() {
    return const SizedBox.square(
      dimension: _minTapTarget,
      child: Center(
        child: IconStickerGlyphIcon(
          glyph: IconStickerGlyph.close,
          color: _leaveGlyphInkBottomBar,
          size: _bottomBarLeaveGlyph,
        ),
      ),
    );
  }

  Widget _privacy() {
    final double lock = sidebar ? _sidebarLockSize : _bottomBarLockSize;
    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: lock,
            child: const CustomPaint(painter: _LockGlyphPainter()),
          ),
          const SizedBox(width: _privacyGap),
          Flexible(
            child: Text(
              surface.privacyLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: sidebar ? _sidebarChromeSize : _bottomBarChromeSize,
                fontWeight: FontWeight.w500,
                color: _chromeInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _questionGap {
    if (_voice) {
      return sidebar ? _voiceQuestionGapSidebar : _voiceQuestionGapBottomBar;
    }
    return sidebar ? _videoQuestionGapSidebar : _videoQuestionGapBottomBar;
  }

  Widget _body() {
    final Widget? question = surface.question;
    final Widget? centre = _voice ? _voiceGroup() : surface.centre;
    final Widget? status = _voice ? null : surface.status;
    return CustomMultiChildLayout(
      delegate: _StageBodyDelegate(
        questionGap: _questionGap,
        reserveCentre: _voice,
      ),
      children: <Widget>[
        if (centre != null) LayoutId(id: _Slot.centre, child: centre),
        if (question != null)
          LayoutId(id: _Slot.question, child: _questionFrame(question)),
        if (status != null)
          LayoutId(
            id: _Slot.status,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _videoStatusGutter,
              ),
              child: status,
            ),
          ),
        LayoutId(id: _Slot.actions, child: _actionsFrame()),
      ],
    );
  }

  Widget? _voiceGroup() {
    final Widget? centre = surface.centre;
    final Widget? status = surface.status;
    if (centre == null && status == null) {
      return null;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ?centre,
        if (status != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sidebar
                  ? _sidebarStatusGutter
                  : _bottomBarStatusGutter,
            ),
            child: status,
          ),
      ],
    );
  }

  Widget _questionFrame(Widget question) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sidebar ? _sidebarQuestionGutter : _bottomBarQuestionGutter,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sidebar
              ? _sidebarQuestionMaxWidth - 2 * _sidebarQuestionGutter
              : double.infinity,
        ),
        child: _ShrinkToFit(child: question),
      ),
    );
  }

  Widget _actionsFrame() {
    final double height = _voice
        ? _voiceActionsHeight
        : (sidebar ? _videoActionsHeightSidebar : _videoActionsHeightBottomBar);
    final double foot = switch ((_voice, sidebar)) {
      (true, true) => 0,
      (true, false) => _voiceActionsFootBottomBar,
      (false, true) => _videoActionsFootSidebar,
      (false, false) => _videoActionsFootBottomBar,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sidebar ? _sidebarActionsGutter : _bottomBarActionsGutter,
        0,
        sidebar ? _sidebarActionsGutter : _bottomBarActionsGutter,
        foot,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Center(heightFactor: 1, child: surface.actions),
      ),
    );
  }
}

enum _Slot { centre, question, status, actions }

class _StageBodyDelegate extends MultiChildLayoutDelegate {
  _StageBodyDelegate({required this.questionGap, required this.reserveCentre});

  final double questionGap;
  final bool reserveCentre;

  @override
  void performLayout(Size size) {
    final double width = size.width;
    final Size actions = layoutChild(
      _Slot.actions,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: size.height),
    );
    final double actionsTop = size.height - actions.height;
    positionChild(_Slot.actions, Offset(0, actionsTop));

    double floor = actionsTop;
    if (hasChild(_Slot.status)) {
      final Size status = layoutChild(
        _Slot.status,
        BoxConstraints(maxWidth: width, maxHeight: math.max(0, floor)),
      );
      floor -= status.height;
      positionChild(_Slot.status, Offset((width - status.width) / 2, floor));
    }

    Size centre = Size.zero;
    if (hasChild(_Slot.centre)) {
      centre = layoutChild(
        _Slot.centre,
        BoxConstraints(
          maxWidth: width,
          maxHeight: reserveCentre ? math.max(0, floor) : size.height,
        ),
      );
    }

    double ceiling = 0;
    if (hasChild(_Slot.question)) {
      final double reserved = reserveCentre ? centre.height : 0;
      final Size question = layoutChild(
        _Slot.question,
        BoxConstraints(
          maxWidth: width,
          maxHeight: math.max(0, floor - questionGap - reserved),
        ),
      );
      positionChild(
        _Slot.question,
        Offset((width - question.width) / 2, questionGap),
      );
      ceiling = questionGap + question.height;
    }

    if (hasChild(_Slot.centre)) {
      final double centred = ceiling + (floor - ceiling - centre.height) / 2;
      final double top = reserveCentre
          ? math.min(math.max(centred, ceiling), floor - centre.height)
          : centred;
      positionChild(_Slot.centre, Offset((width - centre.width) / 2, top));
    }
  }

  @override
  bool shouldRelayout(_StageBodyDelegate oldDelegate) =>
      oldDelegate.questionGap != questionGap ||
      oldDelegate.reserveCentre != reserveCentre;
}

class _ShrinkToFit extends StatelessWidget {
  const _ShrinkToFit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.maxWidth.isFinite) {
          return child;
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(width: constraints.maxWidth, child: child),
        );
      },
    );
  }
}

class _EllipseToBox extends GradientTransform {
  const _EllipseToBox({
    required this.focus,
    required this.widthShare,
    required this.heightShare,
  });

  final Alignment focus;
  final double widthShare;
  final double heightShare;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double side = bounds.shortestSide;
    if (side <= 0) {
      return Matrix4.identity();
    }
    final Offset origin = focus.withinRect(bounds);
    return Matrix4.translationValues(origin.dx, origin.dy, 0)
        .multiplied(
          Matrix4.diagonal3Values(
            widthShare * bounds.width / side,
            heightShare * bounds.height / side,
            1,
          ),
        )
        .multiplied(Matrix4.translationValues(-origin.dx, -origin.dy, 0));
  }
}

class _LockGlyphPainter extends CustomPainter {
  const _LockGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = _lockInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lockStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _lockViewBox);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 11, 14, 9),
        const Radius.circular(2),
      ),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8, 11)
        ..lineTo(8, 8)
        ..arcToPoint(const Offset(16, 8), radius: const Radius.circular(4))
        ..lineTo(16, 11),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LockGlyphPainter oldDelegate) => false;
}
