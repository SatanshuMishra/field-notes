import 'package:flutter/widgets.dart';

import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';

const double _conflictLabelGap = 6;

String conflictCopyLabel(String deviceName) => 'Conflict copy from $deviceName';

class ConflictCopyLabel extends StatelessWidget {
  const ConflictCopyLabel({super.key, required this.deviceName});

  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return Text(
      conflictCopyLabel(deviceName),
      style: context.textStyles.captionSans.copyWith(
        color: context.colors.accentInk,
      ),
    );
  }
}

class NoteBody extends StatelessWidget {
  const NoteBody({
    super.key,
    required this.text,
    this.selectable = true,
    this.onToggleTask,
    this.onOpenPhoto,
    this.conflictSourceDevice,
  });

  final String text;
  final bool selectable;
  final ValueChanged<int>? onToggleTask;
  final ValueChanged<int>? onOpenPhoto;
  final String? conflictSourceDevice;

  @override
  Widget build(BuildContext context) {
    final String? device = conflictSourceDevice;
    if (device == null) {
      return NoteColumn(child: _body(context));
    }
    return NoteColumn(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConflictCopyLabel(deviceName: device),
          const SizedBox(height: _conflictLabelGap),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (text.trim().isEmpty) {
      return Text(
        'Empty note',
        style: context.textStyles.noteBodyItalic.copyWith(
          color: context.colors.muted,
        ),
      );
    }
    return NoteReaderView(
      source: text,
      selectable: selectable,
      onToggleTask: onToggleTask,
      onOpenPhoto: onOpenPhoto,
    );
  }
}
