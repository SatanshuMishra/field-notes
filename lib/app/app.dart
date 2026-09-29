import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/state/settings_providers.dart';

import 'capture/app_capture_routes.dart';
import 'macos_menu_bar.dart';
import 'macos_text_shortcuts.dart';
import 'shell/app_shell.dart';
import 'shell/window_chrome.dart';
import 'theme/app_theme.dart';

const Duration _settingsWait = Duration(seconds: 1);

class FieldNotesApp extends StatelessWidget {
  const FieldNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [captureRoutesProvider.overrideWithValue(appCaptureRoutes)],
      child: const _ThemedApp(),
    );
  }

  static Widget _appBuilder(BuildContext context, Widget? child) {
    final Widget scaled = AppTextScale(child: child!);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: switch (Theme.of(context).brightness) {
        Brightness.dark => SystemUiOverlayStyle.light,
        Brightness.light => SystemUiOverlayStyle.dark,
      },
      child: defaultTargetPlatform == TargetPlatform.macOS
          ? MacosMenuBar(child: MacosTextShortcuts(child: scaled))
          : scaled,
    );
  }
}

class _ThemedApp extends ConsumerStatefulWidget {
  const _ThemedApp();

  @override
  ConsumerState<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends ConsumerState<_ThemedApp> {
  Timer? _settingsTimeout;
  bool _settingsReady = false;

  @override
  void initState() {
    super.initState();
    _settingsTimeout = Timer(_settingsWait, _showApp);
    ref.listenManual<AsyncValue<AppSettings>>(appSettingsProvider, (
      AsyncValue<AppSettings>? _,
      AsyncValue<AppSettings> settings,
    ) {
      if (settings.hasValue || settings.hasError) {
        _showApp();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _settingsTimeout?.cancel();
    super.dispose();
  }

  void _showApp() {
    if (_settingsReady || !mounted) {
      return;
    }
    _settingsTimeout?.cancel();
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      ref.listenManual<Appearance>(
        appearanceProvider,
        (Appearance? _, Appearance appearance) =>
            unawaited(setWindowAppearance(appearance)),
        fireImmediately: true,
      );
    }
    setState(() => _settingsReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsReady) {
      return const SizedBox.shrink();
    }
    return MaterialApp(
      title: 'Field Notes',
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(),
      darkTheme: fieldNotesTheme(brightness: Brightness.dark),
      themeMode: switch (ref.watch(appearanceProvider)) {
        Appearance.light => ThemeMode.light,
        Appearance.dark => ThemeMode.dark,
        Appearance.system => ThemeMode.system,
      },
      builder: FieldNotesApp._appBuilder,
      home: const OnboardingHost(child: AppShell()),
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
