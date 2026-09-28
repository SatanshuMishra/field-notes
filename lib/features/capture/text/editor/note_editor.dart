import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureMedia;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController, NoteEditorView, NotePhotoToolbarRequest;

import 'photo_toolbar.dart' show PhotoToolbarLayer;

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
    this.spellCheckEnabled = false,
    this.photoMediaImporter,
  });

  final NoteEditorController controller;
  final FocusNode focusNode;
  final UndoHistoryController undoController;
  final ScrollController scrollController;
  final TextStyle style;
  final String hintText;
  final TextStyle hintStyle;
  final Color cursorColor;
  final Future<List<String>> Function()? photoImporter;
  final double bottomInset;
  final bool spellCheckEnabled;
  final Future<String> Function(CaptureMedia photo)? photoMediaImporter;
}

Widget noteEditorFor(NoteEditorConfig config) {
  return NoteEditorView(
    controller: config.controller,
    focusNode: config.focusNode,
    undoController: config.undoController,
    scrollController: config.scrollController,
    hintText: config.hintText,
    hintStyle: config.hintStyle,
    cursorColor: config.cursorColor,
    photoImporter: config.photoImporter,
    photoMediaImporter: config.photoMediaImporter,
    bottomInset: config.bottomInset,
    spellCheckEnabled: config.spellCheckEnabled,
    photoToolbarBuilder:
        (BuildContext context, NotePhotoToolbarRequest request) =>
            PhotoToolbarLayer(request: request),
  );
}
