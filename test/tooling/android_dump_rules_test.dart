import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/a11y/android_dump_rules.dart';

const String _head =
    r'''<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
<node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="false" enabled="true" focusable="false" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[0,0][1080,2280]">
<node index="0" text="" resource-id="" class="android.widget.LinearLayout" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="false" enabled="true" focusable="false" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[0,0][1080,2280]">
<node index="0" text="" resource-id="android:id/content" class="android.widget.FrameLayout" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="false" enabled="true" focusable="false" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[0,0][1080,2280]">
<node index="0" text="" resource-id="" class="android.view.View" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="false" enabled="true" focusable="false" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[0,0][1080,2280]">
''';

const String _tail = '''
</node>
</node>
</node>
</node>
</hierarchy>
''';

const String _viewerEditNote = r'''
<node index="0" text="" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="Edit note" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[870,160][1038,328]">
<node index="0" text="" resource-id="" class="android.view.View" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[870,160][1038,328]" />
</node>
''';

const String _cardHarbour = r'''
<node index="0" text="" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="true" password="false" selected="false" bounds="[42,420][1038,780]">
<node index="0" text="" resource-id="" class="android.widget.ImageView" package="dev.satanshumishra.field_notes" content-desc="Harbour at dawn" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[44,422][1036,778]" />
</node>
''';

const String _cardTidePools = r'''
<node index="1" text="" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="true" password="false" selected="false" bounds="[42,820][1038,1180]">
<node index="0" text="" resource-id="" class="android.widget.ImageView" package="dev.satanshumishra.field_notes" content-desc="Tide pools" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[42,820][1038,1180]" />
</node>
''';

const String _moodPrompt = r'''
<node index="0" text="" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="How are you feeling today?&#10;Peony&#10;How are you feeling today?&#10;tap to plant today&apos;s bloom" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[90,600][990,900]" />
''';

const String _composerCancel = r'''
<node index="0" text="" resource-id="" class="android.view.View" package="dev.satanshumishra.field_notes" content-desc="Cancel" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[42,150][442,350]" />
''';

const String _tideButton = r'''
<node index="0" text="" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="Tide &amp; weather" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[960,180][1020,240]" />
''';

const String _clean = r'''
<node index="0" text="" resource-id="" class="android.view.View" package="dev.satanshumishra.field_notes" content-desc="Thursday&#13;&#10;24 September" checkable="false" checked="false" clickable="false" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[42,150][800,276]" />
<node index="1" text="Save" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[912,150][1038,276]" />
<node index="2" text="" resource-id="" class="android.widget.EditText" package="dev.satanshumishra.field_notes" content-desc="" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="true" scrollable="false" long-clickable="true" password="false" selected="false" bounds="[42,320][1038,1200]" />
<node index="3" text="" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="Voice note&#10;0:42" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[42,1260][1038,1560]">
<node index="0" text="" resource-id="" class="android.widget.Button" package="dev.satanshumishra.field_notes" content-desc="Play" checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[45,1263][1035,1557]" />
</node>
''';

String _dump(String nodes) => '$_head$nodes$_tail';

Future<ProcessResult> _rules(List<String> arguments) => Process.run(
  'dart',
  <String>['run', 'tool/a11y/android_dump_rules.dart', ...arguments],
);

void main() {
  test('each known phone problem is caught by its rule', () {
    expect(
      androidDumpFindings(
        _dump(_viewerEditNote),
        state: 'd2-viewer-photo',
        density: 420,
      ),
      <String>[
        'doubled-target | d2-viewer-photo | Edit note | <root>',
        'missing-role | d2-viewer-photo | <unlabelled> | Edit note',
        'unlabelled-tap | d2-viewer-photo | <unlabelled> | Edit note',
      ],
    );
    expect(
      androidDumpFindings(
        _dump(_cardHarbour),
        state: 'a2-today-feed',
        density: 420,
      ),
      <String>[
        'doubled-target | a2-today-feed | Harbour at dawn | <root>',
        'missing-role | a2-today-feed | Harbour at dawn | <root>',
        'unlabelled-tap | a2-today-feed | <unlabelled> | <root>',
      ],
    );
    expect(
      androidDumpFindings(
        _dump(_moodPrompt),
        state: 'd9-mood-prompt-today',
        density: 420,
      ),
      <String>[
        "repeated-text | d9-mood-prompt-today | How are you feeling today? / Peony / How are you feeling today? / tap to plant today's bloom | <root>",
      ],
    );
    expect(
      androidDumpFindings(
        _dump(_composerCancel),
        state: 'c2-composer-new',
        density: 420,
      ),
      <String>['missing-role | c2-composer-new | Cancel | <root>'],
    );
    expect(
      androidDumpFindings(
        _dump(_tideButton),
        state: 'a1-today-empty',
        density: 420,
      ),
      <String>['small-target | a1-today-empty | Tide & weather | <root>'],
    );
  });

  test('a dump without problems has no findings', () {
    expect(
      androidDumpFindings(_dump(_clean), state: 'c5-edit-note', density: 420),
      isEmpty,
    );
  });

  test(
    'the command prints sorted IDs and exits 1 on findings and 0 on none',
    () async {
      final Directory directory = Directory.systemTemp.createTempSync(
        'android_dump_rules',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final File viewer = File('${directory.path}/viewer.xml')
        ..writeAsStringSync(_dump(_viewerEditNote));
      final File feed = File('${directory.path}/feed.xml')
        ..writeAsStringSync(_dump('$_cardHarbour$_cardTidePools'));
      final File clean = File('${directory.path}/clean.xml')
        ..writeAsStringSync(_dump(_clean));

      final ProcessResult found = await _rules(<String>[
        '--density',
        '420',
        '--state',
        'd2-viewer-photo',
        viewer.path,
        '--state',
        'a2-today-feed',
        feed.path,
      ]);
      expect(found.exitCode, 1, reason: '${found.stderr}');
      expect(const LineSplitter().convert('${found.stdout}'), <String>[
        'doubled-target | a2-today-feed | Harbour at dawn | <root>',
        'doubled-target | a2-today-feed | Tide pools | <root>',
        'doubled-target | d2-viewer-photo | Edit note | <root>',
        'missing-role | a2-today-feed | Harbour at dawn | <root>',
        'missing-role | a2-today-feed | Tide pools | <root>',
        'missing-role | d2-viewer-photo | <unlabelled> | Edit note',
        'unlabelled-tap | a2-today-feed | <unlabelled> | <root>',
        'unlabelled-tap | a2-today-feed | <unlabelled> | <root> #2',
        'unlabelled-tap | d2-viewer-photo | <unlabelled> | Edit note',
      ]);

      final ProcessResult none = await _rules(<String>[
        '--density',
        '420',
        '--state',
        'c5-edit-note',
        clean.path,
      ]);
      expect(none.exitCode, 0, reason: '${none.stdout}${none.stderr}');
      expect('${none.stdout}', isEmpty);

      final String absent = '${directory.path}/absent.xml';
      final ProcessResult missing = await _rules(<String>[
        '--density',
        '420',
        '--state',
        'd2-viewer-photo',
        absent,
      ]);
      expect(missing.exitCode, 2);
      expect('${missing.stdout}', isEmpty);
      expect('${missing.stderr}', contains(absent));

      final ProcessResult undensed = await _rules(<String>[
        '--state',
        'c5-edit-note',
        clean.path,
      ]);
      expect(undensed.exitCode, 2);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
