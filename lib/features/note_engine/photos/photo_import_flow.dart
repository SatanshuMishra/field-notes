import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart'
    show PhotoPickException;
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart'
    show NeutralMediaPlaceholder;
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/photos/photo_commands.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart'
    show composerPhotoFailedMessage;
import 'package:flutter/widgets.dart';

typedef PhotoReferenceLoader = Future<List<String>> Function();

const String photoAddedToastMessage = 'Photo added — tap it to size & place it';
const Duration photoAddedToastLifetime = Duration(seconds: 4);

const double _desktopColumnEms = 30;

PhotoTarget mapPhotoTarget(PhotoTarget target, ChangeSet changes) =>
    switch (target) {
      PhotoBoundaryTarget(boundary: final int boundary) => PhotoBoundaryTarget(
        changes.mapPosition(boundary, side: MapSide.before),
      ),
      PhotoEmptyLineTarget(start: final int start, end: final int end) =>
        PhotoEmptyLineTarget(
          changes.mapPosition(start, side: MapSide.before),
          changes.mapPosition(end, side: MapSide.after),
        ),
    };

PhotoTarget resolvePhotoTarget(String source, MdTree tree, PhotoTarget target) {
  final int offset = switch (target) {
    PhotoBoundaryTarget(boundary: final int boundary) => boundary,
    PhotoEmptyLineTarget(start: final int start) => start,
  };
  final int clamped = offset.clamp(0, source.length);
  final bool kept = switch (target) {
    PhotoBoundaryTarget(boundary: final int boundary) => photoBoundaries(
      source,
      tree,
    ).contains(boundary),
    PhotoEmptyLineTarget() =>
      offset == clamped && photoTargetAt(source, tree, clamped) == target,
  };
  return kept ? target : photoTargetAt(source, tree, clamped);
}

Size photoImportPlaceholderSize({
  required double columnWidth,
  required double em,
}) {
  final double width = columnWidth >= _desktopColumnEms * em
      ? columnWidth / 2
      : columnWidth;
  return Size(width, width * 2 / 3);
}

@immutable
final class PhotoImportPlaceholder {
  const PhotoImportPlaceholder({required this.id, required this.target});

  final int id;
  final PhotoTarget target;

  int get offset => switch (target) {
    PhotoBoundaryTarget(boundary: final int boundary) => boundary,
    PhotoEmptyLineTarget(start: final int start) => start,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoImportPlaceholder &&
          id == other.id &&
          target == other.target;

  @override
  int get hashCode => Object.hash(id, target);

  @override
  String toString() => 'PhotoImportPlaceholder($id, $target)';
}

sealed class PhotoImportOutcome {
  const PhotoImportOutcome();
}

final class PhotoImportInserted extends PhotoImportOutcome {
  const PhotoImportInserted(this.result);

  final PhotoCommandResult result;
}

final class PhotoImportFailed extends PhotoImportOutcome {
  const PhotoImportFailed(this.message, {this.error, this.stackTrace});

  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoImportFailed && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => "PhotoImportFailed('$message')";
}

final class PhotoImportFlow extends ChangeNotifier {
  PhotoImportFlow({required this._readState, required this._onOutcome});

  final EditorState Function() _readState;
  final void Function(PhotoImportOutcome outcome) _onOutcome;
  List<PhotoImportPlaceholder> _placeholders = const <PhotoImportPlaceholder>[];
  int _nextId = 0;
  bool _disposed = false;

  List<PhotoImportPlaceholder> get placeholders => _placeholders;

  Future<PhotoImportOutcome?> importAtCaret(
    PhotoReferenceLoader load, {
    bool reportFailure = true,
  }) {
    final EditorState state = _readState();
    return _import(
      photoTargetAt(state.source, state.tree, state.selection.end),
      load,
      reportFailure: reportFailure,
    );
  }

  Future<PhotoImportOutcome?> importAtBoundary(
    int boundary,
    PhotoReferenceLoader load, {
    bool reportFailure = true,
  }) => _import(
    PhotoBoundaryTarget(boundary),
    load,
    reportFailure: reportFailure,
  );

  void mapThrough(ChangeSet changes) {
    if (_disposed || _placeholders.isEmpty) {
      return;
    }
    final List<PhotoImportPlaceholder> mapped =
        List<PhotoImportPlaceholder>.unmodifiable(<PhotoImportPlaceholder>[
          for (final PhotoImportPlaceholder placeholder in _placeholders)
            PhotoImportPlaceholder(
              id: placeholder.id,
              target: mapPhotoTarget(placeholder.target, changes),
            ),
        ]);
    final bool moved = mapped.indexed.any(
      ((int, PhotoImportPlaceholder) entry) =>
          entry.$2 != _placeholders[entry.$1],
    );
    if (!moved) {
      return;
    }
    _placeholders = mapped;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<PhotoImportOutcome?> _import(
    PhotoTarget target,
    PhotoReferenceLoader load, {
    required bool reportFailure,
  }) async {
    final int id = _nextId;
    _nextId += 1;
    _placeholders = List<PhotoImportPlaceholder>.unmodifiable(
      <PhotoImportPlaceholder>[
        ..._placeholders,
        PhotoImportPlaceholder(id: id, target: target),
      ],
    );
    notifyListeners();
    final List<String> references;
    try {
      references = await load();
    } on PhotoPickException catch (error, stackTrace) {
      return _fail(
        id,
        PhotoImportFailed(error.message, error: error, stackTrace: stackTrace),
        reportFailure: reportFailure,
      );
    } catch (error, stackTrace) {
      if (!_disposed && reportFailure) {
        debugPrint('Adding a photo to a note failed: $error\n$stackTrace');
      }
      return _fail(
        id,
        PhotoImportFailed(
          composerPhotoFailedMessage,
          error: error,
          stackTrace: stackTrace,
        ),
        reportFailure: reportFailure,
      );
    }
    if (_disposed) {
      return null;
    }
    final PhotoTarget pending = _remove(id);
    if (references.isEmpty) {
      return null;
    }
    final EditorState state = _readState();
    final PhotoEdit edit = photoInsertion(
      state.source,
      resolvePhotoTarget(state.source, state.tree, pending),
      references,
    );
    final PhotoImportInserted outcome = PhotoImportInserted(
      PhotoCommandResult(
        transaction: Transaction(
          changes: edit.changes,
          selection: edit.selection,
          event: TransactionEvent.photo,
        ),
        toast: PhotoToast.added,
      ),
    );
    _onOutcome(outcome);
    return outcome;
  }

  PhotoImportFailed? _fail(
    int id,
    PhotoImportFailed outcome, {
    required bool reportFailure,
  }) {
    if (_disposed) {
      return null;
    }
    _remove(id);
    if (reportFailure) {
      _onOutcome(outcome);
    }
    return outcome;
  }

  PhotoTarget _remove(int id) {
    final PhotoImportPlaceholder removed = _placeholders.firstWhere(
      (PhotoImportPlaceholder placeholder) => placeholder.id == id,
    );
    _placeholders =
        List<PhotoImportPlaceholder>.unmodifiable(<PhotoImportPlaceholder>[
          for (final PhotoImportPlaceholder placeholder in _placeholders)
            if (placeholder.id != id) placeholder,
        ]);
    notifyListeners();
    return removed.target;
  }
}

class PhotoImportPlaceholderBox extends StatelessWidget {
  const PhotoImportPlaceholderBox({super.key, required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) =>
      NeutralMediaPlaceholder(width: size.width, height: size.height);
}
