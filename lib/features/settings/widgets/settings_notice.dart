import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class SettingsNotice extends StatelessWidget {
  const SettingsNotice({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Toast(message: message)),
        const SizedBox(width: 12),
        StickerButton(
          label: 'Dismiss',
          variant: StickerButtonVariant.secondary,
          onPressed: onDismiss,
        ),
      ],
    );
  }
}
