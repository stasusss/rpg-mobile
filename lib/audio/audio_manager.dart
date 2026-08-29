import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../models/location.dart';
import 'synth.dart';

enum SfxKind { hit, crit, death, gold, craft, click, skill }

/// Process-wide mixer. Volumes are pushed from [settingsProvider].
///
/// Playback is best-effort: a missing plugin or a test VM must not crash the
/// simulation. Set [enabled] to false in unit tests so [AudioPlayer] is never
/// constructed (it requires a Flutter binding).
class AudioManager {
  AudioManager._();

  static final AudioManager instance = AudioManager._();

  static bool enabled = true;

  double sfxVolume = 0.75;
  double bgmVolume = 0.4;

  AudioPlayer? _sfx;
  AudioPlayer? _bgmA;
  AudioPlayer? _bgmB;
  bool _usingA = true;
  BiomeMood? _mood;
  bool _ready = false;

  final Map<SfxKind, Uint8List> _sfxCache = {};
  final Map<BiomeMood, Uint8List> _bgmCache = {};

  Future<void> ensureStarted() async {
    if (!enabled || _ready) return;
    try {
      _sfx = AudioPlayer();
      _bgmA = AudioPlayer();
      _bgmB = AudioPlayer();
      await _sfx!.setPlayerMode(PlayerMode.lowLatency);
      await _bgmA!.setReleaseMode(ReleaseMode.loop);
      await _bgmB!.setReleaseMode(ReleaseMode.loop);
      _ready = true;
    } catch (_) {
      enabled = false;
    }
  }

  void applyVolumes({required double sfx, required double bgm}) {
    sfxVolume = sfx.clamp(0.0, 1.0);
    bgmVolume = bgm.clamp(0.0, 1.0);
    if (!enabled || !_ready) return;
    final active = _usingA ? _bgmA : _bgmB;
    if (active != null) unawaited(active.setVolume(bgmVolume));
  }

  Future<void> play(SfxKind kind) async {
    if (!enabled || sfxVolume <= 0.01) return;
    try {
      await ensureStarted();
      if (!enabled || _sfx == null) return;
      final bytes = _sfxCache.putIfAbsent(kind, () => _buildSfx(kind));
      await _sfx!.stop();
      await _sfx!.setVolume(sfxVolume);
      await _sfx!.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Audio is cosmetic.
    }
  }

  Future<void> setBiome(BiomeMood mood) async {
    if (!enabled || mood == _mood) return;
    _mood = mood;
    if (bgmVolume <= 0.01) {
      await _stopBoth();
      return;
    }
    try {
      await ensureStarted();
      if (!enabled || _bgmA == null || _bgmB == null) return;
      final incoming = _usingA ? _bgmB! : _bgmA!;
      final outgoing = _usingA ? _bgmA! : _bgmB!;
      final bytes = _bgmCache.putIfAbsent(mood, () => _buildBgm(mood));
      await incoming.stop();
      await incoming.setVolume(0);
      await incoming.play(BytesSource(bytes, mimeType: 'audio/wav'));
      await incoming.setVolume(bgmVolume);
      await outgoing.setVolume(0);
      await outgoing.stop();
      _usingA = !_usingA;
    } catch (_) {
      // Keep the simulation running if the mixer fails.
    }
  }

  Future<void> _stopBoth() async {
    try {
      await _bgmA?.stop();
      await _bgmB?.stop();
    } catch (_) {}
  }

  static Uint8List _buildSfx(SfxKind kind) => switch (kind) {
    SfxKind.hit => sfxHit(),
    SfxKind.crit => sfxCrit(),
    SfxKind.death => sfxDeath(),
    SfxKind.gold => sfxGold(),
    SfxKind.craft => sfxCraft(),
    SfxKind.click => sfxClick(),
    SfxKind.skill => sfxSkill(),
  };

  static Uint8List _buildBgm(BiomeMood mood) => switch (mood) {
    BiomeMood.ash => bgmLoop(root: 98, fifth: 147, drone: 0.14),
    BiomeMood.underground ||
    BiomeMood.night => bgmLoop(root: 73, fifth: 110, drone: 0.11),
    BiomeMood.dusk => bgmLoop(root: 87, fifth: 130, drone: 0.12),
    BiomeMood.day => bgmLoop(root: 110, fifth: 165, drone: 0.10),
  };
}
