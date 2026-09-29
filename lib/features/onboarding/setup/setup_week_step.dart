import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/widgets.dart';

Key setupWeekOptionKey(WeekStart start) =>
    ValueKey<String>('setup-week-${start.name}');

Key setupWeekLetterKey(WeekStart start, int index) =>
    ValueKey<String>('setup-week-${start.name}-letter-$index');

const List<String> _mondayFirstLetters = <String>[
  'M',
  'T',
  'W',
  'T',
  'F',
  'S',
  'S',
];

const List<WeekStart> _offerOrder = <WeekStart>[
  WeekStart.monday,
  WeekStart.sunday,
  WeekStart.saturday,
];

const String _sidebarSuggestion = 'suggested for your region';
const String _bottomBarSuggestion = 'suggested';

const double _optionHeight = 56;
const double _optionGap = 8;
const double _radioSize = 18;
const double _radioInset = 3;
const double _sidebarLetterSize = 22;
const double _bottomBarLetterSize = 16;
const double _sidebarLetterGap = 3;
const double _bottomBarLetterGap = 2;
const double _optionBorderWidth = 2;

const BorderRadius _optionRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

TextStyle _labelStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: colors.ink,
);

TextStyle _suggestionStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  color: colors.sage,
);

const TextStyle _letterStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10,
  fontWeight: FontWeight.w600,
);

List<String> weekLettersFor(WeekStart start) {
  final int offset = (start.value + 6) % 7;
  return <String>[
    for (int day = 0; day < 7; day++) _mondayFirstLetters[(offset + day) % 7],
  ];
}

class SetupWeekStep extends StatelessWidget {
  const SetupWeekStep({
    super.key,
    required this.layout,
    required this.suggestion,
    required this.selected,
    required this.onChanged,
  });

  final ShellLayout layout;
  final WeekStart suggestion;
  final WeekStart selected;
  final ValueChanged<WeekStart> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<WeekStart> options = <WeekStart>[
      suggestion,
      for (final WeekStart start in _offerOrder)
        if (start != suggestion) start,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < options.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: _optionGap),
          _WeekOption(
            key: setupWeekOptionKey(options[index]),
            layout: layout,
            start: options[index],
            suggested: options[index] == suggestion,
            selected: options[index] == selected,
            onPressed: () => onChanged(options[index]),
          ),
        ],
      ],
    );
  }
}

class _WeekOption extends StatelessWidget {
  const _WeekOption({
    super.key,
    required this.layout,
    required this.start,
    required this.suggested,
    required this.selected,
    required this.onPressed,
  });

  final ShellLayout layout;
  final WeekStart start;
  final bool suggested;
  final bool selected;
  final VoidCallback onPressed;

  bool get _sidebar => layout == ShellLayout.sidebar;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final String suggestionText = _sidebar
        ? _sidebarSuggestion
        : _bottomBarSuggestion;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: suggested ? '${start.label}, $suggestionText' : start.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _optionRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _optionHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? colors.cardLight : colors.cardWarm,
                border: Border.all(
                  color: selected ? Palette.coral : colors.ink22,
                  width: _optionBorderWidth,
                ),
                borderRadius: _optionRadius,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _sidebar ? 14 : 12,
                  vertical: 10,
                ),
                child: ExcludeSemantics(
                  child: Row(
                    children: <Widget>[
                      SetupRadioDot(selected: selected),
                      SizedBox(width: _sidebar ? 12 : 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(start.label, style: _labelStyle(colors)),
                            if (suggested) ...<Widget>[
                              const SizedBox(height: 1),
                              Text(
                                suggestionText,
                                style: _sidebar
                                    ? _suggestionStyle(colors)
                                    : _suggestionStyle(
                                        colors,
                                      ).copyWith(fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _letters(colors),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _letters(FieldNotesColors colors) {
    final List<String> letters = weekLettersFor(start);
    final double size = _sidebar ? _sidebarLetterSize : _bottomBarLetterSize;
    final double gap = _sidebar ? _sidebarLetterGap : _bottomBarLetterGap;
    final BorderRadius radius = BorderRadius.circular(_sidebar ? 6 : 5);
    final Color lead = selected ? Palette.coral : colors.pill;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < letters.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: gap),
          SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              key: setupWeekLetterKey(start, index),
              decoration: BoxDecoration(
                color: index == 0 ? lead : null,
                border: index == 0
                    ? null
                    : Border.all(color: colors.ink25, width: 1),
                borderRadius: radius,
              ),
              child: Center(
                child: Text(
                  letters[index],
                  style: _letterStyle.copyWith(
                    fontSize: _sidebar ? 10 : 9,
                    color: index == 0 ? Palette.onAccent : colors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SetupRadioDot extends StatelessWidget {
  const SetupRadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _radioSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.cardBright,
          border: context.shadows.outline,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_radioInset + Shapes.outlineWidth),
          child: selected
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.coral,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.expand(),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
