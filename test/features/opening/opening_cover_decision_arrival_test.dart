import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/opening/opening_cover.dart';
import 'package:field_notes/features/opening/opening_frame.dart';
import 'package:field_notes/features/opening/opening_providers.dart';

class _GateAnsweringAfter extends OnboardingGate {
  _GateAnsweringAfter(this._delay);

  final Duration _delay;

  @override
  Future<OnboardingVisibility> build() => Future<OnboardingVisibility>.delayed(
    _delay,
    () => OnboardingVisibility.hidden,
  );
}

Future<void> _pumpCoverDecidingAfter(
  WidgetTester tester,
  Duration delay,
) async {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        playsOpeningProvider.overrideWithValue(true),
        onboardingGateProvider.overrideWith(() => _GateAnsweringAfter(delay)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: TargetPlatform.android,
          brightness: Brightness.light,
        ),
        builder: (BuildContext context, Widget? app) =>
            OpeningCover(child: app!),
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
}

Finder get _drawing => find.byType(OpeningFrame);

Finder get _paper => find.byKey(openingPaperKey);

void main() {
  testWidgets(
    'a decision landing just after a second, between frames, never starts the drawing',
    (WidgetTester tester) async {
      await _pumpCoverDecidingAfter(tester, const Duration(milliseconds: 1005));
      await tester.pump(const Duration(milliseconds: 994));
      expect(_drawing, findsNothing);
      await tester.pump(const Duration(milliseconds: 16));
      expect(_drawing, findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_drawing, findsNothing);
      expect(_paper, findsNothing);
    },
  );

  testWidgets(
    'a decision after a second during a stalled frame never starts the drawing',
    (WidgetTester tester) async {
      await _pumpCoverDecidingAfter(tester, const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 900));
      expect(_drawing, findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_drawing, findsNothing);
      expect(_paper, findsNothing);
    },
  );

  testWidgets(
    'a decision inside the second during a stalled frame still starts the drawing',
    (WidgetTester tester) async {
      await _pumpCoverDecidingAfter(tester, const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 510));
      expect(_drawing, findsOneWidget);
    },
  );
}
