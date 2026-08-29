import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_manager.dart';
import '../data/enemies_data.dart';
import '../data/items_data.dart';
import '../data/skills_data.dart';
import '../models/combat_event.dart';
import '../models/combat_math.dart';
import '../models/enemy.dart';
import '../models/location.dart';
import '../models/prestige.dart';
import '../models/skill.dart';
import '../models/stats.dart';
import '../models/status_effect.dart';
import 'achievements_provider.dart';
import 'skill_loadout_provider.dart';
import 'inventory_provider.dart';
import 'locale_provider.dart';
import 'player_provider.dart';
import 'player_stats_provider.dart';
import 'prestige_provider.dart';
import 'progress_provider.dart';
import 'settings_provider.dart';
import 'skills_provider.dart';
import 'stats_provider.dart';
import 'time_controller.dart';

@immutable
class SkillHudSlot {
  const SkillHudSlot({
    required this.skillId,
    required this.cooldown,
    required this.cooldownMax,
    required this.manaCost,
  });

  final String skillId;
  final double cooldown;
  final double cooldownMax;
  final double manaCost;

  bool get ready => cooldown <= 0.001;
  double get fraction =>
      cooldownMax <= 0 ? 1 : (1 - cooldown / cooldownMax).clamp(0.0, 1.0);
}

enum CombatPhase {
  /// Running toward the next spawn; the background scrolls.
  traveling,

  /// Toe to toe with an enemy; the background is still.
  fighting,

  /// Player is down and waiting to recover.
  playerDown,
}

/// Live battle state. Ticked at [CombatNotifier.tickHz] by the simulation.
@immutable
class CombatState {
  const CombatState({
    required this.phase,
    required this.playerHp,
    required this.playerMana,
    required this.enemy,
    required this.approach,
    required this.recoveryRemaining,
    required this.feed,
    required this.sessionKills,
    this.playerShield = 0,
    this.playerEffects = const [],
    this.enemyEffects = const [],
    this.skillSlots = const [],
    this.bossEnraged = false,
    this.bossPhasing = false,
  });

  final CombatPhase phase;
  final double playerHp;
  final double playerMana;
  final EnemyInstance? enemy;

  /// 1.0 when the next enemy is off screen, 0.0 when it is in melee range.
  final double approach;

  /// Seconds left before the player gets back up.
  final double recoveryRemaining;

  /// Newest-first activity log, capped at [CombatNotifier.feedLimit].
  final List<ActivityEntry> feed;
  final int sessionKills;
  final double playerShield;
  final List<StatusEffect> playerEffects;
  final List<StatusEffect> enemyEffects;
  final List<SkillHudSlot> skillSlots;
  final bool bossEnraged;
  final bool bossPhasing;

  static const CombatState initial = CombatState(
    phase: CombatPhase.traveling,
    playerHp: 1,
    playerMana: 1,
    enemy: null,
    approach: 1,
    recoveryRemaining: 0,
    feed: [],
    sessionKills: 0,
  );

  CombatState copyWith({
    CombatPhase? phase,
    double? playerHp,
    double? playerMana,
    EnemyInstance? enemy,
    bool clearEnemy = false,
    double? approach,
    double? recoveryRemaining,
    List<ActivityEntry>? feed,
    int? sessionKills,
    double? playerShield,
    List<StatusEffect>? playerEffects,
    List<StatusEffect>? enemyEffects,
    List<SkillHudSlot>? skillSlots,
    bool? bossEnraged,
    bool? bossPhasing,
  }) => CombatState(
    phase: phase ?? this.phase,
    playerHp: playerHp ?? this.playerHp,
    playerMana: playerMana ?? this.playerMana,
    enemy: clearEnemy ? null : (enemy ?? this.enemy),
    approach: approach ?? this.approach,
    recoveryRemaining: recoveryRemaining ?? this.recoveryRemaining,
    feed: feed ?? this.feed,
    sessionKills: sessionKills ?? this.sessionKills,
    playerShield: playerShield ?? this.playerShield,
    playerEffects: playerEffects ?? this.playerEffects,
    enemyEffects: enemyEffects ?? this.enemyEffects,
    skillSlots: skillSlots ?? this.skillSlots,
    bossEnraged: bossEnraged ?? this.bossEnraged,
    bossPhasing: bossPhasing ?? this.bossPhasing,
  );
}

/// Fire-and-forget visual cues for the Flame world.
final combatEventBusProvider = Provider<CombatEventBus>(
  (ref) => CombatEventBus(),
);

/// The auto-battler.
///
/// Runs a fixed-step simulation independent of frame rate: all randomness,
/// rewards and progression happen here, and the renderer only ever reads the
/// resulting [CombatState] plus the event bus.
class CombatNotifier extends Notifier<CombatState> {
  /// Simulation rate. Fast enough for smooth bars, slow enough that Riverpod
  /// listeners are not the bottleneck.
  static const int tickHz = 20;
  static const double tickSeconds = 1 / tickHz;

  /// Seconds spent running between fights before Ashen Swiftness.
  static const double travelSeconds = baseTravelSeconds;

  /// Seconds the player stays down after dying.
  static const double recoverySeconds = 4;

  static const int feedLimit = 40;

  /// Guards against unbounded catch-up if the app was suspended.
  static const int maxAttacksPerTick = 4;

  /// How often batched hit / damage-taken counters are written to the player.
  static const double counterFlushSeconds = 15;

  final Random _rng = Random();

  Timer? _timer;
  double _playerCooldown = 0;
  double _enemyCooldown = 0;
  double _travelRemaining = travelSeconds;
  double _playTimeAccumulator = 0;
  int _spawnCounter = 0;
  bool _paused = false;
  final Map<ActiveSkillId, double> _activeCooldown = {};
  double _playerShield = 0;
  List<StatusEffect> _playerFx = [];
  List<StatusEffect> _enemyFx = [];
  bool _enraged = false;
  bool _phasing = false;
  double _phaseTimer = 0;
  double _cloudTimer = 0;
  double _fightElapsed = 0;
  int _pendingHits = 0;
  int _pendingDamage = 0;
  int _pendingGold = 0;
  double _counterFlushRemaining = counterFlushSeconds;

  CombatEventBus get _bus => ref.read(combatEventBusProvider);

  @override
  CombatState build() {
    final stats = ref.read(combatStatsProvider);

    // Changing location abandons the current fight and starts a fresh approach.
    ref.listen<LocationDef>(currentLocationProvider, (previous, next) {
      if (previous?.id == next.id) return;
      _beginTravel();
      _log('feed.travel', ActivityKind.info, {'location': next.id});
    });

    // Time-skip mutates wallet and bag off-loop; reset the live fight after.
    ref.listen<int>(timeControllerProvider.select((t) => t.skipGeneration), (
      previous,
      next,
    ) {
      if (previous == null || next <= previous) return;
      final stats = ref.read(combatStatsProvider);
      state = state.copyWith(
        playerHp: stats.maxHp,
        playerMana: stats.maxMana,
        recoveryRemaining: 0,
      );
      _beginTravel();
    });

    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    _timer ??= Timer.periodic(
      const Duration(milliseconds: 1000 ~/ tickHz),
      (_) => _tick(),
    );

    return CombatState.initial.copyWith(
      playerHp: stats.maxHp,
      playerMana: stats.maxMana,
    );
  }

  // -------------------------------------------------------------- public API

  void setPaused(bool value) {
    if (value && !_paused) _flushCombatCounters();
    _paused = value;
  }

  bool get isPaused => _paused;

  /// Restores health from a bag consumable. Returns true if a potion was used.
  bool usePotion(String uid) {
    String? itemId;
    for (final entry in ref.read(inventoryProvider).bag) {
      if (entry.uid == uid) {
        itemId = entry.itemId;
        break;
      }
    }
    final peek = itemId == null ? null : tryItemById(itemId);
    if (peek == null) return false;

    if (peek.healAmount > 0) {
      final stats = ref.read(combatStatsProvider);
      if (state.playerHp >= stats.maxHp - 0.0005) return false;
      final def = ref.read(inventoryProvider.notifier).consumeOne(uid);
      if (def == null || def.healAmount <= 0) return false;
      final healed = _healPlayer(def.healAmount * stats.maxHp, stats);
      if (healed > 0) {
        _log('feed.drank', ActivityKind.info, {
          'item': def.id,
          'hp': '${healed.round()}',
        });
      }
      return true;
    }

    if (peek.buffId.isEmpty) return false;
    final def = ref.read(inventoryProvider.notifier).consumeOne(uid);
    if (def == null || def.buffId.isEmpty) return false;
    final time = ref.read(timeControllerProvider.notifier);
    if (def.buffId == 'berserk') time.activateBerserk();
    if (def.buffId == 'ward') time.activateWard();
    _log('feed.elixir', ActivityKind.info, {'item': def.id});
    return true;
  }

  /// Full heal, used by the "get up now" button and on level up.
  void reviveNow() {
    final stats = ref.read(combatStatsProvider);
    state = state.copyWith(
      playerHp: stats.maxHp,
      playerMana: stats.maxMana,
      recoveryRemaining: 0,
    );
    if (state.phase == CombatPhase.playerDown) _beginTravel();
  }

  void clearFeed() => state = state.copyWith(feed: const []);

  /// Public activity line for systems outside the combat loop (crafting).
  void logActivity(
    String key,
    ActivityKind kind, [
    Map<String, String>? args,
  ]) => _log(key, kind, args);

  // ---------------------------------------------------------------- the loop

  void _tick() {
    if (_paused || ref.read(timeControllerProvider).skipping) return;
    final speed = ref.read(timeControllerProvider).speedMultiplier.clamp(1, 5);
    for (var i = 0; i < speed; i++) {
      if (_paused || ref.read(timeControllerProvider).skipping) return;
      _advanceOneTick();
    }
  }

  bool castSlot(int index) {
    if (state.phase != CombatPhase.fighting) return false;
    final slots = ref.read(equippedActivesProvider);
    if (index < 0 || index >= slots.length) return false;
    final chosen = slots[index];
    if (state.playerMana < chosen.manaCost) return false;
    if ((_activeCooldown[chosen.id] ?? 0) > 0) return false;
    final enemy = state.enemy;
    if (enemy == null) return false;
    final perks = ref.read(learnedPerksProvider);
    final stats = ref.read(combatStatsProvider);
    final cast = _resolveActive(
      chosen: chosen,
      stats: stats,
      enemy: enemy.def,
      enemyHp: enemy.hp,
      playerHp: state.playerHp,
      mana: state.playerMana,
      perks: perks,
    );
    if (cast.enemyHp <= 0) {
      state = state.copyWith(playerHp: cast.playerHp, playerMana: cast.mana);
      _publishHud();
      _resolveKill(enemy.def, stats);
      return true;
    }
    state = state.copyWith(
      playerHp: cast.playerHp,
      playerMana: cast.mana,
      playerShield: _playerShield,
      playerEffects: List.of(_playerFx),
      enemyEffects: List.of(_enemyFx),
      enemy: enemy.copyWith(hp: cast.enemyHp),
    );
    _publishHud();
    return true;
  }

  void _advanceOneTick() {
    ref.read(timeControllerProvider.notifier).tickRealtime(tickSeconds);
    final stats = ref.read(combatStatsProvider);
    var hp = state.playerHp;
    var mana = state.playerMana;
    if (hp > stats.maxHp) hp = stats.maxHp;
    if (mana > stats.maxMana) mana = stats.maxMana;
    if (hp != state.playerHp || mana != state.playerMana) {
      state = state.copyWith(playerHp: hp, playerMana: mana);
    }

    _counterFlushRemaining -= tickSeconds;
    if (_counterFlushRemaining <= 0) {
      _flushCombatCounters();
      _counterFlushRemaining = counterFlushSeconds;
    }

    _playTimeAccumulator += tickSeconds;
    if (_playTimeAccumulator >= 10) {
      ref.read(playerProvider.notifier).addPlayTime(_playTimeAccumulator);
      _playTimeAccumulator = 0;
    }

    switch (state.phase) {
      case CombatPhase.playerDown:
        _tickRecovery(stats);
      case CombatPhase.traveling:
        _tickTravel(stats);
      case CombatPhase.fighting:
        _tickFight(stats);
    }
  }

  void _tickRecovery(CombatStats stats) {
    final remaining = state.recoveryRemaining - tickSeconds;
    if (remaining > 0) {
      state = state.copyWith(recoveryRemaining: remaining);
      return;
    }
    state = state.copyWith(
      playerHp: stats.maxHp,
      playerMana: stats.maxMana,
      recoveryRemaining: 0,
    );
    _beginTravel();
  }

  void _tickTravel(CombatStats stats) {
    // The next enemy is chosen up front so the renderer can walk it in from
    // the right edge while the player runs.
    if (state.enemy == null) _prepareNextEnemy();

    _regen(stats);
    _travelRemaining -= tickSeconds;
    if (_travelRemaining > 0) {
      state = state.copyWith(
        approach: (_travelRemaining / _travelDuration).clamp(0.0, 1.0),
      );
      return;
    }
    _engage();
  }

  void _tickFight(CombatStats stats) {
    final enemy = state.enemy;
    if (enemy == null) {
      _beginTravel();
      return;
    }

    _fightElapsed += tickSeconds;
    _regen(stats);
    _maybeAutoPotion(stats);
    _tickActiveCooldowns();

    var enemyHp = enemy.hp;
    var playerHp = state.playerHp;
    var mana = state.playerMana;
    final perks = _combatPerks();

    final playerDots = tickStatusEffects(_playerFx, tickSeconds);
    _playerFx = playerDots.next;
    if (playerDots.damage > 0) {
      playerHp -= playerDots.damage;
      _bus.push(
        CombatEvent(
          type: CombatEventType.damage,
          target: CombatTarget.player,
          amount: playerDots.damage,
          text: 'DoT',
        ),
      );
    }
    final enemyDots = tickStatusEffects(_enemyFx, tickSeconds);
    _enemyFx = enemyDots.next;
    if (enemyDots.damage > 0) {
      enemyHp -= enemyDots.damage;
      _bus.push(
        CombatEvent(
          type: CombatEventType.damage,
          target: CombatTarget.enemy,
          amount: enemyDots.damage,
          fireAmount: enemyDots.damage,
        ),
      );
    }

    _tickBossScript(enemy.def, enemyHp);

    // Player swings.
    final playerPeriod = 1 / stats.attackSpeed;
    final playerStunned = hasStun(_playerFx);
    if (!playerStunned) _playerCooldown += tickSeconds;
    var swings = 0;
    while (_playerCooldown >= playerPeriod &&
        swings < maxAttacksPerTick &&
        enemyHp > 0) {
      _playerCooldown -= playerPeriod;
      swings++;
      final hit = rollAttack(
        rng: _rng,
        damageMin: stats.damageMin,
        damageMax: stats.damageMax,
        critChance: stats.crit,
        critMultiplier: stats.critMultiplier,
        targetArmor: enemy.def.armor,
        targetDodge: enemy.def.dodge,
        fireDamage: stats.fireDamage,
      );
      if (hit.dodged) {
        _bus.push(
          const CombatEvent(
            type: CombatEventType.dodge,
            target: CombatTarget.enemy,
          ),
        );
        continue;
      }
      var damage = hit.damage;
      var fire = hit.fireDamage;
      if (perks.execute > 0 && enemyHp / enemy.def.maxHp <= 0.25) {
        final scale = 1 + perks.execute;
        damage *= scale;
        fire *= scale;
      }
      enemyHp -= damage;
      _pendingHits++;
      unawaited(
        AudioManager.instance.play(hit.crit ? SfxKind.crit : SfxKind.hit),
      );
      _bus.push(
        CombatEvent(
          type: CombatEventType.damage,
          target: CombatTarget.enemy,
          amount: damage,
          crit: hit.crit,
          fireAmount: fire,
        ),
      );
      final steal =
          stats.lifeSteal + statusMultiplier(_playerFx, StatusId.lifesteal);
      if (steal > 0) {
        playerHp = min(stats.maxHp, playerHp + damage * steal);
      }
      if (perks.goldOnHit > 0) {
        _pendingGold += max(1, perks.goldOnHit.round());
      }
    }

    if (enemyHp > 0 && _fightElapsed > 0.75) {
      final cast = _tryCastActive(
        stats: stats,
        enemy: enemy.def,
        enemyHp: enemyHp,
        playerHp: playerHp,
        mana: mana,
        perks: perks,
      );
      enemyHp = cast.enemyHp;
      playerHp = cast.playerHp;
      mana = cast.mana;
    }

    if (enemyHp <= 0) {
      state = state.copyWith(playerHp: playerHp, playerMana: mana);
      _resolveKill(enemy.def, stats);
      return;
    }

    // Enemy swings back.
    final rage = _enraged ? 1.35 : 1.0;
    final enemyPeriod = 1 / (enemy.def.attackSpeed * rage);
    if (!hasStun(_enemyFx)) _enemyCooldown += tickSeconds;
    var enemySwings = 0;
    while (_enemyCooldown >= enemyPeriod &&
        enemySwings < maxAttacksPerTick &&
        playerHp > 0) {
      _enemyCooldown -= enemyPeriod;
      enemySwings++;
      final hit = rollAttack(
        rng: _rng,
        damageMin: enemy.def.damageMin,
        damageMax: enemy.def.damageMax,
        critChance: enemy.def.crit,
        critMultiplier: 1.5,
        targetArmor: stats.armor,
        targetDodge: stats.dodge,
      );
      if (hit.dodged) {
        _bus.push(
          const CombatEvent(
            type: CombatEventType.dodge,
            target: CombatTarget.player,
          ),
        );
        continue;
      }
      var incoming = applyFireResist(
        hit.damage * rage,
        fireHit: enemy.def.dealsFire,
        fireResist: stats.fireResist,
      );
      incoming = _soakShield(incoming);
      playerHp -= incoming;
      if (incoming > 0.01) {
        _pendingDamage += incoming.round().clamp(0, 100000);
      }
      _bus.push(
        CombatEvent(
          type: CombatEventType.damage,
          target: CombatTarget.player,
          amount: incoming,
          crit: hit.crit,
        ),
      );
      final thorns =
          perks.thorns + statusMultiplier(_playerFx, StatusId.thorns);
      if (thorns > 0 && enemyHp > 0 && incoming > 0) {
        final reflected = max(1.0, hit.damage * thorns);
        enemyHp -= reflected;
        _bus.push(
          CombatEvent(
            type: CombatEventType.damage,
            target: CombatTarget.enemy,
            amount: reflected,
          ),
        );
      }
    }

    if (playerHp <= 0) {
      _resolveDeath(enemy.def);
      return;
    }

    if (enemyHp <= 0) {
      state = state.copyWith(playerHp: playerHp, playerMana: mana);
      _resolveKill(enemy.def, stats);
      return;
    }

    state = state.copyWith(
      playerHp: playerHp,
      playerMana: mana,
      enemy: enemy.copyWith(hp: enemyHp),
      playerShield: _playerShield,
      playerEffects: List.of(_playerFx),
      enemyEffects: List.of(_enemyFx),
      bossEnraged: _enraged,
      bossPhasing: _phasing,
    );
    _publishHud();
  }

  void _regen(CombatStats stats) {
    var hp = state.playerHp;
    var mana = state.playerMana;
    var changed = false;
    if (stats.hpRegen > 0 && hp < stats.maxHp) {
      hp = min(stats.maxHp, hp + stats.hpRegen * tickSeconds);
      changed = true;
    }
    if (stats.manaRegen > 0 && mana < stats.maxMana) {
      mana = min(stats.maxMana, mana + stats.manaRegen * tickSeconds);
      changed = true;
    }
    if (changed) state = state.copyWith(playerHp: hp, playerMana: mana);
  }

  double _soakShield(double incoming) {
    if (_playerShield <= 0 || incoming <= 0) return incoming;
    final soak = min(_playerShield, incoming);
    _playerShield -= soak;
    if (_playerShield <= 0) {
      _playerFx = [
        for (final e in _playerFx)
          if (e.id != StatusId.shield) e,
      ];
    }
    return incoming - soak;
  }

  void _tickBossScript(EnemyDef def, double enemyHp) {
    final abilities = def.resolvedAbilities;
    if (abilities.isEmpty) return;
    if (abilities.contains(BossAbility.enrage) &&
        !_enraged &&
        enemyHp / def.maxHp <= 0.3) {
      _enraged = true;
      _enemyFx = upsertStatus(
        _enemyFx,
        const StatusEffect(
          id: StatusId.enrage,
          target: CombatTarget.enemy,
          remaining: 30,
          magnitude: 0.35,
        ),
      );
      _log('feed.enrage', ActivityKind.info, {'enemy': def.id});
    }
    if (abilities.contains(BossAbility.shieldPhase)) {
      _phaseTimer += tickSeconds;
      if (!_phasing && _phaseTimer >= 8) {
        _phasing = true;
        _phaseTimer = 0;
      } else if (_phasing && _phaseTimer >= 2) {
        _phasing = false;
        _phaseTimer = 0;
      }
    }
    if (abilities.contains(BossAbility.poisonCloud)) {
      _cloudTimer += tickSeconds;
      if (_cloudTimer >= 10) {
        _cloudTimer = 0;
        _playerFx = upsertStatus(
          _playerFx,
          const StatusEffect(
            id: StatusId.poison,
            target: CombatTarget.player,
            remaining: 6,
            magnitude: 4,
            tickEvery: 1,
          ),
        );
        _log('feed.poisonCloud', ActivityKind.info, {'enemy': def.id});
      }
    }
  }

  void _resetEncounterAuras() {
    _enraged = false;
    _phasing = false;
    _phaseTimer = 0;
    _cloudTimer = 0;
    _enemyFx = [];
  }

  void _publishHud() {
    final slots = [
      for (final active in ref.read(equippedActivesProvider))
        SkillHudSlot(
          skillId: active.def.id,
          cooldown: _activeCooldown[active.id] ?? 0,
          cooldownMax: active.cooldown,
          manaCost: active.manaCost,
        ),
    ];
    if (!_listEqualsSlots(state.skillSlots, slots)) {
      state = state.copyWith(skillSlots: slots);
    }
  }

  bool _listEqualsSlots(List<SkillHudSlot> a, List<SkillHudSlot> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].skillId != b[i].skillId) return false;
      if ((a[i].cooldown - b[i].cooldown).abs() > 0.04) return false;
    }
    return true;
  }

  void _tickActiveCooldowns() {
    if (_activeCooldown.isEmpty) return;
    for (final id in _activeCooldown.keys.toList()) {
      final next = (_activeCooldown[id]! - tickSeconds);
      if (next <= 0) {
        _activeCooldown.remove(id);
      } else {
        _activeCooldown[id] = next;
      }
    }
  }

  ({double enemyHp, double playerHp, double mana}) _tryCastActive({
    required CombatStats stats,
    required EnemyDef enemy,
    required double enemyHp,
    required double playerHp,
    required double mana,
    required LearnedPerks perks,
  }) {
    // Signature HUD skills are player-fired via [castSlot]. Auto-casting
    // them one-shots early zones and skips the first auto-attack event.
    final signatureIds = {
      for (final s in signatureSkills)
        if (s.active != null) s.active!,
    };
    final ready = ref
        .read(unlockedActivesProvider)
        .where(
          (a) =>
              !signatureIds.contains(a.id) &&
              mana >= a.manaCost &&
              (_activeCooldown[a.id] ?? 0) <= 0,
        )
        .toList();
    if (ready.isEmpty) {
      return (enemyHp: enemyHp, playerHp: playerHp, mana: mana);
    }

    final hpFrac = playerHp / stats.maxHp;
    final heals = ready.where(
      (a) => a.id == ActiveSkillId.heal || a.id == ActiveSkillId.ironWill,
    );
    final attacks = ready
        .where(
          (a) => a.id != ActiveSkillId.heal && a.id != ActiveSkillId.ironWill,
        )
        .toList()
      ..sort((a, b) => b.power.compareTo(a.power));

    final chosen = (hpFrac < 0.45 && heals.isNotEmpty)
        ? heals.first
        : (attacks.isNotEmpty
              ? attacks.first
              : (hpFrac < 0.9 && heals.isNotEmpty ? heals.first : null));
    if (chosen == null) {
      return (enemyHp: enemyHp, playerHp: playerHp, mana: mana);
    }
    return _resolveActive(
      chosen: chosen,
      stats: stats,
      enemy: enemy,
      enemyHp: enemyHp,
      playerHp: playerHp,
      mana: mana,
      perks: perks,
    );
  }

  ({double enemyHp, double playerHp, double mana}) _resolveActive({
    required UnlockedActive chosen,
    required CombatStats stats,
    required EnemyDef enemy,
    required double enemyHp,
    required double playerHp,
    required double mana,
    required LearnedPerks perks,
  }) {
    mana -= chosen.manaCost;
    _activeCooldown[chosen.id] = chosen.cooldown;
    unawaited(AudioManager.instance.play(SfxKind.skill));

    if (chosen.id == ActiveSkillId.heal) {
      final amount = stats.maxHp * chosen.power;
      playerHp = min(stats.maxHp, playerHp + amount);
      _bus.push(
        CombatEvent(
          type: CombatEventType.heal,
          target: CombatTarget.player,
          amount: amount,
          text: ref.read(l10nProvider).skillName(chosen.def.id),
        ),
      );
      _log('feed.cast', ActivityKind.skill, {'skill': chosen.def.id});
      return (enemyHp: enemyHp, playerHp: playerHp, mana: mana);
    }

    if (chosen.id == ActiveSkillId.ironWill) {
      _playerShield += stats.maxHp * chosen.power;
      _playerFx = upsertStatus(
        _playerFx,
        StatusEffect(
          id: StatusId.shield,
          target: CombatTarget.player,
          remaining: 8,
          magnitude: _playerShield,
        ),
      );
      _playerFx = upsertStatus(
        _playerFx,
        const StatusEffect(
          id: StatusId.thorns,
          target: CombatTarget.player,
          remaining: 8,
          magnitude: 0.15,
        ),
      );
      _bus.push(
        CombatEvent(
          type: CombatEventType.heal,
          target: CombatTarget.player,
          amount: 0,
          text: ref.read(l10nProvider).skillName(chosen.def.id),
        ),
      );
      _log('feed.cast', ActivityKind.skill, {'skill': chosen.def.id});
      return (enemyHp: enemyHp, playerHp: playerHp, mana: mana);
    }

    var damage = switch (chosen.id) {
      ActiveSkillId.powerStrike ||
      ActiveSkillId.cleave ||
      ActiveSkillId.flameSlash => stats.averageDamage * chosen.power,
      ActiveSkillId.shadowStrike =>
        stats.averageDamage * chosen.power * stats.critMultiplier,
      ActiveSkillId.manaBolt ||
      ActiveSkillId.nova => stats.magicDamage * chosen.power,
      ActiveSkillId.heal || ActiveSkillId.ironWill => 0.0,
    };
    if (chosen.id == ActiveSkillId.flameSlash) {
      damage += stats.fireDamage * 2;
      _enemyFx = upsertStatus(
        _enemyFx,
        StatusEffect(
          id: StatusId.fireDot,
          target: CombatTarget.enemy,
          remaining: 5,
          magnitude: max(2, stats.fireDamage + stats.averageDamage * 0.12),
          tickEvery: 1,
        ),
      );
    }
    if (chosen.id == ActiveSkillId.shadowStrike) {
      _enemyFx = upsertStatus(
        _enemyFx,
        StatusEffect(
          id: StatusId.bleed,
          target: CombatTarget.enemy,
          remaining: 4,
          magnitude: max(2, stats.averageDamage * 0.08),
          tickEvery: 0.8,
        ),
      );
      _enemyFx = upsertStatus(
        _enemyFx,
        const StatusEffect(
          id: StatusId.stun,
          target: CombatTarget.enemy,
          remaining: 0.6,
        ),
      );
      _playerFx = upsertStatus(
        _playerFx,
        const StatusEffect(
          id: StatusId.lifesteal,
          target: CombatTarget.player,
          remaining: 4,
          magnitude: 0.12,
        ),
      );
    }
    if (perks.execute > 0 && enemyHp / enemy.maxHp <= 0.25) {
      damage *= 1 + perks.execute;
    }
    if (_phasing) damage *= 0.3;
    damage *= 100 / (100 + max(0, enemy.armor));
    damage = max(1, damage);
    enemyHp -= damage;
    _bus.push(
      CombatEvent(
        type: CombatEventType.skill,
        target: CombatTarget.enemy,
        amount: damage,
        text: ref.read(l10nProvider).skillName(chosen.def.id),
      ),
    );
    _log('feed.cast', ActivityKind.skill, {'skill': chosen.def.id});
    return (enemyHp: enemyHp, playerHp: playerHp, mana: mana);
  }

  void _maybeAutoPotion(CombatStats stats) {
    if (!ref.read(settingsProvider).autoPotion) return;
    if (state.playerHp / stats.maxHp > 0.3) return;
    final uid = ref.read(inventoryProvider.notifier).findPotionUid();
    if (uid == null) return;
    usePotion(uid);
  }

  double _healPlayer(double amount, CombatStats stats) {
    final before = state.playerHp;
    final after = min(stats.maxHp, before + amount);
    if (after <= before) return 0;
    state = state.copyWith(playerHp: after);
    _bus.push(
      CombatEvent(
        type: CombatEventType.heal,
        target: CombatTarget.player,
        amount: after - before,
      ),
    );
    return after - before;
  }

  // -------------------------------------------------------- spawn and travel

  double get _travelDuration => ref.read(prestigeProvider).travelSeconds;

  void _beginTravel() {
    _travelRemaining = _travelDuration;
    _playerCooldown = 0;
    _enemyCooldown = 0;
    state = state.copyWith(
      phase: CombatPhase.traveling,
      approach: 1,
      clearEnemy: true,
    );
  }

  void _prepareNextEnemy() {
    _resetEncounterAuras();
    final def = _pickSpawn(ref.read(currentLocationProvider));
    _spawnCounter++;
    state = state.copyWith(
      enemy: EnemyInstance(def: def, hp: def.maxHp, spawnId: _spawnCounter),
    );
    _bus.push(
      const CombatEvent(
        type: CombatEventType.spawn,
        target: CombatTarget.enemy,
      ),
    );
    if (def.isBoss) {
      _log('feed.boss', ActivityKind.info, {'enemy': def.id});
    }
  }

  /// Travel finished: close to melee range and start trading blows.
  void _engage() {
    final enemy = state.enemy;
    if (enemy == null) return;
    _playerCooldown = 0;
    _fightElapsed = 0;
    // A partial head start so fights are not perfectly mirrored.
    _enemyCooldown = _rng.nextDouble() * 0.4 / enemy.def.attackSpeed;
    state = state.copyWith(phase: CombatPhase.fighting, approach: 0);
  }

  EnemyDef _pickSpawn(LocationDef location) {
    final total = location.spawns.fold<double>(0, (a, s) => a + s.weight);
    var roll = _rng.nextDouble() * total;
    for (final spawn in location.spawns) {
      roll -= spawn.weight;
      if (roll <= 0) return enemyById(spawn.enemyId);
    }
    return enemyById(location.spawns.last.enemyId);
  }

  // ---------------------------------------------------------------- outcomes

  void _resolveKill(EnemyDef def, CombatStats stats) {
    unawaited(AudioManager.instance.play(SfxKind.death));
    unawaited(AudioManager.instance.play(SfxKind.gold));
    _bus.push(
      const CombatEvent(
        type: CombatEventType.death,
        target: CombatTarget.enemy,
      ),
    );

    final player = ref.read(playerProvider.notifier);
    final progress = ref.read(progressProvider.notifier);

    final xp = max(1, (def.xp * stats.xpGain).round());
    final goldSpread = max(0, def.goldMax - def.goldMin);
    final gold = max(
      1,
      ((def.goldMin + _rng.nextInt(goldSpread + 1)) * stats.goldFind).round(),
    );

    _flushCombatCounters();
    player.gainGold(gold);
    player.recordKill();
    progress.recordKill(def.id);
    ref.read(achievementsProvider.notifier).recordKill(isBoss: def.isBoss);
    ref.read(prestigeProvider.notifier).collectAchievementSouls();

    final levels = player.gainXp(xp);
    _log('feed.slew', ActivityKind.kill, {
      'enemy': def.id,
      'xp': '$xp',
      'gold': '$gold',
    });

    final gems = def.isBoss
        ? 1 + _rng.nextInt(3)
        : (_rng.nextDouble() < 0.02 ? 1 : 0);
    if (gems > 0) {
      player.gainGems(gems);
      _log(gems > 1 ? 'feed.gems' : 'feed.gem', ActivityKind.loot, {
        'n': '$gems',
      });
    }

    _grantLoot(def, stats);

    if (levels > 0) {
      _bus.push(
        const CombatEvent(
          type: CombatEventType.levelUp,
          target: CombatTarget.player,
        ),
      );
      final newStats = ref.read(combatStatsProvider);
      state = state.copyWith(playerHp: newStats.maxHp);
      _log('feed.level', ActivityKind.levelUp, {
        'n': '${ref.read(playerProvider).level}',
      });
    }

    state = state.copyWith(sessionKills: state.sessionKills + 1);
    _beginTravel();
  }

  void _grantLoot(EnemyDef def, CombatStats stats) {
    if (def.loot.isEmpty) return;
    final inventory = ref.read(inventoryProvider.notifier);
    final settings = ref.read(settingsProvider);
    final player = ref.read(playerProvider.notifier);
    final dropped = <String>[];

    for (final drop in def.loot) {
      final chance = min(0.95, drop.chance * stats.lootFind);
      if (_rng.nextDouble() >= chance) continue;

      final spread = max(0, drop.max - drop.min);
      var quantity = drop.min + _rng.nextInt(spread + 1);
      if (quantity <= 0) continue;
      final perks = ref.read(learnedPerksProvider);
      if (perks.doubleLoot > 0 && _rng.nextDouble() < perks.doubleLoot) {
        quantity *= 2;
      }
      if (ref.read(timeControllerProvider).doubleLootActive) {
        quantity *= 2;
      }

      final item = tryItemById(drop.itemId);
      if (item == null) continue;
      dropped.add(drop.itemId);

      // Junk gear is converted to gold before it ever occupies a slot.
      if (settings.autoSellEnabled &&
          item.isEquipment &&
          item.rarity.index <= settings.autoSellRarity.index) {
        final gold = item.sellValue * quantity;
        player.gainGold(gold);
        _log('feed.autoSold', ActivityKind.loot, {
          'item': item.id,
          'gold': '$gold',
        });
        continue;
      }

      final before = ref.read(inventoryProvider).bag.length;
      final outcome = inventory.add(drop.itemId, quantity);
      if (outcome == PickupOutcome.bagFull) {
        _log('feed.bagFull', ActivityKind.info, {'item': item.id});
        continue;
      }

      _log(quantity > 1 ? 'feed.lootedQty' : 'feed.looted', ActivityKind.loot, {
        'item': item.id,
        'n': '$quantity',
      });

      final bag = ref.read(inventoryProvider).bag;
      if (settings.autoEquipUpgrades &&
          item.isEquipment &&
          bag.length > before &&
          bag.last.itemId == drop.itemId &&
          inventory.tryAutoEquip(bag.last.uid)) {
        _log('feed.equipped', ActivityKind.info, {'item': item.id});
      }
    }

    if (dropped.isNotEmpty) {
      ref.read(progressProvider.notifier).discoverItems(dropped);
    }
  }

  void _resolveDeath(EnemyDef killer) {
    _bus.push(
      const CombatEvent(
        type: CombatEventType.death,
        target: CombatTarget.player,
      ),
    );
    _flushCombatCounters();
    ref.read(playerProvider.notifier).recordDeath();
    _log('feed.death', ActivityKind.death, {'enemy': killer.id});
    _playerFx = [];
    _playerShield = 0;
    _resetEncounterAuras();
    state = state.copyWith(
      phase: CombatPhase.playerDown,
      playerHp: 0,
      playerShield: 0,
      playerEffects: const [],
      enemyEffects: const [],
      bossEnraged: false,
      bossPhasing: false,
      recoveryRemaining: recoverySeconds,
      clearEnemy: true,
    );
  }

  LearnedPerks _combatPerks() {
    final learned = ref.read(learnedPerksProvider);
    final extra = ref.read(setThornsProvider);
    if (extra <= 0) return learned;
    return LearnedPerks(
      doubleLoot: learned.doubleLoot,
      execute: learned.execute,
      thorns: (learned.thorns + extra).clamp(0.0, 0.6),
      goldOnHit: learned.goldOnHit,
    );
  }

  void _flushCombatCounters() {
    if (_pendingHits == 0 && _pendingDamage == 0 && _pendingGold == 0) {
      return;
    }
    final player = ref.read(playerProvider.notifier);
    final scale = ref.read(prestigeProvider).masteryGainScale;
    player.recordHits((_pendingHits * scale).round());
    player.recordDamageTakenAmount((_pendingDamage * scale).round());
    if (_pendingGold > 0) player.gainGold(_pendingGold);
    _pendingHits = 0;
    _pendingDamage = 0;
    _pendingGold = 0;
    _counterFlushRemaining = counterFlushSeconds;
  }

  void _log(String key, ActivityKind kind, [Map<String, String>? args]) {
    final feed = [
      ActivityEntry(key: key, args: args ?? const {}, kind: kind),
      ...state.feed,
    ];
    state = state.copyWith(
      feed: feed.length > feedLimit ? feed.sublist(0, feedLimit) : feed,
    );
  }
}

final combatProvider = NotifierProvider<CombatNotifier, CombatState>(
  CombatNotifier.new,
);

/// Player health as a 0..1 fraction, for the bars.
final playerHpFractionProvider = Provider<double>((ref) {
  final hp = ref.watch(combatProvider.select((s) => s.playerHp));
  final maxHp = ref.watch(combatStatsProvider.select((s) => s.maxHp));
  return (hp / maxHp).clamp(0.0, 1.0);
});

final playerManaFractionProvider = Provider<double>((ref) {
  final mana = ref.watch(combatProvider.select((s) => s.playerMana));
  final maxMana = ref.watch(combatStatsProvider.select((s) => s.maxMana));
  return (mana / maxMana).clamp(0.0, 1.0);
});
