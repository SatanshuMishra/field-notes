import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/features/capture/core/capture.dart';

import 'capture/app_capture_routes.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

class FieldNotesApp extends StatelessWidget {
  const FieldNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        captureRoutesProvider.overrideWithValue(appCaptureRoutes),
      ],
      child: MaterialApp(
        title: 'Field Notes',
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(),
        home: const AppShell(),
      ),
    );
  }
}
