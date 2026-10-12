import 'dart:math' as math;

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/links/link_opener.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/features/settings/sections/about_section.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/update_overrides.dart';
import '../support/fake_settings_repository.dart';

const Size _desktopWindow = Size(1140, 726);
const Size _phoneView = Size(384, 832);
const double _contentWidth = 680;
const double _phoneSide = 14;
const String _version = '1.4.2';
const double _tolerance = 0.01;

final Uri _website = Uri.parse('https://www.satanshu.tech');
final Uri _repository = Uri.parse(
  'https://github.com/SatanshuMishra/field-notes',
);

Future<bool> _openNothing(Uri link) async => true;

List<Override> _overrides({required bool versionFails}) => <Override>[
  settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  ...updateQuietOverrides(),
  installedAppProvider.overrideWith((Ref ref) async {
    if (versionFails) {
      throw PlatformException(code: 'unavailable');
    }
    return const InstalledApp(version: _version);
  }),
];

Future<void> _pumpAbout(
  WidgetTester tester, {
  required TargetPlatform platform,
  bool versionFails = false,
  LinkOpener openLink = _openNothing,
  List<String>? notices,
}) async {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phoneView : _desktopWindow;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    const FakeViewPadding padding = FakeViewPadding(top: 34, bottom: 24);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
  }
  addTearDown(tester.view.reset);
  final Widget about = AboutSection(
    onFeedback: (String message) => notices?.add(message),
    openLink: openLink,
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(versionFails: versionFails),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Builder(
          builder: (BuildContext context) => ColoredBox(
            color: context.colors.page,
            child: SingleChildScrollView(
              padding: phone
                  ? const EdgeInsets.fromLTRB(_phoneSide, 60, _phoneSide, 60)
                  : const EdgeInsets.fromLTRB(28, 26, 34, 34),
              child: phone
                  ? about
                  : Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(width: _contentWidth, child: about),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _element(Element element) =>
    find.byElementPredicate((Element candidate) => candidate == element);

Text _text(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text));

void _expectStyle(
  WidgetTester tester,
  String text, {
  required String family,
  required double size,
  required FontWeight weight,
  required Color color,
  double? height,
}) {
  final TextStyle? style = _text(tester, text).style;
  expect(style?.fontFamily, family, reason: text);
  expect(style?.fontSize, size, reason: text);
  expect(style?.fontWeight, weight, reason: text);
  expect(style?.color?.toARGB32(), color.toARGB32(), reason: text);
  if (height != null) {
    expect(style?.height, height, reason: text);
  }
}

void _expectCardDecoration(WidgetTester tester, Finder card) {
  final FieldNotesColors colors = FieldNotesColors.light;
  final BoxDecoration decoration =
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(of: card, matching: find.byType(DecoratedBox))
                    .first,
              )
              .decoration
          as BoxDecoration;
  expect(decoration.color?.toARGB32(), colors.cardWarm.toARGB32());
  final Border border = decoration.border! as Border;
  expect(border.top.width, 1.5);
  expect(border.top.color.toARGB32(), colors.line.toARGB32());
  expect(border.left.width, 1.5);
  expect(decoration.borderRadius, BorderRadius.circular(16));
  final List<BoxShadow> shadows = decoration.boxShadow!;
  expect(shadows, hasLength(1));
  expect(shadows.single.offset, const Offset(3, 3));
  expect(shadows.single.blurRadius, 0);
  expect(shadows.single.spreadRadius, 0);
  expect(
    shadows.single.color.toARGB32(),
    colors.shadow.withValues(alpha: 0.2).toARGB32(),
  );
}

Finder _authorRow() => find.ancestor(
  of: find.text('Satanshu Mishra'),
  matching: find.byType(SettingsFieldRow),
);

Finder _pill(String label) => find.descendant(
  of: _authorRow(),
  matching: find.widgetWithText(SettingsActionButton, label),
);

Finder _phoneButton(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
    .first;

void main() {
  testWidgets(
    'the desktop About page shows the app, its version and its author',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final FieldNotesColors colors = FieldNotesColors.light;
      await _pumpAbout(tester, platform: TargetPlatform.macOS);

      expect(find.text('About'), findsNothing);
      final Finder card = find.byKey(aboutIdentityCardKey);
      expect(card, findsOneWidget);
      _expectCardDecoration(tester, card);
      expect(
        tester.widget<StickerCard>(card).padding,
        const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      );

      final Finder logo = find.descendant(
        of: card,
        matching: find.byType(FlowerBloom),
      );
      expect(logo, findsOneWidget);
      expect(tester.widget<FlowerBloom>(logo).kind, FlowerKind.peony);
      expect(tester.getSize(logo), const Size(52, 52));
      expect(
        tester.getTopLeft(logo).dx - tester.getTopLeft(card).dx,
        closeTo(20, _tolerance),
      );

      _expectStyle(
        tester,
        'Field Notes',
        family: TypographyTokens.serif,
        size: 22,
        weight: FontWeight.w500,
        color: colors.ink,
        height: 1.15,
      );
      _expectStyle(
        tester,
        'A journal of days · Version 1.4.2',
        family: TypographyTokens.sans,
        size: 12.5,
        weight: FontWeight.w400,
        color: colors.muted,
      );
      expect(
        tester.getTopLeft(find.text('Field Notes')).dx -
            tester.getTopRight(logo).dx,
        closeTo(16, _tolerance),
      );
      expect(
        tester.getTopLeft(find.text('A journal of days · Version 1.4.2')).dy,
        closeTo(tester.getBottomLeft(find.text('Field Notes')).dy, _tolerance),
      );
      expect(
        find.bySemanticsLabel('Field Notes, a journal of days, version 1.4.2'),
        findsOneWidget,
      );

      final Finder section = find.ancestor(
        of: find.text('author'),
        matching: find.byType(SettingsSection),
      );
      expect(section, findsOneWidget);
      expect(
        tester.getTopLeft(section).dy - tester.getBottomLeft(card).dy,
        closeTo(15, _tolerance),
      );
      _expectStyle(
        tester,
        'author',
        family: TypographyTokens.accent,
        size: 17,
        weight: FontWeight.w600,
        color: colors.sage,
      );
      expect(_authorRow(), findsOneWidget);
      final SettingsFieldRow row = tester.widget<SettingsFieldRow>(
        _authorRow(),
      );
      expect(row.label, 'Satanshu Mishra');
      expect(row.description, 'Designed and built Field Notes.');
      expect(
        find.descendant(
          of: _authorRow(),
          matching: find.byType(SettingsActionButton),
        ),
        findsNWidgets(2),
      );
      expect(_pill('Website'), findsOneWidget);
      expect(_pill('GitHub'), findsOneWidget);
      expect(
        tester.getTopLeft(_pill('GitHub')).dx -
            tester.getTopRight(_pill('Website')).dx,
        closeTo(8, _tolerance),
      );
      expect(find.bySemanticsLabel('Website'), findsOneWidget);
      expect(find.bySemanticsLabel('GitHub'), findsOneWidget);

      const String licence =
          '© 2026 Satanshu Mishra · Licensed under the Apache License 2.0';
      _expectStyle(
        tester,
        licence,
        family: TypographyTokens.sans,
        size: 12,
        weight: FontWeight.w400,
        color: colors.muted,
      );
      expect(
        tester.getTopLeft(find.text(licence)).dy -
            tester.getBottomLeft(section).dy,
        closeTo(10, _tolerance),
      );

      await _pumpAbout(
        tester,
        platform: TargetPlatform.macOS,
        versionFails: true,
      );
      expect(
        find.text('A journal of days · Version unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('1.4.2'), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Field Notes, a journal of days, version unavailable',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'the phone About page shows the app, its version and its author',
    (WidgetTester tester) async {
      final FieldNotesColors colors = FieldNotesColors.light;
      await _pumpAbout(tester, platform: TargetPlatform.android);

      final Finder card = find.byKey(aboutIdentityCardKey);
      expect(card, findsOneWidget);
      _expectCardDecoration(tester, card);
      final Rect cardRect = tester.getRect(card);
      expect(cardRect.left, closeTo(_phoneSide, _tolerance));
      expect(
        cardRect.right,
        closeTo(_phoneView.width - _phoneSide, _tolerance),
      );

      final Finder logo = find.descendant(
        of: card,
        matching: find.byType(FlowerBloom),
      );
      expect(tester.widget<FlowerBloom>(logo).kind, FlowerKind.peony);
      expect(tester.getSize(logo), const Size(60, 60));
      expect(
        tester.getTopLeft(logo).dy - cardRect.top,
        closeTo(22, _tolerance),
      );
      expect(
        tester.getCenter(logo).dx,
        closeTo(cardRect.center.dx, _tolerance),
      );

      _expectStyle(
        tester,
        'Field Notes',
        family: TypographyTokens.serif,
        size: 22,
        weight: FontWeight.w500,
        color: colors.ink,
        height: 1.2,
      );
      const String tagline = 'A journal of days · Version 1.4.2';
      _expectStyle(
        tester,
        tagline,
        family: TypographyTokens.sans,
        size: 12.5,
        weight: FontWeight.w400,
        color: colors.muted,
      );
      expect(
        tester.getTopLeft(find.text('Field Notes')).dy -
            tester.getBottomLeft(logo).dy,
        closeTo(8, _tolerance),
      );
      expect(
        tester.getTopLeft(find.text(tagline)).dy -
            tester.getBottomLeft(find.text('Field Notes')).dy,
        closeTo(2, _tolerance),
      );
      expect(
        tester.getCenter(find.text('Field Notes')).dx,
        closeTo(cardRect.center.dx, _tolerance),
      );
      expect(
        tester.getCenter(find.text(tagline)).dx,
        closeTo(cardRect.center.dx, _tolerance),
      );

      _expectStyle(
        tester,
        'author',
        family: TypographyTokens.accent,
        size: 17,
        weight: FontWeight.w600,
        color: colors.sage,
      );
      final double authorTop = tester.getTopLeft(find.text('author')).dy;
      final double blockAbove = find
          .byType(StickerCard)
          .evaluate()
          .map((Element element) => tester.getRect(_element(element)).bottom)
          .where((double bottom) => bottom <= authorTop + _tolerance)
          .reduce(math.max);
      expect(blockAbove, greaterThanOrEqualTo(cardRect.bottom - _tolerance));
      expect(authorTop - blockAbove, closeTo(14, _tolerance));
      final Finder authorCard = find.byKey(aboutAuthorCardKey);
      _expectCardDecoration(tester, authorCard);
      expect(
        tester.widget<StickerCard>(authorCard).padding,
        const EdgeInsets.all(16),
      );
      expect(
        tester.getTopLeft(authorCard).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('author')).dy - _tolerance,
        ),
      );
      _expectStyle(
        tester,
        'Satanshu Mishra',
        family: TypographyTokens.sans,
        size: 15,
        weight: FontWeight.w600,
        color: colors.ink,
      );
      _expectStyle(
        tester,
        'Designed and built Field Notes.',
        family: TypographyTokens.sans,
        size: 12,
        weight: FontWeight.w400,
        color: colors.muted,
        height: 1.5,
      );

      final Rect website = tester.getRect(_phoneButton('Website'));
      final Rect github = tester.getRect(_phoneButton('GitHub'));
      expect(website.height, closeTo(48, _tolerance));
      expect(github.height, closeTo(48, _tolerance));
      expect(website.width, closeTo(github.width, _tolerance));
      expect(github.left - website.right, closeTo(8, _tolerance));
      expect(website.top, closeTo(github.top, _tolerance));
      expect(
        website.top -
            tester
                .getBottomLeft(find.text('Designed and built Field Notes.'))
                .dy,
        closeTo(14, _tolerance),
      );
      final Rect authorRect = tester.getRect(authorCard);
      expect(website.left - authorRect.left, closeTo(16, _tolerance));
      expect(authorRect.right - github.right, closeTo(16, _tolerance));
      _expectStyle(
        tester,
        'Website',
        family: TypographyTokens.sans,
        size: 14,
        weight: FontWeight.w600,
        color: colors.ink,
      );
      final BoxDecoration buttonFace =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('Website'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(buttonFace.color?.toARGB32(), colors.cardBright.toARGB32());
      expect((buttonFace.border! as Border).top.width, 1.5);
      expect(buttonFace.borderRadius, BorderRadius.circular(14));

      const String licence =
          '© 2026 Satanshu Mishra · Licensed under the Apache License 2.0';
      final Text licenceText = _text(tester, licence);
      expect(licenceText.textAlign, TextAlign.center);
      expect(
        tester.getCenter(find.text(licence)).dx,
        closeTo(_phoneView.width / 2, _tolerance),
      );
      _expectStyle(
        tester,
        licence,
        family: TypographyTokens.sans,
        size: 12,
        weight: FontWeight.w400,
        color: colors.muted,
      );
      expect(
        tester.getTopLeft(find.text(licence)).dy - authorRect.bottom,
        closeTo(14, _tolerance),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('About links open the website and the repository', (
    WidgetTester tester,
  ) async {
    final List<Uri> opened = <Uri>[];
    Future<bool> record(Uri link) async {
      opened.add(link);
      return true;
    }

    final List<String> notices = <String>[];
    await _pumpAbout(
      tester,
      platform: TargetPlatform.macOS,
      openLink: record,
      notices: notices,
    );
    await tester.tap(_pill('Website'));
    await tester.pump();
    await tester.tap(_pill('GitHub'));
    await tester.pump();
    expect(opened, <Uri>[_website, _repository]);
    expect(notices, isEmpty);

    opened.clear();
    for (int press = 0; press < 12; press++) {
      if (find
          .descendant(of: _pill('Website'), matching: find.byKey(focusRingKey))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      find.descendant(of: _pill('Website'), matching: find.byKey(focusRingKey)),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      find.descendant(of: _pill('GitHub'), matching: find.byKey(focusRingKey)),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, <Uri>[_website, _repository]);

    Future<bool> refuse(Uri link) async => false;
    await _pumpAbout(
      tester,
      platform: TargetPlatform.macOS,
      openLink: refuse,
      notices: notices,
    );
    await tester.tap(_pill('Website'));
    await tester.pump();
    expect(notices, <String>[
      "Couldn't open https://www.satanshu.tech. Find it at www.satanshu.tech.",
    ]);

    notices.clear();
    Future<bool> fail(Uri link) async =>
        throw PlatformException(code: 'no-browser');
    await _pumpAbout(
      tester,
      platform: TargetPlatform.macOS,
      openLink: fail,
      notices: notices,
    );
    await tester.tap(_pill('GitHub'));
    await tester.pump();
    expect(notices, <String>[
      "Couldn't open https://github.com/SatanshuMishra/field-notes. Find it at "
          'github.com/SatanshuMishra/field-notes.',
    ]);

    notices.clear();
    opened.clear();
    await _pumpAbout(
      tester,
      platform: TargetPlatform.android,
      openLink: record,
      notices: notices,
    );
    await tester.ensureVisible(_phoneButton('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(_phoneButton('Website'));
    await tester.pump();
    await tester.tap(_phoneButton('GitHub'));
    await tester.pump();
    expect(opened, <Uri>[_website, _repository]);
    expect(notices, isEmpty);

    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester.getSemantics(_phoneButton('Website')),
      matchesSemantics(
        label: 'Website',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: false,
      ),
    );
    semantics.dispose();
    await _pumpAbout(
      tester,
      platform: TargetPlatform.android,
      openLink: refuse,
      notices: notices,
    );
    await tester.ensureVisible(_phoneButton('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(_phoneButton('GitHub'));
    await tester.pump();
    expect(notices, <String>[
      "Couldn't open https://github.com/SatanshuMishra/field-notes. Find it at "
          'github.com/SatanshuMishra/field-notes.',
    ]);
  });
}
