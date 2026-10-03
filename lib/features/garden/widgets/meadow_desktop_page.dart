import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/features/garden/model/meadow_time_of_day.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/garden_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_panel.dart';
import 'package:field_notes/features/garden/widgets/meadow_focus_stepper.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';

const double meadowDeskTitleInset = 26;
const double meadowDeskTitleDrop = 22;
const double meadowDeskScrimDepth = 170;
const double meadowDeskDockBottom = 20;
const double meadowDeskStudyBottom = 82;
const double meadowDeskStudyWidth = 520;
const double meadowDeskYearDropWidth = 300;
const double meadowDeskYearDropHeight = 360;
const double meadowDeskTimeDropWidth = 200;
const Duration meadowDeskChromeFade = Duration(milliseconds: 250);
const Duration meadowDeskRecentre = Duration(milliseconds: 300);
const String meadowYearTooltip = 'Your meadows, year by year (← →)';
const String meadowDetailsTooltip = 'The year, day by day (D)';
const String meadowFullScreenTooltip = 'Full screen (F)';
const String meadowExitFullScreenTooltip = 'Exit full screen (F)';
const ValueKey<String> meadowDropUpKey = ValueKey<String>('meadow-drop-up');
const ValueKey<String> meadowDropUpBarrierKey = ValueKey<String>(
  'meadow-drop-up-barrier',
);
const ValueKey<String> meadowDockFadeKey = ValueKey<String>('meadow-dock-fade');
const ValueKey<String> meadowTitleFadeKey = ValueKey<String>(
  'meadow-title-fade',
);

const Duration _dropRise = Duration(milliseconds: 140);
const double _dropGap = 12;
const double _dockGap = 4;
const double _roundExtent = 40;
const BorderRadius _dockRadius = BorderRadius.all(Radius.circular(26));
const BorderRadius _dropRadius = BorderRadius.all(Radius.circular(18));
const BorderRadius _roundRadius = BorderRadius.all(Radius.circular(20));

class MeadowDesktopPage extends StatefulWidget {
  const MeadowDesktopPage({super.key, required this.chrome, this.study});

  final MeadowChrome chrome;
  final MeadowStudyParts? study;

  @override
  State<MeadowDesktopPage> createState() => _MeadowDesktopPageState();
}

class _MeadowDesktopPageState extends State<MeadowDesktopPage> {
  final LayerLink _yearLink = LayerLink();
  final LayerLink _timeLink = LayerLink();
  final OverlayPortalController _dropUps = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _dropUps.show();
  }

  MeadowChrome get _chrome => widget.chrome;

  void _toggle(MeadowPopover popover) => _chrome.onPopover(
    _chrome.popover == popover ? MeadowPopover.none : popover,
  );

  void _close() => _chrome.onPopover(MeadowPopover.none);

  @override
  Widget build(BuildContext context) {
    final MeadowChrome chrome = _chrome;
    final MeadowStudyParts? parts = widget.study;
    final Widget? stepper = chrome.stepper;
    final double reserve = chrome.detailsOpen ? meadowDetailsPanelReserve : 0;
    final bool hidden = chrome.dragging;
    final Duration recentre = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : meadowDeskRecentre;
    final double top =
        meadowDeskTitleDrop + (chrome.fullScreen ? shellTitleBarHeight : 0);
    return OverlayPortal(
      controller: _dropUps,
      overlayChildBuilder: _dropUp,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double space = math.max(0, constraints.maxWidth - reserve);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: meadowLoadingBackdrop),
              Positioned.fill(child: chrome.scene),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: meadowDeskScrimDepth,
                child: IgnorePointer(child: MeadowScrim(opacity: 0.48)),
              ),
              AnimatedPositioned(
                key: meadowTitleBlockKey,
                duration: recentre,
                curve: meadowEase,
                left: meadowDeskTitleInset,
                right: meadowDeskTitleInset + reserve,
                top: top,
                child: _Fade(
                  key: meadowTitleFadeKey,
                  hidden: hidden,
                  child: chrome.header,
                ),
              ),
              if (parts != null && stepper == null)
                AnimatedPositioned(
                  duration: recentre,
                  curve: meadowEase,
                  left: 0,
                  right: reserve,
                  bottom: meadowDeskStudyBottom,
                  child: Center(
                    child: _Fade(
                      hidden: hidden,
                      child: SizedBox(
                        width: math.max(
                          0,
                          math.min(meadowDeskStudyWidth, space - 40),
                        ),
                        child: parts.panel,
                      ),
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: recentre,
                curve: meadowEase,
                left: 0,
                right: reserve,
                bottom: meadowDeskDockBottom,
                child: Center(
                  child: stepper == null
                      ? _Fade(
                          key: meadowDockFadeKey,
                          hidden: hidden,
                          child: _dock(parts),
                        )
                      : SizedBox(
                          width: math.min(meadowDeskStepperWidth, space - 24),
                          child: stepper,
                        ),
                ),
              ),
              Positioned(
                top: meadowDetailsPanelInset,
                right: meadowDetailsPanelInset,
                bottom: meadowDetailsPanelInset,
                width: meadowDetailsPanelWidth,
                child: MeadowDetailsPanel(
                  open: chrome.detailsOpen,
                  child: chrome.details,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dock(MeadowStudyParts? parts) {
    final MeadowChrome chrome = _chrome;
    final Widget? clock = chrome.clock;
    final List<Widget> items = <Widget>[
      CompositedTransformTarget(
        link: _yearLink,
        child: MeadowDockPill(
          key: meadowYearPickerButtonKey,
          label: meadowYearPickerLabel,
          text: '${chrome.year.year}',
          semanticValue: '${chrome.year.year}',
          tooltip: meadowYearTooltip,
          caret: true,
          fontSize: 14,
          onPressed: () => _toggle(MeadowPopover.year),
        ),
      ),
      const _Divider(),
      if (parts == null) ...<Widget>[
        ?clock,
        CompositedTransformTarget(
          link: _timeLink,
          child: MeadowDockPill(
            key: meadowTimeButtonKey,
            label: meadowTimeButtonLabel,
            text: chrome.timeLabel,
            semanticValue: chrome.timeLabel,
            tooltip: meadowTimeButtonLabel,
            caret: true,
            onPressed: () => _toggle(MeadowPopover.time),
          ),
        ),
      ] else ...<Widget>[parts.play, parts.replay],
      const _Divider(),
      _DockRound(
        key: meadowDetailsButtonKey,
        label: meadowDetailsLabel,
        tooltip: meadowDetailsTooltip,
        selected: chrome.detailsOpen,
        onPressed: chrome.onDetails,
        child: MeadowGlyph(path: meadowFourSquares, size: 17, stroke: 1.8),
      ),
      _DockRound(
        key: meadowFullScreenButtonKey,
        label: chrome.fullScreen
            ? meadowExitFullScreenLabel
            : meadowFullScreenLabel,
        tooltip: chrome.fullScreen
            ? meadowExitFullScreenTooltip
            : meadowFullScreenTooltip,
        selected: false,
        onPressed: chrome.onFullScreen,
        child: MeadowGlyph(
          path: chrome.fullScreen ? meadowCollapseCorners : meadowExpandCorners,
          size: 15,
        ),
      ),
    ];
    return MeadowChromeBlock(
      child: GlassSurface(
        key: meadowDockKey,
        tone: GlassTone.scene,
        borderRadius: _dockRadius,
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int index = 0; index < items.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: _dockGap),
              items[index],
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropUp(BuildContext context) {
    final MeadowChrome chrome = _chrome;
    final MeadowPopover popover = chrome.popover;
    if (popover == MeadowPopover.none || chrome.stepper != null) {
      return const SizedBox.shrink();
    }
    final bool year = popover == MeadowPopover.year;
    final MeadowTimeOfDay? current = meadowTimeOfDayAt(chrome.shownMinutes);
    final Widget content = year
        ? ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: meadowDeskYearDropHeight - 14,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                    child: Semantics(
                      header: true,
                      child: Text(
                        meadowYearPickerHeading,
                        style: meadowHandStyle(15),
                      ),
                    ),
                  ),
                  MeadowYearList(
                    years: chrome.years,
                    openYear: chrome.year.year,
                    compact: false,
                    onPick: (int picked) {
                      _close();
                      chrome.onPickYear(picked);
                    },
                  ),
                ],
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int index = 0; index < meadowTimesOfDay.length; index++)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
                  child: MeadowTimeRow(
                    label: meadowTimesOfDay[index].label,
                    sub: meadowTimesOfDay[index].sub,
                    compact: false,
                    selected: meadowTimesOfDay[index] == current,
                    onPressed: () => chrome.onTime(meadowTimesOfDay[index]),
                  ),
                ),
            ],
          );
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            key: meadowDropUpBarrierKey,
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: year ? _yearLink : _timeLink,
            showWhenUnlinked: false,
            targetAnchor: year ? Alignment.topLeft : Alignment.topCenter,
            followerAnchor: year
                ? Alignment.bottomLeft
                : Alignment.bottomCenter,
            offset: Offset(year ? -6 : 0, -_dropGap),
            child: MeadowRise(
              duration: _dropRise,
              distance: 4,
              child: SizedBox(
                width: year ? meadowDeskYearDropWidth : meadowDeskTimeDropWidth,
                child: MeadowChromeBlock(
                  child: MeadowGlass(
                    key: meadowDropUpKey,
                    borderRadius: _dropRadius,
                    padding: const EdgeInsets.all(6),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({super.key, required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : meadowDeskChromeFade,
        child: child,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 22,
      child: ColoredBox(color: meadowGlassWhite(0.22)),
    );
  }
}

class _DockRound extends StatefulWidget {
  const _DockRound({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_DockRound> createState() => _DockRoundState();
}

class _DockRoundState extends State<_DockRound> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double fill = widget.selected
        ? 0.2
        : _hovered
        ? 0.14
        : 0;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (PointerEnterEvent event) => _hover(true),
        onExit: (PointerExitEvent event) => _hover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onPressed,
          child: FocusRing(
            onPressed: widget.onPressed,
            surface: FocusRingSurface.dark,
            borderRadius: _roundRadius,
            child: ExcludeSemantics(
              child: Tooltip(
                message: widget.tooltip,
                excludeFromSemantics: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: meadowGlassWhite(fill),
                    borderRadius: _roundRadius,
                  ),
                  child: SizedBox.square(
                    dimension: _roundExtent,
                    child: Center(child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
