import 'dart:async';

import 'package:flutter/material.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;
import 'package:field_notes/features/notes/photos/photo_import.dart';

const double composerPhotoBarRoom = 800;

const double _ownEditorHeight = 120;

class ComposerPhotoBar extends StatefulWidget {
  const ComposerPhotoBar({
    super.key,
    required this.controller,
    required this.importer,
    this.editorFocusNode,
  });

  final TextEditingController controller;
  final PhotoImporter importer;
  final FocusNode? editorFocusNode;

  @override
  State<ComposerPhotoBar> createState() => _ComposerPhotoBarState();
}

class _ComposerPhotoBarState extends State<ComposerPhotoBar> {
  final UndoHistoryController _undo = UndoHistoryController();
  final FocusNode _spareFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  late final bool _ownsEditing;
  late final NoteEditorController _editing;
  late final ComposerPhotoAdder _adder;

  FocusNode get _focus => widget.editorFocusNode ?? _spareFocus;

  @override
  void initState() {
    super.initState();
    final TextEditingController given = widget.controller;
    _ownsEditing = given is! NoteEditorController;
    _editing = given is NoteEditorController
        ? given
        : NoteEditorController.attachedTo(given);
    _adder = ComposerPhotoAdder(
      controller: _editing,
      importer: widget.importer,
      editorFocusNode: _focus,
      report: (String message) =>
          showTransientToast(context, message, glyph: IconStickerGlyph.close),
    );
  }

  @override
  void dispose() {
    _adder.dispose();
    if (_ownsEditing) {
      _editing.dispose();
    }
    _undo.dispose();
    _spareFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget bar = FormatBar(
      controller: _editing,
      undoController: _undo,
      editorFocusNode: _focus,
      onAddPhoto: () => unawaited(_adder.add()),
      addingPhoto: _adder.busy,
    );
    if (!_ownsEditing) {
      return bar;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: _ownEditorHeight,
          child: noteEditorFor(
            NoteEditorConfig(
              controller: _editing,
              focusNode: _focus,
              undoController: _undo,
              scrollController: _scroll,
            ),
          ),
        ),
        bar,
      ],
    );
  }
}
