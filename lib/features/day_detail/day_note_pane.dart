import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show LogActionsPill, MediaResolver, logActionsPillTapInset, logPreviewOf;
import 'package:field_notes/features/log_viewer/note_reading.dart';

const String dayNotePanePrompt = 'Choose a log to read it here.';
const String dayNotePaneHint =
    'Notes open on this side. Voice and video open full window.';
const String dayNotePaneEmptyTitle = 'Nothing logged this day yet.';
const String dayNotePaneEmptyHint = "Add a note to start the day's page.";

const Key dayNotePaneKey = ValueKey<String>('day-note-pane');

const double _flowerSize = 56;
const double _flowerGap = 16;
const double _placeholderLineGap = 6;
const EdgeInsets _placeholderPadding = EdgeInsets.all(32);
const double _readingEms = 34;
const double _ruleThickness = 1.5;
const double _actionButtonExtent = 30;
const double _headerVerticalPadding = 16;
const double _headerHorizontalPadding = 28;
const double _headerGap = 14;
const double _titleSize = 22;
const double _titleLineHeight = 1.05;
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(28, 18, 28, 24);

class DayNotePane extends StatelessWidget {
  const DayNotePane({
    super.key,
    required this.entries,
    required this.selected,
    required this.mood,
    required this.dayTitle,
    required this.resolver,
    required this.onEdit,
    required this.onDelete,
    required this.onStep,
    this.onToggleTask,
  });

  final List<Entry> entries;
  final Entry? selected;
  final Mood? mood;
  final String dayTitle;
  final MediaResolver? resolver;
  final ValueChanged<Entry> onEdit;
  final ValueChanged<Entry> onDelete;
  final ValueChanged<Entry> onStep;
  final ValueChanged<int>? onToggleTask;

  @override
  Widget build(BuildContext context) {
    final Entry? note = selected;
    final MediaResolver? media = resolver;
    return KeyedSubtree(
      key: dayNotePaneKey,
      child: note == null || media == null
          ? _placeholder(context)
          : _reading(context, note, media),
    );
  }

  Widget _placeholder(BuildContext context) {
    final Mood? mood = this.mood;
    final bool empty = entries.isEmpty;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return ClipRect(
      child: OverflowBox(
        maxHeight: double.infinity,
        child: Padding(
          padding: _placeholderPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (mood != null) ...<Widget>[
                ExcludeSemantics(
                  child: FlowerBloom.forMood(mood, size: _flowerSize),
                ),
                const SizedBox(height: _flowerGap),
              ],
              Text(
                empty ? dayNotePaneEmptyTitle : dayNotePanePrompt,
                textAlign: TextAlign.center,
                style: textStyles.sectionSerif,
              ),
              const SizedBox(height: _placeholderLineGap),
              Text(
                empty ? dayNotePaneEmptyHint : dayNotePaneHint,
                textAlign: TextAlign.center,
                style: textStyles.captionSans.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reading(BuildContext context, Entry note, MediaResolver media) {
    final Color rule = context.colors.ink25;
    final int index = entries.indexWhere((Entry entry) => entry.id == note.id);
    final Entry? earlier = index > 0 ? entries[index - 1] : null;
    final Entry? later = index >= 0 && index + 1 < entries.length
        ? entries[index + 1]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(context, note),
        DashedDivider(thickness: _ruleThickness, color: rule),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey<String>('day-note-pane-${note.id}'),
            padding: _bodyPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _readingEms * NoteColumn.emOf(context),
                ),
                child: NoteReadingBody(
                  entry: note,
                  resolver: media,
                  dayTitle: dayTitle,
                  onToggleTask: onToggleTask,
                ),
              ),
            ),
          ),
        ),
        if (index >= 0 && entries.length > 1) ...<Widget>[
          DashedDivider(thickness: _ruleThickness, color: rule),
          LogStepFooter(
            index: index,
            count: entries.length,
            earlier: earlier,
            later: later,
            onEarlier: earlier == null ? null : () => onStep(earlier),
            onLater: later == null ? null : () => onStep(later),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, Entry note) {
    final EdgeInsets reach = logActionsPillTapInset(
      buttonExtent: _actionButtonExtent,
      withEdit: true,
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: _headerHorizontalPadding,
        end: math.max<double>(0, _headerHorizontalPadding - reach.right),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                0,
                _headerVerticalPadding,
                math.max<double>(0, _headerGap - reach.left),
                _headerVerticalPadding,
              ),
              child: Text(
                logPreviewOf(note).heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.headlineSerif.copyWith(
                  fontSize: _titleSize,
                  height: _titleLineHeight,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: math.max<double>(0, _headerVerticalPadding - reach.top),
            ),
            child: LogActionsPill(
              buttonExtent: _actionButtonExtent,
              onEdit: () => onEdit(note),
              onDelete: () => onDelete(note),
            ),
          ),
        ],
      ),
    );
  }
}
