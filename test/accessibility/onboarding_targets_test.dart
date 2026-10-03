import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'states/onboarding_states.dart';
import 'support/a11y_state.dart';

const String _phoneSuffix = '-bottom-bar';
const double _phoneBack = 48;
const double _phoneToggle = 44;
const double _phoneSkip = 44;
const double _macBack = 46;
const double _macBackReach = 44;
const double _edge = 1;

enum _Control { phoneBack, phoneToggle, phoneSkip, macBack }

const Set<String> _toggleLabels = <String>{
  appearanceToggleDarkLabel,
  appearanceToggleLightLabel,
};

OnboardingChapter? _chapterOf(WidgetTester tester) =>
    switch (ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingChapter chapter) => chapter,
      OnboardingFlowHidden() || OnboardingFlowMap() => null,
    };

List<Offset> _samples(Rect area) {
  final Rect inner = area.deflate(_edge);
  return <Offset>[
    area.center,
    inner.topLeft,
    inner.topRight,
    inner.bottomLeft,
    inner.bottomRight,
    inner.topCenter,
    inner.bottomCenter,
    inner.centerLeft,
    inner.centerRight,
  ];
}

Finder _tapHandler(Finder control) => find
    .descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (Widget widget) => widget is GestureDetector && widget.onTap != null,
      ),
      matchRoot: true,
    )
    .first;

void _expectReaches(
  WidgetTester tester,
  Finder control,
  Rect area,
  String reason,
) {
  final RenderObject target = tester.renderObject(_tapHandler(control));
  for (final Offset point in _samples(area)) {
    expect(
      tester
          .hitTestOnBinding(point)
          .path
          .any((HitTestEntry entry) => identical(entry.target, target)),
      isTrue,
      reason: '$reason: a tap at $point misses it',
    );
  }
}

Size _nodeSize(WidgetTester tester, Finder control) =>
    tester.getSemantics(control).rect.size;

void _expectPhoneBack(WidgetTester tester, String id) {
  final Finder back = find.byKey(onboardingBackKey);
  expect(back, findsOneWidget, reason: id);
  final Rect rect = tester.getRect(back);
  expect(rect.size, const Size.square(_phoneBack), reason: '$id Back');
  final SemanticsNode node = tester.getSemantics(back);
  expect(node.label, onboardingBackLabel, reason: id);
  expect(node.rect.size, const Size.square(_phoneBack), reason: '$id Back');
  _expectReaches(tester, back, rect, '$id Back');
}

void _expectPhoneToggle(WidgetTester tester, String id) {
  final Finder slot = find.byKey(onboardingToggleKey);
  final Finder toggle = find.byKey(appearanceToggleKey);
  expect(slot, findsOneWidget, reason: id);
  expect(toggle, findsOneWidget, reason: id);
  expect(
    tester.getSize(slot),
    const Size.square(_phoneToggle),
    reason: '$id toggle',
  );
  final Rect rect = tester.getRect(toggle);
  expect(rect.size, const Size.square(_phoneToggle), reason: '$id toggle');
  final SemanticsNode node = tester.getSemantics(toggle);
  expect(_toggleLabels, contains(node.label), reason: id);
  expect(node.rect.size, const Size.square(_phoneToggle), reason: '$id toggle');
  _expectReaches(tester, toggle, rect, '$id toggle');
}

void _expectPhoneSkip(WidgetTester tester, String id) {
  final Finder skip = find.byKey(onboardingSkipKey);
  expect(skip, findsOneWidget, reason: id);
  final Rect rect = tester.getRect(skip);
  expect(rect.height, greaterThanOrEqualTo(_phoneSkip), reason: '$id Skip');
  expect(rect.width, greaterThanOrEqualTo(_phoneSkip), reason: '$id Skip');
  final Size node = _nodeSize(tester, skip);
  expect(node.height, greaterThanOrEqualTo(_phoneSkip), reason: '$id Skip');
  expect(node.width, greaterThanOrEqualTo(_phoneSkip), reason: '$id Skip');
  expect(tester.getSemantics(skip).label, onboardingSkipLabel, reason: id);
  _expectReaches(tester, skip, rect, '$id Skip');
}

void _expectMacBack(WidgetTester tester, String id) {
  final Finder back = find.byKey(onboardingBackKey);
  expect(back, findsOneWidget, reason: id);
  final Finder glass = find.descendant(
    of: back,
    matching: find.byType(GlassSurface),
  );
  expect(glass, findsOneWidget, reason: '$id Back is glass');
  final Rect face = tester.getRect(glass);
  expect(face.size, const Size.square(_macBack), reason: '$id Back');
  final Size target = tester.getSize(back);
  expect(target.width, greaterThanOrEqualTo(_macBackReach), reason: id);
  expect(target.height, greaterThanOrEqualTo(_macBackReach), reason: id);
  final SemanticsNode node = tester.getSemantics(back);
  expect(node.label, onboardingBackLabel, reason: id);
  expect(node.rect.width, greaterThanOrEqualTo(_macBackReach), reason: id);
  expect(node.rect.height, greaterThanOrEqualTo(_macBackReach), reason: id);
  _expectReaches(
    tester,
    back,
    Rect.fromCenter(
      center: face.center,
      width: _macBackReach + 2 * _edge,
      height: _macBackReach + 2 * _edge,
    ),
    '$id Back',
  );
}

void main() {
  testWidgets('onboarding controls meet their target sizes', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Set<_Control> measured = <_Control>{};

    for (final A11yState state in onboardingStates) {
      await state.pump(tester);
      final OnboardingChapter? chapter = _chapterOf(tester);
      if (chapter != null) {
        final bool afterOpening = chapter != OnboardingChapter.opening;
        if (state.id.endsWith(_phoneSuffix)) {
          _expectPhoneToggle(tester, state.id);
          measured.add(_Control.phoneToggle);
          if (afterOpening) {
            _expectPhoneBack(tester, state.id);
            measured.add(_Control.phoneBack);
          }
          if (chapter.isStory) {
            _expectPhoneSkip(tester, state.id);
            measured.add(_Control.phoneSkip);
          }
        } else if (afterOpening) {
          _expectMacBack(tester, state.id);
          measured.add(_Control.macBack);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(measured, containsAll(_Control.values));
    semantics.dispose();
  });
}
