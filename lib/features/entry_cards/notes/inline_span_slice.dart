import 'package:flutter/painting.dart';

(InlineSpan, InlineSpan?) sliceInlineSpan(InlineSpan root, int offset) {
  if (offset <= 0) {
    return (_rebuild(root, text: null, children: null), root);
  }
  if (offset >= plainLengthOf(root)) {
    return (root, null);
  }
  return _split(root, offset);
}

int plainLengthOf(InlineSpan span) => switch (span) {
      TextSpan(:final String? text, :final List<InlineSpan>? children) =>
        (text?.length ?? 0) +
            (children?.fold<int>(
                  0,
                  (int sum, InlineSpan child) => sum + plainLengthOf(child),
                ) ??
                0),
      _ => 1,
    };

(InlineSpan, InlineSpan?) _split(InlineSpan span, int offset) {
  if (span is! TextSpan) {
    return (span, null);
  }
  final String? text = span.text;
  final int textLength = text?.length ?? 0;
  final List<InlineSpan> children = span.children ?? const <InlineSpan>[];
  if (offset < textLength) {
    return (
      _rebuild(span, text: text!.substring(0, offset), children: null),
      _rebuild(span, text: text.substring(offset), children: children),
    );
  }
  int consumed = textLength;
  for (int i = 0; i < children.length; i++) {
    final InlineSpan child = children[i];
    final int length = plainLengthOf(child);
    if (offset == consumed) {
      return (
        _rebuild(span, text: text, children: children.sublist(0, i)),
        _rebuild(span, text: null, children: children.sublist(i)),
      );
    }
    if (offset < consumed + length) {
      final (InlineSpan head, InlineSpan? tail) =
          _split(child, offset - consumed);
      return (
        _rebuild(
          span,
          text: text,
          children: <InlineSpan>[...children.sublist(0, i), head],
        ),
        _rebuild(
          span,
          text: null,
          children: <InlineSpan>[?tail, ...children.sublist(i + 1)],
        ),
      );
    }
    consumed += length;
  }
  return (span, null);
}

TextSpan _rebuild(
  InlineSpan span, {
  required String? text,
  required List<InlineSpan>? children,
}) {
  final TextSpan? source = span is TextSpan ? span : null;
  return TextSpan(
    text: text == null || text.isEmpty ? null : text,
    children: children == null || children.isEmpty ? null : children,
    style: span.style,
    recognizer: source?.recognizer,
    mouseCursor: source?.mouseCursor,
    onEnter: source?.onEnter,
    onExit: source?.onExit,
    locale: source?.locale,
    spellOut: source?.spellOut,
  );
}
