import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/notes/notes.dart';
import '../../notes/render/note_photo_block.dart';
import '../media/media_resolver.dart';
import 'note_block_widgets.dart';

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
    final List<NoteBlock> blocks = parseNote(source);
    final double em = noteEmOf(context, style);
    final MediaResolver? resolver = NoteMediaScope.maybeResolverOf(context);
    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++) ...<Widget>[
          if (i > 0)
            SizedBox(height: noteBlockGapEm(blocks[i - 1], blocks[i]) * em),
          _blockView(blocks[i], resolver),
        ],
      ],
    );
    if (Overlay.maybeOf(context) == null) {
      return column;
    }
    return SelectionArea(child: NoteSelectionScope(child: column));
  }

  Widget _blockView(NoteBlock block, MediaResolver? resolver) {
    if (block is PhotoBlock && resolver != null) {
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
