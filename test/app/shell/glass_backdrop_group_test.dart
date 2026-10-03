import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_shell_harness.dart';

const Size _phone = Size(384, 832);
const Key _bodyGlassKey = ValueKey<String>('body-glass');

Future<void> _pumpPhoneShell(
  WidgetTester tester,
  ShellDestination selected,
) async {
  tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  await pumpShell(
    tester,
    BottomBarShell(
      destinations: ShellDestination.primary,
      selected: selected,
      onSelect: (ShellDestination destination) {},
      onCapture: () {},
      body: ListView(
        children: const <Widget>[
          SizedBox(height: 300),
          SizedBox(
            height: 60,
            child: GlassSurface(
              key: _bodyGlassKey,
              tone: GlassTone.paper,
              borderRadius: BorderRadius.all(Radius.circular(20)),
              child: SizedBox.expand(),
            ),
          ),
          SizedBox(height: 900),
        ],
      ),
    ),
    platform: TargetPlatform.android,
    surface: _phone,
  );
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView), const Offset(0, -240));
  await tester.pumpAndSettle();
}

RenderBackdropFilter _backdropOf(WidgetTester tester, Finder owner) =>
    tester.renderObject<RenderBackdropFilter>(
      find.descendant(of: owner, matching: find.byType(BackdropFilter)).first,
    );

void main() {
  for (final ShellDestination selected in <ShellDestination>[
    ShellDestination.garden,
    ShellDestination.today,
  ]) {
    testWidgets(
      'on ${selected.name} the phone header and bottom bar blur from one shared '
      'backdrop and scrolling glass keeps its own',
      (WidgetTester tester) async {
        await _pumpPhoneShell(tester, selected);
        final RenderBackdropFilter header = _backdropOf(
          tester,
          find.byKey(const ValueKey<String>('phone-header-glass')),
        );
        final List<RenderBackdropFilter> all = tester
            .renderObjectList<RenderBackdropFilter>(find.byType(BackdropFilter))
            .toList();
        final RenderBackdropFilter body = _backdropOf(
          tester,
          find.byKey(_bodyGlassKey),
        );
        final List<RenderBackdropFilter> chrome = <RenderBackdropFilter>[
          for (final RenderBackdropFilter filter in all)
            if (!identical(filter, body)) filter,
        ];
        expect(chrome, hasLength(2));
        expect(header.backdropKey, isNotNull);
        expect(
          chrome.map((RenderBackdropFilter f) => f.backdropKey).toSet(),
          <BackdropKey?>{header.backdropKey},
        );
        expect(body.backdropKey, isNot(header.backdropKey));
      },
    );
  }
}
