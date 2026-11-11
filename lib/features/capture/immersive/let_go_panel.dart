import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/confirm_dialog.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'recorder_inks.dart';

const String letGoTitle = 'Let this one go?';
const String letGoMessage = "Nothing will be saved. That's okay too.";
const String letGoKeepGoingLabel = 'Keep going';
const String letGoConfirmLabel = 'Let it go';

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
  bool _answered = false;

  void _answer(VoidCallback choice) {
    setState(() => _answered = true);
    choice();
  }

  bool get compact => widget.compact;

  @override
  Widget build(BuildContext context) {
    final RecorderInks inks = RecorderInks.of(context);
    final List<Widget> choices = confirmChoicesInOrder(
      Theme.of(context).platform,
      safe: ConfirmChoiceButton.safe(
        buttonKey: widget.keepGoingKey,
        label: letGoKeepGoingLabel,
        ground: inks.sticker,
        onPressed: () => _answer(widget.onKeepGoing),
      ),
      action: ConfirmChoiceButton.action(
        buttonKey: widget.letGoKey,
        label: letGoConfirmLabel,
        ground: inks.sticker,
        onPressed: () => _answer(widget.onLetGo),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: letGoTitle,
      child: TapRegion(
        enabled: !_answered,
        consumeOutsideTaps: true,
        onTapOutside: (PointerDownEvent _) => _answer(widget.onKeepGoing),
        child: _TabCanLeaveFocusScope(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: inks.panelFill,
              border: Border.fromBorderSide(
                BorderSide(color: inks.panelEdge, width: _panelEdgeWidth),
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(_panelRadius),
              ),
            ),
            child: Padding(
              padding: compact ? _compactPadding : _widePadding,
              child: compact
                  ? _belowTheWords(context, choices, inks)
                  : _besideTheWords(choices, inks),
            ),
          ),
        ),
      ),
    );
  }

  Widget _besideTheWords(List<Widget> choices, RecorderInks inks) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: _words(inks)),
        const SizedBox(width: _wideActionsGap),
        choices.first,
        const SizedBox(width: _buttonGap),
        choices.last,
      ],
    );
  }

  Widget _belowTheWords(
    BuildContext context,
    List<Widget> choices,
    RecorderInks inks,
  ) {
    final bool stacked =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _words(inks),
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

  Widget _words(RecorderInks inks) {
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
              color: inks.panelTitle,
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
            color: inks.panelMessage,
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
