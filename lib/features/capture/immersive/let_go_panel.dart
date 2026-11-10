import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/confirm_dialog.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/sticker_button.dart';

const String letGoTitle = 'Let this one go?';
const String letGoMessage = "Nothing will be saved. That's okay too.";
const String letGoKeepGoingLabel = 'Keep going';
const String letGoConfirmLabel = 'Let it go';

const Color _panelFill = Color(0xB81C1713);
const Color _panelEdge = Color(0x24F3E6D1);
const Color _titleInk = Color(0xFFF3E6D1);
const Color _messageInk = Color(0xFFB7A58C);

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

class LetGoPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final List<Widget> choices = confirmChoicesInOrder(
      Theme.of(context).platform,
      safe: ConfirmChoiceButton.safe(
        buttonKey: keepGoingKey,
        label: letGoKeepGoingLabel,
        ground: StickerGround.media,
        onPressed: onKeepGoing,
      ),
      action: ConfirmChoiceButton.action(
        buttonKey: letGoKey,
        label: letGoConfirmLabel,
        ground: StickerGround.media,
        onPressed: onLetGo,
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: letGoTitle,
      child: TapRegion(
        consumeOutsideTaps: true,
        onTapOutside: (PointerDownEvent _) => onKeepGoing(),
        child: _TabCanLeaveFocusScope(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _panelFill,
              border: Border.fromBorderSide(
                BorderSide(color: _panelEdge, width: _panelEdgeWidth),
              ),
              borderRadius: BorderRadius.all(Radius.circular(_panelRadius)),
            ),
            child: Padding(
              padding: compact ? _compactPadding : _widePadding,
              child: compact
                  ? _belowTheWords(context, choices)
                  : _besideTheWords(choices),
            ),
          ),
        ),
      ),
    );
  }

  Widget _besideTheWords(List<Widget> choices) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: _words()),
        const SizedBox(width: _wideActionsGap),
        choices.first,
        const SizedBox(width: _buttonGap),
        choices.last,
      ],
    );
  }

  Widget _belowTheWords(BuildContext context, List<Widget> choices) {
    final bool stacked =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _words(),
        const SizedBox(height: _compactActionsGap),
        if (stacked) ...<Widget>[
          choices.first,
          const SizedBox(height: _buttonGap),
          choices.last,
        ] else
          Row(
            children: <Widget>[
              Expanded(child: choices.first),
              const SizedBox(width: _buttonGap),
              Expanded(child: choices.last),
            ],
          ),
      ],
    );
  }

  Widget _words() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            letGoTitle,
            style: TextStyle(
              fontFamily: TypographyTokens.serif,
              fontSize: compact ? _compactTitleSize : _wideTitleSize,
              fontWeight: FontWeight.w500,
              color: _titleInk,
            ),
          ),
        ),
        SizedBox(height: compact ? _compactMessageGap : _wideMessageGap),
        Text(
          letGoMessage,
          style: TextStyle(
            fontFamily: TypographyTokens.sans,
            fontSize: compact ? _compactMessageSize : _wideMessageSize,
            fontWeight: FontWeight.w400,
            color: _messageInk,
          ),
        ),
      ],
    );
  }
}

class _TabCanLeaveFocusScope extends StatefulWidget {
  const _TabCanLeaveFocusScope({required this.child});

  final Widget child;

  @override
  State<_TabCanLeaveFocusScope> createState() => _TabCanLeaveFocusScopeState();
}

class _TabCanLeaveFocusScopeState extends State<_TabCanLeaveFocusScope> {
  final FocusScopeNode _scope = FocusScopeNode(
    debugLabel: 'Let go panel',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(node: _scope, child: widget.child);
  }
}
