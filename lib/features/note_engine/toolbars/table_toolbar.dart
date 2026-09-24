import 'dart:math' as math;

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/commands/table_commands.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const Key tableToolbarKey = ValueKey<String>('table-toolbar');
const Key tableToolbarRowAboveKey = ValueKey<String>('table-toolbar-row-above');
const Key tableToolbarRowBelowKey = ValueKey<String>('table-toolbar-row-below');
const Key tableToolbarColumnLeftKey = ValueKey<String>(
  'table-toolbar-column-left',
);
const Key tableToolbarColumnRightKey = ValueKey<String>(
  'table-toolbar-column-right',
);
const Key tableToolbarDeleteRowKey = ValueKey<String>(
  'table-toolbar-delete-row',
);
const Key tableToolbarDeleteColumnKey = ValueKey<String>(
  'table-toolbar-delete-column',
);
const Key tableToolbarAlignLeftKey = ValueKey<String>(
  'table-toolbar-align-left',
);
const Key tableToolbarAlignCentreKey = ValueKey<String>(
  'table-toolbar-align-centre',
);
const Key tableToolbarAlignRightKey = ValueKey<String>(
  'table-toolbar-align-right',
);
const Key tableToolbarDeleteTableKey = ValueKey<String>(
  'table-toolbar-delete-table',
);

const double tableToolbarGap = 10;

const double _barPadding = 5;
const double _desktopTarget = 28;
const double _androidTarget = 48;
const double _controlPadding = 7;
const double _controlGap = 2;
const double _groupGap = 5;
const double _ruleHeight = 17;
const double _glyphExtent = 14;
const double _disabledOpacity = 0.4;
const double _focusRingWidth = 2;
const BorderRadius _controlRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusXs + 1),
);
const BorderRadius _barRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusSm),
);

final class _TableControl {
  const _TableControl(this.edit, this.key, this.label);

  final TableEdit edit;
  final Key key;
  final String label;
}

const List<List<_TableControl>> _groups = <List<_TableControl>>[
  <_TableControl>[
    _TableControl(TableEdit.rowAbove, tableToolbarRowAboveKey, 'Row above'),
    _TableControl(TableEdit.rowBelow, tableToolbarRowBelowKey, 'Row below'),
  ],
  <_TableControl>[
    _TableControl(
      TableEdit.columnLeft,
      tableToolbarColumnLeftKey,
      'Column left',
    ),
    _TableControl(
      TableEdit.columnRight,
      tableToolbarColumnRightKey,
      'Column right',
    ),
  ],
  <_TableControl>[
    _TableControl(TableEdit.deleteRow, tableToolbarDeleteRowKey, 'Delete row'),
    _TableControl(
      TableEdit.deleteColumn,
      tableToolbarDeleteColumnKey,
      'Delete column',
    ),
  ],
  <_TableControl>[
    _TableControl(TableEdit.alignLeft, tableToolbarAlignLeftKey, 'Align left'),
    _TableControl(
      TableEdit.alignCentre,
      tableToolbarAlignCentreKey,
      'Align centre',
    ),
    _TableControl(
      TableEdit.alignRight,
      tableToolbarAlignRightKey,
      'Align right',
    ),
  ],
  <_TableControl>[
    _TableControl(
      TableEdit.deleteTable,
      tableToolbarDeleteTableKey,
      'Delete table',
    ),
  ],
];

MdRange? tableAtCaret(EditorState state) => _tableBlockAt(state)?.sourceRange;

MdBlock? _tableBlockAt(EditorState state) {
  final MdBlock? block = state.tree.blockAt(state.selection.head);
  return block != null && block.kind == MdBlockKind.table ? block : null;
}

Rect? tableToolbarRect({
  required Rect table,
  required Size bar,
  required Rect view,
  required Rect surface,
}) {
  if (!table.overlaps(view)) {
    return null;
  }
  final double top = view.top + tableToolbarGap;
  final double bottom = view.bottom - tableToolbarGap - bar.height;
  final double above = table.top - tableToolbarGap - bar.height;
  final double below = table.bottom + tableToolbarGap;
  final double y = bottom <= top
      ? top
      : above >= top
      ? math.min(above, bottom)
      : below <= bottom
      ? math.max(below, top)
      : math.max(top, math.min(table.top + tableToolbarGap, bottom));
  final double width = math.min(bar.width, surface.width);
  final double x = (table.center.dx - width / 2).clamp(
    surface.left,
    surface.right - width,
  );
  return Rect.fromLTWH(x, y, width, bar.height);
}

MdCellAlignment? _alignmentAt(EditorState state, MdBlock table) {
  final int? cell = activeLineAt(
    state.source,
    state.tree,
    state.selection,
  ).cell;
  if (cell == null || table.blocks.isEmpty) {
    return null;
  }
  final List<MdBlock> header = table.blocks.first.blocks;
  if (cell >= header.length) {
    return null;
  }
  final MdBlockData? data = header[cell].data;
  return data is MdTableCellData ? data.alignment : null;
}

MdCellAlignment? _alignmentOf(TableEdit edit) => switch (edit) {
  TableEdit.alignLeft => MdCellAlignment.left,
  TableEdit.alignCentre => MdCellAlignment.centre,
  TableEdit.alignRight => MdCellAlignment.right,
  _ => null,
};

class TableToolbar extends StatelessWidget {
  const TableToolbar({
    super.key,
    required this.state,
    required this.onTransaction,
    this.onDismiss,
    this.tapRegionGroupId = EditableText,
    this.enabled = tablesEnabled,
  });

  final EditorState state;
  final ValueChanged<Transaction> onTransaction;
  final VoidCallback? onDismiss;
  final Object? tapRegionGroupId;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final MdBlock? table = enabled ? _tableBlockAt(state) : null;
    if (table == null) {
      return const SizedBox.shrink();
    }
    final MdCellAlignment? alignment = _alignmentAt(state, table);
    final double target = defaultTargetPlatform == TargetPlatform.android
        ? _androidTarget
        : _desktopTarget;
    final List<Widget> children = <Widget>[
      for (int g = 0; g < _groups.length; g++) ...<Widget>[
        if (g > 0) const _TableToolbarRule(),
        for (int c = 0; c < _groups[g].length; c++) ...<Widget>[
          if (c > 0) const SizedBox(width: _controlGap),
          _control(_groups[g][c], alignment, target),
        ],
      ],
    ];
    final Widget bar = Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        key: tableToolbarKey,
        decoration: const BoxDecoration(
          color: Palette.toolbarInk,
          borderRadius: _barRadius,
          boxShadow: Shadows.toastLift,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_barPadding),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
    final VoidCallback? dismiss = onDismiss;
    return TapRegion(
      groupId: tapRegionGroupId,
      child: dismiss == null
          ? bar
          : CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.escape): dismiss,
              },
              child: bar,
            ),
    );
  }

  Widget _control(
    _TableControl control,
    MdCellAlignment? alignment,
    double target,
  ) {
    final Transaction? transaction = editTable(state, control.edit);
    final MdCellAlignment? writes = _alignmentOf(control.edit);
    return _TableToolbarControl(
      controlKey: control.key,
      label: control.label,
      target: target,
      selected: writes == null ? null : writes == alignment,
      onTap: transaction == null || transaction.changes.isEmpty
          ? null
          : () => onTransaction(transaction),
      child: SizedBox(
        width: _glyphExtent,
        height: _glyphExtent,
        child: CustomPaint(
          painter: _TableGlyphPainter(
            glyph: control.edit,
            color: Palette.toolbarLabel,
          ),
        ),
      ),
    );
  }
}

class _TableToolbarRule extends StatelessWidget {
  const _TableToolbarRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: _groupGap),
      child: SizedBox(
        width: 1,
        height: _ruleHeight,
        child: ColoredBox(color: Palette.toolbarRule),
      ),
    );
  }
}

class _TableGlyphPainter extends CustomPainter {
  const _TableGlyphPainter({required this.glyph, required this.color});

  final TableEdit glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / 24);
    canvas.drawPath(_path(), stroke);
    canvas.restore();
  }

  Path _path() {
    return switch (glyph) {
      TableEdit.rowAbove =>
        Path()
          ..addRect(const Rect.fromLTRB(4, 12, 20, 20))
          ..moveTo(12, 12)
          ..lineTo(12, 20)
          ..moveTo(9, 6)
          ..lineTo(15, 6)
          ..moveTo(12, 3)
          ..lineTo(12, 9),
      TableEdit.rowBelow =>
        Path()
          ..addRect(const Rect.fromLTRB(4, 4, 20, 12))
          ..moveTo(12, 4)
          ..lineTo(12, 12)
          ..moveTo(9, 18)
          ..lineTo(15, 18)
          ..moveTo(12, 15)
          ..lineTo(12, 21),
      TableEdit.columnLeft =>
        Path()
          ..addRect(const Rect.fromLTRB(12, 4, 20, 20))
          ..moveTo(12, 12)
          ..lineTo(20, 12)
          ..moveTo(3, 12)
          ..lineTo(9, 12)
          ..moveTo(6, 9)
          ..lineTo(6, 15),
      TableEdit.columnRight =>
        Path()
          ..addRect(const Rect.fromLTRB(4, 4, 12, 20))
          ..moveTo(4, 12)
          ..lineTo(12, 12)
          ..moveTo(15, 12)
          ..lineTo(21, 12)
          ..moveTo(18, 9)
          ..lineTo(18, 15),
      TableEdit.deleteRow =>
        Path()
          ..addRect(const Rect.fromLTRB(4, 4, 20, 20))
          ..moveTo(4, 12)
          ..lineTo(20, 12)
          ..moveTo(9, 14)
          ..lineTo(15, 18)
          ..moveTo(15, 14)
          ..lineTo(9, 18),
      TableEdit.deleteColumn =>
        Path()
          ..addRect(const Rect.fromLTRB(4, 4, 20, 20))
          ..moveTo(12, 4)
          ..lineTo(12, 20)
          ..moveTo(14, 9)
          ..lineTo(18, 15)
          ..moveTo(18, 9)
          ..lineTo(14, 15),
      TableEdit.alignLeft =>
        Path()
          ..moveTo(4, 6)
          ..lineTo(20, 6)
          ..moveTo(4, 12)
          ..lineTo(14, 12)
          ..moveTo(4, 18)
          ..lineTo(17, 18),
      TableEdit.alignCentre =>
        Path()
          ..moveTo(4, 6)
          ..lineTo(20, 6)
          ..moveTo(7, 12)
          ..lineTo(17, 12)
          ..moveTo(5, 18)
          ..lineTo(19, 18),
      TableEdit.alignRight =>
        Path()
          ..moveTo(4, 6)
          ..lineTo(20, 6)
          ..moveTo(10, 12)
          ..lineTo(20, 12)
          ..moveTo(7, 18)
          ..lineTo(20, 18),
      TableEdit.deleteTable =>
        Path()
          ..addRect(const Rect.fromLTRB(4, 4, 20, 20))
          ..moveTo(4, 12)
          ..lineTo(20, 12)
          ..moveTo(12, 4)
          ..lineTo(12, 20)
          ..moveTo(4, 4)
          ..lineTo(20, 20)
          ..moveTo(20, 4)
          ..lineTo(4, 20),
    };
  }

  @override
  bool shouldRepaint(_TableGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

class _TableToolbarControl extends StatefulWidget {
  const _TableToolbarControl({
    required this.controlKey,
    required this.label,
    required this.target,
    required this.child,
    required this.onTap,
    this.selected,
  });

  final Key controlKey;
  final String label;
  final double target;
  final Widget child;
  final VoidCallback? onTap;
  final bool? selected;

  @override
  State<_TableToolbarControl> createState() => _TableToolbarControlState();
}

class _TableToolbarControlState extends State<_TableToolbarControl> {
  bool _focused = false;

  void _onFocusHighlight(bool focused) {
    if (mounted && focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = widget.onTap;
    final bool enabled = onTap != null;
    final bool marked = widget.selected ?? false;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: _onFocusHighlight,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        inMutuallyExclusiveGroup: widget.selected != null,
        label: widget.label,
        child: GestureDetector(
          key: widget.controlKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.target,
                minHeight: widget.target,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: marked ? Palette.coral : null,
                  border: _focused
                      ? const Border.fromBorderSide(
                          BorderSide(
                            color: Palette.toolbarLabel,
                            width: _focusRingWidth,
                          ),
                        )
                      : null,
                  borderRadius: _controlRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _controlPadding,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Opacity(
                      opacity: enabled ? 1 : _disabledOpacity,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
