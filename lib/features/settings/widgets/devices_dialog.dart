import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/sync/ui/add_device_sheet.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:flutter/material.dart';

const String devicesDoneLabel = 'Done';

const double _dialogMaxWidth = 460;
const double _dialogMargin = 24;
const double _scrimAlpha = 0.42;
const double _titleGap = 16;
const double _footerGap = 20;
const double _buttonGap = 12;

Future<void> showDevicesDialog(
  BuildContext context, {
  required DeviceFeedback onFeedback,
}) async {
  final bool? addDevice = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Palette.toolbarInk.withValues(alpha: _scrimAlpha),
    builder: (BuildContext dialogContext) =>
        DialogHost(child: DevicesDialog(onFeedback: onFeedback)),
  );
  if (addDevice == true && context.mounted) {
    await showAddDeviceSheet(context);
  }
}

class DevicesDialog extends StatelessWidget {
  const DevicesDialog({super.key, required this.onFeedback});

  final DeviceFeedback onFeedback;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(_dialogMargin),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
            child: StickerCard(
              surface: context.colors.cardBright,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      devicesTitle,
                      style: context.textStyles.titleSerif,
                    ),
                  ),
                  const SizedBox(height: _titleGap),
                  Flexible(
                    child: SingleChildScrollView(
                      child: DeviceList(onFeedback: onFeedback),
                    ),
                  ),
                  const SizedBox(height: _footerGap),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: _buttonGap,
                    runSpacing: _buttonGap,
                    children: <Widget>[
                      StickerButton(
                        label: addDeviceTitle,
                        variant: StickerButtonVariant.secondary,
                        padTapTarget: true,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                      StickerButton(
                        label: devicesDoneLabel,
                        padTapTarget: true,
                        autofocus: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
