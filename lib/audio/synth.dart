import 'dart:math';
import 'dart:typed_data';

/// Tiny 16-bit mono WAV builder. Used so the game ships without audio files.
Uint8List synthWav({
  required double seconds,
  required double Function(double t) sample,
  int sampleRate = 22050,
}) {
  final count = max(1, (seconds * sampleRate).round());
  final bytes = BytesBuilder(copy: false);
  const channels = 1;
  const bits = 16;
  final dataSize = count * channels * (bits ~/ 8);
  bytes.add(_ascii('RIFF'));
  bytes.add(_le32(36 + dataSize));
  bytes.add(_ascii('WAVE'));
  bytes.add(_ascii('fmt '));
  bytes.add(_le32(16));
  bytes.add(_le16(1));
  bytes.add(_le16(channels));
  bytes.add(_le32(sampleRate));
  bytes.add(_le32(sampleRate * channels * (bits ~/ 8)));
  bytes.add(_le16(channels * (bits ~/ 8)));
  bytes.add(_le16(bits));
  bytes.add(_ascii('data'));
  bytes.add(_le32(dataSize));
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    final v = sample(t).clamp(-1.0, 1.0);
    final s = (v * 32767).round().clamp(-32768, 32767);
    bytes.add(_le16(s));
  }
  return bytes.toBytes();
}

Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);

Uint8List _le16(int v) =>
    Uint8List.fromList([v & 0xff, (v >> 8) & 0xff]);

Uint8List _le32(int v) => Uint8List.fromList([
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
]);

double _env(double t, double dur, {double attack = 0.01}) {
  if (t < attack) return t / attack;
  final tail = ((dur - t) / dur).clamp(0.0, 1.0);
  return tail * tail;
}

Uint8List sfxHit() => synthWav(
  seconds: 0.12,
  sample: (t) =>
      (sin(2 * pi * 180 * t) * 0.45 + sin(2 * pi * 720 * t) * 0.18) *
      _env(t, 0.12),
);

Uint8List sfxCrit() => synthWav(
  seconds: 0.18,
  sample: (t) =>
      (sin(2 * pi * 520 * t) * 0.35 +
          sin(2 * pi * 780 * t) * 0.28 +
          sin(2 * pi * 1040 * t) * 0.16) *
      _env(t, 0.18, attack: 0.005),
);

Uint8List sfxDeath() => synthWav(
  seconds: 0.32,
  sample: (t) {
    final freq = 240 - t * 280;
    return sin(2 * pi * freq * t) * 0.4 * _env(t, 0.32, attack: 0.02);
  },
);

Uint8List sfxGold() => synthWav(
  seconds: 0.16,
  sample: (t) =>
      sin(2 * pi * (1180 + t * 220) * t) * 0.32 * _env(t, 0.16, attack: 0.004),
);

Uint8List sfxCraft() => synthWav(
  seconds: 0.2,
  sample: (t) =>
      (sin(2 * pi * 210 * t) * 0.4 + (Random(4).nextDouble() * 2 - 1) * 0.08) *
      _env(t, 0.2, attack: 0.002),
);

Uint8List sfxClick() => synthWav(
  seconds: 0.05,
  sample: (t) => sin(2 * pi * 1480 * t) * 0.22 * _env(t, 0.05, attack: 0.002),
);

Uint8List sfxSkill() => synthWav(
  seconds: 0.22,
  sample: (t) =>
      sin(2 * pi * (380 + t * 900) * t) * 0.34 * _env(t, 0.22, attack: 0.01),
);

Uint8List bgmLoop({
  required double root,
  required double fifth,
  double drone = 0.12,
}) => synthWav(
  seconds: 4,
  sample: (t) {
    final a = sin(2 * pi * root * t);
    final b = sin(2 * pi * fifth * t);
    final shimmer = sin(2 * pi * root * 2 * t + sin(t * 0.7));
    return (a * 0.55 + b * 0.28 + shimmer * 0.12) * drone;
  },
);
