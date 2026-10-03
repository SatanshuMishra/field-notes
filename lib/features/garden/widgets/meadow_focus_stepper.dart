import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/features/garden/model/meadow_focus.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';

const String meadowFocusCloseLabel = 'Back to the year';
const double meadowFocusSwipe = 40;
const double meadowDeskStepperWidth = 380;
const ValueKey<String> meadowFocusStepperKey = ValueKey<String>(
  'meadow-focus-stepper',
);
const ValueKey<String> meadowFocusPreviousKey = ValueKey<String>(
  'meadow-focus-previous',
);
const ValueKey<String> meadowFocusNextKey = ValueKey<String>(
  'meadow-focus-next',
);
const ValueKey<String> meadowFocusCloseKey = ValueKey<String>(
  'meadow-focus-close',
);
const ValueKey<String> meadowFocusTitleKey = ValueKey<String>(
  'meadow-focus-title',
);

const Color _stepperFill = Color.fromRGBO(28, 22, 16, 0.38);
const Color _stepperEdge = Color.fromRGBO(255, 250, 240, 0.22);
const List<BoxShadow> _stepperShadows = <BoxShadow>[
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.55),
    offset: Offset(0, 12),
    blurRadius: 30,
    spreadRadius: -12,
  ),
];
const double _disabledOpacity = 0.35;

String meadowFocusPreviousLabel(MeadowFocus focus) => 'Previous ${focus.noun}';

String meadowFocusNextLabel(MeadowFocus focus) => 'Next ${focus.noun}';

class MeadowFocusStepper extends StatefulWidget {
  const MeadowFocusStepper({
    super.key,
    required this.focus,
    required this.counts,
    required this.compact,
    required this.onStep,
    required this.onClose,
  });

  final MeadowFocus focus;
  final String counts;
  final bool compact;
  final ValueChanged<int> onStep;
  final VoidCallback onClose;

  @override
  State<MeadowFocusStepper> createState() => _MeadowFocusStepperState();
}

class _MeadowFocusStepperState extends State<MeadowFocusStepper> {
  double _swipe = 0;

  void _swipeStarted(DragStartDetails details) => _swipe = 0;

  void _swiped(DragUpdateDetails details) => _swipe += details.delta.dx;

  void _swipeEnded(DragEndDetails details) {
    final double travel = _swipe;
    _swipe = 0;
    if (travel.abs() > meadowFocusSwipe) {
      widget.onStep(travel < 0 ? 1 : -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = widget.compact;
    final MeadowFocus focus = widget.focus;
    final double extent = compact ? meadowPhoneControlHeight : 40;
    final Widget centre = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            focus.title,
            key: meadowFocusTitleKey,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TypographyTokens.serif,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.15,
              color: meadowCream,
            ),
          ),
          Text(
            widget.counts,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: meadowSans(
              11,
              opacity: 0.75,
              weight: FontWeight.w500,
            ).copyWith(height: 1.15),
          ),
        ],
      ),
    );
    return MeadowChromeBlock(
      child: MeadowRise(
        child: MeadowGlass(
          key: meadowFocusStepperKey,
          borderRadius: BorderRadius.all(Radius.circular(compact ? 28 : 26)),
          blur: 18,
          fill: _stepperFill,
          edge: _stepperEdge,
          shadows: _stepperShadows,
          padding: EdgeInsets.all(compact ? 4 : 5),
          child: Row(
            children: <Widget>[
              _RoundButton(
                key: meadowFocusPreviousKey,
                extent: extent,
                label: meadowFocusPreviousLabel(focus),
                path: meadowBackChevron,
                glyph: 16,
                enabled: !focus.isFirst,
                onPressed: () => widget.onStep(-1),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: '${focus.title}, ${widget.counts}',
                  excludeSemantics: true,
                  child: compact
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          dragStartBehavior: DragStartBehavior.down,
                          onHorizontalDragStart: _swipeStarted,
                          onHorizontalDragUpdate: _swiped,
                          onHorizontalDragEnd: _swipeEnded,
                          child: SizedBox(height: extent, child: centre),
                        )
                      : SizedBox(height: extent, child: centre),
                ),
              ),
              const SizedBox(width: 2),
              _RoundButton(
                key: meadowFocusNextKey,
                extent: extent,
                label: meadowFocusNextLabel(focus),
                path: meadowNextChevron,
                glyph: 16,
                enabled: !focus.isLast,
                onPressed: () => widget.onStep(1),
              ),
              const SizedBox(width: 2),
              _RoundButton(
                key: meadowFocusCloseKey,
                extent: extent,
                label: meadowFocusCloseLabel,
                path: meadowCross,
                glyph: 14,
                enabled: true,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({
    super.key,
    required this.extent,
    required this.label,
    required this.path,
    required this.glyph,
    required this.enabled,
    required this.onPressed,
  });

  final double extent;
  final String label;
  final Path path;
  final double glyph;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;
    final VoidCallback? press = enabled ? widget.onPressed : null;
    final BorderRadius radius = BorderRadius.circular(widget.extent / 2);
    final Widget face = Opacity(
      opacity: enabled ? 1 : _disabledOpacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: meadowGlassWhite(enabled && _hovered ? 0.14 : 0),
          borderRadius: radius,
        ),
        child: SizedBox.square(
          dimension: widget.extent,
          child: Center(
            child: MeadowGlyph(
              path: widget.path,
              size: widget.glyph,
              stroke: 2.4,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: press,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (PointerEnterEvent event) => _hover(true),
        onExit: (PointerExitEvent event) => _hover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: press,
          child: FocusRing(
            onPressed: press,
            enabled: enabled,
            surface: FocusRingSurface.dark,
            borderRadius: radius,
            child: ExcludeSemantics(
              child: Tooltip(
                message: widget.label,
                excludeFromSemantics: true,
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
