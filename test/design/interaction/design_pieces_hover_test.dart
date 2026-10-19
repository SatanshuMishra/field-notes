import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/confirm_dialog.dart';
import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const int _mousePointerId = 43;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _coral = Color(0xFFB8566A);
const Color _white = Color(0xFFFFFFFF);
const Color _mediaGround = Color(0xFF15110D);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _lightPill = _coral.withValues(alpha: 0.08).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();

const Key _glassKey = ValueKey<String>('glass-circle');
const Key _primaryStickerKey = ValueKey<String>('sticker-primary');
const Key _secondaryStickerKey = ValueKey<String>('sticker-secondary');
const Key _dangerStickerKey = ValueKey<String>('sticker-danger');
const Key _iconStickerKey = ValueKey<String>('icon-sticker');
const Key _neutralActionKey = ValueKey<String>('action-neutral');
const Key _primaryActionKey = ValueKey<String>('action-primary');
const Key _dangerActionKey = ValueKey<String>('action-danger');
const Key _selectKey = ValueKey<String>('select');
const Key _fieldRowKey = ValueKey<String>('field-row');
const Key _toggleOffKey = ValueKey<String>('toggle-off');
const Key _toggleOnKey = ValueKey<String>('toggle-on');
const Key _timeFieldKey = ValueKey<String>('time-field');
const Key _sheetButtonKey = ValueKey<String>('phone-sheet-button');
const Key _textFieldKey = ValueKey<String>('text-field');
const Key _phoneActionKey = ValueKey<String>('phone-action');
const Key _phoneSelectKey = ValueKey<String>('phone-select');
const Key _openDialogKey = ValueKey<String>('open-dialog');
const Key _openSheetKey = ValueKey<String>('open-sheet');

enum _Shape { circle, rounded }

class _Row {
  const _Row(this.label, this.control, this.fill, this.shape, [this.radius]);

  final String label;
  final Finder control;
  final int fill;
  final _Shape shape;
  final double? radius;
}

Finder _pressableAround(String text) => find
    .ancestor(of: find.text(text).last, matching: find.byType(Pressable))
    .first;

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Widget body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(body: body),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<TestGesture> _mousePointer(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: _mousePointerId,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    if (decoration is! BoxDecoration ||
        decoration.color?.toARGB32() != row.fill) {
      return false;
    }
    return switch (row.shape) {
      _Shape.circle => decoration.shape == BoxShape.circle,
      _Shape.rounded =>
        decoration.borderRadius == BorderRadius.circular(row.radius!),
    };
  }),
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(row.control, findsOneWidget, reason: row.label);
    expect(_hoverFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(row), findsOneWidget, reason: row.label);
    expect(
      tester.getSemantics(
        find
            .descendant(
              of: row.control,
              matching: find.byType(Pressable),
              matchRoot: true,
            )
            .first,
      ),
      isSemantics(label: row.label, isButton: true),
      reason: row.label,
    );
  }
}

Widget _desktopPieces() => SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ColoredBox(
          color: _mediaGround,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: GlassCircleButton(
              key: _glassKey,
              tone: GlassTone.media,
              face: 40,
              label: 'Close camera',
              glyph: const SizedBox.square(dimension: 14),
              onPressed: () {},
            ),
          ),
        ),
        StickerButton(
          key: _primaryStickerKey,
          label: 'Save note',
          onPressed: () {},
        ),
        StickerButton(
          key: _secondaryStickerKey,
          label: 'Not now',
          variant: StickerButtonVariant.secondary,
          onPressed: () {},
        ),
        StickerButton(
          key: _dangerStickerKey,
          label: 'Delete note',
          variant: StickerButtonVariant.danger,
          onPressed: () {},
        ),
        IconStickerButton(
          key: _iconStickerKey,
          glyph: IconStickerGlyph.gear,
          glyphColor: _ink,
          background: const Color(0xFFFDF7EC),
          semanticLabel: 'Open settings',
          onPressed: () {},
        ),
        SettingsActionButton(
          key: _neutralActionKey,
          label: 'Show tour',
          onPressed: () {},
        ),
        SettingsActionButton(
          key: _primaryActionKey,
          label: 'Update now',
          tone: SettingsActionTone.primary,
          onPressed: () {},
        ),
        SettingsActionButton(
          key: _dangerActionKey,
          label: 'Delete all',
          tone: SettingsActionTone.danger,
          onPressed: () {},
        ),
        SettingsSelect<int>(
          key: _selectKey,
          semanticLabel: 'Week starts on',
          options: const <SettingsSelectOption<int>>[
            SettingsSelectOption<int>(value: 0, label: 'Sunday'),
            SettingsSelectOption<int>(value: 1, label: 'Monday'),
          ],
          value: 0,
          onChanged: (int _) {},
        ),
        SizedBox(
          width: 420,
          child: SettingsFieldRow(
            key: _fieldRowKey,
            label: 'Server address',
            control: const Text('notes.example.org'),
            onPressed: () {},
          ),
        ),
        SettingsToggle(
          key: _toggleOffKey,
          semanticLabel: 'Spell check',
          value: false,
          onChanged: (bool _) {},
        ),
        SettingsToggle(
          key: _toggleOnKey,
          semanticLabel: 'Sound effects',
          value: true,
          onChanged: (bool _) {},
        ),
        SettingsSegmented<String>(
          segments: const <SettingsSegment<String>>[
            SettingsSegment<String>(value: 'light', label: 'Light'),
            SettingsSegment<String>(value: 'dark', label: 'Dark'),
          ],
          value: 'light',
          onChanged: (String _) {},
        ),
        SettingsTimeField(
          key: _timeFieldKey,
          semanticLabel: 'Reminder time',
          value: const TimeOfDay(hour: 20, minute: 30),
          onTap: () {},
        ),
        SizedBox(
          width: 220,
          child: PhoneSheetButton(
            key: _sheetButtonKey,
            label: 'Keep editing',
            background: const Color(0xFFFDF7EC),
            foreground: _ink,
            onPressed: () {},
          ),
        ),
        Toast(
          message: 'Note moved',
          action: ToastAction(label: 'Undo', onPressed: () {}),
        ),
        Toast(
          message: 'Saved',
          variant: ToastVariant.dark,
          scale: ToastScale.desktop,
          action: ToastAction(label: 'Open', onPressed: () {}),
        ),
        SizedBox(
          width: 260,
          child: SettingsTextField(
            key: _textFieldKey,
            controller: TextEditingController(text: 'Field Notes Mac'),
            semanticLabel: 'Device name',
          ),
        ),
      ],
    ),
  ),
);

final List<_Row> _desktopRows = <_Row>[
  _Row('Close camera', find.byKey(_glassKey), _dark, _Shape.circle),
  _Row('Save note', find.byKey(_primaryStickerKey), _dark, _Shape.rounded, 12),
  _Row(
    'Not now',
    find.byKey(_secondaryStickerKey),
    _lightRow,
    _Shape.rounded,
    12,
  ),
  _Row('Delete note', find.byKey(_dangerStickerKey), _dark, _Shape.rounded, 11),
  _Row(
    'Open settings',
    find.byKey(_iconStickerKey),
    _lightRow,
    _Shape.rounded,
    8,
  ),
  _Row(
    'Show tour',
    find.byKey(_neutralActionKey),
    _lightPill,
    _Shape.rounded,
    13,
  ),
  _Row('Update now', find.byKey(_primaryActionKey), _dark, _Shape.rounded, 13),
  _Row('Delete all', find.byKey(_dangerActionKey), _dark, _Shape.rounded, 13),
  _Row('Week starts on', find.byKey(_selectKey), _lightRow, _Shape.rounded, 9),
  _Row(
    'Server address',
    find.byKey(_fieldRowKey),
    _lightRow,
    _Shape.rounded,
    11,
  ),
  _Row(
    'Spell check',
    find.byKey(_toggleOffKey),
    _lightPill,
    _Shape.rounded,
    10,
  ),
  _Row('Sound effects', find.byKey(_toggleOnKey), _dark, _Shape.rounded, 10),
  _Row('Light', _pressableAround('Light'), _lightRow, _Shape.rounded, 7),
  _Row('Dark', _pressableAround('Dark'), _lightRow, _Shape.rounded, 7),
  _Row(
    'Reminder time',
    find.byKey(_timeFieldKey),
    _lightRow,
    _Shape.rounded,
    11,
  ),
  _Row(
    'Keep editing',
    find.byKey(_sheetButtonKey),
    _lightRow,
    _Shape.rounded,
    14,
  ),
  _Row('Undo', _pressableAround('Undo'), _lightRow, _Shape.rounded, 12),
  _Row('Open', _pressableAround('Open'), _dark, _Shape.rounded, 12),
];

Widget _dialogOpener() => Builder(
  builder: (BuildContext context) => Center(
    child: TextButton(
      key: _openDialogKey,
      onPressed: () => showConfirmDialog(
        context,
        title: 'Delete this note?',
        message: 'It leaves this device and every synced one.',
        confirmLabel: 'Delete',
        danger: true,
      ),
      child: const Text('Ask'),
    ),
  ),
);

final List<_Row> _dialogRows = <_Row>[
  _Row(
    'Cancel',
    find.byKey(confirmDialogCancelKey),
    _lightRow,
    _Shape.rounded,
    11,
  ),
  _Row(
    'Delete',
    find.byKey(confirmDialogConfirmKey),
    _dark,
    _Shape.rounded,
    11,
  ),
];

Widget _phonePieces() => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      SettingsActionButton(
        key: _phoneActionKey,
        label: 'Show tour',
        onPressed: () {},
      ),
      const SizedBox(height: 16),
      SettingsSelect<int>(
        key: _phoneSelectKey,
        semanticLabel: 'Week starts on',
        options: const <SettingsSelectOption<int>>[
          SettingsSelectOption<int>(value: 0, label: 'Sunday'),
          SettingsSelectOption<int>(value: 1, label: 'Monday'),
        ],
        value: 0,
        onChanged: (int _) {},
      ),
      const SizedBox(height: 16),
      Builder(
        builder: (BuildContext context) => TextButton(
          key: _openSheetKey,
          onPressed: () => showPhoneSheet<void>(
            context,
            builder: (BuildContext sheetContext) => PhoneSheet(
              onExpandedChanged: (bool _) {},
              child: const SizedBox(height: 120),
            ),
          ),
          child: const Text('Sheet'),
        ),
      ),
    ],
  ),
);

final List<_Row> _phoneRows = <_Row>[
  _Row('Show tour', find.byKey(_phoneActionKey), _lightRow, _Shape.rounded, 12),
  _Row(
    'Week starts on',
    find.byKey(_phoneSelectKey),
    _lightRow,
    _Shape.rounded,
    11,
  ),
];

final List<_Row> _selectSheetRows = <_Row>[
  _Row('Sunday', _pressableAround('Sunday'), _lightRow, _Shape.rounded, 12),
  _Row('Monday', _pressableAround('Monday'), _lightRow, _Shape.rounded, 12),
];

final List<_Row> _grabberRows = <_Row>[
  _Row(
    'Expand sheet',
    find.byKey(phoneSheetGrabberToggleKey),
    _lightRow,
    _Shape.rounded,
    24,
  ),
];

void main() {
  testWidgets(
    'every shared design button piece shows the hover style, the click cursor and a label',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      _view(tester, const Size(1280, 1000));
      final TestGesture mouse = await _mousePointer(tester);

      await _pump(tester, TargetPlatform.macOS, _desktopPieces());
      await _expectRows(tester, mouse, _desktopRows);

      final Finder textField = find.byKey(_textFieldKey);
      final _Row textFieldRow = _Row(
        'Device name',
        textField,
        _lightRow,
        _Shape.rounded,
        11,
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(_hoverFill(textFieldRow), findsNothing);
      await mouse.moveTo(tester.getTopLeft(textField) + const Offset(4, 4));
      await tester.pump();
      expect(_cursor(), SystemMouseCursors.click);
      expect(_hoverFill(textFieldRow), findsOneWidget);
      await mouse.moveTo(tester.getCenter(find.byType(EditableText)));
      await tester.pump();
      expect(_cursor(), SystemMouseCursors.text);
      expect(
        tester.getSemantics(
          find.descendant(of: textField, matching: find.byType(Pressable)),
        ),
        isSemantics(label: 'Device name', isTextField: true),
      );

      await mouse.moveTo(tester.getCenter(find.byKey(_selectKey)));
      await tester.pump();
      await tester.tap(find.byKey(_selectKey));
      await tester.pumpAndSettle();
      expect(find.text('Monday'), findsOneWidget);
      expect(find.byType(PopupMenuItem<int>), findsNothing);
      await tester.tapAt(const Offset(1200, 980));
      await tester.pumpAndSettle();

      await _pump(tester, TargetPlatform.macOS, _dialogOpener());
      await tester.tap(find.byKey(_openDialogKey));
      await tester.pumpAndSettle();
      await _expectRows(tester, mouse, _dialogRows);
      await tester.tap(find.byKey(confirmDialogCancelKey));
      await tester.pumpAndSettle();

      _view(tester, const Size(384, 832));
      await _pump(tester, TargetPlatform.android, _phonePieces());
      await _expectRows(tester, mouse, _phoneRows);

      await tester.tap(find.byKey(_phoneSelectKey));
      await tester.pumpAndSettle();
      await _expectRows(tester, mouse, _selectSheetRows);
      await tester.tap(_pressableAround('Sunday'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_openSheetKey));
      await tester.pumpAndSettle();
      await _expectRows(tester, mouse, _grabberRows);

      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
