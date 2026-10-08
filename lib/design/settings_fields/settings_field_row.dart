import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

const double _sidebarControlGap = 24;
const double _phoneControlGap = 16;

class SettingsFieldRow extends StatelessWidget {
  const SettingsFieldRow({
    super.key,
    required this.label,
    this.description,
    required this.control,
    this.labelColor,
    this.descriptionColor,
  });

  final String label;
  final String? description;
  final Widget control;
  final Color? labelColor;
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) {
    final Widget text = MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: context.textStyles.labelSans.copyWith(color: labelColor),
          ),
          if (description != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              description!,
              style: context.textStyles.captionSans.copyWith(
                color: descriptionColor ?? context.colors.muted,
              ),
            ),
          ],
        ],
      ),
    );
    final Widget slot = Semantics(container: true, child: control);
    return Semantics(
      container: true,
      child: switch (resolveShellLayout(Theme.of(context).platform)) {
        ShellLayout.sidebar => LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: text),
              const SizedBox(width: _sidebarControlGap),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: slot,
              ),
            ],
          ),
        ),
        ShellLayout.bottomBar => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: text),
            const SizedBox(width: _phoneControlGap),
            Flexible(
              flex: 2,
              child: Align(alignment: Alignment.centerRight, child: slot),
            ),
          ],
        ),
      },
    );
  }
}
