import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show LogActionsPill, MediaResolver, logActionsPillTapInset, logPreviewOf;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackKey;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart'
    show ViewerKeys;

const double _panelWidthShare = 0.62;
const double _readingEms = 34;
const double _headerVerticalPadding = 16;
const double _headerHorizontalPadding = 18;
const double _headerGap = 14;
const double _ruleThickness = 1.5;
const double _titleSize = 22;
const double _titleLineHeight = 1.05;
const double _exitPillHeight = 34;
const double _exitPillStartPadding = 8;
const double _exitPillEndPadding = 12;
const BorderRadius _exitPillBorderRadius = BorderRadius.all(
  Radius.circular(10),
);
const double _exitGlyphSize = 15;
const double _exitGlyphGap = 4;
const double _actionButtonExtent = 30;
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(38, 22, 38, 28);
const double _minTapTarget = 48;
const double _exitPillReach = (_minTapTarget - _exitPillHeight) / 2;

double notePanelWidthFor(double window) => clampDouble(
  window * _panelWidthShare,
  composerPanelWidth,
  composerPanelMaxWidth,
);

class _PanelResize extends StatefulWidget {
  const _PanelResize({required this.child});

  final Widget child;

  @override
  State<_PanelResize> createState() => _PanelResizeState();
}

class _PanelResizeState extends State<_PanelResize> {
  final GlobalKey _content = GlobalKey(debugLabel: 'note-panel-content');

  @override
  Widget build(BuildContext context) {
    final Widget content = KeyedSubtree(key: _content, child: widget.child);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return content;
    }
    return AnimatedSize(
      duration: Motion.modalPop,
      curve: Motion.entranceCurve,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

class NotePanelView extends StatelessWidget {
  const NotePanelView({
    super.key,
    required this.scene,
    required this.resolver,
    this.onToggleTask,
    this.editor,
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final ValueChanged<int>? onToggleTask;
  final Widget? editor;

  @override
  Widget build(BuildContext context) {
    return ComposerShell(
      maxWidth: notePanelWidthFor(MediaQuery.sizeOf(context).width),
      closeOnScrimTap: true,
      child: _PanelResize(
        child:
            editor ??
            ViewerKeys(
              onLeft: scene.onEarlier,
              onRight: scene.onLater,
              onEscape: scene.onBack,
              child: _reading(context),
            ),
      ),
    );
  }

  Widget _reading(BuildContext context) {
    final Color rule = context.colors.ink25;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(context),
        DashedDivider(thickness: _ruleThickness, color: rule),
        Flexible(
          child: SingleChildScrollView(
            padding: _bodyPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _readingEms * NoteColumn.emOf(context),
                ),
                child: NoteReadingBody(
                  entry: scene.entry,
                  resolver: resolver,
                  dayTitle: scene.dayTitle,
                  onToggleTask: onToggleTask,
                ),
              ),
            ),
          ),
        ),
        if (scene.count > 1) ...<Widget>[
          DashedDivider(thickness: _ruleThickness, color: rule),
          LogStepFooter(
            index: scene.index,
            count: scene.count,
            earlier: scene.earlier,
            later: scene.later,
            onEarlier: scene.onEarlier,
            onLater: scene.onLater,
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context) {
    final VoidCallback? onEdit = scene.onEdit;
    final EdgeInsets reach = logActionsPillTapInset(
      buttonExtent: _actionButtonExtent,
      withEdit: onEdit != null,
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: _headerHorizontalPadding,
        end: math.max<double>(0, _headerHorizontalPadding - reach.right),
      ),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _headerVerticalPadding - _exitPillReach,
            ),
            child: _ExitPill(
              key: logViewerBackKey,
              label: scene.exitLabel,
              onPressed: scene.onBack,
            ),
          ),
          Expanded(
            child: _titleBlock(
              context,
              endGap: math.max<double>(0, _headerGap - reach.left),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: math.max<double>(0, _headerVerticalPadding - reach.top),
            ),
            child: LogActionsPill(
              buttonExtent: _actionButtonExtent,
              onEdit: onEdit,
              onDelete: scene.onDelete,
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleBlock(BuildContext context, {required double endGap}) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        _headerGap,
        _headerVerticalPadding,
        endGap,
        _headerVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            scene.dayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyles.stampAccent.copyWith(
              color: context.colors.accentInk,
            ),
          ),
          Text(
            logPreviewOf(scene.entry).heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyles.headlineSerif.copyWith(
              fontSize: _titleSize,
              height: _titleLineHeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitPill extends StatelessWidget {
  const _ExitPill({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            child: FocusRing(
              onPressed: onPressed,
              borderRadius: _exitPillBorderRadius,
              child: Container(
                height: _exitPillHeight,
                padding: const EdgeInsets.only(
                  left: _exitPillStartPadding,
                  right: _exitPillEndPadding,
                ),
                decoration: BoxDecoration(
                  color: colors.cardWarm,
                  border: shadows.outline,
                  borderRadius: _exitPillBorderRadius,
                  boxShadow: shadows.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ChevronGlyph(
                      pointsBack: true,
                      color: colors.ink,
                      size: _exitGlyphSize,
                    ),
                    const SizedBox(width: _exitGlyphGap),
                    Text(
                      label,
                      style: context.textStyles.captureLabelSans.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
