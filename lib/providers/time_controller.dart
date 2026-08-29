import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/enemies_data.dart';
import '../data/items_data.dart';
import '../models/combat_math.dart';
import '../models/enemy.dart';
import '../models/location.dart';
import '../models/stats.dart';
import '../models/trusted_clock.dart';
import 'achievements_provider.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';
import 'player_stats_provider.dart';
import 'prestige_provider.dart';
import 'progress_provider.dart';
import 'save_provider.dart';
import 'settings_provider.dart';
import 'skills_provider.dart';
import 'stats_provider.dart';

/// Allowed combat speed multipliers for the test toggle.
const List<int> combatSpeedSteps = [1, 2, 5];

const Duration shopBoosterDuration = Duration(minutes: 30);
const double xpElixirMultiplier = 1.5;

/// Wall-clock travel / recovery copied from the live combat loop.
const double _recoverySeconds = 4;
const double _maxFightSeconds = 90;

/// Rewards collected by one time-skip run.
@immutable
class TimeSkipSummary {
  const TimeSkipSummary({
    required this.hours,
    required this.xp,
    required this.gold,
    required this.gems,
    required this.kills,
    required this.deaths,
    required this.levelsGained,
    required this.loot,
    this.bagFilled = false,
  });

  final int hours;
  final int xp;
  final int gold;
  final int gems;
  final int kills;
  final int deaths;
  final int levelsGained;
  final Map<String, int> loot;
  final bool bagFilled;

  static const TimeSkipSummary empty = TimeSkipSummary(
    hours: 0,
    xp: 0,
    gold: 0,
    gems: 0,
    kills: 0,
    deaths: 0,
    levelsGained: 0,
    loot: {},
  );
}

/// Persisted boosters and the live combat speed multiplier.
@immutable
class TimeState {
  const TimeState({
    this.speedMultiplier = 1,
    this.xpElixirSec = 0,
    this.doubleLootSec = 0,
    this.berserkSec = 0,
    this.wardSec = 0,
    this.skipping = false,
    this.skipGeneration = 0,
  });

  final int speedMultiplier;

  /// Booster time left in seconds. Decremented by the live loop, not the wall clock.
  final double xpElixirSec;
  final double doubleLootSec;
  final double berserkSec;
  final double wardSec;

  /// True while a time-skip is applying rewards so the live loop stays still.
  final bool skipping;

  /// Bumped after each skip so combat can reset travel / HP.
  final int skipGeneration;

  bool get xpElixirActive => xpElixirSec > 0;
  bool get doubleLootActive => doubleLootSec > 0;
  bool get berserkActive => berserkSec > 0;
  bool get wardActive => wardSec > 0;

  Duration? xpElixirRemaining([DateTime? now]) =>
      xpElixirActive ? Duration(milliseconds: (xpElixirSec * 1000).round()) : null;
  Duration? doubleLootRemaining([DateTime? now]) => doubleLootActive
      ? Duration(milliseconds: (doubleLootSec * 1000).round())
      : null;

  TimeState copyWith({
    int? speedMultiplier,
    double? xpElixirSec,
    double? doubleLootSec,
    double? berserkSec,
    double? wardSec,
    bool? skipping,
    int? skipGeneration,
  }) => TimeState(
    speedMultiplier: speedMultiplier ?? this.speedMultiplier,
    xpElixirSec: xpElixirSec ?? this.xpElixirSec,
    doubleLootSec: doubleLootSec ?? this.doubleLootSec,
    berserkSec: berserkSec ?? this.berserkSec,
    wardSec: wardSec ?? this.wardSec,
    skipping: skipping ?? this.skipping,
    skipGeneration: skipGeneration ?? this.skipGeneration,
  );

  Map<String, dynamic> toJson() => {
    'speedMultiplier': speedMultiplier,
    'xpElixirSec': xpElixirSec,
    'doubleLootSec': doubleLootSec,
    'berserkSec': berserkSec,
    'wardSec': wardSec,
  };

  static TimeState fromJson(Map<String, dynamic> json) {
    final speed = (json['speedMultiplier'] as num?)?.toInt() ?? 1;
    return TimeState(
      speedMultiplier: combatSpeedSteps.contains(speed) ? speed : 1,
      xpElixirSec: _readRemaining(json, 'xpElixirSec', 'xpElixirExpires'),
      doubleLootSec: _readRemaining(json, 'doubleLootSec', 'doubleLootExpires'),
      berserkSec: _readRemaining(json, 'berserkSec', 'berserkExpires'),
      wardSec: _readRemaining(json, 'wardSec', 'wardExpires'),
    );
  }

  static double _readRemaining(
    Map<String, dynamic> json,
    String secKey,
    String legacyExpiresKey,
  ) {
    final sec = (json[secKey] as num?)?.toDouble();
    if (sec != null) return max(0, sec);
    final raw = json[legacyExpiresKey];
    if (raw is! num) return 0;
    final left =
        DateTime.fromMillisecondsSinceEpoch(raw.toInt()).difference(
          DateTime.now(),
        );
    return left.isNegative ? 0 : left.inMilliseconds / 1000;
  }
}

/// Game-speed toggle, shop boosters, and offline-style time-skip simulation.
class TimeNotifier extends Notifier<TimeState> {
  final Random _rng = Random();
  int? _lastClaimedSavedAt;

  @override
  TimeState build() {
    final saved = savedSection(ref, 'time');
    return saved == null ? const TimeState() : TimeState.fromJson(saved);
  }

  void setSpeed(int multiplier) {
    if (!combatSpeedSteps.contains(multiplier)) return;
    if (state.speedMultiplier == multiplier) return;
    state = state.copyWith(speedMultiplier: multiplier);
  }

  void activateXpElixir([Duration duration = shopBoosterDuration]) {
    state = state.copyWith(xpElixirSec: duration.inMilliseconds / 1000);
  }

  void activateDoubleLoot([Duration duration = shopBoosterDuration]) {
    state = state.copyWith(doubleLootSec: duration.inMilliseconds / 1000);
  }

  static const alchemyBuffDuration = Duration(minutes: 3);

  void activateBerserk([Duration duration = alchemyBuffDuration]) {
    state = state.copyWith(berserkSec: duration.inMilliseconds / 1000);
  }

  void activateWard([Duration duration = alchemyBuffDuration]) {
    state = state.copyWith(wardSec: duration.inMilliseconds / 1000);
  }

  /// Drains boosters with monotonic combat time so a clock edit cannot extend them.
  void tickRealtime(double dt) {
    if (dt <= 0) return;
    if (state.xpElixirSec <= 0 &&
        state.doubleLootSec <= 0 &&
        state.berserkSec <= 0 &&
        state.wardSec <= 0) {
      return;
    }
    state = state.copyWith(
      xpElixirSec: max(0, state.xpElixirSec - dt),
      doubleLootSec: max(0, state.doubleLootSec - dt),
      berserkSec: max(0, state.berserkSec - dt),
      wardSec: max(0, state.wardSec - dt),
    );
  }

  /// Instantly resolves [hours] of auto-farm using the live combat formulas.
  TimeSkipSummary skipHours(int hours) {
    if (hours <= 0) return TimeSkipSummary.empty;
    return skipDuration(Duration(hours: hours));
  }

  /// Offline resume path: wall-clock delta, rewind = 0, hard-capped at 12h.
  TimeSkipSummary claimOffline({int? savedAtMs, DateTime? now}) {
    final blob = ref.read(savedGameProvider);
    final at = savedAtMs ?? (blob?['savedAt'] as num?)?.toInt();
    if (at == null || at == _lastClaimedSavedAt) return TimeSkipSummary.empty;
    final elapsed = TrustedClock.offlineDuration(savedAtMs: at, now: now);
    if (!TrustedClock.isWorthSimulating(elapsed)) return TimeSkipSummary.empty;
    _lastClaimedSavedAt = at;
    return skipDuration(elapsed, capOffline: true);
  }

  TimeSkipSummary skipDuration(Duration elapsed, {bool capOffline = false}) {
    var seconds = elapsed.inMilliseconds / 1000;
    if (capOffline) {
      seconds = min(seconds, TrustedClock.maxOffline.inSeconds.toDouble());
    }
    if (seconds <= 0) return TimeSkipSummary.empty;
    state = state.copyWith(skipping: true);
    try {
      return _simulate(seconds / 3600);
    } finally {
      state = state.copyWith(
        skipping: false,
        skipGeneration: state.skipGeneration + 1,
      );
    }
  }

  TimeSkipSummary _simulate(double hours) {
    var remaining = hours * 3600.0;
    var xp = 0;
    var gold = 0;
    var gems = 0;
    var kills = 0;
    var deaths = 0;
    var levels = 0;
    var bagFilled = false;
    final loot = <String, int>{};

    final player = ref.read(playerProvider.notifier);
    var stats = _boostedStats();
    // Full health so a mid-fight snapshot does not brick a long farm.
    var hp = stats.maxHp;

    var pendingHits = 0;
    var pendingDamage = 0;

    void flushCounters() {
      final scale = ref.read(prestigeProvider).masteryGainScale;
      if (pendingHits > 0) {
        player.recordHits((pendingHits * scale).round());
      }
      if (pendingDamage > 0) {
        player.recordDamageTakenAmount((pendingDamage * scale).round());
      }
      pendingHits = 0;
      pendingDamage = 0;
    }

    final maxEncounters = hours * 2500;
    var encounters = 0;
    final travel = ref.read(prestigeProvider).travelSeconds;
    while (remaining > travel && encounters < maxEncounters) {
      encounters++;
      remaining -= travel;
      stats = _boostedStats();
      final enemy = _pickSpawn(ref.read(currentLocationProvider));
      final fight = _fight(stats: stats, enemy: enemy, startHp: hp);
      remaining -= fight.seconds;
      pendingHits += fight.hits;
      pendingDamage += fight.damageTaken;

      if (fight.died) {
        deaths++;
        player.recordDeath();
        hp = stats.maxHp;
        remaining -= _recoverySeconds;
        if (encounters % 40 == 0) flushCounters();
        continue;
      }

      hp = fight.hp;
      final reward = _grantKill(enemy, stats);
      xp += reward.xp;
      gold += reward.gold;
      gems += reward.gems;
      levels += reward.levels;
      kills++;
      for (final e in reward.loot.entries) {
        loot[e.key] = (loot[e.key] ?? 0) + e.value;
      }
      if (reward.bagFilled) bagFilled = true;
      if (kills % 25 == 0) flushCounters();
    }

    flushCounters();
    player.addPlayTime(hours * 3600.0);

    return TimeSkipSummary(
      hours: hours.round(),
      xp: xp,
      gold: gold,
      gems: gems,
      kills: kills,
      deaths: deaths,
      levelsGained: levels,
      loot: loot,
      bagFilled: bagFilled,
    );
  }

  CombatStats _boostedStats() {
    return ref
        .read(baseCombatStatsProvider)
        .scaledGains(
          xp: state.xpElixirActive ? xpElixirMultiplier : 1,
          loot: state.doubleLootActive ? 2 : 1,
        )
        .withAlchemy(berserk: state.berserkActive, ward: state.wardActive);
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

  ({double seconds, double hp, bool died, int hits, int damageTaken}) _fight({
    required CombatStats stats,
    required EnemyDef enemy,
    required double startHp,
  }) {
    var playerHp = startHp;
    var enemyHp = enemy.maxHp;
    var playerCd = 0.0;
    var enemyCd = _rng.nextDouble() * 0.4 / enemy.attackSpeed;
    var time = 0.0;
    var hits = 0;
    var damageTaken = 0;
    final playerPeriod = 1 / stats.attackSpeed;
    final enemyPeriod = 1 / enemy.attackSpeed;
    final learned = ref.read(learnedPerksProvider);
    final thorns = (learned.thorns + ref.read(setThornsProvider)).clamp(
      0.0,
      0.6,
    );

    while (enemyHp > 0 && playerHp > 0 && time < _maxFightSeconds) {
      final toPlayer = max(0.001, playerPeriod - playerCd);
      final toEnemy = max(0.001, enemyPeriod - enemyCd);
      final dt = min(toPlayer, toEnemy);
      time += dt;
      playerCd += dt;
      enemyCd += dt;
      if (stats.hpRegen > 0 && playerHp < stats.maxHp) {
        playerHp = min(stats.maxHp, playerHp + stats.hpRegen * dt);
      }

      if (ref.read(settingsProvider).autoPotion &&
          playerHp / stats.maxHp <= 0.3) {
        final uid = ref.read(inventoryProvider.notifier).findPotionUid();
        if (uid != null) {
          final def = ref.read(inventoryProvider.notifier).consumeOne(uid);
          if (def != null && def.healAmount > 0) {
            playerHp = min(
              stats.maxHp,
              playerHp + def.healAmount * stats.maxHp,
            );
          }
        }
      }

      if (playerCd >= playerPeriod && enemyHp > 0) {
        playerCd -= playerPeriod;
        final hit = rollAttack(
          rng: _rng,
          damageMin: stats.damageMin,
          damageMax: stats.damageMax,
          critChance: stats.crit,
          critMultiplier: stats.critMultiplier,
          targetArmor: enemy.armor,
          targetDodge: enemy.dodge,
          fireDamage: stats.fireDamage,
        );
        if (!hit.dodged) {
          var damage = hit.damage;
          if (learned.execute > 0 && enemyHp / enemy.maxHp <= 0.25) {
            damage *= 1 + learned.execute;
          }
          enemyHp -= damage;
          hits++;
          if (stats.lifeSteal > 0) {
            playerHp = min(stats.maxHp, playerHp + damage * stats.lifeSteal);
          }
          if (learned.goldOnHit > 0) {
            ref
                .read(playerProvider.notifier)
                .gainGold(max(1, learned.goldOnHit.round()));
          }
        }
      }

      if (enemyHp > 0 && playerHp > 0 && enemyCd >= enemyPeriod) {
        enemyCd -= enemyPeriod;
        final hit = rollAttack(
          rng: _rng,
          damageMin: enemy.damageMin,
          damageMax: enemy.damageMax,
          critChance: enemy.crit,
          critMultiplier: 1.5,
          targetArmor: stats.armor,
          targetDodge: stats.dodge,
        );
        if (!hit.dodged) {
          final incoming = applyFireResist(
            hit.damage,
            fireHit: enemy.dealsFire,
            fireResist: stats.fireResist,
          );
          playerHp -= incoming;
          damageTaken += incoming.round().clamp(0, 100000);
          if (thorns > 0 && enemyHp > 0) {
            enemyHp -= max(1.0, hit.damage * thorns);
          }
        }
      }
    }

    final timedOut = time >= _maxFightSeconds && enemyHp > 0 && playerHp > 0;
    return (
      seconds: time,
      hp: timedOut ? 0 : playerHp,
      died: playerHp <= 0 || timedOut,
      hits: hits,
      damageTaken: damageTaken,
    );
  }

  ({
    int xp,
    int gold,
    int gems,
    int levels,
    Map<String, int> loot,
    bool bagFilled,
  })
  _grantKill(EnemyDef def, CombatStats stats) {
    final player = ref.read(playerProvider.notifier);
    final progress = ref.read(progressProvider.notifier);
    final inventory = ref.read(inventoryProvider.notifier);
    final settings = ref.read(settingsProvider);
    final loot = <String, int>{};
    var gold = 0;
    var bagFilled = false;

    final xp = max(1, (def.xp * stats.xpGain).round());
    final goldSpread = max(0, def.goldMax - def.goldMin);
    gold += max(
      1,
      ((def.goldMin + _rng.nextInt(goldSpread + 1)) * stats.goldFind).round(),
    );
    player.gainGold(gold);
    player.recordKill();
    progress.recordKill(def.id);
    ref.read(achievementsProvider.notifier).recordKill(isBoss: def.isBoss);
    ref.read(prestigeProvider.notifier).collectAchievementSouls();
    final levels = player.gainXp(xp);

    final gems = def.isBoss
        ? 1 + _rng.nextInt(3)
        : (_rng.nextDouble() < 0.02 ? 1 : 0);
    if (gems > 0) player.gainGems(gems);

    final doubleLootPerk = ref.read(learnedPerksProvider).doubleLoot;
    final tonic = state.doubleLootActive;
    final discovered = <String>[];

    for (final drop in def.loot) {
      final chance = min(0.95, drop.chance * stats.lootFind);
      if (_rng.nextDouble() >= chance) continue;
      final spread = max(0, drop.max - drop.min);
      var quantity = drop.min + _rng.nextInt(spread + 1);
      if (quantity <= 0) continue;
      if (doubleLootPerk > 0 && _rng.nextDouble() < doubleLootPerk) {
        quantity *= 2;
      }
      if (tonic) quantity *= 2;

      final item = tryItemById(drop.itemId);
      if (item == null) continue;
      discovered.add(item.id);

      if (settings.autoSellEnabled &&
          item.isEquipment &&
          item.rarity.index <= settings.autoSellRarity.index) {
        final sold = item.sellValue * quantity;
        player.gainGold(sold);
        gold += sold;
        continue;
      }

      final before = ref.read(inventoryProvider).bag.length;
      final outcome = inventory.add(drop.itemId, quantity);
      if (outcome == PickupOutcome.bagFull) {
        bagFilled = true;
        continue;
      }
      loot[item.id] = (loot[item.id] ?? 0) + quantity;
      final bag = ref.read(inventoryProvider).bag;
      if (settings.autoEquipUpgrades &&
          item.isEquipment &&
          bag.length > before &&
          bag.last.itemId == drop.itemId) {
        inventory.tryAutoEquip(bag.last.uid);
      }
    }
    if (discovered.isNotEmpty) progress.discoverItems(discovered);

    return (
      xp: xp,
      gold: gold,
      gems: gems,
      levels: levels,
      loot: loot,
      bagFilled: bagFilled,
    );
  }
}

final timeControllerProvider = NotifierProvider<TimeNotifier, TimeState>(
  TimeNotifier.new,
);
