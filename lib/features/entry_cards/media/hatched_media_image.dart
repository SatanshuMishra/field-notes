import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import 'live_media.dart';
import 'media_image.dart';
import 'media_resolver.dart';

class HatchedMediaImage extends StatefulWidget {
  const HatchedMediaImage({
    super.key,
    required this.resolver,
    required this.mediaId,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.variant,
    required this.errorLabel,
    this.hatchChild,
  });

  final MediaResolver resolver;
  final String? mediaId;
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final CrossHatchVariant variant;
  final String errorLabel;
  final Widget? hatchChild;

  @override
  State<HatchedMediaImage> createState() => _HatchedMediaImageState();
}

class _HatchedMediaImageState extends State<HatchedMediaImage> {
  final MediaArrivalWatch _arrivals = MediaArrivalWatch();
  ResolvedMedia? _media;
  bool _decodeFailed = false;

  @override
  void initState() {
    super.initState();
    _media = _start();
  }

  @override
  void didUpdateWidget(HatchedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId == widget.mediaId &&
        oldWidget.resolver == widget.resolver) {
      return;
    }
    _decodeFailed = false;
    _media = _start();
  }

  @override
  void dispose() {
    _arrivals.cancel();
    super.dispose();
  }

  ResolvedMedia? _start() {
    _arrivals.cancel();
    final String? id = widget.mediaId;
    if (id == null || id.isEmpty) {
      return const ResolvedMedia.missing();
    }
    final ResolvedMedia? memo = widget.resolver.resolved(id);
    if (memo != null) {
      return memo;
    }
    _resolve(id);
    return null;
  }

  void _resolve(String id) {
    widget.resolver
        .resolve(id)
        .then(
          (ResolvedMedia media) => _arrive(id, media),
          onError: (Object error, StackTrace stackTrace) =>
              _arrive(id, const ResolvedMedia.missing()),
        );
  }

  void _arrive(String id, ResolvedMedia media) {
    if (!mounted || widget.mediaId != id) {
      return;
    }
    setState(() => _media = media);
    if (media.isAvailable) {
      _arrivals.cancel();
    } else if (!_arrivals.isWatching) {
      _arrivals.watch(widget.resolver, id, () => _resolve(id));
    }
  }

  void _onDecodeError() {
    if (mounted && !_decodeFailed) {
      setState(() => _decodeFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ResolvedMedia? media = _media;
    final File? file = media?.file;
    if (media == null || !media.isAvailable || file == null || _decodeFailed) {
      return CrossHatchPlaceholder(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        variant: widget.variant,
        child: widget.hatchChild,
      );
    }
    return ExcludeSemantics(
      child: MediaImage(
        resolver: widget.resolver,
        mediaId: widget.mediaId,
        errorLabel: widget.errorLabel,
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        fit: BoxFit.cover,
        border: context.shadows.outline,
        onDecodeError: _onDecodeError,
      ),
    );
  }
}
