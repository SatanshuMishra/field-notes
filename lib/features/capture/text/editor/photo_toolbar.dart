import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show
        MdBlock,
        MdBlockKind,
        MdPhotoLine,
        MdPhotoPlacement,
        MdPhotoSide,
        MdPhotoSize;
import 'package:field_notes/features/note_engine/document/editor_state.dart'
    show EditorState;
import 'package:field_notes/features/note_engine/document/transaction.dart'
    show Transaction;
import 'package:field_notes/features/note_engine/layout/photo_planner.dart'
    show photoCanFloat;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NotePhotoToolbarRequest;
import 'package:field_notes/features/note_engine/photos/photo_commands.dart'
    show
        canMovePhotoDown,
        canMovePhotoUp,
        movePhotoDown,
        movePhotoUp,
        removePhoto,
        replacePhotoReference,
        setPhotoCaption,
        setPhotoSide,
        setPhotoSize;
import 'package:field_notes/features/note_engine/render/photo_figure.dart'
    show photoFigureCaptionGap;

import 'photo_caption_field.dart';

const double photoToolbarGap = 10;
const double photoToolbarPadding = 5;
const double photoToolbarTarget = 28;
const double photoToolbarTouchTarget = 48;
const double photoToolbarControlPadding = 7;
const double photoToolbarControlGap = 2;
const double photoToolbarGroupGap = 5;
const double _ruleWidth = 1 + 2 * photoToolbarGroupGap;
const double photoToolbarRuleHeight = 17;

const String photoToolbarCaptionLabel = 'Caption';
const String photoToolbarRemoveLabel = 'Remove';
const String photoToolbarMoveUpLabel = 'Move up';
const String photoToolbarMoveDownLabel = 'Move down';
const String photoToolbarReplaceLabel = 'Replace';
const String photoToolbarMoreLabel = 'More photo actions';
const String photoToolbarNoFloatHint = 'Not enough room to float at this width';
const String photoRemovedMessage = 'Photo removed';
const String photoRemovedUndoLabel = 'Undo';
const String photoRemovedUndoSemanticLabel = 'Undo photo removal';

const Key photoToolbarKey = ValueKey<String>('photo-toolbar');
const Key photoToolbarCaptionKey = ValueKey<String>('photo-toolbar-caption');
const Key photoToolbarRemoveKey = ValueKey<String>('photo-toolbar-remove');
const Key photoToolbarMoveUpKey = ValueKey<String>('photo-toolbar-move-up');
const Key photoToolbarMoveDownKey = ValueKey<String>('photo-toolbar-move-down');
const Key photoToolbarReplaceKey = ValueKey<String>('photo-toolbar-replace');
const Key photoToolbarMoreKey = ValueKey<String>('photo-toolbar-more');

Key photoToolbarSizeKey(MdPhotoSize size) =>
    ValueKey<String>('photo-toolbar-size-${size.name}');

Key photoToolbarSideKey(MdPhotoSide side) =>
    ValueKey<String>('photo-toolbar-side-${side.name}');

String photoToolbarSizeLabel(MdPhotoSize size) => '${size.label} size';

String photoToolbarSideLabel(MdPhotoSide side) => '${side.label} side';

double photoToolbarTargetFor(TargetPlatform platform) =>
    platform == TargetPlatform.android
    ? photoToolbarTouchTarget
    : photoToolbarTarget;

double photoToolbarWidthFor({
  required TextScaler scaler,
  required bool placement,
  required bool moves,
  double target = photoToolbarTarget,
}) {
  final double glyph = _controlExtent(_glyphExtent, target);
  final List<List<double>> groups = <List<double>>[
    if (placement) ...<List<double>>[
      <double>[
        for (final MdPhotoSize size in MdPhotoSize.values)
          _labelControlWidth(size.shortLabel, scaler, target),
      ],
      <double>[
        for (final MdPhotoSide _ in MdPhotoSide.values)
          _controlExtent(_sideGlyphExtent, target),
      ],
    ],
    if (moves) <double>[glyph, glyph, glyph] else <double>[glyph],
    <double>[_labelControlWidth(photoToolbarCaptionLabel, scaler, target)],
    <double>[glyph],
  ];
  final double controls = groups.fold<double>(
    0,
    (double total, List<double> group) =>
        total +
        group.fold<double>(0, (double sum, double width) => sum + width) +
        (group.length - 1) * photoToolbarControlGap,
  );
  return 2 * photoToolbarPadding + controls + (groups.length - 1) * _ruleWidth;
}

double _controlExtent(double content, double target) =>
    math.max(target, content + 2 * photoToolbarControlPadding);

double _labelControlWidth(String label, TextScaler scaler, double target) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: label, style: TypographyTokens.toolbarSans),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return _controlExtent(width, target);
}

Offset photoToolbarOffset({
  required Rect figure,
  required Rect surface,
  required Size bar,
}) {
  final double x = (figure.center.dx - bar.width / 2)
      .clamp(surface.left, math.max(surface.left, surface.right - bar.width))
      .toDouble();
  final double above = figure.top - photoToolbarGap - bar.height;
  if (above >= surface.top && above + bar.height <= surface.bottom) {
    return Offset(x, above);
  }
  final double below = figure.bottom + photoToolbarGap;
  if (below + bar.height <= surface.bottom) {
    return Offset(x, below);
  }
  return Offset(
    x,
    math.min(
      math.max(figure.top + photoToolbarGap, surface.top),
      math.max(surface.top, surface.bottom - bar.height),
    ),
  );
}

const double _glyphExtent = 14;
const double _sideGlyphExtent = 18;
const int _sideGlyphLines = 3;
const double _disabledOpacity = 0.4;
const double _focusRingWidth = 2;
const double _menuGap = 4;
const BorderRadius _controlRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusXs + 1),
);
const BorderRadius _barRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusSm),
);

typedef PhotoToolbarImporter = Future<List<String>> Function();

typedef _PhotoCommand =
    Transaction? Function(EditorState state, MdBlock photo);

MdBlock? _photoAt(EditorState state, int lineStart) {
  for (final MdBlock block in state.tree.blocks) {
    if (block.kind == MdBlockKind.photoLine &&
        block.sourceRange.start == lineStart) {
      return block;
    }
  }
  return null;
}

MdBlock? _photoByOrdinal(EditorState state, int ordinal) {
  final List<MdBlock> photos = <MdBlock>[
    for (final MdBlock block in state.tree.blocks)
      if (block.kind == MdBlockKind.photoLine) block,
  ];
  return ordinal >= 0 && ordinal < photos.length ? photos[ordinal] : null;
}

void _runOnPhoto(NotePhotoToolbarRequest request, _PhotoCommand command) {
  request.controller.applyCommand((EditorState state) {
    final MdBlock? photo = _photoAt(state, request.photoLineStart);
    return photo == null ? null : command(state, photo);
  });
}

class PhotoToolbarLayer extends StatelessWidget {
  const PhotoToolbarLayer({super.key, required this.request});

  final NotePhotoToolbarRequest request;

  @override
  Widget build(BuildContext context) {
    final Rect photoRect = request.photoRect;
    final Rect captionField = Rect.fromLTWH(
      photoRect.left,
      photoRect.bottom + photoFigureCaptionGap,
      photoRect.width,
      photoCaptionLineHeight(MediaQuery.textScalerOf(context)),
    );
    final EdgeInsets captionReach = photoCaptionFieldReach(
      lineHeight: captionField.height,
      roomAbove: photoFigureCaptionGap,
    );
    final Rect captionTarget = captionReach.inflateRect(captionField);
    final Rect withCaption = request.captionRect.isEmpty
        ? photoRect
        : photoRect.expandToInclude(request.captionRect);
    final Rect figure = request.captionOpen
        ? withCaption.expandToInclude(
            Rect.fromLTRB(
              captionField.left,
              captionField.top,
              captionField.right,
              math.max(
                captionField.bottom,
                captionTarget.bottom - photoToolbarGap - photoToolbarPadding,
              ),
            ),
          )
        : withCaption;
    final EditorState state = request.controller.state;
    final MdBlock? photo = _photoAt(state, request.photoLineStart);
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Rect surface = Rect.fromLTRB(
            request.surface.left,
            request.surface.top,
            request.surface.right,
            math.max(
              request.surface.top,
              math.min(
                request.surface.bottom,
                constraints.maxHeight - request.bottomInset,
              ),
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (figure.overlaps(surface))
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _PhotoToolbarLayout(
                      figure: figure,
                      surface: surface,
                    ),
                    child: PhotoToolbar(request: request),
                  ),
                ),
              if (request.captionOpen && photo != null)
                Positioned.fromRect(
                  rect: captionTarget,
                  child: PhotoCaptionField(
                    caption: MdPhotoLine.ofBlock(photo, state.source).caption,
                    width: captionField.width,
                    height: captionField.height,
                    reach: captionReach,
                    onCommit: (String caption) {
                      _runOnPhoto(
                        request,
                        (EditorState s, MdBlock p) =>
                            setPhotoCaption(s, p, caption),
                      );
                      request.onCloseCaption();
                      request.onReturnToEditor();
                    },
                    onCancel: () {
                      request.onCloseCaption();
                      request.onReturnToEditor();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoToolbarLayout extends SingleChildLayoutDelegate {
  const _PhotoToolbarLayout({required this.figure, required this.surface});

  final Rect figure;
  final Rect surface;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(surface.size);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      photoToolbarOffset(figure: figure, surface: surface, bar: childSize);

  @override
  bool shouldRelayout(_PhotoToolbarLayout oldDelegate) =>
      oldDelegate.figure != figure || oldDelegate.surface != surface;
}

class PhotoToolbar extends StatefulWidget {
  const PhotoToolbar({super.key, required this.request});

  final NotePhotoToolbarRequest request;

  @override
  State<PhotoToolbar> createState() => _PhotoToolbarState();
}

class _PhotoToolbarState extends State<PhotoToolbar> {
  final OverlayPortalController _menu = OverlayPortalController();
  final Object _menuGroup = Object();
  final GlobalKey _moreKey = GlobalKey();

  NotePhotoToolbarRequest get _request => widget.request;

  void _toggleMenu() {
    setState(() {
      if (_menu.isShowing) {
        _menu.hide();
      } else {
        _menu.show();
      }
    });
  }

  void _closeMenu() {
    if (!_menu.isShowing || !mounted) {
      return;
    }
    setState(_menu.hide);
  }

  void _remove() {
    final NotePhotoToolbarRequest request = _request;
    final EditorState before = request.controller.state;
    _runOnPhoto(
      request,
      (EditorState s, MdBlock p) => removePhoto(s, p).transaction,
    );
    final EditorState removedState = request.controller.state;
    if (identical(before, removedState) || !mounted) {
      return;
    }
    showTransientToast(
      context,
      photoRemovedMessage,
      glyph: IconStickerGlyph.trash,
      action: ToastAction(
        label: photoRemovedUndoLabel,
        semanticLabel: photoRemovedUndoSemanticLabel,
        onPressed: () {
          if (identical(request.controller.state, removedState)) {
            request.controller.undo();
          }
        },
      ),
    );
    request.onRemovalToastShown();
  }

  Future<void> _replace() async {
    final NotePhotoToolbarRequest request = _request;
    final PhotoToolbarImporter? pick = request.importer;
    if (pick == null) {
      return;
    }
    final List<String> picked;
    try {
      picked = await pick();
    } catch (error, stackTrace) {
      debugPrint('Replacing a photo in a note failed: $error\n$stackTrace');
      return;
    }
    if (picked.isEmpty) {
      return;
    }
    request.controller.applyCommand((EditorState state) {
      final MdBlock? photo = _photoByOrdinal(state, request.ordinal);
      return photo == null
          ? null
          : replacePhotoReference(state, photo, picked.first);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _closeMenu();
      _request.onReturnToEditor();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final NotePhotoToolbarRequest request = _request;
    final EditorState state = request.controller.state;
    final MdBlock? photo = _photoAt(state, request.photoLineStart);
    if (photo == null) {
      return const SizedBox.shrink();
    }
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double target = photoToolbarTargetFor(defaultTargetPlatform);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool placement = !request.phoneColumn;
        final bool moves =
            photoToolbarWidthFor(
              scaler: scaler,
              placement: placement,
              moves: true,
              target: target,
            ) <=
            constraints.maxWidth;
        final List<List<Widget>> groups = <List<Widget>>[
          if (placement) ...<List<Widget>>[
            _sizeControls(state, photo, target),
            _sideControls(state, photo, target),
          ],
          if (moves)
            _moveControls(state, photo, target)
          else
            <Widget>[_moreControl(state, photo, target)],
          <Widget>[
            _PhotoToolbarControl(
              controlKey: photoToolbarCaptionKey,
              label: photoToolbarCaptionLabel,
              target: target,
              onTap: request.onOpenCaption,
              child: _segmentLabel(photoToolbarCaptionLabel, selected: false),
            ),
          ],
          <Widget>[
            _PhotoToolbarControl(
              controlKey: photoToolbarRemoveKey,
              label: photoToolbarRemoveLabel,
              target: target,
              onTap: _remove,
              child: const IconStickerGlyphIcon(
                glyph: IconStickerGlyph.trash,
                color: Palette.toolbarLabel,
                size: _glyphExtent,
              ),
            ),
          ],
        ];
        final List<Widget> row = _withFirstFocus(<Widget>[
          for (int g = 0; g < groups.length; g++) ...<Widget>[
            if (g > 0) const _PhotoToolbarRule(),
            for (int c = 0; c < groups[g].length; c++) ...<Widget>[
              if (c > 0) const SizedBox(width: photoToolbarControlGap),
              groups[g][c],
            ],
          ],
        ]);
        return TextFieldTapRegion(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onKey,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: DecoratedBox(
                key: photoToolbarKey,
                decoration: const BoxDecoration(
                  color: Palette.toolbarInk,
                  borderRadius: _barRadius,
                  boxShadow: Shadows.toastLift,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(photoToolbarPadding),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: row,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _withFirstFocus(List<Widget> row) {
    final int first = row.indexWhere(
      (Widget w) => w is _PhotoToolbarFocusable,
    );
    if (first < 0) {
      return row;
    }
    final _PhotoToolbarFocusable control = row[first] as _PhotoToolbarFocusable;
    return <Widget>[
      ...row.sublist(0, first),
      control.withFocusNode(_request.firstControlFocusNode),
      ...row.sublist(first + 1),
    ];
  }

  List<Widget> _sizeControls(EditorState state, MdBlock photo, double target) {
    final MdPhotoPlacement placement = MdPhotoLine.ofBlock(
      photo,
      state.source,
    ).placement;
    return <Widget>[
      for (final MdPhotoSize size in MdPhotoSize.values)
        _placementControl(
          key: photoToolbarSizeKey(size),
          label: photoToolbarSizeLabel(size),
          target: target,
          marked: placement.isValid && placement.size == size,
          pressable: setPhotoSize(state, photo, size) != null,
          command: (EditorState s, MdBlock p) => setPhotoSize(s, p, size),
          child: _segmentLabel(
            size.shortLabel,
            selected: placement.isValid && placement.size == size,
          ),
        ),
    ];
  }

  List<Widget> _sideControls(EditorState state, MdBlock photo, double target) {
    final MdPhotoPlacement placement = MdPhotoLine.ofBlock(
      photo,
      state.source,
    ).placement;
    final MdPhotoSize size = placement.isValid
        ? placement.size
        : MdPhotoSize.medium;
    final bool floats = photoCanFloat(
      size: size,
      columnWidth: _request.columnWidth,
      em: _request.em,
    );
    final bool full = size == MdPhotoSize.full;
    return <Widget>[
      for (final MdPhotoSide side in MdPhotoSide.values)
        _placementControl(
          key: photoToolbarSideKey(side),
          label: photoToolbarSideLabel(side),
          hint: side != MdPhotoSide.centre && !floats
              ? photoToolbarNoFloatHint
              : null,
          target: target,
          marked: placement.isValid && !full && placement.side == side,
          pressable:
              !full &&
              (side == MdPhotoSide.centre || floats) &&
              setPhotoSide(state, photo, side) != null,
          command: (EditorState s, MdBlock p) => setPhotoSide(s, p, side),
          child: PhotoSideGlyph(
            side: side,
            selected: placement.isValid && !full && placement.side == side,
          ),
        ),
    ];
  }

  Widget _placementControl({
    required Key key,
    required String label,
    required double target,
    required bool marked,
    required bool pressable,
    required _PhotoCommand command,
    required Widget child,
    String? hint,
  }) {
    return _PhotoToolbarControl(
      controlKey: key,
      label: label,
      hint: hint,
      target: target,
      selected: marked,
      onTap: pressable ? () => _runOnPhoto(_request, command) : null,
      child: child,
    );
  }

  List<Widget> _moveControls(
    EditorState state,
    MdBlock photo,
    double target, {
    VoidCallback? after,
  }) {
    VoidCallback? run(VoidCallback? action) =>
        action == null ? null : () {
          after?.call();
          action();
        };
    return <Widget>[
      _PhotoToolbarControl(
        controlKey: photoToolbarMoveUpKey,
        label: photoToolbarMoveUpLabel,
        target: target,
        onTap: run(
          canMovePhotoUp(state, photo)
              ? () => _runOnPhoto(_request, movePhotoUp)
              : null,
        ),
        child: _glyph(_PhotoToolbarGlyph.up),
      ),
      _PhotoToolbarControl(
        controlKey: photoToolbarMoveDownKey,
        label: photoToolbarMoveDownLabel,
        target: target,
        onTap: run(
          canMovePhotoDown(state, photo)
              ? () => _runOnPhoto(_request, movePhotoDown)
              : null,
        ),
        child: _glyph(_PhotoToolbarGlyph.down),
      ),
      _PhotoToolbarControl(
        controlKey: photoToolbarReplaceKey,
        label: photoToolbarReplaceLabel,
        target: target,
        onTap: run(
          _request.importer == null ? null : () => unawaited(_replace()),
        ),
        child: _glyph(_PhotoToolbarGlyph.swap),
      ),
    ];
  }

  Widget _moreControl(EditorState state, MdBlock photo, double target) {
    return _PhotoToolbarMenuAnchor(
      groupId: _menuGroup,
      portalKey: _moreKey,
      controller: _menu,
      overlayChildBuilder: (BuildContext overlayContext) =>
          _menuPanel(state, photo, target),
      control: _PhotoToolbarControl(
        controlKey: photoToolbarMoreKey,
        label: photoToolbarMoreLabel,
        target: target,
        onTap: _toggleMenu,
        child: _glyph(_PhotoToolbarGlyph.more),
      ),
    );
  }

  Widget _menuPanel(EditorState state, MdBlock photo, double target) {
    final RenderBox? button =
        _moreKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null || !button.hasSize) {
      return const SizedBox.shrink();
    }
    final Rect anchor = MatrixUtils.transformRect(
      button.getTransformTo(overlay),
      Offset.zero & button.size,
    );
    final List<Widget> items = _moveControls(
      state,
      photo,
      target,
      after: _closeMenu,
    );
    return CustomSingleChildLayout(
      delegate: _MenuLayout(anchor: anchor),
      child: TextFieldTapRegion(
        child: TapRegion(
          groupId: _menuGroup,
          onTapOutside: (PointerDownEvent _) => _closeMenu(),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Palette.toolbarInk,
                borderRadius: _barRadius,
                boxShadow: Shadows.toastLift,
              ),
              child: Padding(
                padding: const EdgeInsets.all(photoToolbarPadding),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < items.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: photoToolbarControlGap),
                      items[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glyph(_PhotoToolbarGlyph glyph) => SizedBox.square(
    dimension: _glyphExtent,
    child: CustomPaint(
      painter: _PhotoToolbarGlyphPainter(
        glyph: glyph,
        color: Palette.toolbarLabel,
      ),
    ),
  );

  Widget _segmentLabel(String text, {required bool selected}) {
    return Text(
      text,
      style: TypographyTokens.toolbarSans.copyWith(
        color: selected ? Palette.onAccent : Palette.toolbarLabel,
      ),
    );
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({required this.anchor});

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double below = anchor.bottom + _menuGap;
    final double above = anchor.top - _menuGap - childSize.height;
    final double top = below + childSize.height <= size.height || above < 0
        ? below
        : above;
    final double left = anchor.center.dx - childSize.width / 2;
    return Offset(
      left.clamp(0, math.max(0, size.width - childSize.width)).toDouble(),
      top,
    );
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) => oldDelegate.anchor != anchor;
}

class _PhotoToolbarRule extends StatelessWidget {
  const _PhotoToolbarRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: photoToolbarGroupGap),
      child: SizedBox(
        width: 1,
        height: photoToolbarRuleHeight,
        child: ColoredBox(color: Palette.toolbarRule),
      ),
    );
  }
}

enum _PhotoToolbarGlyph { up, down, swap, more }

class _PhotoToolbarGlyphPainter extends CustomPainter {
  const _PhotoToolbarGlyphPainter({required this.glyph, required this.color});

  final _PhotoToolbarGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / 24);
    if (glyph == _PhotoToolbarGlyph.more) {
      final Paint fill = Paint()..color = color;
      for (final double x in <double>[5, 12, 19]) {
        canvas.drawCircle(Offset(x, 12), 2, fill);
      }
    } else {
      final Paint stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(_path(), stroke);
    }
    canvas.restore();
  }

  Path _path() {
    return switch (glyph) {
      _PhotoToolbarGlyph.up => Path()
        ..moveTo(12, 19)
        ..lineTo(12, 5)
        ..moveTo(6, 11)
        ..lineTo(12, 5)
        ..lineTo(18, 11),
      _PhotoToolbarGlyph.down => Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(6, 13)
        ..lineTo(12, 19)
        ..lineTo(18, 13),
      _PhotoToolbarGlyph.swap => Path()
        ..moveTo(4, 8)
        ..lineTo(19, 8)
        ..moveTo(15, 4)
        ..lineTo(19, 8)
        ..lineTo(15, 12)
        ..moveTo(20, 16)
        ..lineTo(5, 16)
        ..moveTo(9, 12)
        ..lineTo(5, 16)
        ..lineTo(9, 20),
      _PhotoToolbarGlyph.more => Path(),
    };
  }

  @override
  bool shouldRepaint(_PhotoToolbarGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

abstract interface class _PhotoToolbarFocusable {
  Widget withFocusNode(FocusNode node);
}

class _PhotoToolbarMenuAnchor extends StatelessWidget
    implements _PhotoToolbarFocusable {
  const _PhotoToolbarMenuAnchor({
    required this.groupId,
    required this.portalKey,
    required this.controller,
    required this.overlayChildBuilder,
    required this.control,
  });

  final Object groupId;
  final GlobalKey portalKey;
  final OverlayPortalController controller;
  final WidgetBuilder overlayChildBuilder;
  final _PhotoToolbarControl control;

  @override
  _PhotoToolbarMenuAnchor withFocusNode(FocusNode node) =>
      _PhotoToolbarMenuAnchor(
        groupId: groupId,
        portalKey: portalKey,
        controller: controller,
        overlayChildBuilder: overlayChildBuilder,
        control: control.withFocusNode(node),
      );

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: groupId,
      child: OverlayPortal(
        key: portalKey,
        controller: controller,
        overlayChildBuilder: overlayChildBuilder,
        child: control,
      ),
    );
  }
}

class _PhotoToolbarControl extends StatefulWidget
    implements _PhotoToolbarFocusable {
  const _PhotoToolbarControl({
    required this.controlKey,
    required this.label,
    required this.target,
    required this.child,
    required this.onTap,
    this.selected,
    this.hint,
    this.focusNode,
  });

  final Key controlKey;
  final String label;
  final double target;
  final Widget child;
  final VoidCallback? onTap;
  final bool? selected;
  final String? hint;
  final FocusNode? focusNode;

  @override
  _PhotoToolbarControl withFocusNode(FocusNode node) => _PhotoToolbarControl(
    controlKey: controlKey,
    label: label,
    target: target,
    onTap: onTap,
    selected: selected,
    hint: hint,
    focusNode: node,
    child: child,
  );

  @override
  State<_PhotoToolbarControl> createState() => _PhotoToolbarControlState();
}

class _PhotoToolbarControlState extends State<_PhotoToolbarControl> {
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
      enabled: enabled || marked,
      focusNode: widget.focusNode,
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
        hint: widget.hint,
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
                    horizontal: photoToolbarControlPadding,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Opacity(
                      opacity: enabled || marked ? 1 : _disabledOpacity,
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

class PhotoSideGlyph extends StatelessWidget {
  const PhotoSideGlyph({super.key, required this.side, required this.selected});

  final MdPhotoSide side;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _sideGlyphExtent,
      child: CustomPaint(
        painter: _PhotoSideGlyphPainter(
          side: side,
          color: selected ? Palette.onAccent : Palette.toastInk,
        ),
      ),
    );
  }
}

class _PhotoSideGlyphPainter extends CustomPainter {
  const _PhotoSideGlyphPainter({required this.side, required this.color});

  final MdPhotoSide side;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double block = size.width * 0.5;
    final double inset = size.height * 0.1;
    final Paint rule = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * 0.11;
    final double gap = (size.height - rule.strokeWidth) / (_sideGlyphLines - 1);
    if (side == MdPhotoSide.centre) {
      final double centreBlock = size.width * 0.44;
      final double left = (size.width - centreBlock) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, inset, centreBlock, size.height - 2 * inset),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
      final double reach = left - size.width * 0.1;
      final double y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(reach, y), rule);
      canvas.drawLine(
        Offset(size.width - reach, y),
        Offset(size.width, y),
        rule,
      );
      return;
    }
    final bool left = side == MdPhotoSide.left;
    final Rect picture = Rect.fromLTWH(
      left ? 0 : size.width - block,
      inset,
      block,
      size.height - 2 * inset,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(picture, const Radius.circular(2)),
      Paint()..color = color,
    );
    final double from = left ? block + size.width * 0.14 : 0;
    final double to = left
        ? size.width
        : size.width - block - size.width * 0.14;
    for (int i = 0; i < _sideGlyphLines; i++) {
      final double y = rule.strokeWidth / 2 + gap * i;
      canvas.drawLine(Offset(from, y), Offset(to, y), rule);
    }
  }

  @override
  bool shouldRepaint(_PhotoSideGlyphPainter oldDelegate) =>
      oldDelegate.side != side || oldDelegate.color != color;
}
