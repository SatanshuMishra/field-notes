import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String captureOpenErrorMessage =
    "Couldn't open capture. Please try again.";

const String todayCaptureTitle = 'capture a moment';

const double _titleGap = 10;
const double _rowGap = 8;
const double _iconSize = 17;

CaptureGlyph _captureGlyphFor(EntryType type) {
  switch (type) {
    case EntryType.text:
      return CaptureGlyph.pencil;
    case EntryType.voice:
      return CaptureGlyph.mic;
    case EntryType.video:
      return CaptureGlyph.video;
  }
}

StickerButtonVariant _captureVariantFor(EntryType type) {
  return type == EntryType.text
      ? StickerButtonVariant.primary
      : StickerButtonVariant.secondary;
}

Color _captureIconColor(StickerButtonVariant variant) {
  return variant == StickerButtonVariant.primary
      ? Palette.onAccent
      : Palette.ink;
}

class TodayCaptureButtons extends ConsumerStatefulWidget {
  const TodayCaptureButtons({
    super.key,
    required this.date,
    this.title = todayCaptureTitle,
  });

  final String date;
  final String title;

  @override
  ConsumerState<TodayCaptureButtons> createState() =>
      _TodayCaptureButtonsState();
}

class _TodayCaptureButtonsState extends ConsumerState<TodayCaptureButtons> {
  String? _error;

  void _clearError() {
    if (!mounted || _error == null) {
      return;
    }
    setState(() => _error = null);
  }

  void _reportError() {
    if (!mounted) {
      return;
    }
    setState(() => _error = captureOpenErrorMessage);
  }

  Future<void> _openRoute(CaptureRoute route) async {
    try {
      await route.open(context, widget.date);
      _clearError();
    } catch (_) {
      _reportError();
    }
  }

  Widget _captureRow(CaptureOption option, CaptureRoute route) {
    final StickerButtonVariant variant = _captureVariantFor(option.type);
    return StickerButton(
      label: option.label,
      variant: variant,
      icon: CaptureIcon(
        glyph: _captureGlyphFor(option.type),
        color: _captureIconColor(variant),
        size: _iconSize,
      ),
      labelStyle: TypographyTokens.captureLabelSans,
      onPressed: () => _openRoute(route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CaptureRouteRegistry registry = ref.watch(captureRoutesProvider);
    final List<(CaptureOption, CaptureRoute)> orderedRoutes =
        <(CaptureOption, CaptureRoute)>[
      for (final CaptureOption option in captureOptions)
        if (registry.routeFor(option.type) case final CaptureRoute route)
          (option, route),
    ];
    final String? error = _error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.title, style: TypographyTokens.sectionHeaderAccent),
        const SizedBox(height: _titleGap),
        for (final (int index, (CaptureOption option, CaptureRoute route))
            in orderedRoutes.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: _rowGap),
          _captureRow(option, route),
        ],
        if (error != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            error,
            style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
          ),
        ],
      ],
    );
  }
}
