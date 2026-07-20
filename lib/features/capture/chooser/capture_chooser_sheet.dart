import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

class CaptureChooserSheet extends StatelessWidget {
  const CaptureChooserSheet({
    super.key,
    required this.availableTypes,
    required this.onOptionSelected,
    this.title = 'Capture a moment',
    this.unavailableLabel = 'Coming soon',
    this.maxWidth = 360,
  });

  final Set<EntryType> availableTypes;
  final ValueChanged<EntryType> onOptionSelected;
  final String title;
  final String unavailableLabel;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: StickerCard(
          surface: Palette.cardBright,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: TypographyTokens.titleSerif),
              const SizedBox(height: 16),
              for (final CaptureOption option in captureOptions)
                _CaptureOptionTile(
                  option: option,
                  isAvailable: availableTypes.contains(option.type),
                  unavailableLabel: unavailableLabel,
                  onSelected: onOptionSelected,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureOptionTile extends StatelessWidget {
  const _CaptureOptionTile({
    required this.option,
    required this.isAvailable,
    required this.unavailableLabel,
    required this.onSelected,
  });

  final CaptureOption option;
  final bool isAvailable;
  final String unavailableLabel;
  final ValueChanged<EntryType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StickerButton(
            label: option.label,
            variant: StickerButtonVariant.secondary,
            onPressed: isAvailable ? () => onSelected(option.type) : null,
          ),
          const SizedBox(height: 6),
          Text(
            isAvailable ? option.description : unavailableLabel,
            style: TypographyTokens.captionSans,
          ),
        ],
      ),
    );
  }
}
