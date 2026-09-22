import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/notes.dart';

import 'photo_bands.dart';

const int _kindMask = 0xF;
const int _kindBody = 0;
const int _kindHeading1 = 1;
const int _kindHeading2 = 2;
const int _kindHeading3 = 3;
const int _kindQuote = 4;
const int _kindListItem = 5;
const int _kindCodeBlock = 6;
const int _kindPhoto = 7;
const int _kindDivider = 8;

const int _flagMarker = 1 << 4;
const int _flagBold = 1 << 5;
const int _flagItalic = 1 << 6;
const int _flagStrike = 1 << 7;
const int _flagInlineCode = 1 << 8;
const int _flagLinkText = 1 << 9;
const int _flagUrl = 1 << 10;
const int _flagComposing = 1 << 11;

const double _heading1Scale = 1.32;
const double _heading2Scale = 1.18;
const double _heading3Scale = 1.06;
const double _codeScale = 0.92;
const double _photoScale = 0.86;

class MarkdownStyleController extends TextEditingController {
  MarkdownStyleController({super.text, this.styleLimit = liveStyleLimit})
      : _source = null;

  MarkdownStyleController.attachedTo(
    TextEditingController source, {
    this.styleLimit = liveStyleLimit,
  }) : _source = source {
    source.addListener(notifyListeners);
  }

  static const int liveStyleLimit = 6000;

  final int styleLimit;
  final TextEditingController? _source;

  @override
  TextEditingValue get value => _source?.value ?? super.value;

  @override
  set value(TextEditingValue newValue) {
    final TextEditingController? source = _source;
    if (source == null) {
      super.value = newValue;
      return;
    }
    source.value = newValue;
  }

  @override
  void dispose() {
    _source?.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextEditingValue current = value;
    assert(
      !current.composing.isValid ||
          !withComposing ||
          current.isComposingRangeValid,
    );
    final String text = current.text;
    final PhotoPatches patches = text.isEmpty
        ? PhotoPatches.none
        : photoPatchesWithin(PhotoBandScope.of(context), text.length);
    final TextScaler scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final TextSpan span;
    if (text.isEmpty || (text.length > styleLimit && patches.isEmpty)) {
      span = super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    } else if (text.length > styleLimit) {
      span = _plainSpan(current, style, withComposing, patches, scaler);
    } else {
      span = _styledSpan(current, style, withComposing, patches, scaler);
    }
    assert(
      span.toPlainText(includeSemanticsLabels: false).length == text.length,
      'MarkdownStyleController must be length preserving: '
      'built ${span.toPlainText(includeSemanticsLabels: false).length} '
      'characters for a value of ${text.length}',
    );
    return span;
  }

  TextSpan _styledSpan(
    TextEditingValue current,
    TextStyle? style,
    bool withComposing,
    PhotoPatches patches,
    TextScaler scaler,
  ) {
    final String text = current.text;
    final TextStyle base = style ?? TypographyTokens.noteBody;
    final bool composing = withComposing && current.isComposingRangeValid;
    final List<int> codes = markdownStyleCodes(
      text,
      composing: composing ? current.composing : null,
    );
    final Map<int, TextStyle?> styles = <int, TextStyle?>{};

    TextStyle? styleAt(int code) =>
        styles.putIfAbsent(code, () => markdownRunStyle(code, base));

    void addRuns(int from, int to, List<InlineSpan> out) {
      int runStart = from;
      for (int i = from + 1; i <= to; i++) {
        if (i < to && codes[i] == codes[runStart]) {
          continue;
        }
        out.add(
          TextSpan(
            text: text.substring(runStart, i),
            style: styleAt(codes[runStart]),
          ),
        );
        runStart = i;
      }
    }

    InlineSpan kernSpan(PhotoKern kern) {
      final TextStyle run = styleAt(codes[kern.start]) ?? const TextStyle();
      return TextSpan(
        text: text.substring(kern.start, kern.end),
        style: run.copyWith(
          letterSpacing: (base.letterSpacing ?? 0) + kern.spacing,
        ),
      );
    }

    return _patchedSpan(text, style, patches, scaler, addRuns, kernSpan);
  }

  TextSpan _plainSpan(
    TextEditingValue current,
    TextStyle? style,
    bool withComposing,
    PhotoPatches patches,
    TextScaler scaler,
  ) {
    final String text = current.text;
    final TextStyle base = style ?? TypographyTokens.noteBody;
    final TextRange? composing =
        withComposing && current.isComposingRangeValid
            ? current.composing
            : null;

    bool composingAt(int index) =>
        composing != null && composing.start <= index && composing.end > index;

    void addPlain(int from, int to, List<InlineSpan> out) {
      if (from >= to) {
        return;
      }
      final TextRange? range = composing;
      if (range == null || range.end <= from || range.start >= to) {
        out.add(TextSpan(text: text.substring(from, to)));
        return;
      }
      final int start = math.max(from, range.start);
      final int end = math.min(to, range.end);
      if (from < start) {
        out.add(TextSpan(text: text.substring(from, start)));
      }
      out.add(
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
      );
      if (end < to) {
        out.add(TextSpan(text: text.substring(end, to)));
      }
    }

    InlineSpan kernSpan(PhotoKern kern) => TextSpan(
          text: text.substring(kern.start, kern.end),
          style: TextStyle(
            letterSpacing: (base.letterSpacing ?? 0) + kern.spacing,
            decoration: composingAt(kern.start)
                ? TextDecoration.underline
                : null,
          ),
        );

    return _patchedSpan(text, style, patches, scaler, addPlain, kernSpan);
  }

  TextSpan _patchedSpan(
    String text,
    TextStyle? style,
    PhotoPatches patches,
    TextScaler scaler,
    void Function(int from, int to, List<InlineSpan> out) addRuns,
    InlineSpan Function(PhotoKern kern) kernSpan,
  ) {
    final List<(int, int, InlineSpan)> events = <(int, int, InlineSpan)>[
      for (final PhotoBand band in patches.bands)
        (band.start, band.end, _bandSpan(text, band, scaler)),
      for (final PhotoSpacer spacer in patches.spacers)
        (spacer.start, spacer.end, _spacerSpan(spacer, style, scaler)),
      for (final PhotoKern kern in patches.kerns)
        (kern.start, kern.end, kernSpan(kern)),
    ]..sort(((int, int, InlineSpan) a, (int, int, InlineSpan) b) =>
        a.$1.compareTo(b.$1));

    final List<InlineSpan> children = <InlineSpan>[];
    int cursor = 0;
    for (final (int start, int end, InlineSpan span) in events) {
      addRuns(cursor, start, children);
      children.add(span);
      cursor = end;
    }
    addRuns(cursor, text.length, children);
    return TextSpan(style: style, children: children);
  }

  TextSpan _bandSpan(String text, PhotoBand band, TextScaler scaler) {
    return TextSpan(
      text: text.substring(band.start, band.end),
      style: photoBandStyle(band.height, scaler),
    );
  }

  WidgetSpan _spacerSpan(
    PhotoSpacer spacer,
    TextStyle? style,
    TextScaler scaler,
  ) {
    final double fontSize = style?.fontSize ?? _engineDefaultFontSize;
    final double factor =
        fontSize == 0 ? 1 : scaler.scale(fontSize) / fontSize;
    final double scale = factor == 0 ? 1 : factor;
    return WidgetSpan(
      alignment: spacer.height > 0
          ? PlaceholderAlignment.top
          : PlaceholderAlignment.bottom,
      child: SizedBox(
        width: spacer.width / scale,
        height: spacer.height / scale,
      ),
    );
  }
}

const double _engineDefaultFontSize = 14;

List<int> markdownStyleCodes(String source, {TextRange? composing}) {
  final List<int> codes = List<int>.filled(source.length, _kindBody);

  void setKind(SourceRange range, int kind) {
    final int end = math.min(range.end, codes.length);
    for (int i = math.max(range.start, 0); i < end; i++) {
      codes[i] = (codes[i] & ~_kindMask) | kind;
    }
  }

  void addFlag(int start, int end, int flag) {
    final int last = math.min(end, codes.length);
    for (int i = math.max(start, 0); i < last; i++) {
      codes[i] |= flag;
    }
  }

  void markRange(SourceRange range, int flag) =>
      addFlag(range.start, range.end, flag);

  void markInlines(List<InlineNode> nodes) {
    for (final InlineNode node in nodes) {
      switch (node) {
        case PlainNode():
          break;
        case CodeNode(:final SourceRange contentRange):
          markRange(node.sourceRange, _flagInlineCode);
          addFlag(node.sourceRange.start, contentRange.start, _flagMarker);
          addFlag(contentRange.end, node.sourceRange.end, _flagMarker);
        case StyledNode(:final SourceRange contentRange):
          markRange(contentRange, _inlineFlagOf(node.style));
          addFlag(node.sourceRange.start, contentRange.start, _flagMarker);
          addFlag(contentRange.end, node.sourceRange.end, _flagMarker);
          markInlines(node.children);
        case LinkNode(
            :final SourceRange contentRange,
            :final SourceRange urlRange
          ):
          markRange(contentRange, _flagLinkText);
          markRange(urlRange, _flagUrl);
          addFlag(node.sourceRange.start, contentRange.start, _flagMarker);
          addFlag(contentRange.end, urlRange.start, _flagMarker);
          addFlag(urlRange.end, node.sourceRange.end, _flagMarker);
          markInlines(node.children);
      }
    }
  }

  for (final NoteBlock block in parseNote(source)) {
    setKind(block.sourceRange, _blockKindOf(block));
    for (final SourceRange marker in block.markerRanges) {
      markRange(marker, _flagMarker);
    }
    if (block is InlineBlock) {
      markInlines(block.inlines);
    }
  }

  final TextRange? range = composing;
  if (range != null && range.isValid) {
    addFlag(range.start, range.end, _flagComposing);
  }
  return codes;
}

TextStyle? markdownRunStyle(int code, TextStyle base) {
  if (code == _kindBody) {
    return null;
  }
  final int kind = code & _kindMask;
  final double baseSize = base.fontSize ?? TypographyTokens.noteBody.fontSize!;
  final double scale = switch (kind) {
    _kindHeading1 => _heading1Scale,
    _kindHeading2 => _heading2Scale,
    _kindHeading3 => _heading3Scale,
    _kindCodeBlock => _codeScale,
    _kindPhoto => _photoScale,
    _ => 1,
  };
  final bool inlineCode = code & _flagInlineCode != 0;
  final bool heading = kind == _kindHeading1 ||
      kind == _kindHeading2 ||
      kind == _kindHeading3;
  final bool mono = inlineCode || kind == _kindCodeBlock || kind == _kindPhoto;
  final double size = inlineCode ? baseSize * _codeScale : baseSize * scale;
  final List<TextDecoration> decorations = <TextDecoration>[
    if (code & _flagStrike != 0) TextDecoration.lineThrough,
    if (code & _flagLinkText != 0) TextDecoration.underline,
    if (code & _flagComposing != 0) TextDecoration.underline,
  ];
  return TextStyle(
    fontFamily: mono ? TypographyTokens.mono : null,
    fontSize: size == baseSize ? null : size,
    fontWeight: code & _flagBold != 0
        ? FontWeight.w700
        : heading
            ? FontWeight.w600
            : null,
    fontStyle: code & _flagItalic != 0 || kind == _kindQuote
        ? FontStyle.italic
        : null,
    color: _colorOf(code, kind),
    backgroundColor: inlineCode ? Palette.ink08 : null,
    decoration: decorations.isEmpty
        ? null
        : TextDecoration.combine(decorations.toSet().toList()),
    decorationColor: code & _flagMarker != 0 ? Palette.ink34 : null,
  );
}

Color? _colorOf(int code, int kind) {
  if (code & _flagMarker != 0) {
    return Palette.ink34;
  }
  if (code & _flagUrl != 0) {
    return Palette.ink40;
  }
  if (code & _flagLinkText != 0) {
    return Palette.coralLink;
  }
  if (code & _flagInlineCode != 0) {
    return Palette.inkSoft;
  }
  return switch (kind) {
    _kindQuote => Palette.inkSoft,
    _kindCodeBlock => Palette.inkSoft,
    _kindPhoto => Palette.ink40,
    _kindDivider => Palette.ink34,
    _kindListItem => null,
    _ => null,
  };
}

int _blockKindOf(NoteBlock block) {
  return switch (block) {
    HeadingBlock(:final int level) => switch (level) {
        1 => _kindHeading1,
        2 => _kindHeading2,
        _ => _kindHeading3,
      },
    QuoteBlock() => _kindQuote,
    BulletBlock() => _kindListItem,
    NumberBlock() => _kindListItem,
    CodeBlock() => _kindCodeBlock,
    PhotoBlock() => _kindPhoto,
    DividerBlock() => _kindDivider,
    ParagraphBlock() => _kindBody,
  };
}

int _inlineFlagOf(InlineStyle style) {
  return switch (style) {
    InlineStyle.bold => _flagBold,
    InlineStyle.italic => _flagItalic,
    InlineStyle.strike => _flagStrike,
  };
}
