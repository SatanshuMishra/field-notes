import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/features/mood/mood_picker.dart';
import 'package:field_notes/features/mood/mood_picker_sheet.dart';

import '../../features/capture/core/capture_test_support.dart';
import '../../features/capture/video/video_test_support.dart'
    show FakeVideoRecorder;
import '../../features/capture/voice/voice_test_support.dart'
    show FakeVoiceRecorder;

class _DialogOpener extends StatelessWidget {
  const _DialogOpener({required this.onOpen});

  final ValueGetter<Future<void>> onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: const Text('open'),
    );
  }
}

Widget _harness(
  ValueGetter<Future<void>> Function(BuildContext context) opener, {
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: overrides,
    child: captureHarness(
      Builder(
        builder: (BuildContext context) =>
            _DialogOpener(onOpen: opener(context)),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _expectNoDebugUnderline(WidgetTester tester, Finder sheet) {
  final Finder text =
      find.descendant(of: sheet, matching: find.byType(Text)).first;
  final DefaultTextStyle inherited = DefaultTextStyle.of(tester.element(text));
  final TextStyle resolved =
      inherited.style.merge(tester.widget<Text>(text).style);

  expect(resolved.decoration ?? TextDecoration.none, TextDecoration.none);
}

void main() {
  group('dialogs opened with showGeneralDialog', () {
    testWidgets('the mood picker renders without the debug underline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          (BuildContext context) =>
              () => showMoodPicker(context, selected: Mood.happy),
        ),
      );

      await _openDialog(tester);

      expect(find.byType(MoodPickerSheet), findsOneWidget);
      _expectNoDebugUnderline(tester, find.byType(MoodPickerSheet));
    });

    testWidgets('the capture chooser renders without the debug underline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          (BuildContext context) => () => showCaptureChooser(
                context,
                availableTypes: const <EntryType>{EntryType.text},
              ),
        ),
      );

      await _openDialog(tester);

      expect(find.byType(CaptureChooserSheet), findsOneWidget);
      _expectNoDebugUnderline(tester, find.byType(CaptureChooserSheet));
    });

    testWidgets('the note composer renders without the debug underline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          (BuildContext context) =>
              () => showTextComposer(context, '2026-07-27'),
          overrides: <Override>[
            captureServiceProvider
                .overrideWith((Ref ref) => FakeCaptureService()),
          ],
        ),
      );

      await _openDialog(tester);

      expect(find.byType(TextComposerSheet), findsOneWidget);
      _expectNoDebugUnderline(tester, find.byType(TextComposerSheet));
    });

    testWidgets('the voice composer renders without the debug underline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          (BuildContext context) =>
              () => showVoiceComposer(context, '2026-07-27'),
          overrides: <Override>[
            voiceRecorderProvider.overrideWith((Ref ref) => FakeVoiceRecorder()),
            captureServiceProvider
                .overrideWith((Ref ref) => FakeCaptureService()),
          ],
        ),
      );

      await _openDialog(tester);

      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      _expectNoDebugUnderline(tester, find.byType(VoiceRecorderSheet));
    });

    testWidgets('the video composer renders without the debug underline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          (BuildContext context) =>
              () => showVideoComposer(context, '2026-07-27'),
          overrides: <Override>[
            videoRecorderProvider.overrideWith((Ref ref) => FakeVideoRecorder()),
            captureServiceProvider
                .overrideWith((Ref ref) => FakeCaptureService()),
          ],
        ),
      );

      await _openDialog(tester);

      expect(find.byType(VideoRecorderSheet), findsOneWidget);
      _expectNoDebugUnderline(tester, find.byType(VideoRecorderSheet));
    });
  });
}
