import 'dart:typed_data';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:flutter/widgets.dart';

class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({super.key, required this.media, this.size = 72});

  final CaptureMedia media;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Shapes.buttonBorderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: switch (media) {
          CaptureBytes m => Image.memory(
              Uint8List.fromList(m.bytes),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: _placeholder,
            ),
          CaptureFile m => Image.file(
              m.file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: _placeholder,
            ),
        },
      ),
    );
  }

  Widget _placeholder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return CrossHatchPlaceholder(
      width: size,
      height: size,
      borderRadius: Shapes.buttonBorderRadius,
    );
  }
}
