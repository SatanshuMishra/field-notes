import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const String _svgPath = 'tool/icons/app_icon.svg';
const String _macIconSet = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const String _androidRes = 'android/app/src/main/res';

const List<int> _macSizes = <int>[16, 32, 64, 128, 256, 512, 1024];

const Map<String, int> _legacyLauncherSizes = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

const double _appleCanvas = 1024;
const double _appleBody = 824;
const double _appleShadowOffset = 10;
const double _appleShadowBlur = 20;
const int _appleShadowAlpha = 77;

const double _adaptiveCanvas = 108;
const double _adaptiveViewport = 72;
const double _adaptiveSafeMin = 21;
const double _adaptiveSafeMax = 87;

const double _circleKappa = 0.5522847498307936;

const Set<String> _styleAttributes = <String>{
  'fill',
  'stroke',
  'stroke-width',
  'stroke-linejoin',
  'transform',
};

const Map<String, Set<String>> _elementAttributes = <String, Set<String>>{
  'svg': <String>{'xmlns', 'xmlns:c2pa', 'width', 'height', 'viewBox'},
  'g': <String>{},
  'rect': <String>{'x', 'y', 'width', 'height', 'rx'},
  'circle': <String>{'cx', 'cy', 'r'},
  'path': <String>{'d'},
};

final RegExp _numberPattern = RegExp(r'-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

class _Affine {
  const _Affine(this.scaleX, this.scaleY, this.dx, this.dy);

  static const _Affine identity = _Affine(1, 1, 0, 0);

  final double scaleX;
  final double scaleY;
  final double dx;
  final double dy;

  _Affine times(_Affine inner) => _Affine(
    scaleX * inner.scaleX,
    scaleY * inner.scaleY,
    scaleX * inner.dx + dx,
    scaleY * inner.dy + dy,
  );

  ui.Offset map(ui.Offset point) =>
      ui.Offset(scaleX * point.dx + dx, scaleY * point.dy + dy);

  double get uniformScale {
    if (scaleX != scaleY) {
      throw UnsupportedError('Only uniform scales are supported');
    }
    return scaleX;
  }
}

class _Style {
  const _Style({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.strokeJoin,
  });

  static const _Style initial = _Style(
    fill: ui.Color(0xFF000000),
    stroke: null,
    strokeWidth: 1,
    strokeJoin: ui.StrokeJoin.miter,
  );

  final ui.Color? fill;
  final ui.Color? stroke;
  final double strokeWidth;
  final ui.StrokeJoin strokeJoin;

  _Style inherit(Map<String, String> attributes) {
    final String? fillValue = attributes['fill'];
    final String? strokeValue = attributes['stroke'];
    final String? widthValue = attributes['stroke-width'];
    return _Style(
      fill: fillValue == null ? fill : _parseColor(fillValue),
      stroke: strokeValue == null ? stroke : _parseColor(strokeValue),
      strokeWidth: widthValue == null ? strokeWidth : double.parse(widthValue),
      strokeJoin: switch (attributes['stroke-linejoin']) {
        null => strokeJoin,
        'miter' => ui.StrokeJoin.miter,
        'round' => ui.StrokeJoin.round,
        'bevel' => ui.StrokeJoin.bevel,
        final String other => throw UnsupportedError('stroke-linejoin $other'),
      },
    );
  }

  _Style scaled(double factor) => _Style(
    fill: fill,
    stroke: stroke,
    strokeWidth: strokeWidth * factor,
    strokeJoin: strokeJoin,
  );
}

sealed class _Segment {
  const _Segment();

  _Segment mapped(_Affine transform);
}

final class _MoveTo extends _Segment {
  const _MoveTo(this.point);

  final ui.Offset point;

  @override
  _MoveTo mapped(_Affine transform) => _MoveTo(transform.map(point));
}

final class _LineTo extends _Segment {
  const _LineTo(this.point);

  final ui.Offset point;

  @override
  _LineTo mapped(_Affine transform) => _LineTo(transform.map(point));
}

final class _QuadTo extends _Segment {
  const _QuadTo(this.control, this.end);

  final ui.Offset control;
  final ui.Offset end;

  @override
  _QuadTo mapped(_Affine transform) =>
      _QuadTo(transform.map(control), transform.map(end));
}

final class _CubicTo extends _Segment {
  const _CubicTo(this.first, this.second, this.end);

  final ui.Offset first;
  final ui.Offset second;
  final ui.Offset end;

  @override
  _CubicTo mapped(_Affine transform) =>
      _CubicTo(transform.map(first), transform.map(second), transform.map(end));
}

final class _Close extends _Segment {
  const _Close();

  @override
  _Close mapped(_Affine transform) => this;
}

sealed class _Shape {
  const _Shape(this.style);

  final _Style style;

  _Shape mapped(_Affine transform);

  List<_Segment> get segments;

  ui.Path toPath() => segments.fold(
    ui.Path(),
    (ui.Path path, _Segment segment) => switch (segment) {
      _MoveTo(:final ui.Offset point) => path..moveTo(point.dx, point.dy),
      _LineTo(:final ui.Offset point) => path..lineTo(point.dx, point.dy),
      _QuadTo(:final ui.Offset control, :final ui.Offset end) =>
        path..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
      _CubicTo(
        :final ui.Offset first,
        :final ui.Offset second,
        :final ui.Offset end,
      ) =>
        path..cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy),
      _Close() => path..close(),
    },
  );

  ui.Rect get paintedBounds => toPath().getBounds().inflate(
    style.stroke == null ? 0 : style.strokeWidth / 2,
  );
}

final class _RoundedRect extends _Shape {
  const _RoundedRect(super.style, this.rect, this.radius);

  final ui.Rect rect;
  final double radius;

  @override
  _RoundedRect mapped(_Affine transform) => _RoundedRect(
    style.scaled(transform.uniformScale),
    ui.Rect.fromPoints(
      transform.map(rect.topLeft),
      transform.map(rect.bottomRight),
    ),
    radius * transform.uniformScale,
  );

  ui.RRect get rrect =>
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius));

  @override
  List<_Segment> get segments {
    final double r = radius;
    final double k = r * (1 - _circleKappa);
    final double left = rect.left;
    final double top = rect.top;
    final double right = rect.right;
    final double bottom = rect.bottom;
    return <_Segment>[
      _MoveTo(ui.Offset(left + r, top)),
      _LineTo(ui.Offset(right - r, top)),
      _CubicTo(
        ui.Offset(right - k, top),
        ui.Offset(right, top + k),
        ui.Offset(right, top + r),
      ),
      _LineTo(ui.Offset(right, bottom - r)),
      _CubicTo(
        ui.Offset(right, bottom - k),
        ui.Offset(right - k, bottom),
        ui.Offset(right - r, bottom),
      ),
      _LineTo(ui.Offset(left + r, bottom)),
      _CubicTo(
        ui.Offset(left + k, bottom),
        ui.Offset(left, bottom - k),
        ui.Offset(left, bottom - r),
      ),
      _LineTo(ui.Offset(left, top + r)),
      _CubicTo(
        ui.Offset(left, top + k),
        ui.Offset(left + k, top),
        ui.Offset(left + r, top),
      ),
      const _Close(),
    ];
  }

  @override
  ui.Path toPath() => ui.Path()..addRRect(rrect);
}

final class _Circle extends _Shape {
  const _Circle(super.style, this.centre, this.radius);

  final ui.Offset centre;
  final double radius;

  @override
  _Circle mapped(_Affine transform) => _Circle(
    style.scaled(transform.uniformScale),
    transform.map(centre),
    radius * transform.uniformScale,
  );

  @override
  List<_Segment> get segments {
    final double x = centre.dx;
    final double y = centre.dy;
    final double r = radius;
    final double k = r * _circleKappa;
    return <_Segment>[
      _MoveTo(ui.Offset(x + r, y)),
      _CubicTo(
        ui.Offset(x + r, y + k),
        ui.Offset(x + k, y + r),
        ui.Offset(x, y + r),
      ),
      _CubicTo(
        ui.Offset(x - k, y + r),
        ui.Offset(x - r, y + k),
        ui.Offset(x - r, y),
      ),
      _CubicTo(
        ui.Offset(x - r, y - k),
        ui.Offset(x - k, y - r),
        ui.Offset(x, y - r),
      ),
      _CubicTo(
        ui.Offset(x + k, y - r),
        ui.Offset(x + r, y - k),
        ui.Offset(x + r, y),
      ),
      const _Close(),
    ];
  }

  @override
  ui.Path toPath() =>
      ui.Path()..addOval(ui.Rect.fromCircle(center: centre, radius: radius));
}

final class _PathShape extends _Shape {
  const _PathShape(super.style, this.segments);

  @override
  final List<_Segment> segments;

  @override
  _PathShape mapped(_Affine transform) => _PathShape(
    style.scaled(transform.uniformScale),
    segments.map((_Segment segment) => segment.mapped(transform)).toList(),
  );
}

class _Frame {
  const _Frame(this.transform, this.style);

  final _Affine transform;
  final _Style style;

  _Frame child(Map<String, String> attributes) => _Frame(
    transform.times(_parseTransform(attributes['transform'])),
    style.inherit(attributes),
  );
}

class _ParseState {
  const _ParseState(this.viewBox, this.frames, this.shapes);

  final ui.Rect? viewBox;
  final List<_Frame> frames;
  final List<_Shape> shapes;
}

class _PathCursor {
  const _PathCursor(this.current, this.start, this.segments);

  final ui.Offset current;
  final ui.Offset start;
  final List<_Segment> segments;

  _PathCursor add(_Segment segment, ui.Offset end) =>
      _PathCursor(end, start, <_Segment>[...segments, segment]);
}

class _IconArt {
  const _IconArt(this.viewBox, this.tile, this.flower);

  final ui.Rect viewBox;
  final _RoundedRect tile;
  final List<_Shape> flower;

  List<_Shape> get shapes => <_Shape>[tile, ...flower];

  ui.Color get tileColour {
    final ui.Color? fill = tile.style.fill;
    if (fill == null || fill.a != 1) {
      throw StateError('The icon tile must have an opaque fill');
    }
    return fill;
  }
}

List<double> _numbers(String text) => _numberPattern
    .allMatches(text)
    .map((RegExpMatch match) => double.parse(match.group(0)!))
    .toList();

ui.Color? _parseColor(String value) {
  if (value == 'none') {
    return null;
  }
  final RegExpMatch? hex = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value);
  if (hex == null) {
    throw UnsupportedError('Unsupported colour $value');
  }
  return ui.Color(0xFF000000 | int.parse(hex.group(1)!, radix: 16));
}

_Affine _parseTransform(String? value) {
  if (value == null) {
    return _Affine.identity;
  }
  return RegExp(r'(\w+)\(([^)]*)\)')
      .allMatches(value)
      .fold(_Affine.identity, (_Affine combined, RegExpMatch operation) {
        final List<double> arguments = _numbers(operation.group(2)!);
        final _Affine step = switch (operation.group(1)) {
          'translate' => _Affine(
            1,
            1,
            arguments[0],
            arguments.length > 1 ? arguments[1] : 0,
          ),
          'scale' => _Affine(
            arguments[0],
            arguments.length > 1 ? arguments[1] : arguments[0],
            0,
            0,
          ),
          final String? other => throw UnsupportedError('transform $other'),
        };
        return combined.times(step);
      });
}

List<_Segment> _parsePathData(String data) =>
    RegExp(r'([MmLlQqCcZz])([^MmLlQqCcZz]*)').allMatches(data).fold(
      const _PathCursor(ui.Offset.zero, ui.Offset.zero, <_Segment>[]),
      (_PathCursor cursor, RegExpMatch match) {
        final String command = match.group(1)!;
        final String kind = command.toUpperCase();
        final bool relative = command != kind;
        final List<double> values = _numbers(match.group(2)!);
        if (kind == 'Z') {
          return _PathCursor(cursor.start, cursor.start, <_Segment>[
            ...cursor.segments,
            const _Close(),
          ]);
        }
        final int arity = switch (kind) {
          'M' || 'L' => 2,
          'Q' => 4,
          'C' => 6,
          _ => throw UnsupportedError('Path command $command'),
        };
        if (values.isEmpty || values.length % arity != 0) {
          throw FormatException('Path command $command', data);
        }
        return List<List<double>>.generate(
          values.length ~/ arity,
          (int index) => values.sublist(index * arity, (index + 1) * arity),
        ).indexed.fold(cursor, (_PathCursor inner, (int, List<double>) entry) {
          final (int index, List<double> group) = entry;
          final ui.Offset origin = relative ? inner.current : ui.Offset.zero;
          ui.Offset point(int at) =>
              origin + ui.Offset(group[at], group[at + 1]);
          return switch (kind) {
            'M' when index == 0 => _PathCursor(point(0), point(0), <_Segment>[
              ...inner.segments,
              _MoveTo(point(0)),
            ]),
            'M' || 'L' => inner.add(_LineTo(point(0)), point(0)),
            'Q' => inner.add(_QuadTo(point(0), point(2)), point(2)),
            _ => inner.add(_CubicTo(point(0), point(2), point(4)), point(4)),
          };
        });
      },
    ).segments;

Map<String, String> _attributesOf(String element, String source) {
  final Map<String, String> attributes = <String, String>{
    for (final RegExpMatch match in RegExp(
      r'([\w:-]+)="([^"]*)"',
    ).allMatches(source))
      match.group(1)!: match.group(2)!,
  };
  final Set<String> allowed = <String>{
    ..._elementAttributes[element]!,
    ..._styleAttributes,
  };
  final Iterable<String> unknown = attributes.keys.where(
    (String name) => !allowed.contains(name),
  );
  if (unknown.isNotEmpty) {
    throw UnsupportedError('<$element> attributes ${unknown.join(', ')}');
  }
  return attributes;
}

double _attribute(Map<String, String> attributes, String name) =>
    double.parse(attributes[name] ?? '0');

_Shape _shapeOf(String element, Map<String, String> attributes, _Frame frame) {
  final _Style style = frame.style;
  final _Shape local = switch (element) {
    'rect' => _RoundedRect(
      style,
      ui.Rect.fromLTWH(
        _attribute(attributes, 'x'),
        _attribute(attributes, 'y'),
        _attribute(attributes, 'width'),
        _attribute(attributes, 'height'),
      ),
      _attribute(attributes, 'rx'),
    ),
    'circle' => _Circle(
      style,
      ui.Offset(_attribute(attributes, 'cx'), _attribute(attributes, 'cy')),
      _attribute(attributes, 'r'),
    ),
    _ => _PathShape(style, _parsePathData(attributes['d'] ?? '')),
  };
  return local.mapped(frame.transform);
}

_IconArt _parseSvg(String source) {
  final String markup = source.replaceAll(
    RegExp(r'<metadata>.*?</metadata>', dotAll: true),
    '',
  );
  final _ParseState parsed = RegExp(r'<(/?)([a-zA-Z]+)([^>]*?)(/?)>')
      .allMatches(markup)
      .fold(const _ParseState(null, <_Frame>[], <_Shape>[]), (
        _ParseState state,
        RegExpMatch tag,
      ) {
        final bool closing = tag.group(1)!.isNotEmpty;
        final bool selfClosing = tag.group(4)!.isNotEmpty;
        final String element = tag.group(2)!;
        if (!_elementAttributes.containsKey(element)) {
          throw UnsupportedError('<$element>');
        }
        if (closing) {
          return element == 'svg' || element == 'g'
              ? _ParseState(
                  state.viewBox,
                  state.frames.sublist(0, state.frames.length - 1),
                  state.shapes,
                )
              : state;
        }
        final Map<String, String> attributes = _attributesOf(
          element,
          tag.group(3)!,
        );
        switch (element) {
          case 'svg':
            final List<double> box = _numbers(attributes['viewBox'] ?? '');
            return _ParseState(
              ui.Rect.fromLTWH(box[0], box[1], box[2], box[3]),
              <_Frame>[
                ...state.frames,
                const _Frame(
                  _Affine.identity,
                  _Style.initial,
                ).child(attributes),
              ],
              state.shapes,
            );
          case 'g':
            return selfClosing
                ? state
                : _ParseState(state.viewBox, <_Frame>[
                    ...state.frames,
                    state.frames.last.child(attributes),
                  ], state.shapes);
          default:
            return _ParseState(state.viewBox, state.frames, <_Shape>[
              ...state.shapes,
              _shapeOf(
                element,
                attributes,
                state.frames.last.child(attributes),
              ),
            ]);
        }
      });
  final ui.Rect? viewBox = parsed.viewBox;
  if (viewBox == null || parsed.shapes.isEmpty) {
    throw StateError('$_svgPath holds no drawable icon');
  }
  final _Shape first = parsed.shapes.first;
  if (first is! _RoundedRect || first.rect != viewBox) {
    throw StateError('$_svgPath must start with a tile filling its viewBox');
  }
  return _IconArt(viewBox, first, parsed.shapes.sublist(1));
}

List<_Shape> _place(List<_Shape> shapes, _Affine transform) =>
    shapes.map((_Shape shape) => shape.mapped(transform)).toList();

_Affine _fit(ui.Rect viewBox, double size, double inset) {
  final double scale = size / viewBox.width;
  return _Affine(
    scale,
    scale,
    inset - viewBox.left * scale,
    inset - viewBox.top * scale,
  );
}

void _paint(ui.Canvas canvas, List<_Shape> shapes) {
  for (final _Shape shape in shapes) {
    final ui.Path path = shape.toPath();
    final ui.Color? fill = shape.style.fill;
    final ui.Color? stroke = shape.style.stroke;
    if (fill != null) {
      canvas.drawPath(path, ui.Paint()..color = fill);
    }
    if (stroke != null && shape.style.strokeWidth > 0) {
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = stroke
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = shape.style.strokeWidth
          ..strokeJoin = shape.style.strokeJoin,
      );
    }
  }
}

Future<Uint8List> _renderPng(
  int size,
  void Function(ui.Canvas canvas) draw,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(size, size);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (png == null) {
    throw StateError('PNG encoding failed at $size pixels');
  }
  return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

Future<Uint8List> _renderAppleIcon(_IconArt art, int size) {
  final double unit = size / _appleCanvas;
  final double body = _appleBody * unit;
  final _Affine placement = _fit(art.viewBox, body, (size - body) / 2);
  final _RoundedRect shadow = art.tile
      .mapped(placement)
      .mapped(_Affine(1, 1, 0, _appleShadowOffset * unit));
  return _renderPng(size, (ui.Canvas canvas) {
    canvas.drawRRect(
      shadow.rrect,
      ui.Paint()
        ..color = const ui.Color.fromARGB(_appleShadowAlpha, 0, 0, 0)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          _appleShadowBlur / 2 * unit,
        ),
    );
    _paint(canvas, _place(art.shapes, placement));
  });
}

Future<Uint8List> _renderLegacyLauncher(_IconArt art, int size) => _renderPng(
  size,
  (ui.Canvas canvas) =>
      _paint(canvas, _place(art.shapes, _fit(art.viewBox, size.toDouble(), 0))),
);

String _format(double value) {
  final String trimmed = value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}

String _point(ui.Offset point) => '${_format(point.dx)},${_format(point.dy)}';

String _hex(ui.Color colour) =>
    '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _pathData(_Shape shape) => shape.segments
    .map(
      (_Segment segment) => switch (segment) {
        _MoveTo(:final ui.Offset point) => 'M${_point(point)}',
        _LineTo(:final ui.Offset point) => 'L${_point(point)}',
        _QuadTo(:final ui.Offset control, :final ui.Offset end) =>
          'Q${_point(control)} ${_point(end)}',
        _CubicTo(
          :final ui.Offset first,
          :final ui.Offset second,
          :final ui.Offset end,
        ) =>
          'C${_point(first)} ${_point(second)} ${_point(end)}',
        _Close() => 'Z',
      },
    )
    .join(' ');

String _vectorPath(_Shape shape) {
  final ui.Color? fill = shape.style.fill;
  final ui.Color? stroke = shape.style.stroke;
  final List<String> attributes = <String>[
    if (fill != null) 'android:fillColor="${_hex(fill)}"',
    if (stroke != null) ...<String>[
      'android:strokeColor="${_hex(stroke)}"',
      'android:strokeWidth="${_format(shape.style.strokeWidth)}"',
      if (shape.style.strokeJoin != ui.StrokeJoin.miter)
        'android:strokeLineJoin="${shape.style.strokeJoin.name}"',
    ],
    'android:pathData="${_pathData(shape)}"',
  ];
  return '    <path\n${attributes.map((String line) => '        $line').join('\n')} />\n';
}

String _adaptiveForeground(_IconArt art) {
  final double canvas = _adaptiveCanvas;
  final List<_Shape> flower = _place(
    art.flower,
    _fit(art.viewBox, _adaptiveViewport, (canvas - _adaptiveViewport) / 2),
  );
  final ui.Rect safeZone = ui.Rect.fromLTRB(
    _adaptiveSafeMin,
    _adaptiveSafeMin,
    _adaptiveSafeMax,
    _adaptiveSafeMax,
  );
  for (final _Shape shape in flower) {
    final ui.Rect bounds = shape.paintedBounds;
    if (safeZone.expandToInclude(bounds) != safeZone) {
      throw StateError('The foreground leaves the safe zone at $bounds');
    }
  }
  final String size = _format(canvas);
  return '<?xml version="1.0" encoding="utf-8"?>\n'
      '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
      '    android:width="${size}dp"\n'
      '    android:height="${size}dp"\n'
      '    android:viewportWidth="$size"\n'
      '    android:viewportHeight="$size">\n'
      '${flower.map(_vectorPath).join()}'
      '</vector>\n';
}

String _adaptiveBackground(_IconArt art) =>
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="ic_launcher_background">${_hex(art.tileColour)}</color>\n'
    '</resources>\n';

const String _adaptiveIcon =
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background" />\n'
    '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
    '</adaptive-icon>\n';

void _writeBytes(String path, List<int> bytes) {
  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

void _writeText(String path, String text) {
  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(text);
}

void main() {
  test('renders the app icons from $_svgPath', () async {
    final _IconArt art = _parseSvg(File(_svgPath).readAsStringSync());
    for (final int size in _macSizes) {
      _writeBytes(
        '$_macIconSet/app_icon_$size.png',
        await _renderAppleIcon(art, size),
      );
    }
    for (final MapEntry<String, int> density in _legacyLauncherSizes.entries) {
      _writeBytes(
        '$_androidRes/mipmap-${density.key}/ic_launcher.png',
        await _renderLegacyLauncher(art, density.value),
      );
    }
    _writeText('$_androidRes/mipmap-anydpi-v26/ic_launcher.xml', _adaptiveIcon);
    _writeText(
      '$_androidRes/values/ic_launcher_background.xml',
      _adaptiveBackground(art),
    );
    _writeText(
      '$_androidRes/drawable/ic_launcher_foreground.xml',
      _adaptiveForeground(art),
    );
  });
}
