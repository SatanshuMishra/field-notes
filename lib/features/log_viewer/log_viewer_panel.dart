import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart'
    show composerPanelKey;
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/task_toggle.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/note_panel_view.dart';
import 'package:field_notes/features/log_viewer/note_sheet_view.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import 'log_viewer.dart';

const Key logViewerPanelKey = ValueKey<String>('log-viewer-panel');
const Key logViewerEarlierKey = ValueKey<String>('log-viewer-earlier');
const Key logViewerLaterKey = ValueKey<String>('log-viewer-later');
const Key logViewerBackKey = ValueKey<String>('log-viewer-back');

const String logViewerDeleteTitle = 'Delete this entry?';
const String logViewerDeleteLabel = 'Delete';
const String logViewerDeletedMessage = 'Entry deleted';
const String logViewerDeleteFailedMessage =
    "Couldn't delete that entry. Please try again.";
const String logViewerEarlierLabel = 'Earlier log';
const String logViewerLaterLabel = 'Later log';
const String logViewerBackLabel = 'Back';
const String logViewerCloseLabel = 'Close';

String logViewerDeleteMessageFor(String place) =>
    'This log will be removed from $place. This can’t be undone.';

final Animatable<Offset> _sheetRise = Tween<Offset>(
  begin: const Offset(0, 1),
  end: Offset.zero,
).chain(CurveTween(curve: phoneSheetCurve));

class LogViewerPanel extends ConsumerStatefulWidget {
  const LogViewerPanel({
    super.key,
    required this.date,
    required this.entryId,
    required this.exit,
    this.onReadNote,
  });

  final String date;
  final String entryId;
  final LogViewerExit exit;
  final ValueChanged<String>? onReadNote;

  @override
  ConsumerState<LogViewerPanel> createState() => _LogViewerPanelState();
}

class _LogViewerPanelState extends ConsumerState<LogViewerPanel> {
  late String _entryId = widget.entryId;
  bool _editing = false;
  bool _noteExpanded = false;
  bool _deleting = false;
  bool _left = false;
  int _viewGeneration = 0;
  int? _scrimPointer;

  bool get _sidebar =>
      resolveShellLayout(Theme.of(context).platform) == ShellLayout.sidebar;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    final int pointer = event.pointer;
    if (pointer != _scrimPointer) {
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      Timer.run(() {
        if (_scrimPointer == pointer) {
          _scrimPointer = null;
        }
      });
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_landsOnScrim(event.position)) {
      _scrimPointer = event.pointer;
    }
  }

  bool _landsOnScrim(Offset position) {
    RenderBox? panel;
    void visit(Element element) {
      if (panel != null) {
        return;
      }
      if (element.widget.key == composerPanelKey) {
        final RenderObject? box = element.renderObject;
        if (box is RenderBox && box.hasSize) {
          panel = box;
        }
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    final RenderBox? found = panel;
    if (found == null) {
      return false;
    }
    return !(Offset.zero & found.size).contains(found.globalToLocal(position));
  }

  void _leave(LogViewerOutcome outcome) {
    if (!mounted || _left) {
      return;
    }
    _left = true;
    Navigator.of(context).pop(outcome);
  }

  void _back() => _leave(LogViewerOutcome.returned);

  void _closeAll() => _leave(LogViewerOutcome.closedAll);

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop || _editing) {
      return;
    }
    _leave(
      _scrimPointer == null
          ? LogViewerOutcome.returned
          : LogViewerOutcome.closedAll,
    );
  }

  List<Entry>? _currentEntries() =>
      ref.read(entriesForDateProvider(widget.date)).value;

  int _indexIn(List<Entry> entries) =>
      entries.indexWhere((Entry entry) => entry.id == _entryId);

  void _earlier() => _step(-1);

  void _later() => _step(1);

  void _step(int delta) {
    final List<Entry>? entries = _currentEntries();
    if (entries == null || _left) {
      return;
    }
    final int index = _indexIn(entries);
    final int target = index + delta;
    if (index < 0 || target < 0 || target >= entries.length) {
      return;
    }
    final Entry next = entries[target];
    final ValueChanged<String>? onReadNote = widget.onReadNote;
    if (onReadNote != null && _sidebar && next.type == EntryType.text) {
      _leave(LogViewerOutcome.returned);
      onReadNote(next.id);
      return;
    }
    setState(() => _entryId = next.id);
  }

  void _edit(Entry entry) {
    if (_editing || _left) {
      return;
    }
    if (_sidebar) {
      setState(() => _editing = true);
      return;
    }
    unawaited(_editInComposer(entry));
  }

  Future<void> _editInComposer(Entry entry) async {
    setState(() => _editing = true);
    final bool? saved = await showEditNote(
      context,
      entry: entry,
      date: widget.date,
      exit: ComposerExit.back,
    );
    _onEditDone(saved ?? false);
  }

  void _onNoteExpandedChanged(bool expanded) {
    if (mounted && expanded != _noteExpanded) {
      setState(() => _noteExpanded = expanded);
    }
  }

  void _onEditDone(bool saved) {
    if (!mounted) {
      return;
    }
    setState(() {
      _editing = false;
      _viewGeneration += 1;
    });
  }

  Future<void> _delete(Entry entry) async {
    if (_deleting || _left) {
      return;
    }
    _deleting = true;
    final DateTime? day = parseDateKey(widget.date);
    final String place = day == null
        ? widget.date
        : dayShortLabelFor(day, today: ref.read(todayClockProvider)());
    final bool confirmed = await showConfirmDialog(
      context,
      title: logViewerDeleteTitle,
      message: logViewerDeleteMessageFor(place),
      confirmLabel: logViewerDeleteLabel,
      danger: true,
    );
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      setState(() => _deleting = false);
      return;
    }
    try {
      await ref.read(journalRepositoryProvider).softDeleteEntry(entry.id);
    } catch (error, stackTrace) {
      debugPrint('Log delete failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      showTransientToast(context, logViewerDeleteFailedMessage);
      return;
    }
    if (!mounted) {
      return;
    }
    showTransientToast(context, logViewerDeletedMessage);
    _leave(LogViewerOutcome.deleted);
  }

  void _leaveIfRemoved(List<Entry>? entries) {
    if (entries == null || _deleting || _left || _indexIn(entries) >= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      final List<Entry>? latest = _currentEntries();
      if (mounted && !_deleting && latest != null && _indexIn(latest) < 0) {
        _leave(LogViewerOutcome.returned);
      }
    });
  }

  String _dayTitle() {
    final DateTime? day = parseDateKey(widget.date);
    return day == null
        ? widget.date
        : dayTitleFor(day, today: ref.watch(todayClockProvider)());
  }

  @override
  Widget build(BuildContext context) {
    final List<Entry>? entries = ref
        .watch(entriesForDateProvider(widget.date))
        .value;
    _leaveIfRemoved(entries);
    final int index = entries == null ? -1 : _indexIn(entries);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Listener(
        onPointerDown: _onPointerDown,
        child: SizedBox.expand(
          key: logViewerPanelKey,
          child: index < 0
              ? null
              : KeyedSubtree(
                  key: ValueKey<int>(_viewGeneration),
                  child: _view(entries!, index),
                ),
        ),
      ),
    );
  }

  Widget _view(List<Entry> entries, int index) {
    final MediaResolver? resolver = ref.watch(notesMediaResolverProvider).value;
    if (resolver == null) {
      return const SizedBox.shrink();
    }
    final LogViewerScene scene = _sceneFor(entries, index);
    switch (scene.entry.type) {
      case EntryType.voice:
        return VoicePlayerView(
          scene: scene,
          resolver: resolver,
          playerFactory: ref.watch(todayAudioPlayerFactoryProvider),
        );
      case EntryType.video:
        return VideoViewerView(
          scene: scene,
          resolver: resolver,
          playerFactory: ref.watch(todayVideoPlayerFactoryProvider),
          slots: ref.watch(videoSlotsProvider),
        );
      case EntryType.text:
        return _sidebar
            ? _notePanel(scene, resolver)
            : _noteSheet(scene, resolver);
    }
  }

  LogViewerScene _sceneFor(List<Entry> entries, int index) {
    final Entry entry = entries[index];
    final Entry? earlier = index > 0 ? entries[index - 1] : null;
    final Entry? later = index + 1 < entries.length ? entries[index + 1] : null;
    return LogViewerScene(
      entry: entry,
      date: widget.date,
      dayTitle: _dayTitle(),
      mood: ref.watch(dayForDateProvider(widget.date)).value?.mood,
      index: index,
      count: entries.length,
      earlier: earlier,
      later: later,
      exit: widget.exit,
      onBack: _back,
      onEarlier: earlier == null ? null : _earlier,
      onLater: later == null ? null : _later,
      onDelete: () => _delete(entry),
      onEdit: entry.type == EntryType.text ? () => _edit(entry) : null,
    );
  }

  ValueChanged<int> _toggleTaskOf(Entry entry) {
    return (int boxOffset) => toggleTaskWithUndo(
      context,
      entry: entry,
      date: widget.date,
      boxOffset: boxOffset,
    );
  }

  Widget _noteSheet(LogViewerScene scene, MediaResolver resolver) {
    final Animation<double> appear =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _closeAll,
            child: const ColoredBox(color: phoneSheetBarrierColor),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: appear.drive(_sheetRise),
            child: NoteSheetView(
              scene: scene,
              resolver: resolver,
              expanded: _noteExpanded,
              onExpandedChanged: _onNoteExpandedChanged,
              onToggleTask: _toggleTaskOf(scene.entry),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notePanel(LogViewerScene scene, MediaResolver resolver) {
    final Entry entry = scene.entry;
    return NotePanelView(
      scene: scene,
      resolver: resolver,
      onToggleTask: _toggleTaskOf(entry),
      editor: _editing
          ? EditNoteConnector(
              key: ValueKey<String>('log-viewer-edit-${entry.id}'),
              entry: entry,
              date: widget.date,
              exit: ComposerExit.back,
              onDone: _onEditDone,
            )
          : null,
    );
  }
}
