import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Set<TargetPlatform> a11yPlatforms = <TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.macOS,
  TargetPlatform.windows,
};

const List<Brightness> a11yBrightnesses = <Brightness>[
  Brightness.light,
  Brightness.dark,
];

enum A11yTextScale {
  normal(factor: 1, idSuffix: ''),
  doubled(factor: 2, idSuffix: '@2x');

  const A11yTextScale({required this.factor, required this.idSuffix});

  final double factor;
  final String idSuffix;

  TextScaler get textScaler => TextScaler.linear(factor);
}

final class A11yWindow {
  const A11yWindow({
    required this.physicalSize,
    required this.devicePixelRatio,
  });

  final Size physicalSize;
  final double devicePixelRatio;

  Size get logicalSize => physicalSize / devicePixelRatio;
}

const A11yWindow a11yPhoneWindow = A11yWindow(
  physicalSize: Size(1080, 2280),
  devicePixelRatio: 2.625,
);

const A11yWindow a11yMacWindow = A11yWindow(
  physicalSize: Size(2560, 1600),
  devicePixelRatio: 2,
);

const A11yWindow a11yWindowsWindow = A11yWindow(
  physicalSize: Size(1920, 1200),
  devicePixelRatio: 1.5,
);

String a11yPlatformName(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'android',
  TargetPlatform.macOS => 'macos',
  TargetPlatform.windows => 'windows',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.linux => 'linux',
  TargetPlatform.fuchsia => 'fuchsia',
};

final class A11yVariant {
  const A11yVariant({
    required this.platform,
    this.brightness = Brightness.light,
    this.textScale = A11yTextScale.normal,
  });

  final TargetPlatform platform;
  final Brightness brightness;
  final A11yTextScale textScale;

  String get platformName => a11yPlatformName(platform);

  String get themeName => brightness.name;

  String get baseline => '$platformName-$themeName';

  String get idSuffix => textScale.idSuffix;

  String get name => '$baseline$idSuffix';

  TextScaler get textScaler => textScale.textScaler;

  bool get largeText => textScale == A11yTextScale.doubled;

  ShellLayout get layout => resolveShellLayout(platform);

  bool get desktop => layout == ShellLayout.sidebar;

  ThemeData get theme =>
      fieldNotesTheme(platform: platform, brightness: brightness);

  A11yWindow get window => switch (platform) {
    TargetPlatform.macOS => a11yMacWindow,
    TargetPlatform.windows => a11yWindowsWindow,
    _ => a11yPhoneWindow,
  };

  Widget scaleText(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child ?? const SizedBox.shrink(),
  );

  void useWindow(WidgetTester tester, [A11yWindow? window]) {
    final A11yWindow chosen = window ?? this.window;
    tester.view.physicalSize = chosen.physicalSize;
    tester.view.devicePixelRatio = chosen.devicePixelRatio;
    addTearDown(tester.view.reset);
  }

  @override
  String toString() => name;
}

final List<A11yVariant> a11yVariants = List<A11yVariant>.unmodifiable(
  <A11yVariant>[
    for (final TargetPlatform platform in a11yPlatforms)
      for (final Brightness brightness in a11yBrightnesses)
        for (final A11yTextScale textScale in A11yTextScale.values)
          A11yVariant(
            platform: platform,
            brightness: brightness,
            textScale: textScale,
          ),
  ],
);

final List<String> a11yBaselineNames = List<String>.unmodifiable(<String>[
  for (final A11yVariant variant in a11yVariants)
    if (variant.textScale == A11yTextScale.normal) variant.baseline,
]);
