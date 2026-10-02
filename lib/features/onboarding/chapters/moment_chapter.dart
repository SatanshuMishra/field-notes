import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'a moment';
const String _title = 'Write a little about today.';
const String _placeholder = 'What happened today?';
const String _waitingHint = 'write anything at all to keep going';
const String _savedHint = 'saved to today ✓';
const String _noteLabel = 'Note';
const String _sidebarMediaLead =
    "And there's more than one way to keep a memory.";
const String _sidebarMediaFoot =
    "You'll find these on every log, once you're set up.";
const String _bottomBarMediaLead = 'More than one way to keep a memory:';
const String _videoLength = '0:10';
const int _noteLimit = 280;
const double _sidebarCardWidth = 640;
const double _roomyHeight = 680;

const Key momentCardKey = ValueKey<String>('moment-card');
const Key momentFieldKey = ValueKey<String>('moment-field');
const Key momentMediaKey = ValueKey<String>('moment-media');
const Key momentVoiceKey = ValueKey<String>('moment-voice');
const Key momentVideoKey = ValueKey<String>('moment-video');
const Key momentPhotosKey = ValueKey<String>('moment-photos');

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _cardRise = Duration(milliseconds: 500);
const Duration _cardDelay = Duration(milliseconds: 100);
const Duration _mediaRise = Duration(milliseconds: 600);
const Duration _mediaDelay = Duration(milliseconds: 200);
const Duration _cardsRise = Duration(milliseconds: 500);
const List<Duration> _cardDelays = <Duration>[
  Duration(milliseconds: 350),
  Duration(milliseconds: 500),
  Duration(milliseconds: 650),
];
const Duration _tilePop = Duration(milliseconds: 450);
const Duration _tileDelay = Duration(milliseconds: 350);
const int _tileStaggerMs = 120;

const double _glowDelay = 1.2;
const double _glowPeriod = 2.6;
const double _glowSpread = 6;
const double _glowAlpha = 0.28;
const double _ringPeriod = 2.2;
const double _ringFrom = 0.85;
const double _ringTo = 2;
const double _ringAlpha = 0.6;
const double _blinkPeriod = 1.2;
const double _zoomPeriod = 10;
const double _zoomReach = 0.12;
const double _duskRipplePeriod = 2.2;
const double _jettyRipplePeriod = 2.8;
const double _rippleReach = 3;
const double _sailPeriod = 12;
const double _sailReach = 22;
const double _birdsPeriod = 9;
const double _stillWave = 1.3;

const double _riseDistance = 14;
const double _popPeak = 0.6;
const double _popFrom = 0.2;
const double _popOver = 1.08;
const Cubic _popCurve = Cubic(0.2, 0.9, 0.3, 1.2);

const int _barCount = 22;
const double _barWidth = 4;
const double _barGap = 2;
const double _barHeight = 22;
const double _barRadius = 2;
const double _barLow = 0.22;
const double _barAlpha = 0.75;

const double _sceneWidth = 200;
const double _sceneHeight = 140;

const Color _artScrim = Color(0x73140E08);
const Color _recordDot = Color(0xFFFF4A3D);
const Color _videoGround = Color(0xFF2A221B);
const Color _printPaper = Color(0xFFFBF8F2);
const Color _printShadow = Color(0x80281C12);

const BorderRadius _fieldFocusRadius = BorderRadius.all(Radius.circular(8));

@immutable
class _SidebarArt {
  const _SidebarArt({
    required this.gap,
    required this.cardHeight,
    required this.photoHeight,
  });

  final double gap;
  final double cardHeight;
  final double photoHeight;
}

@immutable
class _MomentMetrics {
  const _MomentMetrics({
    required this.side,
    required this.headingGap,
    required this.cardWidth,
    required this.cardRadius,
    required this.cardShadow,
    required this.cardPadding,
    required this.flowerSize,
    required this.headerGap,
    required this.headerSize,
    required this.showsNote,
    required this.fieldTop,
    required this.fieldSize,
    required this.fieldLine,
    required this.fieldRows,
    required this.hintTop,
    required this.hintSize,
    required this.mediaGap,
    required this.reserve,
    required this.art,
  });

  static const _MomentMetrics sidebar = _MomentMetrics(
    side: 40,
    headingGap: 38,
    cardWidth: _sidebarCardWidth,
    cardRadius: 18,
    cardShadow: Offset(3, 3),
    cardPadding: EdgeInsets.fromLTRB(22, 16, 22, 12),
    flowerSize: 24,
    headerGap: 9,
    headerSize: 12,
    showsNote: true,
    fieldTop: 12,
    fieldSize: 21,
    fieldLine: 34,
    fieldRows: 4,
    hintTop: 4,
    hintSize: 16,
    mediaGap: 20,
    reserve: 60,
    art: _SidebarArt(gap: 12, cardHeight: 118, photoHeight: 94),
  );

  static const _MomentMetrics sidebarCompact = _MomentMetrics(
    side: 40,
    headingGap: 16,
    cardWidth: _sidebarCardWidth,
    cardRadius: 18,
    cardShadow: Offset(3, 3),
    cardPadding: EdgeInsets.fromLTRB(22, 16, 22, 12),
    flowerSize: 24,
    headerGap: 9,
    headerSize: 12,
    showsNote: true,
    fieldTop: 12,
    fieldSize: 21,
    fieldLine: 34,
    fieldRows: 2,
    hintTop: 4,
    hintSize: 16,
    mediaGap: 12,
    reserve: 60,
    art: _SidebarArt(gap: 8, cardHeight: 96, photoHeight: 72),
  );

  static const _MomentMetrics bottomBar = _MomentMetrics(
    side: 16,
    headingGap: 12,
    cardWidth: double.infinity,
    cardRadius: 16,
    cardShadow: Offset(2, 2),
    cardPadding: EdgeInsets.fromLTRB(14, 11, 14, 8),
    flowerSize: 20,
    headerGap: 7,
    headerSize: 11,
    showsNote: false,
    fieldTop: 8,
    fieldSize: 17,
    fieldLine: 30,
    fieldRows: 5,
    hintTop: 2,
    hintSize: 14,
    mediaGap: 14,
    reserve: 76,
    art: null,
  );

  static _MomentMetrics of(ShellLayout layout, double height) =>
      switch (layout) {
        ShellLayout.sidebar when height < _roomyHeight => sidebarCompact,
        ShellLayout.sidebar => sidebar,
        ShellLayout.bottomBar => bottomBar,
      };

  final double side;
  final double headingGap;
  final double cardWidth;
  final double cardRadius;
  final Offset cardShadow;
  final EdgeInsets cardPadding;
  final double flowerSize;
  final double headerGap;
  final double headerSize;
  final bool showsNote;
  final double fieldTop;
  final double fieldSize;
  final double fieldLine;
  final int fieldRows;
  final double hintTop;
  final double hintSize;
  final double mediaGap;
  final double reserve;
  final _SidebarArt? art;
}

String _noteOf(OnboardingFlow flow) => switch (flow) {
  OnboardingFlowRunning(:final OnboardingDraft draft) => draft.noteText,
  OnboardingFlowHidden() || OnboardingFlowMap() => '',
};

NoteSaveState _settledOf(OnboardingFlow flow) => switch (flow) {
  OnboardingFlowRunning(:final OnboardingDraft draft)
      when draft.noteSave != NoteSaveState.saving =>
    draft.noteSave,
  OnboardingFlowRunning() ||
  OnboardingFlowHidden() ||
  OnboardingFlowMap() => NoteSaveState.idle,
};

double _seconds(Duration elapsed) =>
    elapsed.inMicroseconds / Duration.microsecondsPerSecond;

double _swing(double seconds, double period) {
  final double phase = (seconds / period) % 2;
  return phase <= 1 ? phase : 2 - phase;
}

double _pulse(double phase) => phase < 0.5
    ? Curves.ease.transform(phase * 2)
    : 1 - Curves.ease.transform(phase * 2 - 1);

class MomentChapter extends ConsumerStatefulWidget {
  const MomentChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<MomentChapter> createState() => _MomentChapterState();
}

class _MomentChapterState extends ConsumerState<MomentChapter> {
  late final DateTime _openedAt = ref.read(todayClockProvider)();
  late final TextEditingController _note = TextEditingController(
    text: _noteOf(ref.read(onboardingControllerProvider)),
  );
  late NoteSaveState _settled = _settledOf(
    ref.read(onboardingControllerProvider),
  );
  final FocusNode _fieldRing = FocusNode(
    debugLabel: 'moment-field-ring',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _note.dispose();
    _fieldRing.dispose();
    super.dispose();
  }

  void _follow(OnboardingFlow? previous, OnboardingFlow next) {
    if (next is! OnboardingFlowRunning) {
      return;
    }
    final OnboardingDraft draft = next.draft;
    if (draft.noteSave != NoteSaveState.saving) {
      _settled = draft.noteSave;
    }
    if (draft.noteText != _note.text) {
      _note.value = TextEditingValue(
        text: draft.noteText,
        selection: TextSelection.collapsed(offset: draft.noteText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OnboardingFlow>(onboardingControllerProvider, _follow);
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    if (flow is! OnboardingFlowRunning) {
      return const SizedBox.expand();
    }
    final OnboardingDraft draft = flow.draft;
    final ShellLayout layout = widget.layout;
    final bool saved = _settled == NoteSaveState.saved;
    final String? error = _settled == NoteSaveState.failed
        ? draft.noteError
        : null;
    final String clock = formatClock(
      context,
      TimeOfDay.fromDateTime(_openedAt),
    );
    final ValueChanged<String> onChanged = ref
        .read(onboardingControllerProvider.notifier)
        .setNote;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _MomentMetrics metrics = _MomentMetrics.of(
          layout,
          constraints.maxHeight,
        );
        return _body(
          layout: layout,
          metrics: metrics,
          saved: saved,
          card: _NoteCard(
            metrics: metrics,
            draft: draft,
            clock: clock,
            saved: saved,
            error: error,
            field: _NoteField(
              metrics: metrics,
              controller: _note,
              ring: _fieldRing,
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }

  Widget _body({
    required ShellLayout layout,
    required _MomentMetrics metrics,
    required bool saved,
    required Widget card,
  }) {
    final _SidebarArt? art = metrics.art;
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: metrics.reserve),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Enter.rise(
              duration: _headingRise,
              delay: Duration.zero,
              child: OnboardingHeading(
                layout: layout,
                kicker: _kicker,
                title: _title,
              ),
            ),
            SizedBox(height: metrics.headingGap),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.side),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: metrics.cardWidth),
                  child: _Enter.rise(
                    duration: _cardRise,
                    delay: _cardDelay,
                    child: card,
                  ),
                ),
              ),
            ),
            if (saved) ...<Widget>[
              SizedBox(height: metrics.mediaGap),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: metrics.side),
                child: _Enter.rise(
                  key: momentMediaKey,
                  duration: _mediaRise,
                  delay: _mediaDelay,
                  child: art == null
                      ? const _BottomBarMedia()
                      : _SidebarMedia(art: art),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.metrics,
    required this.draft,
    required this.clock,
    required this.saved,
    required this.error,
    required this.field,
  });

  final _MomentMetrics metrics;
  final OnboardingDraft draft;
  final String clock;
  final bool saved;
  final String? error;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(metrics.cardRadius);
    final String? problem = error;
    final BoxShadow rest = BoxShadow(
      color: colors.shadowTint(0x2E),
      offset: metrics.cardShadow,
    );
    return _Loop(
      running: draft.noteText.isEmpty,
      builder: (BuildContext context, Duration? elapsed, Widget? child) {
        final double seconds = elapsed == null ? 0 : _seconds(elapsed);
        final BoxShadow shadow = seconds < _glowDelay
            ? rest
            : _glow(_pulse(((seconds - _glowDelay) / _glowPeriod) % 1));
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: <BoxShadow>[shadow],
          ),
          child: child,
        );
      },
      child: DecoratedBox(
        key: momentCardKey,
        decoration: BoxDecoration(
          color: colors.cardBright,
          border: Border.all(color: colors.line, width: Shapes.outlineWidth),
          borderRadius: radius,
        ),
        child: Padding(
          padding: metrics.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CardHeader(metrics: metrics, draft: draft, clock: clock),
              SizedBox(height: metrics.fieldTop),
              field,
              SizedBox(height: metrics.hintTop),
              Text(
                saved ? _savedHint : _waitingHint,
                style: TextStyle(
                  fontFamily: TypographyTokens.accent,
                  fontSize: metrics.hintSize,
                  fontWeight: FontWeight.w600,
                  color: colors.sage,
                ),
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      problem,
                      style: TextStyle(
                        fontFamily: TypographyTokens.sans,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.dangerInk,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static BoxShadow _glow(double strength) => BoxShadow(
    color: Palette.coral.withValues(alpha: _glowAlpha * strength),
    spreadRadius: _glowSpread * strength,
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.metrics,
    required this.draft,
    required this.clock,
  });

  final _MomentMetrics metrics;
  final OnboardingDraft draft;
  final String clock;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: FlowerBloom.forMood(draft.mood, size: metrics.flowerSize),
        ),
        SizedBox(width: metrics.headerGap),
        Expanded(
          child: Text(
            'Today · $clock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: metrics.headerSize,
              fontWeight: FontWeight.w600,
              color: colors.muted,
            ),
          ),
        ),
        if (metrics.showsNote) ...<Widget>[
          ExcludeSemantics(
            child: _Glyph(kind: _GlyphKind.pencil, color: colors.ink, size: 14),
          ),
          const SizedBox(width: 6),
          Text(
            _noteLabel,
            maxLines: 1,
            style: TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: metrics.headerSize,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.metrics,
    required this.controller,
    required this.ring,
    required this.onChanged,
  });

  final _MomentMetrics metrics;
  final TextEditingController controller;
  final FocusNode ring;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final double ratio = metrics.fieldLine / metrics.fieldSize;
    final double pitch =
        MediaQuery.textScalerOf(context).scale(metrics.fieldSize) * ratio;
    final TextStyle style = TextStyle(
      fontFamily: TypographyTokens.serif,
      fontSize: metrics.fieldSize,
      fontWeight: FontWeight.w500,
      height: ratio,
      leadingDistribution: TextLeadingDistribution.even,
      color: colors.ink,
    );
    final Widget field = CustomPaint(
      painter: _RulePainter(pitch: pitch, color: colors.ink14),
      child: TextField(
        key: momentFieldKey,
        controller: controller,
        onChanged: onChanged,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(_noteLimit),
        ],
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        minLines: metrics.fieldRows,
        maxLines: metrics.fieldRows,
        cursorColor: colors.accentInk,
        style: style,
        strutStyle: StrutStyle(
          fontFamily: TypographyTokens.serif,
          fontSize: metrics.fieldSize,
          height: ratio,
          leadingDistribution: TextLeadingDistribution.even,
          forceStrutHeight: true,
        ),
        decoration: InputDecoration.collapsed(
          hintText: _placeholder,
          hintStyle: style.copyWith(color: colors.placeholder),
        ),
      ),
    );
    return FocusRing(
      onPressed: null,
      focusNode: ring,
      includeFocusSemantics: false,
      borderRadius: _fieldFocusRadius,
      child: field,
    );
  }
}

class _RulePainter extends CustomPainter {
  const _RulePainter({required this.pitch, required this.color});

  final double pitch;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (pitch <= 1) {
      return;
    }
    final Paint paint = Paint()..color = color;
    for (double bottom = pitch; bottom <= size.height + 0.5; bottom += pitch) {
      canvas.drawRect(Rect.fromLTWH(0, bottom - 1, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter oldDelegate) =>
      oldDelegate.pitch != pitch || oldDelegate.color != color;
}

class _SidebarMedia extends StatelessWidget {
  const _SidebarMedia({required this.art});

  final _SidebarArt art;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _sidebarCardWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _sidebarMediaLead,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TypographyTokens.accent,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colors.sage,
              ),
            ),
            SizedBox(height: art.gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _Enter.rise(
                    duration: _cardsRise,
                    delay: _cardDelays[0],
                    child: _MediumCard(
                      key: momentVoiceKey,
                      label: 'your voice',
                      art: _VoiceArt(height: art.cardHeight),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Enter.rise(
                    duration: _cardsRise,
                    delay: _cardDelays[1],
                    child: _MediumCard(
                      key: momentVideoKey,
                      label: 'a video, of you or the view',
                      art: _VideoArt(height: art.cardHeight),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Enter.rise(
                    duration: _cardsRise,
                    delay: _cardDelays[2],
                    child: _MediumCard(
                      key: momentPhotosKey,
                      label: 'photos from the day',
                      art: _PhotoArt(height: art.photoHeight),
                      labelGap: 9,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: art.gap),
            Text(
              _sidebarMediaFoot,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediumCard extends StatelessWidget {
  const _MediumCard({
    super.key,
    required this.label,
    required this.art,
    this.labelGap = 6,
  });

  final String label;
  final Widget art;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(child: art),
        SizedBox(height: labelGap),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TypographyTokens.accent,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.colors.mutedDeep,
          ),
        ),
      ],
    );
  }
}

class _VoiceArt extends StatelessWidget {
  const _VoiceArt({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Widget disc = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Palette.coral,
        border: Border.all(color: colors.line, width: 2),
      ),
      child: const Center(
        child: CaptureIcon(
          glyph: CaptureGlyph.mic,
          color: Palette.onAccent,
          size: 18,
        ),
      ),
    );
    return Transform.rotate(
      angle: -2 * math.pi / 180,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.cardWarm,
          border: Border.all(color: colors.line, width: Shapes.outlineWidth),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        child: _Loop(
          builder: (BuildContext context, Duration? elapsed, Widget? child) {
            final double? seconds = elapsed == null ? null : _seconds(elapsed);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox.square(
                  dimension: 42,
                  child: Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (seconds != null) _ring(seconds),
                      child!,
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CustomPaint(
                  size: const Size(
                    _barCount * _barWidth + (_barCount - 1) * _barGap,
                    _barHeight,
                  ),
                  painter: _WavePainter(
                    seconds: seconds ?? _stillWave,
                    ink: colors.ink,
                  ),
                ),
              ],
            );
          },
          child: disc,
        ),
      ),
    );
  }

  static Widget _ring(double seconds) {
    final double eased = Curves.easeOut.transform(
      (seconds % _ringPeriod) / _ringPeriod,
    );
    return Opacity(
      opacity: _ringAlpha * (1 - eased),
      child: Transform.scale(
        scale: _ringFrom + (_ringTo - _ringFrom) * eased,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Palette.coral, width: 2),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.seconds, required this.ink});

  final double seconds;
  final Color ink;

  static double _scaleOf(int index, double seconds) {
    final double period = 0.7 + ((index * 37) % 9) / 12;
    final double delay = ((index * 53) % 11) / 20;
    if (seconds < delay) {
      return 1;
    }
    final double phase = ((seconds - delay) % period) / period;
    return phase < 0.5
        ? _barLow + (1 - _barLow) * Curves.easeInOut.transform(phase * 2)
        : 1 - (1 - _barLow) * Curves.easeInOut.transform(phase * 2 - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint inkPaint = Paint()..color = ink.withValues(alpha: _barAlpha);
    final Paint coralPaint = Paint()
      ..color = Palette.coral.withValues(alpha: _barAlpha);
    for (int index = 0; index < _barCount; index++) {
      final double height = _barHeight * _scaleOf(index, seconds);
      final Rect bar = Rect.fromLTWH(
        index * (_barWidth + _barGap),
        (_barHeight - height) / 2,
        _barWidth,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bar,
          Radius.circular(math.min(_barRadius, height / 2)),
        ),
        index % 5 == 2 ? coralPaint : inkPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.seconds != seconds || oldDelegate.ink != ink;
}

class _VideoArt extends StatelessWidget {
  const _VideoArt({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(14));
    return Transform.rotate(
      angle: 1.5 * math.pi / 180,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: _videoGround,
          borderRadius: radius,
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: context.colors.line,
            width: Shapes.outlineWidth,
          ),
          borderRadius: radius,
        ),
        padding: const EdgeInsets.all(Shapes.outlineWidth),
        child: _Loop(
          builder: (BuildContext context, Duration? elapsed, Widget? child) {
            final double? seconds = elapsed == null ? null : _seconds(elapsed);
            final double zoom = seconds == null
                ? 1
                : 1 +
                      _zoomReach *
                          Curves.easeInOut.transform(
                            _swing(seconds, _zoomPeriod),
                          );
            final bool lit =
                seconds == null || seconds % _blinkPeriod < _blinkPeriod / 2;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Transform.scale(
                  scale: zoom,
                  child: CustomPaint(painter: _DuskPainter(seconds ?? 0)),
                ),
                Positioned(left: 8, top: 8, child: _Badge(lit: lit)),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _artScrim,
                    ),
                    alignment: Alignment.center,
                    child: const _Glyph(
                      kind: _GlyphKind.flip,
                      color: Palette.onAccent,
                      size: 14,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _artScrim,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Opacity(
              opacity: lit ? 1 : 0,
              child: const SizedBox.square(
                dimension: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recordDot,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              _videoLength,
              maxLines: 1,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Palette.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoArt extends StatelessWidget {
  const _PhotoArt({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -4 * math.pi / 180,
        child: Container(
          width: 146,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
          decoration: BoxDecoration(
            color: _printPaper,
            border: Border.all(color: context.colors.ink30, width: 1),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _printShadow,
                offset: Offset(0, 10),
                blurRadius: 22,
                spreadRadius: -10,
              ),
            ],
          ),
          child: SizedBox(
            height: height,
            child: ClipRect(
              child: _Loop(
                builder:
                    (BuildContext context, Duration? elapsed, Widget? child) =>
                        CustomPaint(
                          painter: _JettyPainter(
                            elapsed == null ? 0 : _seconds(elapsed),
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

class _BottomBarMedia extends StatelessWidget {
  const _BottomBarMedia();

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _bottomBarMediaLead,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TypographyTokens.accent,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.15,
            color: colors.sage,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _Enter.pop(
                duration: _tilePop,
                delay: _tileDelay,
                child: _MediumTile(
                  key: momentVoiceKey,
                  label: 'your voice',
                  icon: CaptureIcon(
                    glyph: CaptureGlyph.mic,
                    color: colors.ink,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Enter.pop(
                duration: _tilePop,
                delay:
                    _tileDelay + const Duration(milliseconds: _tileStaggerMs),
                child: _MediumTile(
                  key: momentVideoKey,
                  label: 'a video',
                  icon: CaptureIcon(
                    glyph: CaptureGlyph.video,
                    color: colors.ink,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Enter.pop(
                duration: _tilePop,
                delay:
                    _tileDelay +
                    const Duration(milliseconds: 2 * _tileStaggerMs),
                child: _MediumTile(
                  key: momentPhotosKey,
                  label: 'photos',
                  icon: _Glyph(
                    kind: _GlyphKind.photo,
                    color: colors.ink,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MediumTile extends StatelessWidget {
  const _MediumTile({super.key, required this.label, required this.icon});

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardWarm,
        border: Border.all(color: colors.ink20, width: Shapes.outlineWidth),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.cardWarm,
                  border: Border.all(
                    color: colors.line,
                    width: Shapes.outlineWidth,
                  ),
                ),
                child: icon,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TypographyTokens.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.05,
                color: colors.mutedDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _GlyphKind { pencil, photo, flip }

class _Glyph extends StatelessWidget {
  const _Glyph({required this.kind, required this.color, required this.size});

  final _GlyphKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(kind: kind, color: color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.kind, required this.color});

  final _GlyphKind kind;
  final Color color;

  static const double _viewBox = 24;

  Path _path() => switch (kind) {
    _GlyphKind.pencil =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(8, 20)
        ..lineTo(19, 9)
        ..arcToPoint(
          const Offset(16, 6),
          radius: const Radius.circular(2.1),
          clockwise: false,
        )
        ..lineTo(5, 17)
        ..lineTo(5, 20)
        ..close()
        ..moveTo(14, 8)
        ..lineTo(17, 11),
    _GlyphKind.photo =>
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 6, 18, 14),
            const Radius.circular(2),
          ),
        )
        ..addOval(Rect.fromCircle(center: const Offset(12, 13), radius: 3.5))
        ..moveTo(8, 6)
        ..lineTo(9.5, 4)
        ..lineTo(14.5, 4)
        ..lineTo(16, 6),
    _GlyphKind.flip =>
      Path()
        ..moveTo(4, 9)
        ..arcToPoint(const Offset(18, 6), radius: const Radius.circular(8))
        ..lineTo(20, 8)
        ..moveTo(20, 4)
        ..lineTo(20, 8)
        ..lineTo(16, 8)
        ..moveTo(20, 15)
        ..arcToPoint(const Offset(6, 18), radius: const Radius.circular(8))
        ..lineTo(4, 16)
        ..moveTo(4, 20)
        ..lineTo(4, 16)
        ..lineTo(8, 16),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / _viewBox);
    canvas.drawPath(
      _path(),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

void _sliceScene(Canvas canvas, Size size, void Function(Canvas canvas) draw) {
  if (size.isEmpty) {
    return;
  }
  final double scale = math.max(
    size.width / _sceneWidth,
    size.height / _sceneHeight,
  );
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.translate(
    (size.width - _sceneWidth * scale) / 2,
    (size.height - _sceneHeight * scale) / 2,
  );
  canvas.scale(scale);
  draw(canvas);
  canvas.restore();
}

Paint _fill(Color color) => Paint()..color = color;

Paint _band(Rect rect, List<Color> colors, [List<double>? stops]) =>
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(rect);

Paint _line(Color color, double width, {bool round = false}) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;

Path _bird(double x, double y, double half) => Path()
  ..moveTo(x, y)
  ..relativeQuadraticBezierTo(half / 2, -half / 2, half, 0)
  ..relativeQuadraticBezierTo(half / 2, -half / 2, half, 0);

class _DuskPainter extends CustomPainter {
  const _DuskPainter(this.seconds);

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) => _sliceScene(canvas, size, _draw);

  void _draw(Canvas canvas) {
    const Rect sky = Rect.fromLTWH(0, 0, 200, 78);
    canvas.drawRect(
      sky,
      _band(
        sky,
        const <Color>[Color(0xFF5D4A78), Color(0xFFD9826F), Color(0xFFF6C48A)],
        const <double>[0, 0.45, 1],
      ),
    );
    const Offset glowCentre = Offset(100, 74);
    canvas.drawCircle(
      glowCentre,
      44,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xCCFFE2B0), Color(0x00FFE2B0)],
        ).createShader(Rect.fromCircle(center: glowCentre, radius: 44)),
    );
    canvas.drawCircle(
      const Offset(100, 76),
      15,
      _fill(const Color(0xFFFFE6B8)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 68)
        ..quadraticBezierTo(24, 58, 52, 66)
        ..lineTo(70, 72)
        ..lineTo(0, 78)
        ..close(),
      _fill(const Color(0xFF4A3A52)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(200, 64)
        ..quadraticBezierTo(172, 56, 146, 66)
        ..lineTo(128, 74)
        ..lineTo(200, 78)
        ..close(),
      _fill(const Color(0xFF3E3248)),
    );
    const Rect water = Rect.fromLTWH(0, 77, 200, 64);
    canvas.drawRect(
      water,
      _band(water, const <Color>[Color(0xFF8A6F86), Color(0xFF2F3650)]),
    );
    final double ripple =
        -_rippleReach +
        2 *
            _rippleReach *
            Curves.easeInOut.transform(_swing(seconds, _duskRipplePeriod));
    for (int index = 0; index < 9; index++) {
      final double width = 40 - index * 3.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(100 - width / 2 + ripple, 80.0 + index * 6, width, 1.8),
          const Radius.circular(0.9),
        ),
        _fill(const Color(0xFFFFD9A0).withValues(alpha: 0.8 - index * 0.07)),
      );
    }
    final double sail =
        _sailReach * Curves.easeInOut.transform(_swing(seconds, _sailPeriod));
    canvas.save();
    canvas.translate(sail, 0);
    canvas.drawPath(
      Path()
        ..moveTo(36, 92)
        ..lineTo(58, 92)
        ..lineTo(55, 96)
        ..lineTo(39, 96)
        ..close(),
      _fill(const Color(0xFF231C26)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(47, 91)
        ..lineTo(47, 70)
        ..lineTo(58, 90)
        ..close(),
      _fill(const Color(0xFF2C2330)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(46, 91)
        ..lineTo(46, 74)
        ..lineTo(38, 90)
        ..close(),
      _fill(const Color(0xD92C2330)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 97, 18, 1.4),
        const Radius.circular(0.7),
      ),
      _fill(const Color(0x66FFD9A0)),
    );
    canvas.restore();
    final double flight = _swing(seconds, _birdsPeriod);
    canvas.save();
    canvas.translate(-30 + 70 * flight, 6 - 10 * flight);
    final Paint wing = _line(const Color(0xFF2C2330), 1.1, round: true);
    canvas.drawPath(_bird(120, 30, 6), wing);
    canvas.drawPath(_bird(138, 22, 4), wing);
    canvas.drawPath(_bird(110, 40, 4), wing);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DuskPainter oldDelegate) =>
      oldDelegate.seconds != seconds;
}

class _JettyPainter extends CustomPainter {
  const _JettyPainter(this.seconds);

  final double seconds;

  static final List<double> _treeline = <double>[
    for (int index = 0; index < 20; index++) 3.0 + (index * 7) % 4,
  ];

  @override
  void paint(Canvas canvas, Size size) => _sliceScene(canvas, size, _draw);

  void _draw(Canvas canvas) {
    const Rect sky = Rect.fromLTWH(0, 0, 200, 82);
    canvas.drawRect(
      sky,
      _band(
        sky,
        const <Color>[Color(0xFF9CC3D2), Color(0xFFF3D9B0), Color(0xFFF0B88F)],
        const <double>[0, 0.6, 1],
      ),
    );
    canvas.drawCircle(
      const Offset(132, 60),
      24,
      _fill(const Color(0x66FDE7C0)),
    );
    canvas.drawCircle(
      const Offset(132, 60),
      10,
      _fill(const Color(0xFFFFF3D6)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 70)
        ..quadraticBezierTo(30, 54, 62, 63)
        ..quadraticBezierTo(94, 72, 124, 58)
        ..quadraticBezierTo(154, 44, 200, 62)
        ..lineTo(200, 82)
        ..lineTo(0, 82)
        ..close(),
      _fill(const Color(0xD9A9A3B6)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 76)
        ..quadraticBezierTo(40, 64, 80, 73)
        ..quadraticBezierTo(120, 82, 160, 69)
        ..quadraticBezierTo(200, 56, 200, 73)
        ..lineTo(200, 82)
        ..lineTo(0, 82)
        ..close(),
      _fill(const Color(0xFF6F7F72)),
    );
    final Path trees = Path()..moveTo(0, 82);
    for (final double rise in _treeline) {
      trees.relativeQuadraticBezierTo(5, -rise, 10, 0);
    }
    canvas.drawPath(trees..close(), _fill(const Color(0xFF46594A)));
    const Rect water = Rect.fromLTWH(0, 81, 200, 60);
    canvas.drawRect(
      water,
      _band(water, const <Color>[Color(0xFF8FB4BD), Color(0xFF4D7686)]),
    );
    final double ripple =
        -_rippleReach +
        2 *
            _rippleReach *
            Curves.easeInOut.transform(_swing(seconds, _jettyRipplePeriod));
    canvas.save();
    canvas.translate(ripple, 0);
    for (int index = 0; index < 7; index++) {
      final double width = 22 - index * 2.6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(132 - width / 2, 86.0 + index * 6, width, 1.6),
          const Radius.circular(0.8),
        ),
        _fill(const Color(0xFFFDE7C0).withValues(alpha: 0.75 - index * 0.08)),
      );
    }
    final Paint glint = _line(const Color(0x80D6E6E6), 1, round: true);
    canvas.drawLine(const Offset(20, 100), const Offset(38, 100), glint);
    canvas.drawLine(const Offset(150, 112), const Offset(174, 112), glint);
    canvas.drawLine(const Offset(60, 124), const Offset(80, 124), glint);
    canvas.drawLine(const Offset(120, 130), const Offset(150, 130), glint);
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(8, 140)
        ..lineTo(74, 140)
        ..lineTo(104, 92)
        ..lineTo(96, 92)
        ..close(),
      _fill(const Color(0xFF9B7049)),
    );
    for (int index = 1; index < 12; index++) {
      final double t = math.pow(index / 12, 0.8).toDouble();
      final double y = 140 - 48 * t;
      canvas.drawLine(
        Offset(8 + 88 * t, y),
        Offset(74 + 30 * t, y),
        _line(const Color(0xFF5E4128), 1.1 - t * 0.6),
      );
    }
    final Paint post = _fill(const Color(0xFF4A321F));
    for (final double t in const <double>[0.15, 0.4, 0.65, 0.88]) {
      final double y = 140 - 48 * t;
      final double height = 10 - t * 6;
      canvas.drawRect(
        Rect.fromLTWH(74 + 30 * t - 1.5, y, 3 - t * 1.5, height),
        post,
      );
      canvas.drawRect(
        Rect.fromLTWH(8 + 88 * t - 1, y, 2.6 - t * 1.4, height * 0.7),
        post,
      );
    }
    const Color figure = Color(0xFF3B2E2A);
    canvas.drawCircle(const Offset(100, 83.5), 2.1, _fill(figure));
    canvas.drawPath(
      Path()
        ..moveTo(98, 86)
        ..lineTo(102, 86)
        ..lineTo(103, 91)
        ..lineTo(97, 91)
        ..close(),
      _fill(figure),
    );
    final Paint leg = _line(figure, 1.1);
    canvas.drawLine(const Offset(97.5, 90), const Offset(95.5, 93), leg);
    canvas.drawLine(const Offset(102.5, 90), const Offset(104.5, 93), leg);
    final Paint wing = _line(const Color(0xFF5E5560), 1, round: true);
    canvas.drawPath(_bird(52, 30, 6), wing);
    canvas.drawPath(_bird(68, 24, 4), wing);
  }

  @override
  bool shouldRepaint(_JettyPainter oldDelegate) =>
      oldDelegate.seconds != seconds;
}

typedef _LoopBuilder = Widget Function(
  BuildContext context,
  Duration? elapsed,
  Widget? child,
);

class _Loop extends StatefulWidget {
  const _Loop({required this.builder, this.running = true, this.child});

  final _LoopBuilder builder;
  final bool running;
  final Widget? child;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _elapsed = Duration.zero;
  bool _still = false;

  bool get _moving => widget.running && !_still;

  void _onTick(Duration elapsed) => setState(() => _elapsed = elapsed);

  void _sync() {
    if (_moving && !_ticker.isActive) {
      _elapsed = Duration.zero;
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_Loop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      _sync();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _moving ? _elapsed : null, widget.child);
}

enum _EnterKind { rise, pop }

class _Enter extends StatefulWidget {
  const _Enter.rise({
    super.key,
    required this.duration,
    required this.delay,
    required this.child,
  }) : kind = _EnterKind.rise;

  const _Enter.pop({
    required this.duration,
    required this.delay,
    required this.child,
  }) : kind = _EnterKind.pop;

  final _EnterKind kind;
  final Duration duration;
  final Duration delay;
  final Widget child;

  @override
  State<_Enter> createState() => _EnterState();
}

class _EnterState extends State<_Enter> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _progress {
    final int delay = widget.delay.inMicroseconds;
    final int duration = widget.duration.inMicroseconds;
    final double elapsed = _clock.value * (delay + duration);
    return duration == 0 ? 1 : ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  Widget _frame(double progress, Widget child) {
    switch (widget.kind) {
      case _EnterKind.rise:
        final double eased = Curves.ease.transform(progress);
        return Opacity(
          opacity: eased,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, _riseDistance * (1 - eased)),
            child: child,
          ),
        );
      case _EnterKind.pop:
        final bool rising = progress < _popPeak;
        final double eased = rising
            ? _popCurve.transform(progress / _popPeak)
            : _popCurve.transform((progress - _popPeak) / (1 - _popPeak));
        final double scale = rising
            ? _popFrom + (_popOver - _popFrom) * eased
            : _popOver + (1 - _popOver) * eased;
        return Opacity(
          opacity: rising ? eased.clamp(0.0, 1.0) : 1,
          alwaysIncludeSemantics: true,
          child: Transform.scale(scale: scale, child: child),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) =>
          _frame(_progress, child!),
    );
  }
}
