import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';

import 'day_detail_panel.dart';

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
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss day detail',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return _DayDetailPage(
        date: date,
        focusEntryId: focusEntryId,
        coverAnimation: secondaryAnimation,
      );
    },
    transitionBuilder: (
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

class _DayDetailPage extends StatefulWidget {
  const _DayDetailPage({
    required this.date,
    required this.focusEntryId,
    required this.coverAnimation,
  });

  final String date;
  final String? focusEntryId;
  final Animation<double> coverAnimation;

  @override
  State<_DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<_DayDetailPage> {
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
      child: DialogHost(
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
              date: widget.date,
              focusEntryId: widget.focusEntryId,
              onCoveredChanged: _setCovered,
            ),
          ],
        ),
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
