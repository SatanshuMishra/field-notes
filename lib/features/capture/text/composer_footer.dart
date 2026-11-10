import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/sticker_button.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;
import 'package:field_notes/features/notes/photos/photo_import.dart';

const Key composerAddPhotoKey = ValueKey<String>('composer-add-photo');
const Key composerSaveKey = ValueKey<String>('composer-save');
const Key composerLetGoKey = ValueKey<String>('composer-let-go');
const Key composerWordCountKey = ValueKey<String>('composer-word-count');

const String composerAddPhotoLabel = 'Add a photo';

String composerWordsLabel(int words) => words == 1 ? '1 word' : '$words words';

const double _desktopActionGap = 40;
const double _phoneActionGap = 12;
const double _wordsMinWidth = 96;
const double _desktopRowMinHeight = 104;
const double _phoneRowMinHeight = 190;
const EdgeInsets _desktopRowPadding = EdgeInsets.fromLTRB(32, 10, 32, 24);
const EdgeInsets _phoneRowPadding = EdgeInsets.fromLTRB(20, 8, 20, 56);
const EdgeInsets _tightRowPadding = EdgeInsets.fromLTRB(20, 4, 20, 8);

final class ComposerPhotoAdder {
  ComposerPhotoAdder({
    required this.controller,
    required this.importer,
    required this.editorFocusNode,
    required this.report,
  });

  final NoteEditorController controller;
  final PhotoImporter importer;
  final FocusNode editorFocusNode;
  final ValueChanged<String> report;
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);
  bool _disposed = false;

  ValueListenable<bool> get busy => _busy;

  Future<void> add() async {
    if (_busy.value) {
      return;
    }
    _busy.value = true;
    try {
      await controller.addPhotos(importer);
    } on PhotoPickException catch (error) {
      _reportUnlessGone(error.message);
    } catch (error, stackTrace) {
      debugPrint('Adding a photo to a note failed: $error\n$stackTrace');
      _reportUnlessGone(composerPhotoFailedMessage);
    } finally {
      if (!_disposed) {
        _busy.value = false;
        editorFocusNode.requestFocus();
      }
    }
  }

  void _reportUnlessGone(String message) {
    if (!_disposed) {
      report(message);
    }
  }

  void dispose() {
    _disposed = true;
    _busy.dispose();
  }
}

enum ComposerFooterRoom { desktop, phone, tight }

class ComposerFooter extends StatelessWidget {
  const ComposerFooter({
    super.key,
    required this.leaveLabel,
    required this.keepLabel,
    required this.words,
    required this.onLeave,
    required this.onKeep,
    this.room = ComposerFooterRoom.desktop,
  });

  final String leaveLabel;
  final String keepLabel;
  final int words;
  final VoidCallback? onLeave;
  final VoidCallback? onKeep;
  final ComposerFooterRoom room;

  bool get _desktop => room == ComposerFooterRoom.desktop;

  @override
  Widget build(BuildContext context) {
    final double gap = _desktop ? _desktopActionGap : _phoneActionGap;
    return TextFieldTapRegion(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: switch (room) {
            ComposerFooterRoom.desktop => _desktopRowMinHeight,
            ComposerFooterRoom.phone => _phoneRowMinHeight,
            ComposerFooterRoom.tight => 0,
          },
        ),
        child: Padding(
          padding: switch (room) {
            ComposerFooterRoom.desktop => _desktopRowPadding,
            ComposerFooterRoom.phone => _phoneRowPadding,
            ComposerFooterRoom.tight => _tightRowPadding,
          },
          child: Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: StickerButton(
                    key: composerLetGoKey,
                    label: leaveLabel,
                    variant: StickerButtonVariant.stageSoft,
                    onPressed: onLeave,
                  ),
                ),
              ),
              SizedBox(width: gap),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _wordsMinWidth),
                child: _wordCount(context),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StickerButton(
                    key: composerSaveKey,
                    label: keepLabel,
                    variant: StickerButtonVariant.keep,
                    onPressed: onKeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wordCount(BuildContext context) {
    return Text(
      composerWordsLabel(words),
      key: composerWordCountKey,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: context.textStyles.caption.copyWith(
        color: ComposerStageInks.of(context).chrome,
        fontSize: 13,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}
