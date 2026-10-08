import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../feedback/dialog_host.dart';
import '../tokens/tokens.dart';

const Color phoneSheetBarrierColor = Color(0x572A241D);
const Duration phoneSheetEntrance = Duration(milliseconds: 260);
const Cubic phoneSheetCurve = Cubic(0.2, 0.8, 0.2, 1);

const double phoneSheetBorderWidth = 2;
const double phoneSheetRadius = Shapes.radiusSheet;
const double phoneSheetTopClearance = 8;
const double phoneSheetGrabberWidth = 38;
const double phoneSheetGrabberHeight = 4;
const double phoneSheetGrabberRadius = 3;
const double phoneSheetGrabberTop = 10;
const double phoneSheetGrabberBottom = 2;
const double phoneSheetDragArea = 44;
const double phoneSheetDismissDistance = 60;
const double phoneSheetExpandDistance = 30;
const double phoneSheetShrinkDistance = 40;
const double phoneSheetTapSlop = 6;
const double phoneSheetGrabberTargetWidth = 88;
const double phoneSheetActionGap = 8;
const EdgeInsets phoneSheetFooterPadding = EdgeInsets.fromLTRB(12, 10, 12, 12);

const double _titleTop = 8;
const double _titleSize = 18;
const Duration _settleBack = Duration(milliseconds: 180);

const Key phoneSheetGrabberKey = ValueKey<String>('phone-sheet-grabber');
const Key phoneSheetFooterKey = ValueKey<String>('phone-sheet-footer');
const Key phoneSheetGrabberToggleKey = ValueKey<String>(
  'phone-sheet-grabber-toggle',
);

const String phoneSheetExpandLabel = 'Expand sheet';
const String phoneSheetShrinkLabel = 'Shrink sheet';

Future<T?> showPhoneSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String barrierLabel = 'Dismiss',
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: phoneSheetBarrierColor,
    transitionDuration: still ? Duration.zero : phoneSheetEntrance,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    pageBuilder:
        (
          BuildContext sheetContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return DialogHost(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Builder(builder: builder),
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext sheetContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: phoneSheetCurve),
                ),
            child: child,
          );
        },
  );
}

class PhoneSheet extends StatefulWidget {
  const PhoneSheet({
    super.key,
    required this.child,
    this.color,
    this.title,
    this.header,
    this.aboveFooter,
    this.actions = const <Widget>[],
    this.footerDirection = Axis.horizontal,
    this.footerPadding = phoneSheetFooterPadding,
    this.expanded = false,
    this.onExpandedChanged,
  });

  final Widget child;
  final Color? color;
  final String? title;
  final Widget? header;
  final Widget? aboveFooter;
  final List<Widget> actions;
  final Axis footerDirection;
  final EdgeInsets footerPadding;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<PhoneSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  double _travel = 0;
  Offset _tapOrigin = Offset.zero;

  void _onDragStart(DragStartDetails details) {
    _travel = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double delta = details.primaryDelta ?? 0;
    _travel += delta;
    _drag.value = math.max(0, _drag.value + delta);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final ValueChanged<bool>? onExpandedChanged = widget.onExpandedChanged;
    if (onExpandedChanged == null) {
      if (_drag.value > phoneSheetDismissDistance) {
        await Navigator.maybeOf(context)?.maybePop();
      }
    } else if (_travel < -phoneSheetExpandDistance) {
      if (!widget.expanded) {
        onExpandedChanged(true);
      }
    } else if (_travel > phoneSheetShrinkDistance) {
      if (widget.expanded) {
        onExpandedChanged(false);
      } else {
        await Navigator.maybeOf(context)?.maybePop();
      }
    }
    if (mounted && (ModalRoute.isCurrentOf(context) ?? true)) {
      _settle();
    }
  }

  void _onGrabberTapDown(TapDownDetails details) {
    _tapOrigin = details.globalPosition;
  }

  void _onGrabberTapUp(TapUpDetails details) {
    if ((details.globalPosition - _tapOrigin).distance < phoneSheetTapSlop) {
      _toggle();
    }
  }

  void _toggle() {
    widget.onExpandedChanged?.call(!widget.expanded);
  }

  void _settle() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _drag.value = 0;
      return;
    }
    _drag.animateTo(0, duration: _settleBack, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double maxHeight = math.max(
      0,
      MediaQuery.sizeOf(context).height - padding.top - phoneSheetTopClearance,
    );
    final String? title = widget.title;
    final Widget? header = widget.header;
    final Widget? aboveFooter = widget.aboveFooter;
    final bool expandable = widget.onExpandedChanged != null;
    final bool full = expandable && widget.expanded;
    final List<Widget> top = <Widget>[
      const _Grabber(),
      if (title != null) _title(context, title),
      ?header,
    ];
    final Widget body = SingleChildScrollView(child: widget.child);
    final Widget sheet = SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: full
            ? BoxConstraints.tightFor(height: maxHeight)
            : BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color ?? colors.cardWarm,
            border: Border(
              top: BorderSide(color: colors.line, width: phoneSheetBorderWidth),
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(phoneSheetRadius),
            ),
            boxShadow: Shadows.chooserSheetLift,
          ),
          child: Stack(
            children: <Widget>[
              Column(
                mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (expandable)
                    _dragArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: top,
                      ),
                    )
                  else
                    ...top,
                  if (full) Expanded(child: body) else Flexible(child: body),
                  ?aboveFooter,
                  if (widget.actions.isNotEmpty) _footer(),
                  SizedBox(height: padding.bottom),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: phoneSheetDragArea,
                child: _dragArea(),
              ),
              if (expandable)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: phoneSheetDragArea,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _grabberToggle(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _drag,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(
          offset: Offset(0, _drag.value),
          child: child,
        );
      },
      child: sheet,
    );
  }

  Widget _dragArea({Widget? child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onVerticalDragCancel: _settle,
      child: child,
    );
  }

  Widget _grabberToggle() {
    return Semantics(
      container: true,
      button: true,
      label: widget.expanded ? phoneSheetShrinkLabel : phoneSheetExpandLabel,
      onTap: _toggle,
      child: GestureDetector(
        key: phoneSheetGrabberToggleKey,
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTapDown: _onGrabberTapDown,
        onTapUp: _onGrabberTapUp,
        child: const SizedBox(
          width: phoneSheetGrabberTargetWidth,
          height: phoneSheetDragArea,
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: _titleTop),
      child: Text(
        title,
        style: context.textStyles.headlineSerif.copyWith(fontSize: _titleSize),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _footer() {
    final bool horizontal = widget.footerDirection == Axis.horizontal;
    final Widget gap = horizontal
        ? const SizedBox(width: phoneSheetActionGap)
        : const SizedBox(height: phoneSheetActionGap);
    return Padding(
      key: phoneSheetFooterKey,
      padding: widget.footerPadding,
      child: Flex(
        direction: widget.footerDirection,
        mainAxisSize: horizontal ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: horizontal
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: <Widget>[
          for (
            int index = 0;
            index < widget.actions.length;
            index++
          ) ...<Widget>[if (index > 0) gap, widget.actions[index]],
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: phoneSheetGrabberTop,
        bottom: phoneSheetGrabberBottom,
      ),
      child: Center(
        child: SizedBox(
          key: phoneSheetGrabberKey,
          width: phoneSheetGrabberWidth,
          height: phoneSheetGrabberHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.ink30,
              borderRadius: const BorderRadius.all(
                Radius.circular(phoneSheetGrabberRadius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
