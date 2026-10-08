import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/features/garden/widgets/meadow_desktop_page.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the full-screen Meadow lightens the caption glyphs only under a dark sky',
    () {
      expect(meadowSkyDarkensCaptions(const Color(0xFFBED2DE)), isFalse);
      expect(meadowSkyDarkensCaptions(const Color(0xFF969FC0)), isFalse);
      expect(meadowSkyDarkensCaptions(const Color(0xFF2E3A6A)), isTrue);
      expect(meadowSkyDarkensCaptions(const Color(0xFF0C1022)), isTrue);
    },
  );

  test(
    'the full-screen Meadow details panel clears the Windows caption buttons',
    () {
      expect(
        meadowDetailsPanelTop(
          fullScreen: true,
          platform: TargetPlatform.windows,
        ),
        meadowDetailsPanelInset + shellTitleBarHeight,
      );
      expect(meadowDetailsPanelInset + shellTitleBarHeight, 54);
      expect(
        meadowDetailsPanelTop(fullScreen: true, platform: TargetPlatform.macOS),
        meadowDetailsPanelInset,
      );
      expect(
        meadowDetailsPanelTop(
          fullScreen: false,
          platform: TargetPlatform.windows,
        ),
        meadowDetailsPanelInset,
      );
      expect(
        meadowDetailsPanelTop(
          fullScreen: false,
          platform: TargetPlatform.macOS,
        ),
        meadowDetailsPanelInset,
      );
    },
  );
}
