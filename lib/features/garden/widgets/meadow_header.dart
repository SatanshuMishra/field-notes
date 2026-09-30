import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:flutter/widgets.dart';

const String meadowBackLabel = 'Your meadow this year';
const String meadowBackCompactLabel = 'This year';
const String meadowFullScreenLabel = 'Full screen';

const double _minTapTarget = 48;
const EdgeInsets _compactClockBalance = EdgeInsets.only(top: 8);
const Offset _buttonShadow = Offset(1.5, 1.5);
const int _buttonShadowAlpha = 0x33;
const BorderRadius _linkRadius = BorderRadius.all(Radius.circular(6));

final Path _backChevron = Path()
  ..moveTo(15, 5)
  ..lineTo(8, 12)
  ..lineTo(15, 19);

final Path _expandCorners = Path()
  ..moveTo(4, 9)
  ..lineTo(4, 4)
  ..lineTo(9, 4)
  ..moveTo(20, 9)
  ..lineTo(20, 4)
  ..lineTo(15, 4)
  ..moveTo(4, 15)
  ..lineTo(4, 20)
  ..lineTo(9, 20)
  ..moveTo(20, 15)
  ..lineTo(20, 20)
  ..lineTo(15, 20);

class MeadowHeader extends StatelessWidget {
  const MeadowHeader({
    super.key,
    required this.compact,
    required this.mode,
    required this.year,
    required this.blooms,
    required this.sprouts,
    required this.weather,
    this.onBack,
    this.controls,
  });

  final bool compact;
  final MeadowSceneMode mode;
  final int year;
  final int blooms;
  final int sprouts;
  final String weather;
  final VoidCallback? onBack;
  final Widget? controls;

  bool get _study => mode == MeadowSceneMode.study;

  String get _kicker => _study ? 'meadow study' : 'your meadow';

  String get _title => _study ? 'Your meadow, $year' : 'Every day, a bloom';

  String get _subtitle {
    final String counts = meadowCountPhrase(blooms, sprouts);
    return _study
        ? '$weather · $counts across $year'
        : '$counts so far in $year · quietly filling in as the year goes';
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles styles = context.textStyles;
    final Widget? back = _study
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: _BackLink(compact: compact, onPressed: onBack),
          )
        : null;
    final Widget? trailing = controls;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ?back,
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 9),
            child: _TitleBlock(
              kicker: _kicker,
              title: _title,
              subtitle: _subtitle,
              kickerStyle: styles.pageEyebrowAccent.copyWith(fontSize: 14),
              titleStyle: styles.headlineSerif.copyWith(height: 1.05),
              subtitleStyle: styles.caption10Sans.copyWith(height: 1.35),
              subtitleGap: 3,
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
              child: trailing,
            ),
        ],
      );
    }
    final Widget title = _TitleBlock(
      kicker: _kicker,
      title: _title,
      subtitle: _subtitle,
      kickerStyle: styles.pageEyebrowAccent,
      titleStyle: styles.displaySerif,
      subtitleStyle: styles.captionSans,
      subtitleGap: 7,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ?back,
          if (trailing == null)
            title
          else
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 16,
              runSpacing: 12,
              children: <Widget>[title, trailing],
            ),
        ],
      ),
    );
  }
}

class MeadowHeaderControls extends StatelessWidget {
  const MeadowHeaderControls({
    super.key,
    required this.compact,
    required this.picker,
    this.clock,
    this.onFullScreen,
  });

  final bool compact;
  final Widget picker;
  final Widget? clock;
  final VoidCallback? onFullScreen;

  @override
  Widget build(BuildContext context) {
    final Widget? time = clock;
    final Widget fullScreen = _FullScreenButton(
      compact: compact,
      onPressed: onFullScreen,
    );
    if (compact) {
      return Row(
        children: <Widget>[
          picker,
          const SizedBox(width: 6),
          if (time == null)
            const Spacer()
          else
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                heightFactor: 1,
                child: Padding(
                  padding: _compactClockBalance,
                  child: IntrinsicWidth(child: time),
                ),
              ),
            ),
          const SizedBox(width: 8),
          fullScreen,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (time != null) ...<Widget>[time, const SizedBox(width: 12)],
        picker,
        const SizedBox(width: 8),
        fullScreen,
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.kickerStyle,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.subtitleGap,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final TextStyle kickerStyle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final double subtitleGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(kicker, style: kickerStyle),
        Semantics(header: true, child: Text(title, style: titleStyle)),
        SizedBox(height: subtitleGap),
        Text(subtitle, style: subtitleStyle),
      ],
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final String label = compact ? meadowBackCompactLabel : meadowBackLabel;
    final double glyphSize = compact ? 11 : 12;
    final Widget face = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CustomPaint(
            size: Size.square(glyphSize),
            painter: _GlyphPainter(
              path: _backChevron,
              color: colors.mutedDeep,
              stroke: 2.4,
            ),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: context.textStyles.captureLabelSans.copyWith(
              color: colors.mutedDeep,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: FocusRing(
                enabled: onPressed != null,
                onPressed: onPressed,
                borderRadius: _linkRadius,
                child: ExcludeSemantics(child: face),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenButton extends StatelessWidget {
  const _FullScreenButton({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 9 : 11),
    );
    final double glyphSize = compact ? 12 : 14;
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBright,
        border: context.shadows.outline,
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadowTint(_buttonShadowAlpha),
            offset: _buttonShadow,
          ),
        ],
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 9.5, vertical: 7.5)
            : const EdgeInsets.symmetric(horizontal: 11.5, vertical: 9.5),
        child: CustomPaint(
          size: Size.square(glyphSize),
          painter: _GlyphPainter(
            path: _expandCorners,
            color: colors.ink,
            stroke: 2,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: meadowFullScreenLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: FocusRing(
                enabled: onPressed != null,
                onPressed: onPressed,
                borderRadius: radius,
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.path,
    required this.color,
    required this.stroke,
  });

  final Path path;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      !identical(oldDelegate.path, path) ||
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke;
}
