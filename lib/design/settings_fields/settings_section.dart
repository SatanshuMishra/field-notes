import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/widgets.dart';

const double settingsSidebarSectionGap = 28;

const double _phoneRowPadding = 12;
const double _phoneSubtitleGap = 2;
const double _phoneHeaderGap = 8;

const double _sidebarLabelSize = 17;
const double _sidebarLabelGap = 6;
const double _sidebarGroupGap = 15;
const double _sidebarSubtitleGap = 2;
const double _sidebarRowMinHeight = 56;
const EdgeInsets _sidebarRowPadding = EdgeInsets.symmetric(
  vertical: 15,
  horizontal: 2,
);
const double _sidebarHairlineThickness = 1;
const double _sidebarHairlineOpacity = 0.13;

class SettingsGroup {
  const SettingsGroup({
    required this.label,
    required this.rows,
    this.danger = false,
  });

  final String label;
  final List<Widget> rows;
  final bool danger;
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required String this.title,
    this.subtitle,
    required List<Widget> this._children,
  }) : _groups = null;

  const SettingsSection.grouped({
    super.key,
    this.title,
    this.subtitle,
    required List<SettingsGroup> this._groups,
  }) : _children = null;

  final String? title;
  final String? subtitle;
  final List<Widget>? _children;
  final List<SettingsGroup>? _groups;

  List<SettingsGroup> get groups =>
      _groups ??
      <SettingsGroup>[
        SettingsGroup(label: title!.toLowerCase(), rows: _children!),
      ];

  @override
  Widget build(BuildContext context) {
    return switch (resolveShellLayout(Theme.of(context).platform)) {
      ShellLayout.sidebar => _buildSidebar(context),
      ShellLayout.bottomBar => _buildPhone(context),
    };
  }

  Widget _buildPhone(BuildContext context) {
    final String? title = this.title;
    final String? subtitle = this.subtitle;
    final List<Widget> rows = <Widget>[
      for (final SettingsGroup group in groups) ...group.rows,
    ];
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null)
            Text(title, style: context.textStyles.sectionHeaderAccent),
          if (subtitle != null) ...<Widget>[
            if (title != null) const SizedBox(height: _phoneSubtitleGap),
            Text(subtitle, style: context.textStyles.captionSans),
          ],
          if (title != null || subtitle != null)
            const SizedBox(height: _phoneHeaderGap),
          for (int index = 0; index < rows.length; index++) ...<Widget>[
            if (index > 0 || title != null) const DashedDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: _phoneRowPadding),
              child: rows[index],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final String? subtitle = this.subtitle;
    final List<SettingsGroup> groups = this.groups;
    final Widget hairline = SizedBox(
      height: _sidebarHairlineThickness,
      child: ColoredBox(
        color: colors.ink.withValues(alpha: _sidebarHairlineOpacity),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < groups.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: _sidebarGroupGap),
          Text(
            groups[index].label,
            style: context.textStyles.sectionHeaderAccent.copyWith(
              fontSize: _sidebarLabelSize,
              color: groups[index].danger ? colors.dangerInk : colors.sage,
            ),
          ),
          if (index == 0 && subtitle != null) ...<Widget>[
            const SizedBox(height: _sidebarSubtitleGap),
            Text(
              subtitle,
              style: context.textStyles.captionSans.copyWith(
                color: colors.muted,
              ),
            ),
          ],
          const SizedBox(height: _sidebarLabelGap),
          for (int row = 0; row < groups[index].rows.length; row++) ...<Widget>[
            if (row > 0) hairline,
            _SidebarRow(child: groups[index].rows[row]),
          ],
        ],
      ],
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _sidebarRowMinHeight),
      child: Padding(
        padding: _sidebarRowPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[child],
        ),
      ),
    );
  }
}
