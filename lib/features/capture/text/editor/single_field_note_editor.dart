import 'package:flutter/cupertino.dart'
    show cupertinoDesktopTextSelectionHandleControls,
         cupertinoTextSelectionHandleControls;
import 'package:flutter/material.dart';

import 'note_editor.dart';

class SingleFieldNoteEditor extends NoteEditor {
  const SingleFieldNoteEditor({super.key, required super.config});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        IgnorePointer(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: config.controller,
            builder: (
              BuildContext context,
              TextEditingValue value,
              Widget? child,
            ) {
              if (value.text.isNotEmpty) {
                return const SizedBox.shrink();
              }
              return Text(config.hintText, style: config.hintStyle);
            },
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: TextField(
            controller: config.controller,
            focusNode: config.focusNode,
            undoController: config.undoController,
            scrollController: config.scrollController,
            style: unmergedFromTheMaterialTextTheme(config.style),
            cursorColor: config.cursorColor,
            decoration: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            minLines: null,
            maxLines: null,
            expands: true,
            selectionControls: _handlesFor(Theme.of(context).platform),
            contextMenuBuilder: _contextMenu,
            magnifierConfiguration:
                TextMagnifier.adaptiveMagnifierConfiguration,
            spellCheckConfiguration:
                spellCheckDisabledBecauseItShortCircuitsTheStyledSpan,
            stylusHandwritingEnabled:
                stylusHandwritingDisabledBecauseItShortCircuitsTheStyledSpan,
          ),
        ),
      ],
    );
  }
}

Widget _contextMenu(BuildContext context, EditableTextState editableTextState) {
  return AdaptiveTextSelectionToolbar.editableText(
    editableTextState: editableTextState,
  );
}

TextStyle unmergedFromTheMaterialTextTheme(TextStyle style) => style.copyWith(
      inherit: false,
      textBaseline: style.textBaseline ?? TextBaseline.alphabetic,
    );

TextSelectionControls _handlesFor(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS => cupertinoTextSelectionHandleControls,
    TargetPlatform.macOS => cupertinoDesktopTextSelectionHandleControls,
    TargetPlatform.android ||
    TargetPlatform.fuchsia =>
      materialTextSelectionHandleControls,
    TargetPlatform.linux ||
    TargetPlatform.windows =>
      desktopTextSelectionHandleControls,
  };
}
