import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/material.dart';

const Key setupNotificationPreviewKey = ValueKey<String>(
  'setup-notification-preview',
);

Key setupReminderPresetKey(ReminderPreset preset) =>
    ValueKey<String>('setup-reminder-preset-${preset.name}');

const String _notificationTitle = 'Field Notes';
const String _notificationBody = 'You haven’t written today’s field note yet.';
const String _reminderLabel = 'Daily reminder';
const String _otherLabel = 'Other';
const String _offLabel = 'off';

const double _offOpacity = 0.38;
const double _sidebarPresetHeight = 56;
const double _bottomBarPresetHeight = 52;
const double _presetGap = 8;
const double _sidebarGap = 14;
const double _bottomBarGap = 12;
const double _appIconBox = 36;
const double _appIconFlower = 24;
const double _headerFlower = 16;

const int _previewPaperAlpha = 0xF2;
const Color _presetCaptionOnCoral = Color(0xE0FFFFFF);

const List<BoxShadow> _previewShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x73322314),
    offset: Offset(0, 10),
    blurRadius: 24,
    spreadRadius: -12,
  ),
];

const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

TextStyle _rowLabelStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: colors.ink,
);

TextStyle _presetValueStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: colors.ink,
);

TextStyle _presetCaptionStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10,
  fontWeight: FontWeight.w500,
  color: colors.muted,
);

enum ReminderPreset {
  morning('morning', ReminderTime(hour: 8, minute: 0)),
  midday('midday', ReminderTime(hour: 12, minute: 30)),
  evening('evening', ReminderTime(hour: 20, minute: 30)),
  other('pick a time', null);

  const ReminderPreset(this.caption, this.time);

  final String caption;
  final ReminderTime? time;
}

String formatSetupTime(ReminderTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

class SetupReminderStep extends StatelessWidget {
  const SetupReminderStep({
    super.key,
    required this.layout,
    required this.enabled,
    required this.preset,
    required this.time,
    required this.onEnabledChanged,
    required this.onPresetChanged,
    required this.onTimeChanged,
  });

  final ShellLayout layout;
  final bool enabled;
  final ReminderPreset preset;
  final ReminderTime time;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<ReminderPreset> onPresetChanged;
  final ValueChanged<ReminderTime> onTimeChanged;

  bool get _sidebar => layout == ShellLayout.sidebar;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final double gap = _sidebar ? _sidebarGap : _bottomBarGap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Opacity(
          key: setupNotificationPreviewKey,
          opacity: enabled ? 1 : _offOpacity,
          child: enabled
              ? _preview(colors, shadows)
              : ColorFiltered(
                  colorFilter: _greyscale,
                  child: _preview(colors, shadows),
                ),
        ),
        SizedBox(height: gap),
        DashedDivider(thickness: 1, color: colors.ink20),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(_reminderLabel, style: _rowLabelStyle(colors)),
            ),
            SettingsToggle(
              semanticLabel: _reminderLabel,
              value: enabled,
              onChanged: onEnabledChanged,
            ),
          ],
        ),
        DashedDivider(thickness: 1, color: colors.ink20),
        if (enabled) ...<Widget>[
          SizedBox(height: gap),
          _presetGrid(colors, shadows),
          if (preset == ReminderPreset.other) ...<Widget>[
            SizedBox(height: gap),
            Align(
              alignment: Alignment.centerLeft,
              child: SettingsTimeField(
                value: TimeOfDay(hour: time.hour, minute: time.minute),
                onTap: () => _pickTime(context),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
    );
    if (picked == null) {
      return;
    }
    onTimeChanged(ReminderTime(hour: picked.hour, minute: picked.minute));
  }

  Widget _preview(FieldNotesColors colors, FieldNotesShadows shadows) {
    final String when = enabled ? formatSetupTime(time) : _offLabel;
    return MergeSemantics(
      child: _sidebar
          ? _bannerPreview(when, colors, shadows)
          : _shadePreview(when, colors),
    );
  }

  Widget _bannerPreview(
    String when,
    FieldNotesColors colors,
    FieldNotesShadows shadows,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBright.withAlpha(_previewPaperAlpha),
        border: Border.all(color: colors.ink20),
        borderRadius: const BorderRadius.all(Radius.circular(Shapes.radiusMd)),
        boxShadow: _previewShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: _appIconBox,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.cardWarm,
                  border: shadows.outline,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(Shapes.radiusThumb),
                  ),
                ),
                child: Center(
                  child: ExcludeSemantics(
                    child: FlowerBloom.forMood(
                      Mood.happy,
                      size: _appIconFlower,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _notificationTitle,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      Text(
                        when,
                        style: TextStyle(
                          fontFamily: TypographyTokens.sans,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _notificationBody,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shadePreview(String when, FieldNotesColors colors) {
    final TextStyle header = TextStyle(
      fontFamily: TypographyTokens.sans,
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      color: colors.noticeInk,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBright,
        border: Border.all(color: colors.ink14),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: _previewShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: FlowerBloom.forMood(Mood.happy, size: _headerFlower),
                ),
                const SizedBox(width: 6),
                Text(_notificationTitle, style: header),
                ExcludeSemantics(child: Text(' · ', style: header)),
                Text(when, style: header),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              _notificationBody,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.noticeBodyInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetGrid(FieldNotesColors colors, FieldNotesShadows shadows) {
    final int columns = _sidebar ? 4 : 2;
    final List<ReminderPreset> presets = ReminderPreset.values;
    final int rows = (presets.length / columns).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int row = 0; row < rows; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: _presetGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int column = 0; column < columns; column++) ...<Widget>[
                if (column > 0) const SizedBox(width: _presetGap),
                Expanded(
                  child: _presetTile(
                    presets[row * columns + column],
                    colors,
                    shadows,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _presetTile(
    ReminderPreset option,
    FieldNotesColors colors,
    FieldNotesShadows shadows,
  ) {
    final bool selected = option == preset;
    final ReminderTime? fixed = option.time;
    final String value = fixed != null
        ? formatSetupTime(fixed)
        : selected
        ? formatSetupTime(time)
        : _otherLabel;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(Shapes.radiusControl),
    );
    void choose() => onPresetChanged(option);
    return Semantics(
      key: setupReminderPresetKey(option),
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$value, ${option.caption}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: choose,
        child: FocusRing(
          onPressed: choose,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: _sidebar
                  ? _sidebarPresetHeight
                  : _bottomBarPresetHeight,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? Palette.coral : colors.cardWarm,
                border: selected
                    ? shadows.outline
                    : Border.all(
                        color: colors.ink30,
                        width: Shapes.outlineWidth,
                      ),
                borderRadius: radius,
                boxShadow: selected ? shadows.emphasis : null,
              ),
              child: Center(
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          value,
                          maxLines: 1,
                          style: selected
                              ? _presetValueStyle(
                                  colors,
                                ).copyWith(color: Palette.onAccent)
                              : _presetValueStyle(colors),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          option.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: selected
                              ? _presetCaptionStyle(
                                  colors,
                                ).copyWith(color: _presetCaptionOnCoral)
                              : _presetCaptionStyle(colors),
                        ),
                      ],
                    ),
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
