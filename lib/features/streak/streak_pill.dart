import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/icons/flame_icon.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/phone_sheet.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart'
    show weekdayNames;
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StreakPillForm { header, headerOverScene, sidebar, rail }

String streakPillLabel(int days) => days == 1 ? '1 day' : '$days days';

String streakPillAnnouncement(int days) => '${streakPillLabel(days)} in a row';

const String _lateNightEnds = '$lateNightEndHour AM';

const String streakLateNightLine = 'late night · until $_lateNightEnds';

const String streakLateNightNudge =
    'Add a log and pick its bloom to keep your run going.';

String streakLateNightTitle(DateTime day) =>
    '${_weekdayOf(day)} still counts until $_lateNightEnds';

String streakLateNightAction(DateTime day) => 'Open ${_weekdayOf(day)}';

String streakLateNightAnnouncement(int days) =>
    '${streakPillAnnouncement(days)}, late night until $_lateNightEnds';

String _weekdayOf(DateTime day) =>
    weekdayNames(firstWeekday: day.weekday).first;

const Key streakPillFaceKey = ValueKey<String>('streak-pill-face');
const Key streakMoonBadgeKey = ValueKey<String>('streak-moon-badge');
const Key streakLateNightOpenKey = ValueKey<String>('streak-late-night-open');

const double streakPillHeaderHeight = 30;
const double streakRailWidth = 44;
const double streakRailHeight = 56;

const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(9, 0, 11, 0);
const EdgeInsets _sidebarPadding = EdgeInsets.symmetric(
  vertical: 10,
  horizontal: 12,
);

const BorderRadius _headerRadius = BorderRadius.all(
  Radius.circular(streakPillHeaderHeight / 2),
);
const BorderRadius _stickerRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

const double _headerFlame = 14;
const double _stickerFlame = 17;
const double _railFlame = 14;
const double _headerGap = 5;
const double _sidebarGap = 6;
const double _railGap = 2;
const double _headerText = 19;
const double _sidebarText = 23;
const double _railText = 19;
const double _railLineHeight = 0.9;
const double _lateLineText = 14;
const double _lateLineGap = 3;
const double _sceneEdgeWidth = 1;
const double _nightEdgeWidth = 1.5;
const double _ringSpread = 4;

const double _moonBadgeSize = 18;
const double _moonBadgeRing = 1.5;
const double _moonBadgeOverlap = 6;
const double _moonGlyph = 10;
const double _moonStroke = 2;
const double _moonViewBox = 24;

const Color _sceneFill = Color.fromRGBO(255, 250, 240, 0.14);
const Color _sceneEdge = Color.fromRGBO(255, 250, 240, 0.28);
const Color _ring = Color.fromRGBO(184, 86, 106, 0.25);

const EdgeInsets _tipPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 12,
);
const BorderRadius _tipRadius = BorderRadius.all(Radius.circular(12));
const double _tipMaxWidth = 280;
const TextStyle _tipText = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.45,
  color: Palette.toolbarInk,
);
const TextStyle _tipTitle = TextStyle(fontWeight: FontWeight.w700, height: 1.3);
const BorderRadius _tipLinkRadius = BorderRadius.all(Radius.circular(4));
const TextStyle _tipLink = TextStyle(
  fontWeight: FontWeight.w600,
  height: 2,
  decoration: TextDecoration.underline,
);

const EdgeInsets _sheetBodyPadding = EdgeInsets.fromLTRB(20, 10, 20, 4);
const EdgeInsets _sheetFooterPadding = EdgeInsets.fromLTRB(12, 14, 12, 12);
const double _sheetMessageGap = 6;
const TextStyle _sheetMessage = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 15,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

typedef _PillLook = ({
  Color fill,
  Border? border,
  Color? dashes,
  Color ink,
  Color flame,
  List<BoxShadow> shadows,
});

class StreakPill extends ConsumerWidget {
  const StreakPill({
    super.key,
    this.form = StreakPillForm.header,
    this.count,
    this.numberOnly = false,
    this.highlighted = false,
  });

  final StreakPillForm form;
  final int? count;
  final bool numberOnly;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (int days, DateTime? waitingDay) = switch (count) {
      final int fixed => (fixed, null),
      null => ref.watch(
        streakSummaryProvider.select(
          (StreakSummary summary) => (summary.current, summary.lateNightDay),
        ),
      ),
    };
    if (waitingDay != null && !highlighted) {
      return _LateNightPill(
        form: form,
        days: days,
        day: waitingDay,
        numberOnly: numberOnly,
      );
    }
    final String announcement = streakPillAnnouncement(days);
    return Tooltip(
      message: announcement,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        label: announcement,
        excludeSemantics: true,
        child: _PillFace(
          form: form,
          days: days,
          numberOnly: numberOnly,
          highlighted: highlighted,
          lateNight: false,
        ),
      ),
    );
  }
}

class _LateNightPill extends StatefulWidget {
  const _LateNightPill({
    required this.form,
    required this.days,
    required this.day,
    required this.numberOnly,
  });

  final StreakPillForm form;
  final int days;
  final DateTime day;
  final bool numberOnly;

  @override
  State<_LateNightPill> createState() => _LateNightPillState();
}

class _LateNightPillState extends State<_LateNightPill> {
  bool get _onPhone =>
      widget.form == StreakPillForm.header ||
      widget.form == StreakPillForm.headerOverScene;

  void _openDay() {
    showDayDetail(context, date: captureDateKey(widget.day));
  }

  Future<void> _press() async {
    if (!_onPhone) {
      _openDay();
      return;
    }
    final bool? open = await showPhoneSheet<bool>(
      context,
      builder: (BuildContext sheetContext) => _LateNightSheet(day: widget.day),
    );
    if ((open ?? false) && mounted) {
      _openDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String announcement = streakLateNightAnnouncement(widget.days);
    return Tooltip(
      excludeFromSemantics: true,
      constraints: const BoxConstraints(maxWidth: _tipMaxWidth),
      padding: _tipPadding,
      decoration: BoxDecoration(
        color: Palette.mediaInk,
        borderRadius: _tipRadius,
        boxShadow: context.shadows.emphasis,
      ),
      textStyle: _tipText,
      richMessage: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '${streakLateNightTitle(widget.day)}\n',
            style: _tipTitle,
          ),
          const TextSpan(text: '$streakLateNightNudge\n'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Pressable(
              label: streakLateNightAction(widget.day),
              onPressed: _openDay,
              borderRadius: _tipLinkRadius,
              paintsHover: false,
              child: Text(
                streakLateNightAction(widget.day),
                style: _tipText
                    .merge(_tipLink)
                    .copyWith(color: FieldNotesColors.light.accentInkStrong),
              ),
            ),
          ),
        ],
      ),
      child: Pressable(
        label: announcement,
        hint: streakLateNightAction(widget.day),
        onPressed: _press,
        borderRadius: _onPhone ? _headerRadius : _stickerRadius,
        child: _PillFace(
          form: widget.form,
          days: widget.days,
          numberOnly: widget.numberOnly,
          highlighted: false,
          lateNight: true,
        ),
      ),
    );
  }
}

class _LateNightSheet extends StatelessWidget {
  const _LateNightSheet({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return PhoneSheet(
      footerDirection: Axis.vertical,
      footerPadding: _sheetFooterPadding,
      actions: <Widget>[
        PhoneSheetButton(
          key: streakLateNightOpenKey,
          label: streakLateNightAction(day),
          background: Palette.coral,
          foreground: Palette.onAccent,
          shadows: context.shadows.emphasis,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      child: Padding(
        padding: _sheetBodyPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(streakLateNightTitle(day), style: context.textStyles.title),
            const SizedBox(height: _sheetMessageGap),
            Text(
              streakLateNightNudge,
              style: _sheetMessage.copyWith(color: colors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillFace extends StatelessWidget {
  const _PillFace({
    required this.form,
    required this.days,
    required this.numberOnly,
    required this.highlighted,
    required this.lateNight,
  });

  final StreakPillForm form;
  final int days;
  final bool numberOnly;
  final bool highlighted;
  final bool lateNight;

  bool get _sticker =>
      form == StreakPillForm.sidebar || form == StreakPillForm.rail;

  BorderRadius get _radius => _sticker ? _stickerRadius : _headerRadius;

  FieldNotesColors _lateNightColors(BuildContext context) =>
      form == StreakPillForm.headerOverScene
      ? FieldNotesColors.dark
      : context.colors;

  _PillLook _look(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final List<BoxShadow> base = _sticker
        ? context.shadows.emphasis
        : const <BoxShadow>[];
    if (highlighted) {
      return (
        fill: Palette.coral,
        border: context.shadows.outline,
        dashes: null,
        ink: Palette.onAccent,
        flame: Palette.onAccent,
        shadows: <BoxShadow>[
          const BoxShadow(color: _ring, spreadRadius: _ringSpread),
          ...base,
        ],
      );
    }
    final Color fill = switch (form) {
      StreakPillForm.headerOverScene => _sceneFill,
      StreakPillForm.header ||
      StreakPillForm.sidebar ||
      StreakPillForm.rail => colors.cardLight,
    };
    if (lateNight) {
      final Color sage = _lateNightColors(context).lateNight;
      return (
        fill: fill,
        border: null,
        dashes: sage,
        ink: sage,
        flame: sage,
        shadows: base,
      );
    }
    return switch (form) {
      StreakPillForm.header => (
        fill: fill,
        border: Border.all(color: colors.ink22, width: Shapes.outlineWidth),
        dashes: null,
        ink: colors.accentInk,
        flame: colors.accentInk,
        shadows: base,
      ),
      StreakPillForm.headerOverScene => (
        fill: fill,
        border: Border.all(color: _sceneEdge, width: _sceneEdgeWidth),
        dashes: null,
        ink: colors.accentTint,
        flame: colors.accentInk,
        shadows: base,
      ),
      StreakPillForm.sidebar || StreakPillForm.rail => (
        fill: fill,
        border: context.shadows.outline,
        dashes: null,
        ink: colors.accentInk,
        flame: colors.accentInk,
        shadows: base,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final _PillLook look = _look(context);
    final Widget face = _decorated(look, _content(context, look));
    final Widget shaped = form == StreakPillForm.rail
        ? Center(
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(
              width: streakRailWidth,
              height: streakRailHeight,
              child: face,
            ),
          )
        : face;
    if (!lateNight) {
      return shaped;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        shaped,
        Positioned(
          top: -_moonBadgeOverlap,
          right: -_moonBadgeOverlap,
          child: _MoonBadge(colors: _lateNightColors(context)),
        ),
      ],
    );
  }

  Widget _decorated(_PillLook look, Widget content) {
    final Widget box = DecoratedBox(
      key: streakPillFaceKey,
      decoration: BoxDecoration(
        color: look.fill,
        border: look.border,
        borderRadius: _radius,
        boxShadow: look.shadows,
      ),
      child: content,
    );
    final Color? dashes = look.dashes;
    if (dashes == null) {
      return box;
    }
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: dashes,
        strokeWidth: _nightEdgeWidth,
        radius: _radius.topLeft.x,
      ),
      child: box,
    );
  }

  Widget _content(BuildContext context, _PillLook look) {
    final bool bareNumber = numberOnly || form == StreakPillForm.rail;
    final String label = bareNumber ? '$days' : streakPillLabel(days);
    final TextStyle accent = context.textStyles.streakAccent;
    final Widget text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: accent.copyWith(
        fontSize: switch (form) {
          StreakPillForm.header ||
          StreakPillForm.headerOverScene => _headerText,
          StreakPillForm.sidebar => _sidebarText,
          StreakPillForm.rail => _railText,
        },
        height: form == StreakPillForm.rail ? _railLineHeight : null,
        color: look.ink,
      ),
    );
    return switch (form) {
      StreakPillForm.header || StreakPillForm.headerOverScene => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: streakPillHeaderHeight),
        child: Padding(
          padding: _headerPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FlameIcon(color: look.flame, size: _headerFlame),
              const SizedBox(width: _headerGap),
              text,
            ],
          ),
        ),
      ),
      StreakPillForm.sidebar => Padding(
        padding: _sidebarPadding,
        child: lateNight
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _sidebarRow(look, text),
                  const SizedBox(height: _lateLineGap),
                  Text(
                    streakLateNightLine,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: accent.copyWith(
                      fontSize: _lateLineText,
                      fontWeight: FontWeight.w600,
                      color: look.ink,
                    ),
                  ),
                ],
              )
            : _sidebarRow(look, text),
      ),
      StreakPillForm.rail => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FlameIcon(color: look.flame, size: _railFlame),
            const SizedBox(height: _railGap),
            text,
          ],
        ),
      ),
    };
  }

  Widget _sidebarRow(_PillLook look, Widget text) => Row(
    children: <Widget>[
      FlameIcon(color: look.flame, size: _stickerFlame),
      const SizedBox(width: _sidebarGap),
      Flexible(child: text),
    ],
  );
}

class _MoonBadge extends StatelessWidget {
  const _MoonBadge({required this.colors});

  final FieldNotesColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: streakMoonBadgeKey,
      dimension: _moonBadgeSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.page,
          shape: BoxShape.circle,
          border: Border.all(color: colors.lateNight, width: _moonBadgeRing),
        ),
        child: Center(
          child: CustomPaint(
            size: const Size.square(_moonGlyph),
            painter: _MoonPainter(color: colors.lateNight),
          ),
        ),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _moonStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas
      ..save()
      ..scale(size.shortestSide / _moonViewBox)
      ..drawPath(_crescent(), stroke)
      ..restore();
  }

  Path _crescent() => Path()
    ..moveTo(19, 14.5)
    ..arcToPoint(const Offset(9.5, 5), radius: const Radius.circular(7.5))
    ..arcToPoint(
      const Offset(19, 14.5),
      radius: const Radius.circular(7.5),
      largeArc: true,
      clockwise: false,
    )
    ..close();

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => oldDelegate.color != color;
}
