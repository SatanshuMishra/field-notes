import 'package:field_notes/domain/models/models.dart';
import 'package:flutter/widgets.dart';

typedef CaptureRouteOpener = Future<String?> Function(
  BuildContext context,
  String date,
);

class CaptureOption {
  const CaptureOption({
    required this.type,
    required this.label,
    required this.description,
  });

  final EntryType type;
  final String label;
  final String description;
}

const List<CaptureOption> captureOptions = <CaptureOption>[
  CaptureOption(
    type: EntryType.text,
    label: 'Write a note',
    description: 'A few words for today',
  ),
  CaptureOption(
    type: EntryType.voice,
    label: 'Record voice',
    description: 'Say it out loud',
  ),
  CaptureOption(
    type: EntryType.video,
    label: 'Record video',
    description: 'Up to 30 minutes',
  ),
];

class CaptureRoute {
  const CaptureRoute({required this.type, required this.open});

  final EntryType type;
  final CaptureRouteOpener open;
}

class CaptureRouteRegistry {
  const CaptureRouteRegistry(this._routes);

  static const CaptureRouteRegistry empty =
      CaptureRouteRegistry(<CaptureRoute>[]);

  final List<CaptureRoute> _routes;

  List<CaptureRoute> get routes => List<CaptureRoute>.unmodifiable(_routes);

  CaptureRoute? routeFor(EntryType type) {
    for (final CaptureRoute route in _routes) {
      if (route.type == type) {
        return route;
      }
    }
    return null;
  }

  bool supports(EntryType type) => routeFor(type) != null;

  CaptureRouteRegistry withRoute(CaptureRoute route) {
    return CaptureRouteRegistry(<CaptureRoute>[
      for (final CaptureRoute existing in _routes)
        if (existing.type != route.type) existing,
      route,
    ]);
  }
}
