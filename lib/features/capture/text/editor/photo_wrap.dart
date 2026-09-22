import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/notes/notes.dart';

import 'markdown_style_controller.dart';
import 'photo_bands.dart';

const double photoWrapFillerGap = 1.5;
const double photoWrapSideMargin = 1;
const double photoWrapCharsBand = 1;
const int _measureWindow = 512;
const int _newline = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;

@immutable
class PhotoWrapEnv {
  const PhotoWrapEnv({
    required this.textWidth,
    required this.style,
    required this.strut,
    required this.scaler,
    required this.styleLimit,
  });

  final double textWidth;
  final TextStyle style;
  final StrutStyle strut;
  final TextScaler scaler;
  final int styleLimit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoWrapEnv &&
          textWidth == other.textWidth &&
          style == other.style &&
          strut == other.strut &&
          scaler == other.scaler &&
          styleLimit == other.styleLimit;

  @override
  int get hashCode =>
      Object.hash(textWidth, style, strut, scaler, styleLimit);
}

@immutable
class PhotoCaretFix {
  const PhotoCaretFix({
    required this.start,
    required this.end,
    required this.dx,
    required this.upstream,
  });

  final int start;
  final int end;
  final double dx;
  final bool upstream;

  bool covers(int offset) => offset >= start && offset <= end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoCaretFix &&
          start == other.start &&
          end == other.end &&
          dx == other.dx &&
          upstream == other.upstream;

  @override
  int get hashCode => Object.hash(start, end, dx, upstream);
}

@immutable
class PhotoWrap {
  const PhotoWrap({
    required this.patches,
    required this.caretFixes,
    required this.anchor,
    required this.indent,
    this.carrier,
  });

  final PhotoPatches patches;
  final List<PhotoCaretFix> caretFixes;
  final int anchor;
  final double indent;
  final int? carrier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoWrap &&
          patches == other.patches &&
          listEquals(caretFixes, other.caretFixes) &&
          anchor == other.anchor &&
          indent == other.indent &&
          carrier == other.carrier;

  @override
  int get hashCode => Object.hash(
        patches,
        Object.hashAll(caretFixes),
        anchor,
        indent,
        carrier,
      );
}

PhotoWrap? planPhotoWrap({
  required String text,
  required NotePhotoLine line,
  required PhotoPlan plan,
  required double figureHeight,
  required PhotoWrapEnv env,
  required Set<int> photoLineStarts,
}) {
  final SourceRange? paragraph = line.paragraph;
  if (paragraph == null || plan.isStacked || !figureHeight.isFinite) {
    return null;
  }
  final int ls = line.lineStart;
  final int le = line.lineEnd;
  final int ps = paragraph.start;
  final int pe = math.min(paragraph.end, text.length);
  if (le >= ps || pe <= ps || le >= text.length) {
    return null;
  }
  if (!_blankBetween(text, le, ps)) {
    return null;
  }
  final double width = env.textWidth;
  final bool left = plan.side == PhotoSide.left;
  final double indent = left ? plan.width + plan.gutter : 0;
  final double band = width - plan.width - plan.gutter;
  final double measure = band - photoWrapSideMargin;
  if (measure <= 0) {
    return null;
  }
  final _Measurer measurer = _Measurer(text: text, env: env, end: pe);
  final List<_WrapLine> lines = <_WrapLine>[];
  double top = 0;
  int pos = ps;
  bool tail = false;
  try {
    while (pos < pe) {
      if (top >= figureHeight - floatEdgeTolerance) {
        tail = true;
        break;
      }
      final _WrapLine? measured = measurer.lineFrom(pos, measure);
      if (measured == null) {
        return null;
      }
      lines.add(measured);
      top += measured.height;
      if (measured.breakAt == null) {
        pos = pe;
        break;
      }
      pos = measured.breakAt! + 1;
    }
  } finally {
    measurer.dispose();
  }
  if (lines.isEmpty) {
    return null;
  }

  final List<PhotoSpacer> spacers = <PhotoSpacer>[];
  final List<PhotoKern> kerns = <PhotoKern>[];
  final List<PhotoBand> bands = <PhotoBand>[
    PhotoBand(start: ls, end: le, height: photoWrapCharsBand),
  ];
  final List<PhotoCaretFix> fixes = <PhotoCaretFix>[];

  for (int i = le; i < ps; i++) {
    if (text.codeUnitAt(i) == _newline) {
      spacers.add(
        PhotoSpacer(
          index: i,
          width: i == le ? indent : 0,
          role: PhotoSpacerRole.indent,
        ),
      );
    } else {
      bands.add(
        PhotoBand(start: i, end: i + 1, height: photoWrapCharsBand),
      );
    }
  }

  for (int i = 0; i < lines.length; i++) {
    final _WrapLine line = lines[i];
    final int? breakAt = line.breakAt;
    if (breakAt == null) {
      continue;
    }
    final bool nextIsBeside = i < lines.length - 1;
    final double lineLeft = i == 0 ? indent + photoWrapSideMargin : indent;
    final double right = lineLeft + line.trailingRight;
    if (line.hardBreak) {
      if (!left || !nextIsBeside) {
        continue;
      }
      final double? kern = _kernFor(right, indent, width);
      if (kern != null) {
        kerns.add(
          PhotoKern(start: line.glyphStart, end: line.glyphEnd, spacing: kern),
        );
      }
      spacers.add(
        PhotoSpacer(
          index: breakAt,
          width: indent,
          role: PhotoSpacerRole.indent,
        ),
      );
      fixes.add(
        PhotoCaretFix(
          start: line.glyphEnd,
          end: breakAt,
          dx: -(kern ?? 0),
          upstream: true,
        ),
      );
      continue;
    }
    if (left && nextIsBeside) {
      final double? kern = _kernFor(right, indent, width);
      if (kern != null) {
        kerns.add(
          PhotoKern(start: line.glyphStart, end: line.glyphEnd, spacing: kern),
        );
      }
      spacers.add(
        PhotoSpacer(
          index: breakAt,
          width: indent,
          role: PhotoSpacerRole.indent,
        ),
      );
      fixes.add(
        PhotoCaretFix(
          start: line.glyphEnd,
          end: breakAt,
          dx: -(kern ?? 0),
          upstream: true,
        ),
      );
      continue;
    }
    spacers.add(
      PhotoSpacer(
        index: breakAt,
        width: math.max(0, width - right - photoWrapFillerGap),
        role: PhotoSpacerRole.trailing,
      ),
    );
  }

  if (!tail) {
    final _WrapLine last = lines.last;
    final double need = figureHeight - top;
    if (need > floatEdgeTolerance) {
      final int? newline = _newlineAfter(text, pe);
      final int? clear = newline == null ? null : newline + 1;
      if (clear != null && clear < text.length) {
        if (text.codeUnitAt(clear) == _newline) {
          spacers.add(
            PhotoSpacer(
              index: clear,
              width: width,
              height: need + last.height,
              role: PhotoSpacerRole.trailing,
            ),
          );
          if (left) {
            fixes.add(
              PhotoCaretFix(
                start: clear,
                end: clear,
                dx: indent,
                upstream: false,
              ),
            );
          }
        } else if (photoLineStarts.contains(clear)) {
          spacers.add(
            PhotoSpacer(
              index: clear,
              width: width,
              height: need,
              role: PhotoSpacerRole.trailing,
            ),
          );
          return _wrap(
            bands,
            spacers,
            kerns,
            fixes,
            le,
            indent,
            carrier: clear,
          );
        } else {
          final double right =
              (lines.length == 1 ? indent + photoWrapSideMargin : indent) +
                  last.trailingRight;
          spacers.add(
            PhotoSpacer(
              index: newline!,
              width: math.max(0, width - right - photoWrapFillerGap),
              height: need + last.height,
              role: PhotoSpacerRole.trailing,
            ),
          );
        }
      } else if (left && clear != null) {
        fixes.add(
          PhotoCaretFix(start: clear, end: clear, dx: indent, upstream: false),
        );
      }
    }
  }

  return _wrap(bands, spacers, kerns, fixes, le, indent);
}

PhotoWrap _wrap(
  List<PhotoBand> bands,
  List<PhotoSpacer> spacers,
  List<PhotoKern> kerns,
  List<PhotoCaretFix> fixes,
  int anchor,
  double indent, {
  int? carrier,
}) {
  return PhotoWrap(
    patches: PhotoPatches(bands: bands, spacers: spacers, kerns: kerns),
    caretFixes: fixes,
    anchor: anchor - 1,
    indent: indent,
    carrier: carrier,
  );
}

double? _kernFor(double right, double indent, double width) {
  if (right + indent > width + floatEdgeTolerance) {
    return null;
  }
  return width + 1 - indent - right;
}

@immutable
class _WrapLine {
  const _WrapLine({
    required this.breakAt,
    required this.hardBreak,
    required this.glyphStart,
    required this.glyphEnd,
    required this.trailingRight,
    required this.height,
  });

  final int? breakAt;
  final bool hardBreak;
  final int glyphStart;
  final int glyphEnd;
  final double trailingRight;
  final double height;
}

class _Measurer {
  _Measurer({required this.text, required this.env, required this.end})
      : _codes = text.length > env.styleLimit ? null : markdownStyleCodes(text);

  final String text;
  final PhotoWrapEnv env;
  final int end;
  final List<int>? _codes;
  final TextPainter _painter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  void dispose() => _painter.dispose();

  _WrapLine? lineFrom(int from, double measure) {
    int window = _measureWindow;
    List<LineMetrics> metrics = const <LineMetrics>[];
    int to = from;
    while (true) {
      to = math.min(end, from + window);
      _layout(from, to, measure);
      metrics = _painter.computeLineMetrics();
      if (metrics.length > 1 || to >= end) {
        break;
      }
      window *= 2;
    }
    if (metrics.isEmpty) {
      return null;
    }
    final double height = metrics.first.height;
    int? breakAt;
    bool hard = false;
    if (metrics.length > 1) {
      final LineMetrics next = metrics[1];
      final int start = _painter
          .getLineBoundary(
            _painter.getPositionForOffset(
              Offset(
                next.left + 0.1,
                next.baseline - next.ascent + next.height / 2,
              ),
            ),
          )
          .start;
      if (start <= 0) {
        return null;
      }
      breakAt = from + start - 1;
      final int unit = text.codeUnitAt(breakAt);
      hard = unit == _newline;
      if (!hard && !_isSpace(unit)) {
        final int? moved = _lastSpaceBefore(text, from, breakAt);
        if (moved == null) {
          return null;
        }
        breakAt = moved;
      }
    }
    final int glyphEnd = _lastGlyphEnd(text, from, breakAt ?? end);
    if (glyphEnd <= from) {
      return null;
    }
    final double trailing = _rightOf(from, from, breakAt ?? end);
    return _WrapLine(
      breakAt: breakAt,
      hardBreak: hard,
      glyphStart: _glyphStart(text, glyphEnd),
      glyphEnd: glyphEnd,
      trailingRight: trailing,
      height: height,
    );
  }

  void _layout(int from, int to, double measure) {
    _painter
      ..text = _spanFor(from, to)
      ..textScaler = env.scaler
      ..strutStyle = env.strut
      ..layout(maxWidth: measure);
  }

  double _rightOf(int origin, int from, int to) {
    if (to <= from) {
      return 0;
    }
    final List<TextBox> boxes = _painter.getBoxesForSelection(
      TextSelection(baseOffset: from - origin, extentOffset: to - origin),
    );
    double right = 0;
    for (final TextBox box in boxes) {
      right = math.max(right, box.right);
    }
    return right;
  }

  InlineSpan _spanFor(int from, int to) {
    final List<int>? codes = _codes;
    if (codes == null) {
      return TextSpan(text: text.substring(from, to), style: env.style);
    }
    final List<InlineSpan> children = <InlineSpan>[];
    int runStart = from;
    for (int i = from + 1; i <= to; i++) {
      if (i < to && codes[i] == codes[runStart]) {
        continue;
      }
      children.add(
        TextSpan(
          text: text.substring(runStart, i),
          style: markdownRunStyle(codes[runStart], env.style),
        ),
      );
      runStart = i;
    }
    return TextSpan(style: env.style, children: children);
  }
}

bool _isSpace(int unit) =>
    unit == _space || unit == _tab || unit == _carriageReturn;

bool _isBlankUnit(int unit) => _isSpace(unit) || unit == _newline;

bool _blankBetween(String text, int from, int to) {
  for (int i = from; i < to; i++) {
    if (!_isBlankUnit(text.codeUnitAt(i))) {
      return false;
    }
  }
  return true;
}

int? _lastSpaceBefore(String text, int from, int before) {
  for (int i = before - 1; i > from; i--) {
    if (_isSpace(text.codeUnitAt(i))) {
      return i;
    }
  }
  return null;
}

int _lastGlyphEnd(String text, int from, int to) {
  int i = to;
  while (i > from && _isBlankUnit(text.codeUnitAt(i - 1))) {
    i--;
  }
  return i;
}

int _glyphStart(String text, int glyphEnd) {
  final int unit = text.codeUnitAt(glyphEnd - 1);
  final bool low = unit >= 0xDC00 && unit <= 0xDFFF;
  return low && glyphEnd - 2 >= 0 ? glyphEnd - 2 : glyphEnd - 1;
}

int? _newlineAfter(String text, int from) {
  for (int i = from; i < text.length; i++) {
    final int unit = text.codeUnitAt(i);
    if (unit == _newline) {
      return i;
    }
    if (!_isSpace(unit)) {
      return null;
    }
  }
  return null;
}
