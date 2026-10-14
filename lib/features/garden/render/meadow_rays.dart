import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

const double meadowRaysReach = 547.2;
const double meadowRaysScale = 0.5;

const double _raysInner = 120;
const double _raysOuter = meadowRaysReach;
const double _raysGlowRadius = 294;
const int _raysSegments = 120;
const int _bytesPerPixel = 4;
const Color _white = Color(0xFFFFFFFF);

class MeadowRays {
  MeadowRays(MeadowPalette palette)
    : _sunColour = palette.sunColour,
      _glowAlpha = palette.raysGlowAlpha;

  static final int _side = (2 * meadowRaysReach * meadowRaysScale).ceil();

  ui.Image? _beamsMask;
  ui.Image? _glowMask;
  ui.Image? _image;
  Color _sunColour;
  double _glowAlpha;
  Color? _shownSunColour;
  double? _shownGlowAlpha;
  bool _stale = false;
  bool _disposed = false;
  int _revision = 0;
  int _geometryRecordings = 0;

  ui.Image get image => _image!;

  bool get isReady => !_disposed && _image != null;

  bool get isRecolouring => !_disposed && _stale;

  int get revision => _revision;

  int get imageBytes =>
      <ui.Image?>[_beamsMask, _glowMask, _image].nonNulls.fold<int>(
        0,
        (int total, ui.Image image) =>
            total + image.width * image.height * _bytesPerPixel,
      );

  @visibleForTesting
  int get debugGeometryRecordings => _geometryRecordings;

  bool step() {
    if (_disposed) {
      return false;
    }
    final ui.Image? beams = _beamsMask;
    final ui.Image? glow = _glowMask;
    final ui.Image? shown = _image;
    if (beams == null) {
      _beamsMask = _record(_paintBeams);
    } else if (glow == null) {
      _glowMask = _record(_paintGlow);
    } else if (shown == null) {
      _image = _composite(beams, glow);
      _noteShown();
    } else if (_stale) {
      _image = _composite(beams, glow);
      _noteShown();
      _stale = false;
      _revision++;
      shown.dispose();
    }
    return !isReady || isRecolouring;
  }

  void buildAll() {
    while (step()) {}
  }

  void recolour(MeadowPalette palette) {
    if (_disposed) {
      return;
    }
    _sunColour = palette.sunColour;
    _glowAlpha = palette.raysGlowAlpha;
    if (_image != null) {
      _stale = _sunColour != _shownSunColour || _glowAlpha != _shownGlowAlpha;
    }
  }

  void _noteShown() {
    _shownSunColour = _sunColour;
    _shownGlowAlpha = _glowAlpha;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _beamsMask?.dispose();
    _glowMask?.dispose();
    _image?.dispose();
    _beamsMask = null;
    _glowMask = null;
    _image = null;
    _stale = false;
  }

  ui.Image _record(void Function(Canvas canvas) paint) {
    _geometryRecordings++;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, _bounds)
      ..translate(_side / 2, _side / 2)
      ..scale(meadowRaysScale);
    paint(canvas);
    return _rasterise(recorder);
  }

  ui.Image _composite(ui.Image beams, ui.Image glow) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder, _bounds)
      ..drawImage(
        beams,
        Offset.zero,
        Paint()..colorFilter = ColorFilter.mode(_sunColour, BlendMode.srcIn),
      )
      ..drawImage(
        glow,
        Offset.zero,
        Paint()
          ..colorFilter = ColorFilter.mode(
            _sunColour.withValues(alpha: _sunColour.a * _glowAlpha),
            BlendMode.srcIn,
          ),
      );
    return _rasterise(recorder);
  }

  static Rect get _bounds =>
      Rect.fromLTWH(0, 0, _side.toDouble(), _side.toDouble());

  static ui.Image _rasterise(ui.PictureRecorder recorder) {
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = meadowSnapshot(picture, _side, _side);
    picture.dispose();
    return image;
  }
}

void _paintBeams(Canvas canvas) {
  canvas
    ..rotate(-math.pi / 2)
    ..drawVertices(
      _raysMesh,
      BlendMode.modulate,
      Paint()..shader = _beamsGradient(_white),
    );
}

void _paintGlow(Canvas canvas) {
  canvas.drawCircle(
    Offset.zero,
    _raysGlowRadius,
    Paint()..shader = _raysGlowGradient(_white, 1),
  );
}

double _raysMask(double radius) => radius <= _raysInner
    ? radius / _raysInner
    : math.max(0.0, (_raysOuter - radius) / (_raysOuter - _raysInner));

final ui.Vertices _raysMesh = _buildRaysMesh();

ui.Vertices _buildRaysMesh() {
  final List<Offset> positions = <Offset>[Offset.zero];
  final List<Color> colours = <Color>[const Color(0x00FFFFFF)];
  for (final (double radius, Color colour) in <(double, Color)>[
    (_raysInner, const Color(0xFFFFFFFF)),
    (_raysOuter, const Color(0x00FFFFFF)),
  ]) {
    for (int i = 0; i < _raysSegments; i++) {
      final double angle = i / _raysSegments * math.pi * 2;
      positions.add(Offset(math.cos(angle), math.sin(angle)) * radius);
      colours.add(colour);
    }
  }
  final List<int> indices = <int>[];
  for (int i = 0; i < _raysSegments; i++) {
    final int next = (i + 1) % _raysSegments;
    final int inner = 1 + i;
    final int innerNext = 1 + next;
    final int outer = 1 + _raysSegments + i;
    final int outerNext = 1 + _raysSegments + next;
    indices.addAll(<int>[
      0,
      inner,
      innerNext,
      inner,
      outer,
      innerNext,
      innerNext,
      outer,
      outerNext,
    ]);
  }
  return ui.Vertices(
    VertexMode.triangles,
    positions,
    colors: colours,
    indices: indices,
  );
}

double _conic(double degrees, double from, List<(double, double)> stops) {
  final double period = stops.last.$1;
  final double local = (degrees - from) % period;
  for (int i = 0; i < stops.length - 1; i++) {
    final (double at, double alpha) = stops[i];
    final (double next, double nextAlpha) = stops[i + 1];
    if (local <= next) {
      return alpha + (nextAlpha - alpha) * (local - at) / (next - at);
    }
  }
  return stops.last.$2;
}

const List<(double, double)> _beamStops = <(double, double)>[
  (0, 0),
  (3, 0.16),
  (6.5, 0),
  (17, 0),
];
const double _beamFrom = 3;
const List<(double, double)> _fineBeamStops = <(double, double)>[
  (0, 0),
  (4, 0.12),
  (9, 0),
  (23, 0),
];

double _beamAlpha(double degrees) {
  final double wide = _conic(degrees, _beamFrom, _beamStops);
  final double fine = _conic(degrees, 0, _fineBeamStops);
  return 1 - (1 - wide) * (1 - fine);
}

List<double> _beamAngles() {
  final Set<double> breaks = <double>{0, 360};
  for (double at = _beamFrom - 17; at < 360; at += 17) {
    for (final (double offset, double _) in _beamStops) {
      breaks.add(at + offset);
    }
  }
  for (double at = 0; at < 360; at += 23) {
    for (final (double offset, double _) in _fineBeamStops) {
      breaks.add(at + offset);
    }
  }
  final List<double> sorted =
      breaks.where((double at) => at >= 0 && at <= 360).toList()..sort();
  return <double>[
    for (int i = 0; i < sorted.length; i++) ...<double>[
      sorted[i],
      if (i + 1 < sorted.length) (sorted[i] + sorted[i + 1]) / 2,
    ],
  ];
}

final List<double> _beamSamples = _beamAngles();

ui.Gradient _beamsGradient(Color colour) => ui.Gradient.sweep(
  Offset.zero,
  <Color>[
    for (final double at in _beamSamples)
      colour.withValues(alpha: _beamAlpha(at)),
  ],
  <double>[for (final double at in _beamSamples) at / 360],
);

ui.Gradient _raysGlowGradient(Color colour, double alpha) {
  final List<double> radii = <double>[
    for (double radius = 0; radius < _raysGlowRadius; radius += 14) radius,
    _raysGlowRadius,
  ];
  return ui.Gradient.radial(
    Offset.zero,
    _raysGlowRadius,
    <Color>[
      for (final double radius in radii)
        colour.withValues(
          alpha: alpha * (1 - radius / _raysGlowRadius) * _raysMask(radius),
        ),
    ],
    <double>[for (final double radius in radii) radius / _raysGlowRadius],
  );
}
