import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/features/onboarding/tour/tour_tips.dart';
import 'package:flutter/painting.dart';

const double tourCardGap = 16;
const double tourWindowInset = 16;
const double tourSidebarCardWidth = 344;
const double tourBottomBarSideInset = 12;
const double tourControlsHeight = 48;
const double tourControlsGap = 12;
const double tourTopSafeGap = 8;

const double _fitTolerance = 0.5;

class TourPlacement {
  const TourPlacement({
    required this.spotlight,
    required this.radius,
    required this.card,
    required this.cardWidth,
    required this.cardMaxHeight,
    this.controls,
  });

  final Rect? spotlight;
  final double radius;
  final Offset card;
  final double cardWidth;
  final double cardMaxHeight;
  final Rect? controls;

  Rect cardRect(double height) =>
      card & Size(cardWidth, math.min(height, cardMaxHeight));

  bool closeTo(TourPlacement other, {double tolerance = 0.5}) {
    return _rectsClose(spotlight, other.spotlight, tolerance) &&
        _rectsClose(controls, other.controls, tolerance) &&
        (radius - other.radius).abs() <= tolerance &&
        (card - other.card).distance <= tolerance &&
        (cardWidth - other.cardWidth).abs() <= tolerance &&
        (cardMaxHeight - other.cardMaxHeight).abs() <= tolerance;
  }

  static TourPlacement lerp(
    TourPlacement from,
    TourPlacement to,
    double t,
    Offset centre,
  ) {
    final Rect? spotlight = from.spotlight == null && to.spotlight == null
        ? null
        : Rect.lerp(
            from.spotlight ??
                Rect.fromCenter(center: centre, width: 0, height: 0),
            to.spotlight ??
                Rect.fromCenter(center: centre, width: 0, height: 0),
            t,
          );
    return TourPlacement(
      spotlight: spotlight == null || spotlight.isEmpty ? null : spotlight,
      radius: lerpDouble(from.radius, to.radius, t) ?? to.radius,
      card: Offset.lerp(from.card, to.card, t) ?? to.card,
      cardWidth: to.cardWidth,
      cardMaxHeight: to.cardMaxHeight,
      controls: to.controls,
    );
  }

  static bool _rectsClose(Rect? a, Rect? b, double tolerance) {
    if (a == null || b == null) {
      return a == b;
    }
    return (a.left - b.left).abs() <= tolerance &&
        (a.top - b.top).abs() <= tolerance &&
        (a.right - b.right).abs() <= tolerance &&
        (a.bottom - b.bottom).abs() <= tolerance;
  }
}

TourPlacement placeTour({
  required Size window,
  required EdgeInsets safeArea,
  required TourTip tip,
  required ShellLayout layout,
  required Rect? target,
  required double cardHeight,
  Rect? navRect,
}) {
  final TourSpot? spot = target == null ? null : tip.spotFor(layout);
  final Rect? spotlight = spot == null ? null : target!.inflate(spot.padding);
  return switch (layout) {
    ShellLayout.sidebar => _placeSidebar(
      window: window,
      spot: spot,
      spotlight: spotlight,
      cardHeight: cardHeight,
    ),
    ShellLayout.bottomBar => _placeBottomBar(
      window: window,
      safeArea: safeArea,
      spot: spot,
      spotlight: spotlight,
      cardHeight: cardHeight,
      navRect: navRect,
    ),
  };
}

TourPlacement _placeSidebar({
  required Size window,
  required TourSpot? spot,
  required Rect? spotlight,
  required double cardHeight,
}) {
  final double width = math.min(
    tourSidebarCardWidth,
    math.max(0, window.width - 2 * tourWindowInset),
  );
  final double maxHeight = math.max(0, window.height - 2 * tourWindowInset);
  final double height = math.min(cardHeight, maxHeight);
  final Offset centred = Offset(
    (window.width - width) / 2,
    (window.height - height) / 2,
  );
  final Offset card = spot == null || spotlight == null
      ? centred
      : _firstFit(
              _sidebarSides(spot.side),
              window: window,
              spotlight: spotlight,
              width: width,
              height: height,
            ) ??
            centred;
  return TourPlacement(
    spotlight: spotlight,
    radius: spot?.radius ?? 0,
    card: card,
    cardWidth: width,
    cardMaxHeight: maxHeight,
  );
}

List<TourSide> _sidebarSides(TourSide preferred) {
  return <TourSide>{
    preferred,
    _opposite(preferred),
    TourSide.below,
    TourSide.above,
  }.toList();
}

TourSide _opposite(TourSide side) {
  return switch (side) {
    TourSide.right => TourSide.left,
    TourSide.left => TourSide.right,
    TourSide.below => TourSide.above,
    TourSide.above => TourSide.below,
  };
}

Offset? _firstFit(
  List<TourSide> sides, {
  required Size window,
  required Rect spotlight,
  required double width,
  required double height,
}) {
  for (final TourSide side in sides) {
    final Offset? offset = _beside(
      side,
      window: window,
      spotlight: spotlight,
      width: width,
      height: height,
    );
    if (offset != null) {
      return offset;
    }
  }
  return null;
}

Offset? _beside(
  TourSide side, {
  required Size window,
  required Rect spotlight,
  required double width,
  required double height,
}) {
  final double minLeft = tourWindowInset;
  final double maxLeft = window.width - tourWindowInset - width;
  final double minTop = tourWindowInset;
  final double maxTop = window.height - tourWindowInset - height;
  switch (side) {
    case TourSide.right:
      final double left = spotlight.right + tourCardGap;
      return left > maxLeft
          ? null
          : Offset(left, _clamp(spotlight.top, minTop, maxTop));
    case TourSide.left:
      final double left = spotlight.left - tourCardGap - width;
      return left < minLeft
          ? null
          : Offset(left, _clamp(spotlight.top, minTop, maxTop));
    case TourSide.below:
      final double top = spotlight.bottom + tourCardGap;
      return top > maxTop
          ? null
          : Offset(
              _clamp(spotlight.center.dx - width / 2, minLeft, maxLeft),
              top,
            );
    case TourSide.above:
      final double top = spotlight.top - tourCardGap - height;
      return top < minTop
          ? null
          : Offset(
              _clamp(spotlight.center.dx - width / 2, minLeft, maxLeft),
              top,
            );
  }
}

TourPlacement _placeBottomBar({
  required Size window,
  required EdgeInsets safeArea,
  required TourSpot? spot,
  required Rect? spotlight,
  required double cardHeight,
  required Rect? navRect,
}) {
  final double width = math.max(0, window.width - 2 * tourBottomBarSideInset);
  final double controlsBottom =
      (navRect?.top ?? window.height - safeArea.bottom) - tourControlsGap;
  final Rect controls = Rect.fromLTRB(
    tourBottomBarSideInset,
    controlsBottom - tourControlsHeight,
    window.width - tourBottomBarSideInset,
    controlsBottom,
  );
  final double bandTop = safeArea.top + tourTopSafeGap;
  final double bandBottom = controls.top - tourControlsGap;
  if (spot == null || spotlight == null) {
    final double maxHeight = math.max(0, bandBottom - bandTop);
    final double height = math.min(cardHeight, maxHeight);
    return TourPlacement(
      spotlight: null,
      radius: 0,
      card: Offset(tourBottomBarSideInset, bandTop + (maxHeight - height) / 2),
      cardWidth: width,
      cardMaxHeight: maxHeight,
      controls: controls,
    );
  }
  final double aboveBottom = math.min(bandBottom, spotlight.top - tourCardGap);
  final double belowTop = math.max(bandTop, spotlight.bottom + tourCardGap);
  final double aboveRoom = math.max(0, aboveBottom - bandTop);
  final double belowRoom = math.max(0, bandBottom - belowTop);
  final bool prefersBelow = spot.side == TourSide.below;
  final double preferredRoom = prefersBelow ? belowRoom : aboveRoom;
  final double otherRoom = prefersBelow ? aboveRoom : belowRoom;
  final bool usePreferred =
      cardHeight <= preferredRoom + _fitTolerance ||
      (cardHeight > otherRoom + _fitTolerance && preferredRoom >= otherRoom);
  final bool below = usePreferred == prefersBelow;
  final double room = below ? belowRoom : aboveRoom;
  final double height = math.min(cardHeight, room);
  return TourPlacement(
    spotlight: spotlight,
    radius: spot.radius,
    card: Offset(
      tourBottomBarSideInset,
      below ? belowTop : aboveBottom - height,
    ),
    cardWidth: width,
    cardMaxHeight: room,
    controls: controls,
  );
}

double _clamp(double value, double min, double max) {
  return math.max(min, math.min(max, value));
}
