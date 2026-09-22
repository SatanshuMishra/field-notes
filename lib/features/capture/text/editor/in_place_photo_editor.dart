import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';

import 'markdown_style_controller.dart';
import 'note_editor.dart';
import 'photo_bands.dart';
import 'photo_line_keys.dart';
import 'single_field_note_editor.dart';

const double photoBandPadding = 12;
const double inPlacePhotoRingWidth = 2.5;
const double inPlacePhotoFallbackAspect = 4 / 3;
const Color _hiddenCaret = Color(0x00000000);
const double _ringInset = 4;

Key inPlacePhotoKey(int ordinal) => ValueKey<String>('in-place-photo-$ordinal');

const Key inPlacePhotoRingKey = ValueKey<String>('in-place-photo-ring');

class ComposerMediaScope extends InheritedWidget {
  const ComposerMediaScope({
    super.key,
    required this.resolver,
    required super.child,
  });

  final MediaResolver? resolver;

  static MediaResolver? maybeResolverOf(BuildContext context) {
    final ComposerMediaScope? scope =
        context.dependOnInheritedWidgetOfExactType<ComposerMediaScope>();
    return scope == null
        ? NoteMediaScope.maybeResolverOf(context)
        : scope.resolver;
  }

  @override
  bool updateShouldNotify(ComposerMediaScope oldWidget) =>
      !identical(resolver, oldWidget.resolver);
}

@immutable
class InPlacePhoto {
  const InPlacePhoto({
    required this.line,
    required this.plan,
    required this.media,
    required this.photoHeight,
    required this.figureSize,
    required this.alignX,
  });

  final NotePhotoLine line;
  final PhotoPlan plan;
  final ResolvedMedia? media;
  final double photoHeight;
  final Size figureSize;
  final double alignX;

  double get band => figureSize.height + 2 * photoBandPadding;

  PhotoBand get photoBand =>
      PhotoBand(start: line.lineStart, end: line.lineEnd, height: band);
}

List<InPlacePhoto> inPlacePhotosFor(
  String text, {
  required double measure,
  required double em,
  required TextScaler scaler,
  MediaResolver? resolver,
}) {
  return <InPlacePhoto>[
    for (final NotePhotoLine line in notePhotoLines(text))
      _inPlacePhoto(line, measure, em, scaler, resolver),
  ];
}

InPlacePhoto _inPlacePhoto(
  NotePhotoLine line,
  double measure,
  double em,
  TextScaler scaler,
  MediaResolver? resolver,
) {
  final PhotoPlacement placement = line.placement;
  final ResolvedMedia? media = resolver?.resolved(line.reference);
  final MediaBlob? blob = media?.blob;
  final PhotoPlan plan = planFloat(
    measure: measure,
    em: em,
    side: placement.side,
    size: placement.size,
    aspect: photoAspectOf(blob?.width, blob?.height) ??
        inPlacePhotoFallbackAspect,
    nextIsParagraph: line.wrapsParagraph && placement.isValid,
  );
  final double photoHeight = media != null && !media.isAvailable
      ? notePhotoUnavailableHeight
      : plan.height;
  final double caption = line.caption.isEmpty
      ? 0
      : notePhotoCaptionGap + _captionHeight(line.caption, plan.width, scaler);
  return InPlacePhoto(
    line: line,
    plan: plan,
    media: media,
    photoHeight: photoHeight,
    figureSize: Size(plan.width, photoHeight + caption),
    alignX: plan.isStacked
        ? 0.5
        : placement.side == PhotoSide.left
            ? 0
            : 1,
  );
}

double _captionHeight(String caption, double width, TextScaler scaler) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: caption, style: notePhotoCaptionStyle),
    textAlign: notePhotoCaptionAlign,
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout(maxWidth: width);
  final double height = painter.height;
  painter.dispose();
  return height;
}

class InPlacePhotoEditor extends NoteEditor {
  const InPlacePhotoEditor({super.key, required super.config});

  @override
  Widget build(BuildContext context) => _InPlacePhotoField(config: config);
}

class _InPlacePhotoField extends StatefulWidget {
  const _InPlacePhotoField({required this.config});

  final NoteEditorConfig config;

  @override
  State<_InPlacePhotoField> createState() => _InPlacePhotoFieldState();
}

class _InPlacePhotoFieldState extends State<_InPlacePhotoField> {
  final GlobalKey _fieldKey = GlobalKey();
  final GlobalKey _flowKey = GlobalKey();
  final Set<String> _resolving = <String>{};

  NoteEditorConfig get _config => widget.config;

  MarkdownStyleController get _controller => _config.controller;

  @override
  Widget build(BuildContext context) {
    final MediaResolver? resolver = ComposerMediaScope.maybeResolverOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double em = scaler.scale(
      _config.style.fontSize ?? TypographyTokens.noteBody.fontSize!,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (BuildContext context, TextEditingValue value, Widget? _) {
            final List<InPlacePhoto> photos = inPlacePhotosFor(
              value.text,
              measure: constraints.maxWidth,
              em: em,
              scaler: scaler,
              resolver: resolver,
            );
            _resolveMissing(photos, resolver);
            return _PhotoKeys(
              controller: _controller,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _hint(value),
                  PhotoBandScope(
                    bands: <PhotoBand>[
                      for (final InPlacePhoto photo in photos) photo.photoBand,
                    ],
                    child: KeyedSubtree(
                      key: _fieldKey,
                      child: noteTextField(
                        context,
                        _config,
                        cursorColor: _caretOnPhoto(photos, value.selection)
                            ? _hiddenCaret
                            : null,
                        inputFormatters: const <TextInputFormatter>[
                          PhotoLineGuard(),
                        ],
                        strutStyle: StrutStyle.fromTextStyle(
                          unmergedFromTheMaterialTextTheme(_config.style),
                          forceStrutHeight: false,
                        ),
                        selectionHeightStyle: BoxHeightStyle.max,
                      ),
                    ),
                  ),
                  if (photos.isNotEmpty)
                    Positioned.fill(
                      child: TextFieldTapRegion(
                        child: Flow(
                          key: _flowKey,
                          delegate: _PhotoFlowDelegate(
                            photos: photos,
                            fieldKey: _fieldKey,
                            flowKey: _flowKey,
                            repaint: Listenable.merge(<Listenable>[
                              _controller,
                              _config.scrollController,
                            ]),
                          ),
                          children: <Widget>[
                            for (final InPlacePhoto photo in photos)
                              _InPlaceFigure(
                                key: inPlacePhotoKey(photo.line.ordinal),
                                photo: photo,
                                resolver: resolver,
                                selected: selectionTouchesPhoto(
                                  photo.line,
                                  value.selection,
                                ),
                                onTap: () => _select(photo.line.ordinal),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _hint(TextEditingValue value) {
    return IgnorePointer(
      child: value.text.isEmpty
          ? Text(_config.hintText, style: _config.hintStyle)
          : const SizedBox.shrink(),
    );
  }

  bool _caretOnPhoto(List<InPlacePhoto> photos, TextSelection selection) {
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }
    return photos.any(
      (InPlacePhoto photo) => photo.line.containsOffset(selection.baseOffset),
    );
  }

  void _select(int ordinal) {
    final TextEditingValue value = _controller.value;
    final List<NotePhotoLine> lines = notePhotoLines(value.text);
    if (ordinal >= lines.length) {
      return;
    }
    _config.focusNode.requestFocus();
    _controller.value = selectPhotoLine(value, lines[ordinal]);
  }

  void _resolveMissing(List<InPlacePhoto> photos, MediaResolver? resolver) {
    if (resolver == null) {
      return;
    }
    for (final InPlacePhoto photo in photos) {
      final String reference = photo.line.reference;
      if (photo.media != null || !_resolving.add(reference)) {
        continue;
      }
      resolver.resolve(reference).whenComplete(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }
}

class _PhotoKeys extends StatelessWidget {
  const _PhotoKeys({required this.controller, required this.child});

  final TextEditingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Actions(
        actions: <Type, Action<Intent>>{
          DeleteCharacterIntent: _PhotoDeleteAction(controller),
          ExtendSelectionByCharacterIntent: _PhotoStepAction(controller),
        },
        child: child,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final TextEditingValue? next = deselectPhoto(controller.value);
    if (next == null) {
      return KeyEventResult.ignored;
    }
    controller.value = next;
    return KeyEventResult.handled;
  }
}

class _PhotoDeleteAction extends ContextAction<DeleteCharacterIntent> {
  _PhotoDeleteAction(this.controller);

  final TextEditingController controller;

  @override
  Object? invoke(DeleteCharacterIntent intent, [BuildContext? context]) {
    final TextEditingValue? next =
        photoAwareDelete(controller.value, forward: intent.forward);
    if (next == null) {
      return callingAction?.invoke(intent);
    }
    controller.value = next;
    return null;
  }
}

class _PhotoStepAction extends ContextAction<ExtendSelectionByCharacterIntent> {
  _PhotoStepAction(this.controller);

  final TextEditingController controller;

  @override
  Object? invoke(
    ExtendSelectionByCharacterIntent intent, [
    BuildContext? context,
  ]) {
    final TextEditingValue? next = photoAwareStep(
      controller.value,
      forward: intent.forward,
      collapse: intent.collapseSelection,
    );
    if (next == null) {
      return callingAction?.invoke(intent);
    }
    controller.value = next;
    return null;
  }
}

class _PhotoFlowDelegate extends FlowDelegate {
  _PhotoFlowDelegate({
    required this.photos,
    required this.fieldKey,
    required this.flowKey,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<InPlacePhoto> photos;
  final GlobalKey fieldKey;
  final GlobalKey flowKey;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    return BoxConstraints.tight(photos[i].figureSize);
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final RenderEditable? editable =
        _editableUnder(fieldKey.currentContext?.findRenderObject());
    final RenderObject? flow = flowKey.currentContext?.findRenderObject();
    if (editable == null || flow is! RenderBox || !editable.hasSize) {
      return;
    }
    final Offset origin = flow.globalToLocal(
      editable.localToGlobal(Offset.zero),
    );
    final int length = editable.plainText.length;
    for (int i = 0; i < photos.length; i++) {
      final InPlacePhoto photo = photos[i];
      final int start = photo.line.lineStart;
      if (start >= length) {
        continue;
      }
      final List<TextBox> boxes = editable.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + 1),
      );
      if (boxes.isEmpty) {
        continue;
      }
      final double top = boxes.first.top + photoBandPadding;
      final double left =
          (context.size.width - photo.figureSize.width) * photo.alignX;
      context.paintChild(
        i,
        transform: Matrix4.translationValues(
          origin.dx + left,
          origin.dy + top,
          0,
        ),
      );
    }
  }

  @override
  bool shouldRelayout(_PhotoFlowDelegate oldDelegate) {
    if (oldDelegate.photos.length != photos.length) {
      return true;
    }
    for (int i = 0; i < photos.length; i++) {
      if (oldDelegate.photos[i].figureSize != photos[i].figureSize) {
        return true;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(_PhotoFlowDelegate oldDelegate) => true;
}

RenderEditable? _editableUnder(RenderObject? root) {
  if (root == null) {
    return null;
  }
  if (root is RenderEditable) {
    return root;
  }
  RenderEditable? found;
  root.visitChildren((RenderObject child) {
    found ??= _editableUnder(child);
  });
  return found;
}

class _InPlaceFigure extends StatelessWidget {
  const _InPlaceFigure({
    super.key,
    required this.photo,
    required this.resolver,
    required this.selected,
    required this.onTap,
  });

  final InPlacePhoto photo;
  final MediaResolver? resolver;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DefaultTextStyle(
          style: notePhotoCaptionStyle,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _figure(),
              if (selected)
                Positioned(
                  left: -_ringInset,
                  top: -_ringInset,
                  width: photo.plan.width + 2 * _ringInset,
                  height: photo.photoHeight + 2 * _ringInset,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      key: inPlacePhotoRingKey,
                      decoration: BoxDecoration(
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: Palette.coral,
                            width: inPlacePhotoRingWidth,
                          ),
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(Shapes.radiusSm),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _figure() {
    final MediaResolver? resolver = this.resolver;
    if (resolver == null) {
      return SizedBox(
        width: photo.plan.width,
        height: photo.photoHeight,
        child: const NeutralMediaPlaceholder(
          borderRadius: BorderRadius.zero,
        ),
      );
    }
    return NotePhotoFigure(
      block: photo.line.block,
      resolver: resolver,
      media: photo.media,
      plan: photo.plan,
    );
  }
}
