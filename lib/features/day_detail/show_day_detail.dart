import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';

import 'day_detail_panel.dart';

const String _barrierLabel = 'Dismiss day detail';

const double _scrimBlurSigma = 3.5;

const RadialGradient _scrimGradient = RadialGradient(
  center: Alignment(0, -0.36),
  radius: 1.2,
  colors: <Color>[Color(0x5C2A2016), Color(0x9E1C140C)],
);

Future<void> showDayDetail(
  BuildContext context, {
  required String date,
  String? focusEntryId,
}) {
  if (!isCaptureDateKey(date)) {
    throw ArgumentError.value(
      date,
      'date',
      'must be a YYYY-MM-DD calendar date key',
    );
  }
  if (resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar) {
    return showPhoneSheet<void>(
      context,
      barrierLabel: _barrierLabel,
      builder: (BuildContext sheetContext) {
        return _HandOverCover(
          coverAnimation:
              ModalRoute.of(sheetContext)?.secondaryAnimation ??
              kAlwaysDismissedAnimation,
          builder: (ValueChanged<bool> onCoveredChanged) {
            return DayDetailPanel(
              date: date,
              focusEntryId: focusEntryId,
              onCoveredChanged: onCoveredChanged,
              layout: ShellLayout.bottomBar,
            );
          },
        );
      },
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: _barrierLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return _HandOverCover(
            coverAnimation: secondaryAnimation,
            builder: (ValueChanged<bool> onCoveredChanged) {
              return _DayDetailPage(
                date: date,
                focusEntryId: focusEntryId,
                onCoveredChanged: onCoveredChanged,
              );
            },
          );
        },
    transitionBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Motion.entranceCurve,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
  );
}

class _HandOverCover extends StatefulWidget {
  const _HandOverCover({required this.coverAnimation, required this.builder});

  final Animation<double> coverAnimation;
  final Widget Function(ValueChanged<bool> onCoveredChanged) builder;

  @override
  State<_HandOverCover> createState() => _HandOverCoverState();
}

class _HandOverCoverState extends State<_HandOverCover> {
  bool _covered = false;

  void _setCovered(bool covered) {
    if (mounted && covered != _covered) {
      setState(() => _covered = covered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.coverAnimation,
      builder: (BuildContext context, Widget? child) {
        return Offstage(
          offstage: _covered && widget.coverAnimation.isCompleted,
          child: child,
        );
      },
      child: widget.builder(_setCovered),
    );
  }
}

class _DayDetailPage extends StatelessWidget {
  const _DayDetailPage({
    required this.date,
    required this.focusEntryId,
    required this.onCoveredChanged,
  });

  final String date;
  final String? focusEntryId;
  final ValueChanged<bool> onCoveredChanged;

  @override
  Widget build(BuildContext context) {
    return DialogHost(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => Navigator.maybePop(context),
              child: const _DayDetailScrim(),
            ),
          ),
          DayDetailPanel(
            date: date,
            focusEntryId: focusEntryId,
            onCoveredChanged: onCoveredChanged,
          ),
        ],
      ),
    );
  }
}

class _DayDetailScrim extends StatelessWidget {
  const _DayDetailScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _scrimBlurSigma,
          sigmaY: _scrimBlurSigma,
        ),
        child: const DecoratedBox(
          decoration: BoxDecoration(gradient: _scrimGradient),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
