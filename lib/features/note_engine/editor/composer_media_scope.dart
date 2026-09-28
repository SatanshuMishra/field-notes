import 'package:flutter/widgets.dart';

import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

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
