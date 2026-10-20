import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sharedPiece = 'lib/design/interaction/pressable.dart';

final RegExp _gestureToken = RegExp(
  r'\b(RawGestureDetector|GestureDetector|InkWell|InkResponse|TapGestureRecognizer)\b',
);
final RegExp _tapCallback = RegExp(
  r'\bon(Tap|TapUp|TapDown|Pressed|SecondaryTap)\s*:',
);

class _AllowedSite {
  const _AllowedSite(this.file, this.token, this.reason, {this.needle});

  final String file;
  final String token;
  final String reason;
  final String? needle;
}

const List<_AllowedSite> _allowedSites = <_AllowedSite>[
  _AllowedSite(
    'lib/app/shell/window_chrome.dart',
    'GestureDetector',
    'drag',
    needle: 'startWindowDrag',
  ),
  _AllowedSite(
    'lib/app/shell/windows_caption_buttons.dart',
    'GestureDetector',
    'drag',
    needle: 'startWindowResize',
  ),
  _AllowedSite(
    'lib/design/widgets/phone_sheet.dart',
    'GestureDetector',
    'drag',
    needle: 'onVerticalDragStart',
  ),
  _AllowedSite(
    'lib/features/calendar/widgets/phone_flower_month.dart',
    'GestureDetector',
    'drag',
    needle: 'onHorizontalDragStart',
  ),
  _AllowedSite(
    'lib/features/garden/widgets/meadow_focus_stepper.dart',
    'GestureDetector',
    'drag',
    needle: 'onHorizontalDragStart',
  ),
  _AllowedSite(
    'lib/features/log_viewer/viewer_chrome.dart',
    'Listener',
    'swipe',
  ),
  _AllowedSite(
    'lib/features/onboarding/onboarding_swipe.dart',
    'RawGestureDetector',
    'swipe',
  ),
  _AllowedSite(
    'lib/features/entry_cards/compact/log_actions_pill.dart',
    'GestureDetector',
    'long-press',
    needle: 'onLongPress',
  ),
  _AllowedSite(
    'lib/features/calendar/widgets/month_picker_route.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/capture/core/composer_shell.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/day_detail/show_day_detail.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/garden/widgets/meadow_desktop_page.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/garden/widgets/meadow_glass_popover.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/log_viewer/log_viewer_panel.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/sync/ui/add_device_sheet.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/sync/ui/start_sync_flow.dart',
    'GestureDetector',
    'barrier',
  ),
  _AllowedSite(
    'lib/features/garden/widgets/meadow_glass_popover.dart',
    'Listener',
    'swallow',
  ),
  _AllowedSite(
    'lib/features/onboarding/onboarding_frame.dart',
    'Listener',
    'swallow',
  ),
  _AllowedSite(
    'lib/design/settings_fields/settings_text_field.dart',
    'GestureDetector',
    'text-selection',
    needle: '_handleTapDown',
  ),
  _AllowedSite(
    'lib/features/capture/text/editor/photo_caption_field.dart',
    'GestureDetector',
    'focus',
  ),
  _AllowedSite(
    'lib/features/sync/ui/pairing_word_fields.dart',
    'GestureDetector',
    'focus',
  ),
  _AllowedSite(
    'lib/features/garden/widgets/garden_view.dart',
    'Listener',
    'focus',
  ),
  _AllowedSite(
    'lib/features/capture/video/camera_gestures.dart',
    'GestureDetector',
    'pointer',
  ),
  _AllowedSite(
    'lib/features/entry_cards/cards/video_controls_overlay.dart',
    'Listener',
    'pointer',
  ),
  _AllowedSite(
    'lib/features/garden/scene/meadow_stage.dart',
    'Listener',
    'pointer',
  ),
  _AllowedSite(
    'lib/features/log_viewer/log_viewer_panel.dart',
    'Listener',
    'pointer',
  ),
  _AllowedSite(
    'lib/features/note_engine/editor/note_editor_view.dart',
    'Listener',
    'text',
  ),
  _AllowedSite(
    'lib/features/note_engine/gestures/mouse_selection.dart',
    'TapGestureRecognizer',
    'text',
  ),
  _AllowedSite(
    'lib/features/note_engine/gestures/touch_selection.dart',
    'RawGestureDetector',
    'text',
  ),
  _AllowedSite(
    'lib/features/note_engine/reader/note_reader_view.dart',
    'RawGestureDetector',
    'text',
  ),
  _AllowedSite(
    'lib/features/note_engine/reader/note_reader_view.dart',
    'TapGestureRecognizer',
    'text',
  ),
  _AllowedSite(
    'lib/design/settings_fields/settings_text_field.dart',
    'EditableText',
    'text',
  ),
  _AllowedSite(
    'lib/app/shell/windows_caption_buttons.dart',
    'GestureDetector',
    'caption',
    needle: '_press(true)',
  ),
];

class _Hit {
  const _Hit(this.file, this.line, this.token, this.context);

  final String file;
  final int line;
  final String token;
  final String context;

  String get label => '$file:$line $token';
}

String _normalise(String path) => path.replaceAll(r'\', '/');

List<File> _libSources() {
  final List<File> files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

String _withoutLineComments(String source) => source
    .split('\n')
    .map((String line) => line.trimLeft().startsWith('//') ? '' : line)
    .join('\n');

int _skipGenerics(String source, int from) {
  int index = from;
  while (index < source.length && source[index] == ' ') {
    index++;
  }
  if (index < source.length && source[index] == '<') {
    int depth = 0;
    while (index < source.length) {
      if (source[index] == '<') {
        depth++;
      } else if (source[index] == '>') {
        depth--;
        if (depth == 0) {
          index++;
          break;
        }
      }
      index++;
    }
  }
  while (index < source.length && source[index] == ' ') {
    index++;
  }
  return index;
}

String _directArguments(String source, int openParen) {
  final StringBuffer direct = StringBuffer();
  final StringBuffer whole = StringBuffer();
  int depth = 0;
  for (int index = openParen; index < source.length; index++) {
    final String char = source[index];
    whole.write(char);
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
      if (depth == 0) {
        break;
      }
    } else if (depth == 1) {
      direct.write(char);
    }
  }
  return '${direct.toString()}\u0000${whole.toString()}';
}

List<_Hit> _tapHits(String file, String rawSource) {
  final String source = _withoutLineComments(rawSource);
  final List<_Hit> hits = <_Hit>[];
  for (final RegExpMatch match in _gestureToken.allMatches(source)) {
    final String token = match.group(1)!;
    final int lineStart = source.lastIndexOf('\n', match.start) + 1;
    final String linePrefix = source.substring(lineStart, match.start);
    if (linePrefix.trimLeft().startsWith('import ')) {
      continue;
    }
    final int after = _skipGenerics(source, match.end);
    final bool isCall = after < source.length && source[after] == '(';
    final bool isSubclass = linePrefix.contains('extends');
    final int line = _lineOf(source, match.start);
    if (token == 'TapGestureRecognizer') {
      if (isCall || isSubclass) {
        final String context = isCall
            ? _directArguments(source, after).split('\u0000').last
            : source.substring(lineStart, source.indexOf('\n', match.end));
        hits.add(_Hit(file, line, token, context));
      }
      continue;
    }
    if (!isCall || token == 'RawGestureDetector') {
      continue;
    }
    final List<String> parts = _directArguments(source, after).split('\u0000');
    if (_tapCallback.hasMatch(parts.first)) {
      hits.add(_Hit(file, line, token, parts.last));
    }
  }
  return hits;
}

bool _isAllowed(_Hit hit) => _allowedSites.any(
  (_AllowedSite site) =>
      site.file == hit.file &&
      site.token == hit.token &&
      (site.needle == null || hit.context.contains(site.needle!)),
);

void main() {
  test(
    'no clickable control in lib is built by hand outside the shared pieces',
    () {
      final List<String> offences = <String>[];
      for (final File file in _libSources()) {
        final String path = _normalise(file.path);
        if (path == _sharedPiece) {
          continue;
        }
        for (final _Hit hit in _tapHits(path, file.readAsStringSync())) {
          if (!_isAllowed(hit)) {
            offences.add(hit.label);
          }
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'Build clickable controls from Pressable; hand-built tap targets: '
            '${offences.join(', ')}',
      );
    },
  );

  test('every allow list entry names a gesture still present in its file', () {
    final List<String> stale = <String>[];
    for (final _AllowedSite site in _allowedSites) {
      final File file = File(site.file);
      if (!file.existsSync() || !file.readAsStringSync().contains(site.token)) {
        stale.add('${site.file} ${site.token}');
      }
    }
    expect(stale, isEmpty);
  });
}
