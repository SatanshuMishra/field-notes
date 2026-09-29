import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../onboarding_surface.dart';

const String _wordmark = 'field notes';
const String _headline = 'A journal of days.';
const String _lede = 'Write, speak or film a moment. Each day grows a bloom.';
const String _beginLabel = 'Let’s begin';
const String _skipLabel = 'Skip how it works';

const double _sidebarFlowerSize = 62;
const double _bottomBarFlowerSize = 70;
const double _sidebarHeadlineSize = 34;
const double _bottomBarHeadlineSize = 28;
const double _sidebarBeginHeight = 46;
const double _bottomBarBeginHeight = 48;
const double _bottomBarLedeWidth = 230;
const double _partNumberSize = 24;

const EdgeInsets _sidebarPadding = EdgeInsets.fromLTRB(36, 32, 36, 24);
const EdgeInsets _bottomBarPadding = EdgeInsets.fromLTRB(20, 24, 20, 22);

const TextStyle _wordmarkStyle = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 26,
  fontWeight: FontWeight.w700,
  height: 1,
  color: Palette.coral,
);

const TextStyle _headlineStyle = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: _sidebarHeadlineSize,
  fontWeight: FontWeight.w500,
  height: 1.1,
  color: Palette.ink,
);

const TextStyle _ledeStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.5,
  color: Palette.mutedDeep,
);

const TextStyle _partNumberStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Palette.composerPaper,
);

const TextStyle _partTitleStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: Palette.ink,
);

const TextStyle _partSubtitleStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11.5,
  fontWeight: FontWeight.w400,
  height: 1.4,
  color: Palette.muted,
);

const TextStyle _skipStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Palette.mutedDeep,
);

const List<({String number, String title, String subtitle})> _parts =
    <({String number, String title, String subtitle})>[
      (
        number: '1',
        title: 'How it works',
        subtitle: '6 quick tips · about a minute',
      ),
      (
        number: '2',
        title: 'Basic setup',
        subtitle: 'Reminder · week · storage',
      ),
    ];

class OnboardingWelcome extends StatelessWidget {
  const OnboardingWelcome({
    super.key,
    required this.layout,
    required this.onBegin,
    required this.onSkip,
  });

  final ShellLayout layout;
  final VoidCallback onBegin;
  final VoidCallback onSkip;

  bool get _sidebar => layout == ShellLayout.sidebar;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.arrowRight) {
      onBegin();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      onSkip();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingSurface(
      layout: layout,
      child: FocusScope(
        onKeyEvent: _handleKey,
        child: FocusTraversalGroup(
          child: Padding(
            padding: _sidebar ? _sidebarPadding : _bottomBarPadding,
            child: Column(
              mainAxisSize: _sidebar ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_sidebar)
                  Flexible(child: SingleChildScrollView(child: _content()))
                else
                  Expanded(child: SingleChildScrollView(child: _content())),
                if (_sidebar) const SizedBox(height: 24),
                OnboardingPrimaryButton(
                  label: _beginLabel,
                  onPressed: onBegin,
                  height: _sidebar
                      ? _sidebarBeginHeight
                      : _bottomBarBeginHeight,
                  borderRadius: BorderRadius.circular(
                    _sidebar ? Shapes.radiusPill : Shapes.radiusMd,
                  ),
                  expand: true,
                  autofocus: true,
                ),
                Center(
                  child: OnboardingTextButton(
                    label: _skipLabel,
                    onPressed: onSkip,
                    style: _sidebar
                        ? _skipStyle
                        : _skipStyle.copyWith(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: FlowerBloom.forMood(
            Mood.happy,
            size: _sidebar ? _sidebarFlowerSize : _bottomBarFlowerSize,
          ),
        ),
        const SizedBox(height: 8),
        const Text(_wordmark, style: _wordmarkStyle),
        SizedBox(height: _sidebar ? 12 : 14),
        Semantics(
          header: true,
          child: Text(
            _headline,
            textAlign: TextAlign.center,
            style: _sidebar
                ? _headlineStyle
                : _headlineStyle.copyWith(fontSize: _bottomBarHeadlineSize),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _sidebar ? double.infinity : _bottomBarLedeWidth,
          ),
          child: Text(
            _lede,
            textAlign: TextAlign.center,
            style: _sidebar ? _ledeStyle : _ledeStyle.copyWith(fontSize: 12.5),
          ),
        ),
        SizedBox(height: _sidebar ? 24 : 26),
        if (_sidebar)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _PartCard(part: _parts[0], compact: false)),
                const SizedBox(width: 10),
                Expanded(child: _PartCard(part: _parts[1], compact: false)),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _PartCard(part: _parts[0], compact: true),
              const SizedBox(height: 8),
              _PartCard(part: _parts[1], compact: true),
            ],
          ),
      ],
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({required this.part, required this.compact});

  final ({String number, String title, String subtitle}) part;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Palette.cardWarm,
          border: Shapes.outline,
          borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusMd)),
          boxShadow: Shadows.cardDefault,
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 13, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox.square(
                dimension: _partNumberSize,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Palette.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(part.number, style: _partNumberStyle),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      part.title,
                      style: compact
                          ? _partTitleStyle.copyWith(fontSize: 13.5)
                          : _partTitleStyle,
                    ),
                    SizedBox(height: compact ? 1 : 2),
                    Text(
                      part.subtitle,
                      style: compact
                          ? _partSubtitleStyle.copyWith(fontSize: 11)
                          : _partSubtitleStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
