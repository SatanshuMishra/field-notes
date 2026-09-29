import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';

const String letGoTitle = 'Let this one go?';
const String letGoMessage = 'Nothing will be saved. That’s okay too.';
const String letGoKeepGoingLabel = 'Keep going';
const String letGoConfirmLabel = 'Let it go';

const Color _panelFill = Color(0xB81C1713);
const Color _panelEdge = Color(0x24F3E6D1);
const Color _titleInk = Color(0xFFF3E6D1);
const Color _messageInk = Color(0xFFB7A58C);
const Color _outlineInk = Color(0x66F3E6D1);

const double _panelRadius = 18;
const double _panelEdgeWidth = 1;
const EdgeInsets _widePadding = EdgeInsets.fromLTRB(24, 16, 16, 16);
const EdgeInsets _compactPadding = EdgeInsets.all(14);
const double _wideTitleSize = 19;
const double _compactTitleSize = 16;
const double _wideMessageSize = 12;
const double _compactMessageSize = 11;
const double _wideMessageGap = 3;
const double _compactMessageGap = 2;
const double _wideActionsGap = 26;
const double _compactActionsGap = 12;
const double _buttonGap = 8;
const double _buttonLabelSize = 13;
const double _outlineWidth = 1.5;
const double _minTapTarget = 48;
const BorderRadius _pillRadius = BorderRadius.all(Radius.circular(20));
const BorderRadius _compactPillRadius = BorderRadius.all(Radius.circular(24));
const EdgeInsets _keepGoingPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 10,
);
const EdgeInsets _letGoPadding = EdgeInsets.symmetric(
  horizontal: 17,
  vertical: 11,
);

class LetGoPanel extends StatefulWidget {
  const LetGoPanel({
    super.key,
    required this.onKeepGoing,
    required this.onLetGo,
    required this.compact,
    this.keepGoingKey,
    this.letGoKey,
  });

  final VoidCallback onKeepGoing;
  final VoidCallback onLetGo;
  final bool compact;
  final Key? keepGoingKey;
  final Key? letGoKey;

  @override
  State<LetGoPanel> createState() => _LetGoPanelState();
}

class _LetGoPanelState extends State<LetGoPanel> {
  final FocusNode _keepGoingFocus = FocusNode(debugLabel: letGoKeepGoingLabel);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_focusSafeChoice);
  }

  void _focusSafeChoice(Duration _) {
    if (mounted) {
      _keepGoingFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _keepGoingFocus.dispose();
    super.dispose();
  }

  bool get _compact => widget.compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: letGoTitle,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _panelFill,
          border: Border.fromBorderSide(
            BorderSide(color: _panelEdge, width: _panelEdgeWidth),
          ),
          borderRadius: BorderRadius.all(Radius.circular(_panelRadius)),
        ),
        child: Padding(
          padding: _compact ? _compactPadding : _widePadding,
          child: _compact ? _stacked() : _sideBySide(),
        ),
      ),
    );
  }

  Widget _sideBySide() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: _copy()),
        const SizedBox(width: _wideActionsGap),
        _keepGoing(),
        const SizedBox(width: _buttonGap),
        _letGo(),
      ],
    );
  }

  Widget _stacked() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _copy(),
        const SizedBox(height: _compactActionsGap),
        Row(
          children: <Widget>[
            Expanded(child: _keepGoing()),
            const SizedBox(width: _buttonGap),
            Expanded(child: _letGo()),
          ],
        ),
      ],
    );
  }

  Widget _copy() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            letGoTitle,
            style: TextStyle(
              fontFamily: TypographyTokens.serif,
              fontSize: _compact ? _compactTitleSize : _wideTitleSize,
              fontWeight: FontWeight.w500,
              color: _titleInk,
            ),
          ),
        ),
        SizedBox(height: _compact ? _compactMessageGap : _wideMessageGap),
        Text(
          letGoMessage,
          style: TextStyle(
            fontFamily: TypographyTokens.sans,
            fontSize: _compact ? _compactMessageSize : _wideMessageSize,
            fontWeight: FontWeight.w400,
            color: _messageInk,
          ),
        ),
      ],
    );
  }

  Widget _keepGoing() {
    return _PanelButton(
      key: widget.keepGoingKey,
      label: letGoKeepGoingLabel,
      onPressed: widget.onKeepGoing,
      focusNode: _keepGoingFocus,
      compact: _compact,
      padding: _keepGoingPadding,
      decoration: BoxDecoration(
        border: Border.all(color: _outlineInk, width: _outlineWidth),
        borderRadius: _compact ? _compactPillRadius : _pillRadius,
      ),
      labelColor: _titleInk,
    );
  }

  Widget _letGo() {
    return _PanelButton(
      key: widget.letGoKey,
      label: letGoConfirmLabel,
      onPressed: widget.onLetGo,
      compact: _compact,
      padding: _letGoPadding,
      decoration: BoxDecoration(
        color: Palette.coral,
        borderRadius: _compact ? _compactPillRadius : _pillRadius,
      ),
      labelColor: Palette.onAccent,
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.compact,
    required this.padding,
    required this.decoration,
    required this.labelColor,
    this.focusNode,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;
  final EdgeInsets padding;
  final BoxDecoration decoration;
  final Color labelColor;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        decoration.borderRadius?.resolve(Directionality.of(context)) ??
        _pillRadius;
    final Widget face = DecoratedBox(
      decoration: decoration,
      child: Padding(
        padding: compact ? EdgeInsets.zero : padding,
        child: SizedBox(
          height: compact ? _minTapTarget : null,
          child: Center(
            widthFactor: compact ? null : 1,
            heightFactor: compact ? null : 1,
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: _buttonLabelSize,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: compact ? null : 1,
            heightFactor: 1,
            child: FocusRing(
              onPressed: onPressed,
              focusNode: focusNode,
              surface: FocusRingSurface.dark,
              borderRadius: radius,
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}
