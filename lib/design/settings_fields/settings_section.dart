import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/widgets.dart';

const double settingsSidebarSectionGap = 28;

const double _sidebarHeadingSize = 19;

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (final Widget child in children) {
      rows.add(const DashedDivider());
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: child,
        ),
      );
    }
    final bool sidebar =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.sidebar;
    final TextStyle heading = sidebar
        ? context.textStyles.sectionHeaderAccent.copyWith(
            fontSize: _sidebarHeadingSize,
          )
        : context.textStyles.sectionHeaderAccent;
    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: heading),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(subtitle!, style: context.textStyles.captionSans),
        ],
        const SizedBox(height: 8),
        ...rows,
      ],
    );
    if (sidebar) {
      return column;
    }
    return StickerCard(child: column);
  }
}
