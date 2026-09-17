import 'dart:math' as math;

/// The empty world bible's picture, as numbers: a ridged horizon under a moon.
/// A port of the desktop's `useNightscape`, draw order and random draws
/// included, so seed 41022 is the same land on the phone as on the desk.
///
/// Generated rather than shipped, because the point of the panel is that this
/// world has no shape yet — a stock illustration would be someone else's
/// world, and the same one for every author.
class NightscapeScene {
  NightscapeScene._(this.width, this.height, this.ridges, this.moon, this.stars);

  final double width;
  final double height;
  final List<Ridge> ridges;
  final ({double x, double y, double r}) moon;
  final List<({double x, double y, double r, double phase})> stars;

  static const int _layers = 5;
  static const int _stars = 46;

  factory NightscapeScene.build(int seed, double width, double height) {
    final rand = _random(seed);
    // Nearer ranges are taller, paler and slide faster — parallax is the whole
    // reason five flat curves read as distance.
    final ridges = [
      for (var i = 0; i < _layers; i++)
        Ridge(
          at: _ridgeline(rand, 3 + i * 2),
          amp: height * (0.1 + 0.055 * i),
          base: height * (0.44 + 0.13 * i),
          speed: 0.9 + i * 2.6,
          period: width * (1.9 - i * 0.22),
          tint: 0.42 - i * 0.105,
        ),
    ];
    final moon = (x: 0.18 + rand() * 0.64, y: 0.16 + rand() * 0.16, r: 30 + rand() * 26);
    final stars = [
      for (var i = 0; i < _stars; i++)
        (x: rand(), y: rand() * 0.5, r: 0.4 + rand() * 0.9, phase: rand() * math.pi * 2),
    ];
    return NightscapeScene._(width, height, ridges, moon, stars);
  }
}

class Ridge {
  const Ridge({
    required this.at,
    required this.amp,
    required this.base,
    required this.speed,
    required this.period,
    required this.tint,
  });
  final double Function(double u) at;
  final double amp;
  final double base;
  final double speed;
  final double period;
  final double tint;
}

/// The plate under the picture. A land is nothing but its number, which is
/// the joke: the author has not named anything yet.
String nightscapeLabel(int seed) => 'No. ${seed.toString().padLeft(5, '0')}';

/// xorshift32, bit for bit the desktop's — including JS's `>>`, which reads
/// the state as a signed 32-bit int.
double Function() _random(int seed) {
  var state = seed & 0xFFFFFFFF;
  if (state == 0) state = 1;
  return () {
    state = (state ^ (state << 13)) & 0xFFFFFFFF;
    state = (state ^ (state.toSigned(32) >> 17)) & 0xFFFFFFFF;
    state = (state ^ (state << 5)) & 0xFFFFFFFF;
    return state / 4294967296;
  };
}

/// One periodic octave: `points` control points, cosine-interpolated.
/// Periodic is what lets a ridge drift forever without a seam coming round.
double Function(double u) _octave(double Function() rand, int points) {
  final heights = List.generate(points, (_) => rand());
  return (u) {
    final x = (((u % 1) + 1) % 1) * points;
    final i = x.floor();
    final f = x - i;
    final a = heights[i % points];
    final b = heights[(i + 1) % points];
    final smooth = (1 - math.cos(f * math.pi)) / 2;
    return a * (1 - smooth) + b * smooth;
  };
}

/// Three octaves of falling amplitude — the shape of a skyline rather than
/// the shape of a sine.
double Function(double u) _ridgeline(double Function() rand, int points) {
  final coarse = _octave(rand, points);
  final mid = _octave(rand, points * 2);
  final fine = _octave(rand, points * 4);
  return (u) => coarse(u) * 0.6 + mid(u) * 0.28 + fine(u) * 0.12;
}
