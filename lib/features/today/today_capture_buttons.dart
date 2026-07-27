import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String captureOpenErrorMessage =
    "Couldn't open capture. Please try again.";

class TodayCaptureButtons extends ConsumerStatefulWidget {
  const TodayCaptureButtons({
    super.key,
    required this.date,
    this.title = 'Quick capture',
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

  Future<void> _openChooser() async {
    try {
      await openCapture(context, ref, date: widget.date);
      _clearError();
    } catch (_) {
      _reportError();
    }
  }

  Future<void> _openRoute(CaptureRoute route) async {
    try {
      await route.open(context, widget.date);
      _clearError();
    } catch (_) {
      _reportError();
    }
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

    return StickerCard(
      surface: Palette.cardLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: TypographyTokens.sectionHeaderAccent),
          const SizedBox(height: 10),
          StickerButton(label: 'Capture', onPressed: _openChooser),
          for (final (CaptureOption option, CaptureRoute route)
              in orderedRoutes) ...<Widget>[
            const SizedBox(height: 8),
            StickerButton(
              label: option.label,
              variant: StickerButtonVariant.secondary,
              onPressed: () => _openRoute(route),
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              error,
              style:
                  TypographyTokens.captionSans.copyWith(color: Palette.danger),
            ),
          ],
        ],
      ),
    );
  }
}
