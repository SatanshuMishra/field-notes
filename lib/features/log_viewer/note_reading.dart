import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show parseNoteTree;
import 'package:field_notes/domain/notes/note_photos.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show
        MediaResolver,
        NoteBody,
        formatMediaDuration,
        logPreviewOf,
        logTypeLabelFor;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show
        logViewerEarlierKey,
        logViewerEarlierLabel,
        logViewerLaterKey,
        logViewerLaterLabel;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart'
    show entryClockOf;
import 'package:field_notes/features/log_viewer/photo_viewer.dart'
    show showPhotoViewer;
import 'package:field_notes/features/note_engine/capabilities.dart'
    show tablesEnabled;
import 'package:field_notes/features/notes/notes.dart' show NoteMediaScope;

const String _metaJoin = ' · ';
const double _metaSize = 11;
const double _metaLetterSpacing = 0.44;
const double _metaGap = 14;
const double _footerVerticalPadding = 10;
const double _footerHorizontalPadding = 14;
const double _stepGlyphGap = 6;
const double _absentStepOpacity = 0.35;
const double _phoneStepTarget = 48;
const double _desktopStepTarget = 48;
const double _noteRingOutset = 8;

const BorderRadius _stepBorderRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

const BorderRadius _noteRingRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusSm),
);

String logMetaFor(BuildContext context, Entry entry) {
  final int? durationMs = entry.durationMs;
  final List<String> parts = <String>[
    entryClockOf(context, entry),
    if (entry.type == EntryType.text) logPreviewOf(entry).meta,
    if (entry.type != EntryType.text && durationMs != null)
      formatMediaDuration(durationMs),
  ];
  return parts.where((String part) => part.isNotEmpty).join(_metaJoin);
}

class NoteReadingBody extends StatelessWidget {
  const NoteReadingBody({
    super.key,
    required this.entry,
    required this.resolver,
    required this.dayTitle,
    this.onToggleTask,
  });

  final Entry entry;
  final MediaResolver resolver;
  final String dayTitle;
  final ValueChanged<int>? onToggleTask;

  void _openPhoto(BuildContext context, int index) {
    showPhotoViewer(
      context,
      photos: notePhotosOf(
        parseNoteTree(entry.textContent ?? '', tables: tablesEnabled),
      ),
      initialIndex: index,
      dayTitle: dayTitle,
      resolver: resolver,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          logMetaFor(context, entry),
          style: context.textStyles.captureLabelSans.copyWith(
            fontSize: _metaSize,
            letterSpacing: _metaLetterSpacing,
            color: context.colors.muted,
          ),
        ),
        const SizedBox(height: _metaGap),
        KeyedSubtree(
          key: ValueKey<String>('log-viewer-content-${entry.id}'),
          child: _NoteFocusRing(
            child: NoteMediaScope(
              resolver: resolver,
              child: NoteBody(
                text: entry.textContent ?? '',
                onToggleTask: onToggleTask,
                onOpenPhoto: (int index) => _openPhoto(context, index),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LogStepFooter extends StatelessWidget {
  const LogStepFooter({
    super.key,
    required this.index,
    required this.count,
    required this.earlier,
    required this.later,
    required this.onEarlier,
    required this.onLater,
  });

  final int index;
  final int count;
  final Entry? earlier;
  final Entry? later;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final double target =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar
        ? _phoneStepTarget
        : _desktopStepTarget;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _footerHorizontalPadding),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _StepControl(
                key: logViewerEarlierKey,
                label: logViewerEarlierLabel,
                neighbour: earlier,
                pointsBack: true,
                target: target,
                onStep: onEarlier,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _footerVerticalPadding,
            ),
            child: Text(
              '${index + 1} of $count',
              style: context.textStyles.promptAccent,
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _StepControl(
                key: logViewerLaterKey,
                label: logViewerLaterLabel,
                neighbour: later,
                pointsBack: false,
                target: target,
                onStep: onLater,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepControl extends StatelessWidget {
  const _StepControl({
    super.key,
    required this.label,
    required this.neighbour,
    required this.pointsBack,
    required this.target,
    required this.onStep,
  });

  final String label;
  final Entry? neighbour;
  final bool pointsBack;
  final double target;
  final VoidCallback? onStep;

  @override
  Widget build(BuildContext context) {
    final Entry? next = neighbour;
    final VoidCallback? step = next == null ? null : onStep;
    final bool enabled = step != null;
    final String caption = next == null
        ? label
        : '${entryClockOf(context, next)}$_metaJoin'
              '${logTypeLabelFor(next.type)}';
    final FieldNotesColors colors = context.colors;
    final Widget glyph = ChevronGlyph(
      pointsBack: pointsBack,
      color: colors.ink,
    );
    final Widget text = Text(
      caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textStyles.captureLabelSans.copyWith(color: colors.ink),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: step,
      child: FocusRing(
        enabled: enabled,
        onPressed: step,
        borderRadius: _stepBorderRadius,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: step,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: target, minHeight: target),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _footerVerticalPadding,
                ),
                child: Opacity(
                  opacity: enabled ? 1 : _absentStepOpacity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: pointsBack
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: pointsBack
                        ? <Widget>[
                            glyph,
                            const SizedBox(width: _stepGlyphGap),
                            Flexible(child: text),
                          ]
                        : <Widget>[
                            Flexible(child: text),
                            const SizedBox(width: _stepGlyphGap),
                            glyph,
                          ],
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

class _NoteFocusRing extends StatefulWidget {
  const _NoteFocusRing({required this.child});

  final Widget child;

  @override
  State<_NoteFocusRing> createState() => _NoteFocusRingState();
}

class _NoteFocusRingState extends State<_NoteFocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChange(bool focused) {
    if (mounted && focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ringed =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          if (ringed)
            Positioned(
              left: -_noteRingOutset,
              top: -_noteRingOutset,
              right: -_noteRingOutset,
              bottom: -_noteRingOutset,
              child: IgnorePointer(
                key: focusRingKey,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.colors.ink,
                      width: FocusRingSurface.light.width,
                    ),
                    borderRadius: _noteRingRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
