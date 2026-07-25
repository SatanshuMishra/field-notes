import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import 'media_placeholders.dart';
import 'media_resolver.dart';

class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.resolver,
    required this.mediaId,
    required this.errorLabel,
    this.width,
    this.height,
    this.borderRadius = Shapes.cardBorderRadius,
    this.fit = BoxFit.cover,
  });

  final MediaResolver resolver;
  final String? mediaId;
  final String errorLabel;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String? id = mediaId;
    if (id == null || id.isEmpty) {
      return _neutral();
    }
    return FutureBuilder<ResolvedMedia>(
      future: resolver.resolve(id),
      builder: (BuildContext context, AsyncSnapshot<ResolvedMedia> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _neutral();
        }
        final ResolvedMedia? media = snapshot.data;
        final File? file = media?.file;
        if (media == null || !media.isAvailable || file == null) {
          return _corrupt();
        }
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) =>
                _corrupt(),
          ),
        );
      },
    );
  }

  Widget _neutral() => NeutralMediaPlaceholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );

  Widget _corrupt() => CorruptMediaPlaceholder(
        label: errorLabel,
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
}
