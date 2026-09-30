const int _mask32 = 0xFFFFFFFF;
const int _mask16 = 0xFFFF;
const int _increment = 0x6D2B79F5;
const int _golden = 0x9E3779B1;
const double _range32 = 4294967296;

int _imul(int a, int b) {
  final int aHigh = (a >> 16) & _mask16;
  final int aLow = a & _mask16;
  final int bHigh = (b >> 16) & _mask16;
  final int bLow = b & _mask16;
  final int cross = ((aHigh * bLow + aLow * bHigh) & _mask16) << 16;
  return (aLow * bLow + cross) & _mask32;
}

int _finalise(int value) {
  int h = value & _mask32;
  h ^= h >> 16;
  h = _imul(h, 0x85EBCA6B);
  h ^= h >> 13;
  h = _imul(h, 0xC2B2AE35);
  h ^= h >> 16;
  return h;
}

int _combine(int a, int b) =>
    _finalise((a & _mask32) ^ _imul(b & _mask32, _golden));

class MeadowRandom {
  MeadowRandom(int seed) : _state = seed & _mask32;

  int _state;

  double next() {
    _state = (_state + _increment) & _mask32;
    final int s = _state;
    int t = _imul(s ^ (s >> 15), 1 | s);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & _mask32) ^ t;
    return (t ^ (t >> 14)) / _range32;
  }

  double between(double a, double b) => a + (b - a) * next();

  int nextInt(int n) => (next() * n).floor();
}

enum MeadowPart {
  terrain(0x243F6A88),
  plants(0x85A308D3),
  drifts(0x13198A2E),
  grass(0x03707344),
  ambience(0xA4093822);

  const MeadowPart(this.salt);

  final int salt;
}

int meadowSeed(int key, int year) => _combine(key, year);

int meadowPartSeed(int seed, MeadowPart part) =>
    _finalise((seed & _mask32) ^ part.salt);

int meadowItemSeed(int partSeed, int index) => _combine(partSeed, index + 1);
