import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/notes/note_photos.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

const String photoViewerPreviousLabel = 'Previous';
const String photoViewerBackLabel = 'Back to note';
const String photoViewerNextLabel = 'Next';

const String _barrierLabel = 'Dismiss photo viewer';
const String _photoLabel = 'Photo';
const String _quietJoin = ' · ';
const Color _clearBarrier = Color(0x00000000);

const double _glyphSize = 15;
const double _dockCircle = 48;
const double _capsuleCircle = 40;
const double _capsuleTextGap = 14;

const EdgeInsets _macPhotoInset = EdgeInsets.fromLTRB(24, 56, 24, 84);
const double _macCapsuleBottom = 24;

const double _phoneQuietTop = 16;
const double _phoneQuietSide = 18;

Future<void> showPhotoViewer(
  BuildContext context, {
  required List<NotePhoto> photos,
  required int initialIndex,
  required String dayTitle,
  required MediaResolver resolver,
}) {
  playbackFocus.silence();
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: _barrierLabel,
    barrierColor: _clearBarrier,
    transitionDuration: still ? Duration.zero : Motion.fade,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return DialogHost(
            child: PhotoViewer(
              photos: photos,
              initialIndex: initialIndex,
              dayTitle: dayTitle,
              resolver: resolver,
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Motion.fadeCurve,
            ),
            child: child,
          );
        },
  );
}

String photoViewerQuietLine({
  required NotePhoto photo,
  required int index,
  required int count,
  required String dayTitle,
}) {
  final String caption = photo.caption.trim();
  return <String>[
    if (caption.isNotEmpty) caption,
    if (count > 1) photoViewerPosition(index: index, count: count),
    dayTitle,
  ].join(_quietJoin);
}

String photoViewerPosition({required int index, required int count}) =>
    '${index + 1} of $count';

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.dayTitle,
    required this.resolver,
  });

  final List<NotePhoto> photos;
  final int initialIndex;
  final String dayTitle;
  final MediaResolver resolver;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _index = _clamped(widget.initialIndex);
  bool _overlaysHidden = false;
  bool _controlFocused = false;

  int get _count => widget.photos.length;

  int get _shown => _clamped(_index);

  bool get _hasPrevious => _shown > 0;

  bool get _hasNext => _shown < _count - 1;

  int _clamped(int index) => math.max(0, math.min(index, _count - 1));

  void _previous() {
    if (_hasPrevious) {
      setState(() => _index = _shown - 1);
    }
  }

  void _next() {
    if (_hasNext) {
      setState(() => _index = _shown + 1);
    }
  }

  void _back() {
    Navigator.of(context).maybePop();
  }

  bool get _overlaysPinned =>
      _controlFocused || MediaQuery.accessibleNavigationOf(context);

  void _toggleOverlays() {
    if (_overlaysPinned) {
      return;
    }
    setState(() => _overlaysHidden = !_overlaysHidden);
  }

  void _overlayFocusChanged(bool focused) {
    if (focused != _controlFocused) {
      setState(() => _controlFocused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool sidebar =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.sidebar;
    return ViewerKeys(
      onLeft: _previous,
      onRight: _next,
      onEscape: _back,
      child: ViewerStage(
        ground: ViewerGround.media,
        onSwipeNext: _next,
        onSwipePrevious: _previous,
        child: _count == 0
            ? const SizedBox.expand()
            : sidebar
            ? _macLayout(context)
            : _phoneLayout(context),
      ),
    );
  }

  NotePhoto get _photo => widget.photos[_shown];

  String get _quiet => photoViewerQuietLine(
    photo: _photo,
    index: _shown,
    count: _count,
    dayTitle: widget.dayTitle,
  );

  Widget _picture() {
    final NotePhoto photo = _photo;
    final String caption = photo.caption.trim();
    return Semantics(
      image: true,
      label: caption.isEmpty ? _photoLabel : caption,
      child: ExcludeSemantics(
        child: MediaImage(
          resolver: widget.resolver,
          mediaId: photo.reference,
          errorLabel: _photoLabel,
          fit: BoxFit.contain,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }

  Widget _phoneLayout(BuildContext context) {
    final bool visible = !_overlaysHidden || _overlaysPinned;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final double statusBar = MediaQuery.viewPaddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _toggleOverlays,
          child: _picture(),
        ),
        AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: still ? Duration.zero : Motion.fade,
          curve: Motion.fadeCurve,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            includeSemantics: false,
            onFocusChange: _overlayFocusChanged,
            child: IgnorePointer(
              ignoring: !visible,
              child: ExcludeSemantics(
                excluding: !visible,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const ViewerOverlayShade(top: true),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        _phoneQuietSide,
                        statusBar + _phoneQuietTop,
                        _phoneQuietSide,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ViewerQuietLine(text: _quiet),
                      ),
                    ),
                    ViewerDock(slots: _dockSlots()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<ViewerDockSlot?> _dockSlots() {
    return <ViewerDockSlot?>[
      _hasPrevious
          ? ViewerDockSlot(
              label: photoViewerPreviousLabel,
              control: _stepCircle(back: true),
            )
          : null,
      ViewerDockSlot(
        label: photoViewerBackLabel,
        control: ViewerGlassCircle(
          label: photoViewerBackLabel,
          glyph: const IconStickerGlyphIcon(
            glyph: IconStickerGlyph.close,
            color: Palette.mediaInk,
            size: _glyphSize,
          ),
          onPressed: _back,
        ),
      ),
      _hasNext
          ? ViewerDockSlot(
              label: photoViewerNextLabel,
              control: _stepCircle(back: false),
            )
          : null,
    ];
  }

  Widget _stepCircle({required bool back, double face = _dockCircle}) {
    return ViewerGlassCircle(
      label: back ? photoViewerPreviousLabel : photoViewerNextLabel,
      face: face,
      glyph: ChevronGlyph(
        pointsBack: back,
        color: Palette.mediaInk,
        size: _glyphSize,
      ),
      onPressed: back ? _previous : _next,
    );
  }

  Widget _macLayout(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Padding(padding: _macPhotoInset, child: _picture()),
        ViewerTopBar(
          exitLabel: photoViewerBackLabel,
          onExit: _back,
          centre: ViewerQuietLine(text: _quiet),
        ),
        if (_count > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: _macCapsuleBottom),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ViewerCapsule(
                children: <Widget>[
                  _capsuleSlot(back: true, present: _hasPrevious),
                  const SizedBox(width: _capsuleTextGap),
                  Text(
                    photoViewerPosition(index: _shown, count: _count),
                    maxLines: 1,
                    style: context.textStyles.labelSans.copyWith(
                      color: Palette.mediaInk,
                    ),
                  ),
                  const SizedBox(width: _capsuleTextGap),
                  _capsuleSlot(back: false, present: _hasNext),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _capsuleSlot({required bool back, required bool present}) {
    return SizedBox.square(
      dimension: _capsuleCircle,
      child: present ? _stepCircle(back: back, face: _capsuleCircle) : null,
    );
  }
}
