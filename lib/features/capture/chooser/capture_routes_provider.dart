import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<CaptureRouteRegistry> captureRoutesProvider =
    Provider<CaptureRouteRegistry>(
  (Ref ref) => CaptureRouteRegistry.empty.withRoute(textCaptureRoute),
);
