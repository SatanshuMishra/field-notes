import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/state/settings_providers.dart';

import 'capture/app_capture_routes.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

class FieldNotesApp extends StatelessWidget {
  const FieldNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [captureRoutesProvider.overrideWithValue(appCaptureRoutes)],
      child: MaterialApp(
        title: 'Field Notes',
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(),
        builder: (BuildContext context, Widget? child) =>
            AppTextScale(child: child!),
        home: const AppShell(),
      ),
    );
  }
}

class AppTextScale extends ConsumerWidget {
  const AppTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double factor = ref.watch(textScaleProvider);
    final MediaQueryData ambient = MediaQuery.of(context);
    return MediaQuery(
      data: ambient.copyWith(
        textScaler: ComposedTextScaler(ambient.textScaler, factor),
      ),
      child: child,
    );
  }
}

class ComposedTextScaler extends TextScaler {
  const ComposedTextScaler(this.ambient, this.factor);

  final TextScaler ambient;
  final double factor;

  @override
  double scale(double fontSize) => ambient.scale(fontSize * factor);

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => ambient.textScaleFactor * factor;

  @override
  bool operator ==(Object other) {
    return other is ComposedTextScaler &&
        other.ambient == ambient &&
        other.factor == factor;
  }

  @override
  int get hashCode => Object.hash(ambient, factor);
}
