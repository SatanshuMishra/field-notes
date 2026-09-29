import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/features/onboarding/tour/tour_geometry.dart';
import 'package:field_notes/features/onboarding/tour/tour_tips.dart';
import 'package:field_notes/features/onboarding/tour_anchor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _desktop = Size(1280, 800);
const Size _phone = Size(360, 640);
const double _cardHeight = 240;
const double _epsilon = 0.001;

const Map<TourTarget, ({double padding, double radius})> _sidebarSpots =
    <TourTarget, ({double padding, double radius})>{
      TourTarget.nav: (padding: 7, radius: 16),
      TourTarget.mood: (padding: 6, radius: 21),
      TourTarget.capture: (padding: 8, radius: 18),
      TourTarget.calendar: (padding: 5, radius: 15),
      TourTarget.settings: (padding: 6, radius: 12),
    };

const Map<TourTarget, ({double padding, double radius})> _bottomBarSpots =
    <TourTarget, ({double padding, double radius})>{
      TourTarget.nav: (padding: 5, radius: 32),
      TourTarget.mood: (padding: 5, radius: 18),
      TourTarget.capture: (padding: 5, radius: 40),
      TourTarget.calendar: (padding: 5, radius: 20),
      TourTarget.settings: (padding: 5, radius: 14),
    };

TourTip _tipFor(TourTarget target) {
  return tourTips.singleWhere((TourTip tip) => tip.target == target);
}

TourTip get _noteTip =>
    tourTips.singleWhere((TourTip tip) => tip.target == null);

TourPlacement _sidebar(
  TourTarget? target,
  Rect? rect, {
  Size window = _desktop,
  double cardHeight = _cardHeight,
}) {
  return placeTour(
    window: window,
    safeArea: EdgeInsets.zero,
    tip: target == null ? _noteTip : _tipFor(target),
    layout: ShellLayout.sidebar,
    target: rect,
    cardHeight: cardHeight,
  );
}

TourPlacement _bottomBar(
  TourTarget? target,
  Rect? rect, {
  Size window = _phone,
  EdgeInsets safeArea = EdgeInsets.zero,
  Rect? navRect,
  double cardHeight = _cardHeight,
}) {
  return placeTour(
    window: window,
    safeArea: safeArea,
    tip: target == null ? _noteTip : _tipFor(target),
    layout: ShellLayout.bottomBar,
    target: rect,
    cardHeight: cardHeight,
    navRect: navRect,
  );
}

void _expectRect(Rect? actual, Rect expected) {
  expect(actual, isNotNull);
  expect(actual!.left, closeTo(expected.left, _epsilon));
  expect(actual.top, closeTo(expected.top, _epsilon));
  expect(actual.right, closeTo(expected.right, _epsilon));
  expect(actual.bottom, closeTo(expected.bottom, _epsilon));
}

void main() {
  test('the spotlight is the target inflated by the tip padding', () {
    const Rect desktopTarget = Rect.fromLTWH(300, 200, 120, 60);
    const Rect phoneTarget = Rect.fromLTWH(20, 300, 100, 50);
    const Rect phoneNav = Rect.fromLTRB(8, 582, 352, 634);

    expect(tourTips.map((TourTip tip) => tip.target).toList(), <TourTarget?>[
      TourTarget.nav,
      TourTarget.mood,
      TourTarget.capture,
      null,
      TourTarget.calendar,
      TourTarget.settings,
    ]);

    for (final TourTarget target in _sidebarSpots.keys) {
      final ({double padding, double radius}) spot = _sidebarSpots[target]!;
      final TourPlacement placement = _sidebar(target, desktopTarget);
      _expectRect(placement.spotlight, desktopTarget.inflate(spot.padding));
      expect(placement.radius, spot.radius, reason: target.name);
    }

    for (final TourTarget target in _bottomBarSpots.keys) {
      final ({double padding, double radius}) spot = _bottomBarSpots[target]!;
      final TourPlacement placement = _bottomBar(
        target,
        phoneTarget,
        navRect: phoneNav,
      );
      _expectRect(placement.spotlight, phoneTarget.inflate(spot.padding));
      expect(placement.radius, spot.radius, reason: target.name);
    }

    final TourPlacement noTarget = _sidebar(null, desktopTarget);
    expect(noTarget.spotlight, isNull);
    expect(noTarget.card.dx, closeTo((1280 - 344) / 2, _epsilon));
    expect(noTarget.card.dy, closeTo((800 - _cardHeight) / 2, _epsilon));

    final TourPlacement unmeasured = _sidebar(TourTarget.mood, null);
    expect(unmeasured.spotlight, isNull);
    expect(unmeasured.card.dx, closeTo((1280 - 344) / 2, _epsilon));
    expect(unmeasured.card.dy, closeTo((800 - _cardHeight) / 2, _epsilon));
  });

  test(
    'sidebar cards sit on their side with a 16 px gap and clamp 16 px inside the window',
    () {
      const Rect nav = Rect.fromLTWH(16, 90, 184, 200);
      final TourPlacement navPlacement = _sidebar(TourTarget.nav, nav);
      final Rect navSpot = navPlacement.spotlight!;
      expect(navPlacement.cardWidth, 344);
      expect(navPlacement.card.dx, closeTo(navSpot.right + 16, _epsilon));
      expect(navPlacement.card.dy, closeTo(navSpot.top, _epsilon));

      const Rect mood = Rect.fromLTWH(260, 120, 600, 90);
      final TourPlacement moodPlacement = _sidebar(TourTarget.mood, mood);
      final Rect moodSpot = moodPlacement.spotlight!;
      expect(moodPlacement.card.dy, closeTo(moodSpot.bottom + 16, _epsilon));
      expect(
        moodPlacement.card.dx,
        closeTo(moodSpot.center.dx - 172, _epsilon),
      );

      const Rect capture = Rect.fromLTWH(1000, 300, 240, 150);
      final TourPlacement capturePlacement = _sidebar(
        TourTarget.capture,
        capture,
      );
      final Rect captureSpot = capturePlacement.spotlight!;
      expect(
        capturePlacement.cardRect(_cardHeight).right,
        closeTo(captureSpot.left - 16, _epsilon),
      );
      expect(capturePlacement.card.dy, closeTo(captureSpot.top, _epsilon));

      const Rect calendar = Rect.fromLTWH(16, 140, 184, 44);
      final TourPlacement calendarPlacement = _sidebar(
        TourTarget.calendar,
        calendar,
      );
      expect(
        calendarPlacement.card.dx,
        closeTo(calendarPlacement.spotlight!.right + 16, _epsilon),
      );

      const Rect settings = Rect.fromLTWH(16, 740, 48, 48);
      final TourPlacement settingsPlacement = _sidebar(
        TourTarget.settings,
        settings,
      );
      expect(
        settingsPlacement.card.dx,
        closeTo(settingsPlacement.spotlight!.right + 16, _epsilon),
      );
      expect(
        settingsPlacement.cardRect(_cardHeight).bottom,
        closeTo(800 - 16, _epsilon),
      );

      const Rect navAtTop = Rect.fromLTWH(16, 2, 184, 100);
      expect(_sidebar(TourTarget.nav, navAtTop).card.dy, closeTo(16, _epsilon));

      const Rect moodAtLeft = Rect.fromLTWH(0, 100, 100, 50);
      expect(
        _sidebar(TourTarget.mood, moodAtLeft).card.dx,
        closeTo(16, _epsilon),
      );

      const Rect moodAtRight = Rect.fromLTWH(1180, 100, 100, 50);
      expect(
        _sidebar(TourTarget.mood, moodAtRight).cardRect(_cardHeight).right,
        closeTo(1280 - 16, _epsilon),
      );

      final TourPlacement tall = _sidebar(
        TourTarget.nav,
        nav,
        cardHeight: 2000,
      );
      expect(tall.cardMaxHeight, 800 - 32);
      expect(tall.card.dy, closeTo(16, _epsilon));
      expect(tall.cardRect(2000).bottom, closeTo(800 - 16, _epsilon));
    },
  );

  test('a card with no room flips sides, then below, then centres', () {
    const Rect captureAtLeft = Rect.fromLTWH(100, 300, 240, 150);
    final TourPlacement flippedRight = _sidebar(
      TourTarget.capture,
      captureAtLeft,
    );
    expect(
      flippedRight.card.dx,
      closeTo(flippedRight.spotlight!.right + 16, _epsilon),
    );

    const Rect navAtRight = Rect.fromLTWH(1100, 100, 150, 100);
    final TourPlacement flippedLeft = _sidebar(TourTarget.nav, navAtRight);
    expect(
      flippedLeft.cardRect(_cardHeight).right,
      closeTo(flippedLeft.spotlight!.left - 16, _epsilon),
    );

    const Size narrow = Size(700, 800);
    const Rect wide = Rect.fromLTWH(200, 100, 300, 100);
    final TourPlacement below = _sidebar(
      TourTarget.calendar,
      wide,
      window: narrow,
    );
    expect(below.card.dy, closeTo(below.spotlight!.bottom + 16, _epsilon));
    expect(below.card.dx, closeTo(below.spotlight!.center.dx - 172, _epsilon));

    const Rect wideLow = Rect.fromLTWH(200, 600, 300, 150);
    final TourPlacement above = _sidebar(
      TourTarget.calendar,
      wideLow,
      window: narrow,
    );
    expect(
      above.cardRect(_cardHeight).bottom,
      closeTo(above.spotlight!.top - 16, _epsilon),
    );

    const Rect moodLow = Rect.fromLTWH(260, 600, 600, 150);
    final TourPlacement moodAbove = _sidebar(TourTarget.mood, moodLow);
    expect(
      moodAbove.cardRect(_cardHeight).bottom,
      closeTo(moodAbove.spotlight!.top - 16, _epsilon),
    );

    const Size small = Size(700, 400);
    const Rect huge = Rect.fromLTWH(150, 60, 400, 280);
    final TourPlacement centred = _sidebar(
      TourTarget.calendar,
      huge,
      window: small,
    );
    expect(centred.card.dx, closeTo((700 - 344) / 2, _epsilon));
    expect(centred.card.dy, closeTo((400 - _cardHeight) / 2, _epsilon));
  });

  test(
    'bottom-bar cards are the screen width minus 24 and stay above the controls bar',
    () {
      const EdgeInsets safeArea = EdgeInsets.only(top: 24);
      const Rect nav = Rect.fromLTRB(8, 582, 352, 634);
      final Map<TourTarget?, Rect?> targets = <TourTarget?, Rect?>{
        TourTarget.nav: nav,
        TourTarget.mood: const Rect.fromLTWH(16, 120, 328, 70),
        TourTarget.capture: const Rect.fromLTWH(154, 580, 52, 52),
        null: null,
        TourTarget.calendar: const Rect.fromLTWH(80, 588, 48, 40),
        TourTarget.settings: const Rect.fromLTWH(304, 28, 48, 48),
      };

      for (final MapEntry<TourTarget?, Rect?> entry in targets.entries) {
        final TourPlacement placement = _bottomBar(
          entry.key,
          entry.value,
          safeArea: safeArea,
          navRect: nav,
        );
        final Rect card = placement.cardRect(_cardHeight);
        final Rect controls = placement.controls!;
        final String reason = entry.key?.name ?? 'no target';
        expect(card.left, closeTo(12, _epsilon), reason: reason);
        expect(card.width, closeTo(360 - 24, _epsilon), reason: reason);
        expect(controls.left, closeTo(12, _epsilon), reason: reason);
        expect(controls.right, closeTo(360 - 12, _epsilon), reason: reason);
        expect(controls.height, closeTo(48, _epsilon), reason: reason);
        expect(
          card.bottom,
          lessThanOrEqualTo(controls.top - 12 + _epsilon),
          reason: reason,
        );
        expect(
          card.top,
          greaterThanOrEqualTo(24 + 8 - _epsilon),
          reason: reason,
        );
        final Rect? spotlight = placement.spotlight;
        switch (entry.key) {
          case TourTarget.mood:
          case TourTarget.settings:
            expect(
              card.top,
              closeTo(spotlight!.bottom + 16, _epsilon),
              reason: reason,
            );
          case TourTarget.nav:
          case TourTarget.capture:
          case TourTarget.calendar:
            expect(
              card.bottom,
              lessThanOrEqualTo(spotlight!.top - 16 + _epsilon),
              reason: reason,
            );
            expect(
              card.bottom,
              closeTo(controls.top - 12, _epsilon),
              reason: reason,
            );
          case null:
            expect(spotlight, isNull);
            expect(
              card.center.dy,
              closeTo((32 + controls.top - 12) / 2, _epsilon),
            );
        }
      }

      final TourPlacement tall = _bottomBar(
        TourTarget.mood,
        targets[TourTarget.mood],
        safeArea: safeArea,
        navRect: nav,
        cardHeight: 900,
      );
      final Rect tallCard = tall.cardRect(900);
      expect(tallCard.top, closeTo(tall.spotlight!.bottom + 16, _epsilon));
      expect(tallCard.bottom, closeTo(tall.controls!.top - 12, _epsilon));
      expect(tallCard.overlaps(tall.spotlight!), isFalse);

      final TourPlacement moodLow = _bottomBar(
        TourTarget.mood,
        const Rect.fromLTWH(16, 400, 328, 70),
        safeArea: safeArea,
        navRect: nav,
      );
      final Rect moodLowCard = moodLow.cardRect(_cardHeight);
      expect(
        moodLowCard.bottom,
        closeTo(moodLow.spotlight!.top - 16, _epsilon),
      );
      expect(moodLowCard.height, closeTo(_cardHeight, _epsilon));

      final TourPlacement squeezed = _bottomBar(
        TourTarget.mood,
        const Rect.fromLTWH(16, 250, 328, 70),
        safeArea: safeArea,
        navRect: nav,
        cardHeight: 400,
      );
      final Rect squeezedCard = squeezed.cardRect(400);
      expect(squeezedCard.overlaps(squeezed.spotlight!), isFalse);
      expect(squeezedCard.top, closeTo(32, _epsilon));
      expect(
        squeezedCard.bottom,
        closeTo(squeezed.spotlight!.top - 16, _epsilon),
      );
    },
  );

  test(
    'the bottom-bar controls bar clears the navigation bar with a bottom inset',
    () {
      const EdgeInsets safeArea = EdgeInsets.only(bottom: 48);
      const Rect nav = Rect.fromLTRB(0, 640 - 48 - 56, 360, 640 - 48);

      final TourPlacement placement = _bottomBar(
        TourTarget.capture,
        const Rect.fromLTWH(154, 540, 52, 52),
        safeArea: safeArea,
        navRect: nav,
      );
      final Rect controls = placement.controls!;
      expect(controls.bottom, closeTo(nav.top - 12, _epsilon));
      expect(controls.top, closeTo(nav.top - 12 - 48, _epsilon));
      expect(controls.overlaps(nav), isFalse);
      expect(
        placement.cardRect(_cardHeight).bottom,
        lessThanOrEqualTo(controls.top - 12 + _epsilon),
      );

      final TourPlacement unknownNav = _bottomBar(
        null,
        null,
        safeArea: safeArea,
      );
      expect(unknownNav.controls!.bottom, closeTo(640 - 48 - 12, _epsilon));
    },
  );
}
