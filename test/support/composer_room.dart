import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

Finder composerTitled(String title) => find.byWidgetPredicate(
  (Widget widget) => widget is TextComposerSheet && widget.title == title,
  description: 'the composer titled "$title"',
);
