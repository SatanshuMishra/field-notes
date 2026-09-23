import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import 'decode_target.dart';
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
    this.border,
    this.onDecodeError,
  });

  final MediaResolver resolver;
  final String? mediaId;
  final String errorLabel;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final BoxBorder? border;
  final VoidCallback? onDecodeError;

  @override
  Widget build(BuildContext context) {
    return _framed(_content());
  }

  Widget _framed(Widget content) {
    final BoxBorder? edge = border;
    if (edge == null) {
      return content;
    }
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: edge, borderRadius: borderRadius),
      child: content,
    );
  }

  Widget _content() {
    final String? id = mediaId;
    if (id == null || id.isEmpty) {
      return _neutral();
    }
    return _MediaResolution(
      resolver: resolver,
      mediaId: id,
      builder: (BuildContext context, ResolvedMedia? media) =>
          media == null ? _neutral() : _resolved(media),
    );
  }

  Widget _resolved(ResolvedMedia media) {
    final File? file = media.file;
    if (!media.isAvailable || file == null) {
      return _corrupt();
    }
    return ClipRRect(borderRadius: borderRadius, child: _image(file));
  }

  Widget _image(File file) {
    final double? fixed = width;
    if (fixed != null) {
      return Builder(
        builder: (BuildContext context) => _fileImage(context, file, fixed),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          _fileImage(context, file, constraints.maxWidth),
    );
  }

  Widget _fileImage(BuildContext context, File file, double boxWidth) {
    return Image.file(
      file,
      key: ValueKey<String>(file.path),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      cacheWidth: decodeTargetWidth(
        logicalWidth: boxWidth,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        _reportDecodeError();
        return _corrupt();
      },
    );
  }

  void _reportDecodeError() {
    final VoidCallback? callback = onDecodeError;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => callback());
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

typedef _MediaResolutionBuilder = Widget Function(
  BuildContext context,
  ResolvedMedia? media,
);

class _MediaResolution extends StatefulWidget {
  const _MediaResolution({
    required this.resolver,
    required this.mediaId,
    required this.builder,
  });

  final MediaResolver resolver;
  final String mediaId;
  final _MediaResolutionBuilder builder;

  @override
  State<_MediaResolution> createState() => _MediaResolutionState();
}

class _MediaResolutionState extends State<_MediaResolution> {
  ResolvedMedia? _media;

  @override
  void initState() {
    super.initState();
    _media = _start();
  }

  @override
  void didUpdateWidget(_MediaResolution oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId == widget.mediaId &&
        oldWidget.resolver == widget.resolver) {
      return;
    }
    _media = _start();
  }

  ResolvedMedia? _start() {
    final String id = widget.mediaId;
    final ResolvedMedia? memo = widget.resolver.resolved(id);
    if (memo != null) {
      return memo;
    }
    widget.resolver.resolve(id).then(
      (ResolvedMedia media) => _arrive(id, media),
      onError: (Object error, StackTrace stackTrace) =>
          _arrive(id, const ResolvedMedia.missing()),
    );
    return null;
  }

  void _arrive(String id, ResolvedMedia media) {
    if (!mounted || widget.mediaId != id) {
      return;
    }
    setState(() => _media = media);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _media);
}
