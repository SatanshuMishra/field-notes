import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import '../../../domain/notes/notes.dart';
import '../notes/note_document.dart';
import 'note_body.dart';

const int notePreviewCharLimit = 1200;
const double notePreviewFadeHeight = 52;
const String noteReadMoreLabel = 'Read more';

const double _readMoreGap = 8;

typedef NotePreviewText = ({String text, bool wasTruncated});

NotePreviewText notePreviewOf(
  String source, {
  int limit = notePreviewCharLimit,
}) {
  if (limit <= 0) {
    return (text: '', wasTruncated: source.isNotEmpty);
  }
  final NotePreviewText prefix = _blockPrefixOf(source, limit);
  if (!prefix.wasTruncated) {
    return (text: source, wasTruncated: false);
  }
  final String head = prefix.text.trimRight();
  if (head.isEmpty) {
    return (text: source.substring(0, _withoutLoneSurrogate(source, limit)),
        wasTruncated: true);
  }
  return (text: head, wasTruncated: true);
}

NotePreviewText _blockPrefixOf(String source, int limit) {
  final StringBuffer kept = StringBuffer();
  bool keptPhoto = false;
  bool lastKeptIsPhoto = false;
  bool dropped = false;
  for (final NoteBlock block in parseNote(source)) {
    if (kept.length >= limit) {
      return (text: kept.toString(), wasTruncated: true);
    }
    final String slice = block.sourceRange.sliceOf(source);
    final int budget = limit - kept.length;
    if (block is PhotoBlock) {
      if (keptPhoto) {
        if (lastKeptIsPhoto) {
          return (text: kept.toString(), wasTruncated: true);
        }
        if (!kept.toString().endsWith('\n\n')) {
          kept.write('\n');
        }
        dropped = true;
        continue;
      }
      if (slice.trimRight().length > budget && kept.isNotEmpty) {
        return (text: kept.toString(), wasTruncated: true);
      }
      kept.write(slice);
      keptPhoto = true;
      lastKeptIsPhoto = true;
      continue;
    }
    if (slice.length <= budget) {
      kept.write(slice);
      lastKeptIsPhoto = false;
      continue;
    }
    final int? cut = _lastBreakAtOrBefore(slice, budget);
    if (cut != null) {
      kept.write(slice.substring(0, cut));
    } else if (kept.isEmpty) {
      kept.write(slice.substring(0, _withoutLoneSurrogate(slice, budget)));
    }
    return (text: kept.toString(), wasTruncated: true);
  }
  return (text: kept.toString(), wasTruncated: dropped);
}

int? _lastBreakAtOrBefore(String source, int limit) {
  for (int index = limit; index >= 0; index--) {
    if (_isBreak(source.codeUnitAt(index))) {
      return index;
    }
  }
  return null;
}

int _withoutLoneSurrogate(String source, int end) {
  if (end <= 0) {
    return end;
  }
  final int unit = source.codeUnitAt(end - 1);
  return unit >= 0xD800 && unit <= 0xDBFF ? end - 1 : end;
}

bool _isBreak(int unit) =>
    unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x0D;

class NotePreview extends StatelessWidget {
  const NotePreview({
    super.key,
    required this.text,
    this.limit = notePreviewCharLimit,
    this.onReadMore,
  });

  final String text;
  final int limit;
  final VoidCallback? onReadMore;

  @override
  Widget build(BuildContext context) {
    final NotePreviewText preview = notePreviewOf(text, limit: limit);
    if (!preview.wasTruncated) {
      return IgnorePointer(child: NoteBody(text: text));
    }
    return NoteColumn(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: notePreviewFadeShader,
              child: NoteDocument(source: preview.text),
            ),
          ),
          const SizedBox(height: _readMoreGap),
          _readMore(),
        ],
      ),
    );
  }

  Widget _readMore() {
    final Widget label = Align(
      alignment: Alignment.centerLeft,
      child: Text(
        noteReadMoreLabel,
        style: TypographyTokens.captionSans.copyWith(
          color: Palette.coralLink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final VoidCallback? tap = onReadMore;
    if (tap == null) {
      return label;
    }
    return Semantics(
      button: true,
      label: noteReadMoreLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: label,
      ),
    );
  }
}

double notePreviewFadeStart(double height) =>
    height <= notePreviewFadeHeight ? 0 : 1 - notePreviewFadeHeight / height;

Shader notePreviewFadeShader(Rect bounds) {
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: const <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    stops: <double>[notePreviewFadeStart(bounds.height), 1],
  ).createShader(bounds);
}
