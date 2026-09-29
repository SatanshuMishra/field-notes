import 'package:flutter/painting.dart';

import 'package:field_notes/design/tokens/tokens.dart';

final class NoteInks {
  const NoteInks({
    required this.body,
    required this.heading,
    required this.quote,
    required this.code,
    required this.codeBackground,
    required this.link,
    required this.linkDecoration,
    required this.highlight,
    required this.marker,
    required this.checked,
    required this.quoteRule,
    required this.divider,
    required this.tableGrid,
    required this.tableHeaderBackground,
    required this.caption,
  });

  factory NoteInks.from(FieldNotesColors colors) => NoteInks(
    body: colors.ink,
    heading: colors.ink,
    quote: colors.inkSoft,
    code: colors.ink,
    codeBackground: colors.ink08,
    link: colors.coralLink,
    linkDecoration: Palette.coral30,
    highlight: Palette.highlight,
    marker: colors.ink34,
    checked: colors.muted,
    quoteRule: colors.dashMuted,
    divider: colors.dashMuted,
    tableGrid: colors.dashMuted,
    tableHeaderBackground: colors.ink08,
    caption: colors.muted,
  );

  static final NoteInks light = NoteInks.from(FieldNotesColors.light);

  final Color body;
  final Color heading;
  final Color quote;
  final Color code;
  final Color codeBackground;
  final Color link;
  final Color linkDecoration;
  final Color highlight;
  final Color marker;
  final Color checked;
  final Color quoteRule;
  final Color divider;
  final Color tableGrid;
  final Color tableHeaderBackground;
  final Color caption;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteInks &&
          body == other.body &&
          heading == other.heading &&
          quote == other.quote &&
          code == other.code &&
          codeBackground == other.codeBackground &&
          link == other.link &&
          linkDecoration == other.linkDecoration &&
          highlight == other.highlight &&
          marker == other.marker &&
          checked == other.checked &&
          quoteRule == other.quoteRule &&
          divider == other.divider &&
          tableGrid == other.tableGrid &&
          tableHeaderBackground == other.tableHeaderBackground &&
          caption == other.caption;

  @override
  int get hashCode => Object.hash(
    body,
    heading,
    quote,
    code,
    codeBackground,
    link,
    linkDecoration,
    highlight,
    marker,
    checked,
    quoteRule,
    divider,
    tableGrid,
    tableHeaderBackground,
    caption,
  );

  @override
  String toString() =>
      'NoteInks(body: $body, heading: $heading, quote: $quote, code: $code, '
      'codeBackground: $codeBackground, link: $link, '
      'linkDecoration: $linkDecoration, highlight: $highlight, '
      'marker: $marker, checked: $checked, quoteRule: $quoteRule, '
      'divider: $divider, tableGrid: $tableGrid, '
      'tableHeaderBackground: $tableHeaderBackground, caption: $caption)';
}
