import 'note_block.dart';
import 'note_parser.dart';

const String plainParagraphBreak = '\n\n';
const String plainListBreak = '\n';

String plainTextOf(String source) {
  final List<NoteBlock> blocks = parseNote(source);
  final StringBuffer buffer = StringBuffer();
  NoteBlock? previous;
  for (final NoteBlock block in blocks) {
    if (block.plainText.isEmpty) {
      continue;
    }
    if (previous != null) {
      buffer.write(plainBreakBetween(previous, block));
    }
    buffer.write(block.plainText);
    previous = block;
  }
  return buffer.toString();
}

String plainBreakBetween(NoteBlock previous, NoteBlock next) =>
    _isListItem(previous) && _isListItem(next)
        ? plainListBreak
        : plainParagraphBreak;

bool _isListItem(NoteBlock block) => block is BulletBlock || block is NumberBlock;
