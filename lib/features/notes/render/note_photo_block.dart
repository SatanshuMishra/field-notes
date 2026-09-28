import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

const TextStyle notePhotoCaptionStyle = TypographyTokens.captionSans;
const TextAlign notePhotoCaptionAlign = TextAlign.center;

class NoteMediaScope extends InheritedWidget {
  const NoteMediaScope({
    super.key,
    required this.resolver,
    required super.child,
  });

  final MediaResolver resolver;

  static MediaResolver? maybeResolverOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NoteMediaScope>()
        ?.resolver;
  }

  @override
  bool updateShouldNotify(NoteMediaScope oldWidget) =>
      !identical(resolver, oldWidget.resolver);
}
