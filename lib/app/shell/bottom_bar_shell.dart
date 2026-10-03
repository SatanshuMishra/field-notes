import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/features/streak/streak.dart';

import '../../design/tokens/tokens.dart';
import 'keep_focus_in_view.dart';
import 'phone_bottom_bar.dart';
import 'shell_destination.dart';

const double phoneHeaderBarHeight = 44;
const double phoneHeaderGearExtent = 44;
const double phoneBottomBarZone = 80;
const double phoneHeaderScrolledOffset = 4;

const double _headerLeftPadding = 18;
const double _headerRightPadding = 8;
const double _headerTrailingGap = 2;
const double _gearIconSize = 22;
const double _headerEdgeWidth = 1;

const Color _paperHeaderTintLight = Color.fromRGBO(239, 226, 206, 0.62);
const Color _paperHeaderTintDark = Color.fromRGBO(31, 26, 21, 0.66);
const Color _sceneHeaderTint = Color.fromRGBO(24, 19, 14, 0.42);
const Color _sceneHeaderEdge = Color.fromRGBO(255, 250, 240, 0.16);
const Color _sceneHeaderShadow = Color.fromRGBO(0, 0, 0, 0.6);
const Color _sceneWordmark = Color(0xFFF6C9B8);
const Color _sceneGear = Color.fromRGBO(251, 243, 228, 1);

const Offset _headerShadowOffset = Offset(0, 8);
const double _headerShadowBlur = 20;
const double _headerShadowSpread = -14;

const BorderRadius _gearRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

double phoneStatusBarInset(MediaQueryData media) =>
    math.max(media.padding.top, media.viewPadding.top);

double phoneGestureBarInset(MediaQueryData media) =>
    math.max(media.padding.bottom, media.viewPadding.bottom);

class BottomBarShell extends StatefulWidget {
  const BottomBarShell({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onCapture,
    required this.body,
    this.obscured = false,
  }) : assert(
         destinations.length == 4,
         'BottomBarShell requires four destinations',
       );

  final List<ShellDestination> destinations;
  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final VoidCallback onCapture;
  final Widget body;
  final bool obscured;

  @override
  State<BottomBarShell> createState() => _BottomBarShellState();
}

class _BottomBarShellState extends State<BottomBarShell> {
  bool _scrolled = false;

  bool get _overScene => widget.selected == ShellDestination.garden;

  @override
  void didUpdateWidget(BottomBarShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _scrolled = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final bool scrolled =
        notification.metrics.extentBefore > phoneHeaderScrolledOffset;
    if (scrolled != _scrolled) {
      setState(() => _scrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double statusBar = phoneStatusBarInset(media);
    final double gestureBar = phoneGestureBarInset(media);
    final double keyboard = media.viewInsets.bottom;
    final double headerHeight = statusBar + phoneHeaderBarHeight;
    final bool obscured = widget.obscured;
    return KeepFocusInView(
      child: ExcludeSemantics(
        excluding: obscured,
        child: ExcludeFocus(
          excluding: obscured,
          child: AbsorbPointer(
            absorbing: obscured,
            child: Scaffold(
              backgroundColor: context.colors.panelTop,
              resizeToAvoidBottomInset: false,
              body: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(bottom: keyboard),
                      child: MediaQuery(
                        data: _bodyMedia(
                          media,
                          headerHeight: headerHeight,
                          gestureBar: gestureBar,
                        ),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: FocusTraversalGroup(child: widget.body),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: headerHeight,
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(0),
                        child: FocusTraversalGroup(
                          child: _header(context, statusBar: statusBar),
                        ),
                      ),
                    ),
                    Positioned(
                      left: phoneBottomBarSideInset,
                      right: phoneBottomBarSideInset,
                      bottom: gestureBar + phoneBottomBarGap,
                      height: phoneBottomBarHeight,
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: FocusTraversalGroup(
                          child: PhoneBottomBar(
                            destinations: widget.destinations,
                            selected: widget.selected,
                            onSelect: widget.onSelect,
                            onCapture: widget.onCapture,
                            overScene: _overScene,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  MediaQueryData _bodyMedia(
    MediaQueryData media, {
    required double headerHeight,
    required double gestureBar,
  }) {
    final double keyboard = media.viewInsets.bottom;
    return media.copyWith(
      padding: media.padding.copyWith(
        top: headerHeight,
        bottom: keyboard > 0 ? 0 : gestureBar + phoneBottomBarZone,
      ),
      viewPadding: media.viewPadding.copyWith(
        bottom: math.max(0, media.viewPadding.bottom - keyboard),
      ),
      viewInsets: media.viewInsets.copyWith(bottom: 0),
    );
  }

  Widget _header(BuildContext context, {required double statusBar}) {
    final FieldNotesColors colors = context.colors;
    final bool overScene = _overScene;
    final Widget? glass = overScene
        ? _sceneGlass()
        : _scrolled
        ? _paperGlass(context)
        : null;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ?glass,
        Padding(
          padding: EdgeInsets.only(
            top: statusBar,
            left: _headerLeftPadding,
            right: _headerRightPadding,
          ),
          child: Row(
            children: <Widget>[
              Text(
                'field notes',
                style: overScene
                    ? context.textStyles.wordmarkAccent.copyWith(
                        color: _sceneWordmark,
                      )
                    : context.textStyles.wordmarkAccent.copyWith(
                        color: colors.accentInkStrong,
                      ),
              ),
              const Spacer(),
              StreakPill(
                form: overScene
                    ? StreakPillForm.headerOverScene
                    : StreakPillForm.header,
              ),
              const SizedBox(width: _headerTrailingGap),
              _gear(overScene ? _sceneGear : colors.ink),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sceneGlass() {
    return const GlassSurface(
      key: ValueKey<String>('phone-header-glass'),
      tone: GlassTone.scene,
      borderRadius: BorderRadius.zero,
      tint: _sceneHeaderTint,
      border: Border(
        bottom: BorderSide(color: _sceneHeaderEdge, width: _headerEdgeWidth),
      ),
      shadows: <BoxShadow>[
        BoxShadow(
          color: _sceneHeaderShadow,
          offset: _headerShadowOffset,
          blurRadius: _headerShadowBlur,
          spreadRadius: _headerShadowSpread,
        ),
      ],
      child: SizedBox.expand(),
    );
  }

  Widget _paperGlass(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final GlassColors glass = GlassTone.paper.colorsFor(brightness);
    return GlassSurface(
      key: const ValueKey<String>('phone-header-glass'),
      tone: GlassTone.paper,
      borderRadius: BorderRadius.zero,
      tint: brightness == Brightness.dark
          ? _paperHeaderTintDark
          : _paperHeaderTintLight,
      border: Border(
        bottom: BorderSide(color: glass.border, width: _headerEdgeWidth),
      ),
      shadows: <BoxShadow>[
        BoxShadow(
          color: glass.shadows.first.color,
          offset: _headerShadowOffset,
          blurRadius: _headerShadowBlur,
          spreadRadius: _headerShadowSpread,
        ),
      ],
      child: const SizedBox.expand(),
    );
  }

  Widget _gear(Color ink) {
    void open() => widget.onSelect(ShellDestination.settings);
    return Semantics(
      button: true,
      label: ShellDestination.settings.label,
      child: GestureDetector(
        key: const ValueKey<String>('gear-button'),
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: SizedBox.square(
          dimension: phoneHeaderGearExtent,
          child: FocusRing(
            onPressed: open,
            borderRadius: _gearRadius,
            placement: FocusRingPlacement.edge,
            child: Center(
              child: ExcludeSemantics(
                child: Icon(
                  Icons.settings_outlined,
                  size: _gearIconSize,
                  color: ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
