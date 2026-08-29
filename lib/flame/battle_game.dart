import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/combat_event.dart';
import '../models/enemy.dart';
import '../models/location.dart';
import '../providers/combat_provider.dart';
import 'character_sprites.dart';
import 'fx.dart';
import 'parallax_background.dart';

/// Everything the renderer needs for one frame, pushed from Riverpod.
///
/// The game never reads providers itself: keeping the data flow one-way means
/// the simulation stays testable without a running engine.
@immutable
class BattleSnapshot {
  const BattleSnapshot({
    required this.phase,
    required this.location,
    required this.enemy,
    required this.approach,
    required this.playerHpFraction,
    required this.playerLook,
    required this.showDamageNumbers,
    required this.labels,
  });

  final CombatPhase phase;
  final LocationDef location;
  final EnemyInstance? enemy;
  final double approach;
  final double playerHpFraction;
  final PlayerLook playerLook;
  final bool showDamageNumbers;
  final CombatFxLabels labels;
}

/// The side-on auto-battler viewport.
class BattleGame extends FlameGame {
  BattleGame({
    required this.initialLocation,
    required this.snapshot,
    required this.eventBus,
  });

  /// Only used for the very first frame; later changes arrive by snapshot.
  final LocationDef initialLocation;

  /// Drained once per frame; the simulation is the only producer.
  final CombatEventBus eventBus;

  /// Latest state pushed from the provider layer.
  BattleSnapshot snapshot;

  late final ParallaxBackground _background;
  late final FogOverlay _fog;
  late final PlayerComponent _player;
  Component? _ambient;
  BiomeMood? _ambientMood;
  double _shakeTime = 0;
  double _shakeAmp = 0;
  Vector2 _shake = Vector2.zero();

  EnemyComponent? _enemy;
  int? _enemySpawnId;
  double _enemyTargetX = 0;
  double _dustTimer = 0;

  /// Fraction of the viewport height a normal actor occupies.
  static const double _actorHeightFactor = 0.44;

  double get _groundY => size.y * 0.90;
  double get _playerX => size.x * 0.26;
  double get _meleeX => size.x * 0.56;
  double get _spawnX => size.x * 1.18;
  double get _actorHeight => size.y * _actorHeightFactor;

  @override
  Color backgroundColor() => initialLocation.palette.skyBottom;

  @override
  Future<void> onLoad() async {
    _background = ParallaxBackground(initialLocation: initialLocation);
    _fog = FogOverlay(color: initialLocation.palette.fog);
    _player = PlayerComponent(height: _actorHeight)
      ..position = Vector2(_playerX, _groundY)
      ..priority = 30;

    await addAll([_background, _fog, Vignette(), _player]);
    _syncAmbient(snapshot.location);
    // Catch up on anything pushed while the layers were rasterising.
    applySnapshot(snapshot);
  }

  void _syncAmbient(LocationDef location) {
    final mood = location.palette.mood;
    if (mood == _ambientMood) return;
    _ambientMood = mood;
    _ambient?.removeFromParent();
    _ambient = null;
    final next = switch (mood) {
      BiomeMood.ash => EmberField(),
      BiomeMood.night || BiomeMood.underground => MoteField(kind: MoteKind.fog),
      BiomeMood.dusk => MoteField(kind: MoteKind.dust),
      BiomeMood.day => null,
    };
    if (next != null) {
      _ambient = next;
      add(next);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    _player
      ..size = Vector2(_actorHeight * 0.72, _actorHeight)
      ..position = Vector2(_playerX, _groundY);
    _resizeEnemy();
  }

  // ------------------------------------------------------- provider -> world

  /// Pushes new simulation state. Cheap enough to call every state change.
  void applySnapshot(BattleSnapshot next) {
    snapshot = next;
    // Snapshots can arrive before onLoad finishes; the last one wins.
    if (!isLoaded) return;

    _background.applyLocation(next.location);
    _fog.color = next.location.palette.fog;
    _syncAmbient(next.location);

    final enemy = next.enemy;
    if (enemy == null) {
      // Location change or a kill: let any surviving sprite bow out.
      final existing = _enemy;
      if (existing != null && !existing.isDying) existing.die();
      _enemy = null;
      _enemySpawnId = null;
    } else if (enemy.spawnId != _enemySpawnId) {
      _spawnEnemyComponent(enemy);
    }

    _enemy?.healthFraction = enemy?.hpFraction;

    _player
      ..look = next.playerLook
      ..healthFraction = next.playerHpFraction
      ..downed = next.phase == CombatPhase.playerDown;

    final traveling = next.phase == CombatPhase.traveling;
    _background.running = traveling;
    _player.isRunning = traveling;
    _enemy?.isRunning = traveling;

    _enemyTargetX = traveling
        ? _meleeX + (_spawnX - _meleeX) * next.approach.clamp(0.0, 1.0)
        : _meleeX;
  }

  void _spawnEnemyComponent(EnemyInstance enemy) {
    final existing = _enemy;
    if (existing != null && !existing.isDying) existing.die();

    _enemySpawnId = enemy.spawnId;
    final height = _actorHeight * enemy.def.visual.scale;
    final component = EnemyComponent(visual: enemy.def.visual, height: height)
      ..position = Vector2(_spawnX, _groundY)
      ..healthFraction = enemy.hpFraction
      ..priority = enemy.def.isBoss ? 28 : 26;
    _enemy = component;
    _enemyTargetX = _spawnX;
    add(component);
  }

  void _resizeEnemy() {
    final component = _enemy;
    final enemy = snapshot.enemy;
    if (component == null || enemy == null) return;
    final height = _actorHeight * enemy.def.visual.scale;
    component
      ..size = Vector2(height * 0.72, height)
      ..position = Vector2(component.position.x, _groundY);
  }

  /// Turns simulation events into one-shot visuals.
  void _consumeEvents(List<CombatEvent> events) {
    for (final event in events) {
      switch (event.type) {
        case CombatEventType.damage:
          _onDamage(event);
        case CombatEventType.dodge:
          _onDodge(event);
        case CombatEventType.heal:
          _floating(
            _playerHeadPosition(),
            '+${event.amount.round()}',
            const Color(0xFF6FE07C),
            fontSize: _textUnit,
          );
        case CombatEventType.death:
          _onDeath(event);
        case CombatEventType.spawn:
          break;
        case CombatEventType.levelUp:
          add(
            ImpactBurst(
              position: _playerCenter(),
              color: const Color(0xFFFFD54F),
              radius: size.y * 0.22,
              shards: 12,
              lifetime: 0.8,
            ),
          );
          _floating(
            _playerHeadPosition() - Vector2(0, size.y * 0.06),
            snapshot.labels.levelUp,
            const Color(0xFFFFD54F),
            bold: true,
            fontSize: _textUnit * 1.15,
          );
        case CombatEventType.skill:
          _onSkill(event);
      }
    }
  }

  static const _physical = Colors.white;
  static const _incoming = Color(0xFFFF6E6E);
  static const _crit = Color(0xFFFFD54F);
  static const _fire = Color(0xFFFF8A3D);

  void _onDamage(CombatEvent event) {
    final toEnemy = event.target == CombatTarget.enemy;
    final attacker = toEnemy ? _player : _enemy;
    final victim = toEnemy ? _enemy : _player;

    attacker?.attack();
    victim?.takeHit(heavy: event.crit || event.amount >= 40);

    if (event.crit) _kickShake(toEnemy ? 5.5 : 3.5, 0.16);

    if (victim != null) {
      final slashColor = !toEnemy
          ? _incoming
          : event.crit
          ? _crit
          : event.fireAmount > 0
          ? _fire
          : _physical;
      add(
        SlashEffect(
          position: _centerOf(victim),
          radius: victim.size.y * 0.42,
          color: slashColor.withValues(alpha: 0.95),
          flip: !toEnemy,
        ),
      );
      add(
        HitSparks(
          position: _centerOf(victim),
          color: event.crit || !toEnemy
              ? (toEnemy ? slashColor : const Color(0xFFB71C1C))
              : slashColor,
          count: event.crit ? 12 : 8,
          direction: toEnemy ? 0.15 : 3.0,
        ),
      );
    }

    if (!snapshot.showDamageNumbers) return;
    final anchor = victim == null
        ? _playerHeadPosition()
        : _headAnchorOf(victim);
    final fire = event.fireAmount;
    final physical = max(0.0, event.amount - fire);
    if (!toEnemy) {
      _floating(
        anchor,
        event.amount.round().toString(),
        _incoming,
        bold: event.crit,
        fontSize: event.crit ? _textUnit * 1.3 : _textUnit,
      );
      return;
    }
    if (physical >= 0.5) {
      _floating(
        anchor,
        event.crit ? '${physical.round()}!' : physical.round().toString(),
        event.crit ? _crit : _physical,
        bold: event.crit,
        fontSize: event.crit ? _textUnit * 1.45 : _textUnit,
      );
    }
    if (fire >= 0.5) {
      _floating(
        anchor + Vector2(_jitter(10), -size.y * 0.035),
        fire.round().toString(),
        _fire,
        fontSize: _textUnit * 0.92,
      );
    }
  }

  void _onDodge(CombatEvent event) {
    final toEnemy = event.target == CombatTarget.enemy;
    (toEnemy ? _player : _enemy)?.attack();
    if (!snapshot.showDamageNumbers) return;
    final victim = toEnemy ? _enemy : _player;
    _floating(
      victim == null ? _playerHeadPosition() : _headAnchorOf(victim),
      event.text ??
          (event.target == CombatTarget.player
              ? snapshot.labels.dodge
              : snapshot.labels.miss),
      const Color(0xFFCFD8DC),
      fontSize: _textUnit * 0.85,
    );
  }

  void _onSkill(CombatEvent event) {
    _player.attack();
    final victim = _enemy;
    add(
      ImpactBurst(
        position: victim == null ? _playerCenter() : _centerOf(victim),
        color: const Color(0xFF818CF8),
        radius: size.y * 0.18,
        shards: 10,
        lifetime: 0.55,
      ),
    );
    if (victim != null) {
      add(
        SlashEffect(
          position: _centerOf(victim),
          radius: victim.size.y * 0.5,
          color: const Color(0xFFC4B5FD),
        ),
      );
    }
    if (!snapshot.showDamageNumbers) return;
    _floating(
      victim == null ? _playerHeadPosition() : _headAnchorOf(victim),
      event.text ?? snapshot.labels.skill,
      const Color(0xFFC4B5FD),
      bold: true,
      fontSize: _textUnit * 0.95,
    );
    if (event.amount > 0) {
      _floating(
        victim == null
            ? _playerHeadPosition()
            : _headAnchorOf(victim) + Vector2(0, -size.y * 0.05),
        event.amount.round().toString(),
        const Color(0xFFA78BFA),
        bold: true,
        fontSize: _textUnit * 1.2,
      );
    }
  }

  void _onDeath(CombatEvent event) {
    if (event.target == CombatTarget.enemy) {
      final enemy = _enemy;
      if (enemy != null) {
        add(
          ImpactBurst(
            position: _centerOf(enemy),
            color: enemy.visual.accent,
            radius: enemy.size.y * 0.5,
          ),
        );
        enemy.die();
      }
    } else {
      add(
        ImpactBurst(
          position: _playerCenter(),
          color: const Color(0xFFEF5350),
          radius: size.y * 0.2,
        ),
      );
      _floating(
        _playerHeadPosition(),
        snapshot.labels.defeated,
        const Color(0xFFEF5350),
        bold: true,
        fontSize: _textUnit * 1.15,
      );
    }
  }

  void _floating(
    Vector2 at,
    String text,
    Color color, {
    bool bold = false,
    double? fontSize,
  }) {
    add(
      FloatingText(
        text: text,
        position: at.clone(),
        color: color,
        bold: bold,
        fontSize: fontSize ?? _textUnit,
        velocity: Vector2(_jitter(18), -size.y * 0.10 - _jitter(8)),
      ),
    );
  }

  final Random _rng = Random();
  double _jitter(double magnitude) => (_rng.nextDouble() - 0.5) * magnitude;

  /// Base size for floating text, so numbers stay proportional on any screen.
  double get _textUnit => (size.y * 0.045).clamp(11.0, 26.0);

  Vector2 _playerCenter() => Vector2(_playerX, _groundY - _actorHeight * 0.5);

  Vector2 _playerHeadPosition() => _headAnchorOf(_player);

  Vector2 _centerOf(ActorComponent c) =>
      Vector2(c.position.x, c.position.y - c.size.y * 0.5);

  /// Just above the drawn silhouette rather than the (often taller) hit box.
  Vector2 _headAnchorOf(ActorComponent c) =>
      Vector2(c.position.x, c.visibleTop - c.size.y * 0.13);

  void _kickShake(double amplitude, double duration) {
    _shakeAmp = max(_shakeAmp, amplitude);
    _shakeTime = max(_shakeTime, duration);
  }

  @override
  void render(Canvas canvas) {
    if (_shakeTime > 0) {
      canvas.save();
      canvas.translate(_shake.x, _shake.y);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;

    if (_shakeTime > 0) {
      _shakeTime = max(0, _shakeTime - dt);
      final falloff = (_shakeTime / 0.16).clamp(0.0, 1.0);
      _shake = Vector2(
        _jitter(_shakeAmp * falloff * 2),
        _jitter(_shakeAmp * falloff * 1.4),
      );
      if (_shakeTime <= 0) {
        _shake = Vector2.zero();
        _shakeAmp = 0;
      }
    }

    _consumeEvents(eventBus.drain());

    // Smooth the 20 Hz simulation into per-frame motion.
    final enemy = _enemy;
    if (enemy != null && !enemy.isDying) {
      final delta = _enemyTargetX - enemy.position.x;
      enemy.position.x += delta * (dt * 9).clamp(0.0, 1.0);
    }

    if (snapshot.phase == CombatPhase.traveling) {
      _dustTimer -= dt;
      if (_dustTimer <= 0) {
        _dustTimer = 0.11;
        add(
          DustPuff(
            position: Vector2(_playerX - _actorHeight * 0.2, _groundY),
            color: snapshot.location.palette.groundAccent,
          ),
        );
      }
    }
  }
}
