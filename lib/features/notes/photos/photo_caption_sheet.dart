import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'photo_options_sheet.dart';

const String photoCaptionTitle = 'Caption';
const String photoCaptionHelp =
    'Shown under the photo, and read aloud by screen readers as its '
    'description.';
const String photoCaptionHint = 'What is in this photo?';
const String photoCaptionSaveLabel = 'Save caption';
const String photoCaptionCancelLabel = 'Cancel';

const Key photoCaptionFieldKey = ValueKey<String>('photo-caption-field');
const Key photoCaptionSaveKey = ValueKey<String>('photo-caption-save');
const Key photoCaptionCancelKey = ValueKey<String>('photo-caption-cancel');

const int _captionMaxLines = 3;
const double _fieldPadding = 12;
const double _gap = 12;

final RegExp _captionForbidden = RegExp(r'[\]\r\n]');

Future<String?> showPhotoCaptionSheet(
  BuildContext context, {
  required String caption,
}) {
  return showPhotoSheet<String>(
    context,
    barrierLabel: 'Dismiss caption editor',
    builder: (BuildContext dialogContext) => PhotoCaptionSheet(
      caption: caption,
      onDone: (String? result) => Navigator.of(dialogContext).pop(result),
    ),
  );
}

class PhotoCaptionSheet extends StatefulWidget {
  const PhotoCaptionSheet({
    super.key,
    required this.caption,
    required this.onDone,
  });

  final String caption;
  final ValueChanged<String?> onDone;

  @override
  State<PhotoCaptionSheet> createState() => _PhotoCaptionSheetState();
}

class _PhotoCaptionSheetState extends State<PhotoCaptionSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.caption,
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.caption.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => widget.onDone(_controller.text.trim());

  void _cancel() => widget.onDone(null);

  @override
  Widget build(BuildContext context) {
    return PhotoSheetFrame(
      title: photoCaptionTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(photoCaptionHelp, style: TypographyTokens.captionSans),
          const SizedBox(height: _gap),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Palette.cardBright,
              border: Shapes.outline,
              borderRadius: Shapes.buttonBorderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_fieldPadding),
              child: TextField(
                key: photoCaptionFieldKey,
                controller: _controller,
                autofocus: true,
                minLines: 1,
                maxLines: _captionMaxLines,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.deny(_captionForbidden),
                ],
                onSubmitted: (String _) => _save(),
                style: TypographyTokens.bodySans,
                cursorColor: Palette.coral,
                decoration: const InputDecoration.collapsed(
                  hintText: photoCaptionHint,
                  hintStyle: TypographyTokens.captionSans,
                ),
              ),
            ),
          ),
          const SizedBox(height: _gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              StickerButton(
                key: photoCaptionCancelKey,
                label: photoCaptionCancelLabel,
                variant: StickerButtonVariant.secondary,
                onPressed: _cancel,
              ),
              const SizedBox(width: _gap),
              StickerButton(
                key: photoCaptionSaveKey,
                label: photoCaptionSaveLabel,
                onPressed: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
