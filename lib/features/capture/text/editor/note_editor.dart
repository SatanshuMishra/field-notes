import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import 'in_place_photo_editor.dart';
import 'markdown_style_controller.dart';

const SpellCheckConfiguration?
    spellCheckDisabledBecauseItShortCircuitsTheStyledSpan = null;

const bool stylusHandwritingDisabledBecauseItShortCircuitsTheStyledSpan = false;

@immutable
class NoteEditorConfig {
  const NoteEditorConfig({
    required this.controller,
    required this.focusNode,
    required this.undoController,
    required this.scrollController,
    this.style = TypographyTokens.noteBody,
    this.hintText = '',
    this.hintStyle = TypographyTokens.noteBodyPlaceholder,
    this.cursorColor = Palette.coral,
    this.photoImporter,
    this.bottomInset = 0,
  });

  final MarkdownStyleController controller;
  final FocusNode focusNode;
  final UndoHistoryController undoController;
  final ScrollController scrollController;
  final TextStyle style;
  final String hintText;
  final TextStyle hintStyle;
  final Color cursorColor;
  final Future<List<String>> Function()? photoImporter;
  final double bottomInset;
}

abstract class NoteEditor extends StatelessWidget {
  const NoteEditor({super.key, required this.config});

  final NoteEditorConfig config;
}

NoteEditor noteEditorFor(NoteEditorConfig config) =>
    InPlacePhotoEditor(config: config);
