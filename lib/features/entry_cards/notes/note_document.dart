import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/notes/notes.dart';
import '../../notes/model/photo_placement.dart';
import '../../notes/render/note_photo_block.dart';
import '../../notes/render/photo_wrap_block.dart';
import '../media/media_resolver.dart';
import 'note_block_widgets.dart';

@immutable
final class NoteBlockRun {
  const NoteBlockRun(this.block, {this.wraps});

  final NoteBlock block;
  final ParagraphBlock? wraps;

  NoteBlock get last => wraps ?? block;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteBlockRun &&
          identical(block, other.block) &&
          identical(wraps, other.wraps);

  @override
  int get hashCode =>
      Object.hash(identityHashCode(block), identityHashCode(wraps));

  @override
  String toString() => wraps == null
      ? 'NoteBlockRun($block)'
      : 'NoteBlockRun($block wrapping $wraps)';
}

List<NoteBlockRun> noteBlockRuns(
  List<NoteBlock> blocks, {
  required bool floats,
}) {
  ParagraphBlock? paragraphAfter(int index) {
    final NoteBlock block = blocks[index];
    final NoteBlock? next =
        index + 1 < blocks.length ? blocks[index + 1] : null;
    return floats &&
            block is PhotoBlock &&
            next is ParagraphBlock &&
            block.placement.isValid
        ? next
        : null;
  }

  return <NoteBlockRun>[
    for (int i = 0; i < blocks.length; i++)
      if (i == 0 || paragraphAfter(i - 1) == null)
        NoteBlockRun(blocks[i], wraps: paragraphAfter(i)),
  ];
}

class NoteDocument extends StatelessWidget {
  const NoteDocument({
    super.key,
    required this.source,
    this.style = TypographyTokens.noteBody,
  });

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double em = noteEmOf(context, style);
    final MediaResolver? resolver = NoteMediaScope.maybeResolverOf(context);
    final List<NoteBlockRun> runs = noteBlockRuns(
      parseNote(source),
      floats: resolver != null,
    );
    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < runs.length; i++) ...<Widget>[
          if (i > 0)
            SizedBox(
              height: noteBlockGapEm(runs[i - 1].last, runs[i].block) * em,
            ),
          _runView(runs[i], resolver),
        ],
      ],
    );
    if (Overlay.maybeOf(context) == null) {
      return column;
    }
    return SelectionArea(child: NoteSelectionScope(child: column));
  }

  Widget _runView(NoteBlockRun run, MediaResolver? resolver) {
    final NoteBlock block = run.block;
    final ParagraphBlock? wraps = run.wraps;
    if (block is PhotoBlock && resolver != null) {
      if (wraps != null) {
        return PhotoWrapBlock(
          photo: block,
          paragraph: wraps,
          resolver: resolver,
          style: style,
        );
      }
      return StackedPhoto(block: block, resolver: resolver, style: style);
    }
    return NoteBlockView(block: block, style: style);
  }
}

class NoteSelectionScope extends StatefulWidget {
  const NoteSelectionScope({super.key, required this.child});

  final Widget child;

  @override
  State<NoteSelectionScope> createState() => _NoteSelectionScopeState();
}

class _NoteSelectionScopeState extends State<NoteSelectionScope> {
  final NoteSelectionDelegate _delegate = NoteSelectionDelegate();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionContainer(delegate: _delegate, child: widget.child);
  }
}

class NoteSelectionDelegate extends StaticSelectionContainerDelegate {
  @override
  SelectedContent? getSelectedContent() {
    final List<String> parts = <String>[
      for (final Selectable selectable in selectables)
        if (selectable.getSelectedContent() case final SelectedContent content)
          content.plainText,
    ];
    if (parts.isEmpty) {
      return null;
    }
    return SelectedContent(plainText: parts.join(plainParagraphBreak));
  }
}
