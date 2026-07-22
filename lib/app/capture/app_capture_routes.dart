import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/capture/video/video.dart';
import 'package:field_notes/features/capture/voice/voice.dart';

final CaptureRouteRegistry appCaptureRoutes = CaptureRouteRegistry.empty
    .withRoute(textCaptureRoute)
    .withRoute(voiceCaptureRoute)
    .withRoute(videoCaptureRoute);
