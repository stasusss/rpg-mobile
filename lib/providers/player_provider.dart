import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/combat_math.dart';
import '../models/mastery.dart';
import '../models/stats.dart';
import 'achievements_provider.dart';
import 'save_provider.dart';

/// Progression and currencies. Deliberately free of derived combat numbers so
/// that gear and skill changes never invalidate it.
@immutable
class PlayerState {
  const PlayerState({
    this.level = 1,
    this.xp = 0,
    this.gold = 25,
    this.gems = 0,
    this.allocated = const {
      Attribute.strength: 5,
      Attribute.agility: 5,
      Attribute.endurance: 5,
      Attribute.intelligence: 5,
    },
    this.attributePoints = 0,
    this.skillPoints = 1,
    this.totalKills = 0,
    this.deaths = 0,
    this.playSeconds = 0,
    this.hitsDealt = 0,
    this.damageTaken = 0,
    this.itemsCrafted = 0,
  });

  final int level;
  final int xp;
  final int gold;
  final int gems;

  /// Load-only snapshot of the pre-mastery attribute map. Combat derives
  /// attributes from mastery counters. Kept so old saves can seed hits/damage.
  final Map<Attribute, int> allocated;
  final int attributePoints;
  final int skillPoints;
  final int totalKills;
  final int deaths;
  final double playSeconds;

  /// Landed auto-attacks. Levels Weapon Mastery and attack power.
  final int hitsDealt;

  /// Incoming damage absorbed. Levels Armor Mastery and max HP.
  final int damageTaken;

  /// Successful crafts this pilgrimage. Feeds the Altar of Rebirth.
  final int itemsCrafted;

  int get xpForNext => xpToNextLevel(level);
  double get xpFraction => (xp / xpForNext).clamp(0.0, 1.0);

  PlayerState copyWith({
    int? level,
    int? xp,
    int? gold,
    int? gems,
    Map<Attribute, int>? allocated,
    int? attributePoints,
    int? skillPoints,
    int? totalKills,
    int? deaths,
    double? playSeconds,
    int? hitsDealt,
    int? damageTaken,
    int? itemsCrafted,
  }) => PlayerState(
    level: level ?? this.level,
    xp: xp ?? this.xp,
    gold: gold ?? this.gold,
    gems: gems ?? this.gems,
    allocated: allocated ?? this.allocated,
    attributePoints: attributePoints ?? this.attributePoints,
    skillPoints: skillPoints ?? this.skillPoints,
    totalKills: totalKills ?? this.totalKills,
    deaths: deaths ?? this.deaths,
    playSeconds: playSeconds ?? this.playSeconds,
    hitsDealt: hitsDealt ?? this.hitsDealt,
    damageTaken: damageTaken ?? this.damageTaken,
    itemsCrafted: itemsCrafted ?? this.itemsCrafted,
  );

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp': xp,
    'gold': gold,
    'gems': gems,
    'allocated': {for (final e in allocated.entries) e.key.name: e.value},
    'attributePoints': attributePoints,
    'skillPoints': skillPoints,
    'totalKills': totalKills,
    'deaths': deaths,
    'playSeconds': playSeconds,
    'hitsDealt': hitsDealt,
    'damageTaken': damageTaken,
    'itemsCrafted': itemsCrafted,
  };

  static PlayerState fromJson(Map<String, dynamic> json) {
    final rawAlloc = json['allocated'] as Map<String, dynamic>? ?? const {};
    final allocated = <Attribute, int>{
      for (final attr in Attribute.values) attr: _readAttr(rawAlloc, attr),
    };
    final spentStr = (allocated[Attribute.strength] ?? 5) - 5;
    final spentEnd = (allocated[Attribute.endurance] ?? 5) - 5;
    return PlayerState(
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      gold: (json['gold'] as num?)?.toInt() ?? 25,
      gems: (json['gems'] as num?)?.toInt() ?? 0,
      allocated: allocated,
      attributePoints: (json['attributePoints'] as num?)?.toInt() ?? 0,
      skillPoints: (json['skillPoints'] as num?)?.toInt() ?? 0,
      totalKills: (json['totalKills'] as num?)?.toInt() ?? 0,
      deaths: (json['deaths'] as num?)?.toInt() ?? 0,
      playSeconds: (json['playSeconds'] as num?)?.toDouble() ?? 0,
      hitsDealt:
          (json['hitsDealt'] as num?)?.toInt() ??
          ActionMastery.cumulative(
            spentStr.clamp(0, 200),
            ActionMastery.hitsForNextWeapon,
          ),
      damageTaken:
          (json['damageTaken'] as num?)?.toInt() ??
          ActionMastery.cumulative(
            spentEnd.clamp(0, 200),
            ActionMastery.damageForNextArmor,
          ),
      itemsCrafted: (json['itemsCrafted'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    final saved = savedSection(ref, 'player');
    return saved == null ? const PlayerState() : PlayerState.fromJson(saved);
  }

  /// Adds XP and resolves any number of level ups. Returns levels gained.
  int gainXp(int amount) {
    if (amount <= 0) return 0;
    var xp = state.xp + amount;
    var level = state.level;
    var skillPts = state.skillPoints;
    var gained = 0;

    while (xp >= xpToNextLevel(level)) {
      xp -= xpToNextLevel(level);
      level++;
      gained++;
      skillPts += skillPointsPerLevel;
    }

    state = state.copyWith(xp: xp, level: level, skillPoints: skillPts);
    return gained;
  }

  void gainGold(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(gold: state.gold + amount);
    ref.read(achievementsProvider.notifier).recordGold(amount);
  }

  void gainGems(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(gems: state.gems + amount);
  }

  /// Deducts [amount] gold if affordable; returns whether it went through.
  bool spendGold(int amount) {
    if (amount > state.gold) return false;
    state = state.copyWith(gold: state.gold - amount);
    return true;
  }

  bool spendGems(int amount) {
    if (amount > state.gems) return false;
    state = state.copyWith(gems: state.gems - amount);
    return true;
  }

  bool spendSkillPoint() {
    if (state.skillPoints <= 0) return false;
    state = state.copyWith(skillPoints: state.skillPoints - 1);
    return true;
  }

  /// Atomic spend used when unlocking a skill node.
  bool spendUnlock({required int gold, required int skillPoints}) {
    if (gold < 0 || skillPoints < 0) return false;
    if (state.gold < gold || state.skillPoints < skillPoints) return false;
    state = state.copyWith(
      gold: state.gold - gold,
      skillPoints: state.skillPoints - skillPoints,
    );
    return true;
  }

  void refundSkillPoints(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(skillPoints: state.skillPoints + amount);
  }

  void recordKill() => state = state.copyWith(totalKills: state.totalKills + 1);

  void recordHit() => recordHits(1);

  /// Batched landed hits so combat can flush on a cadence instead of per swing.
  void recordHits(int count) {
    if (count <= 0) return;
    state = state.copyWith(hitsDealt: state.hitsDealt + count);
  }

  void recordDamageTaken(double amount) {
    recordDamageTakenAmount(amount.round().clamp(1, 100000));
  }

  void recordDamageTakenAmount(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(damageTaken: state.damageTaken + amount);
  }

  void recordDeath() => state = state.copyWith(deaths: state.deaths + 1);

  void recordCraft() =>
      state = state.copyWith(itemsCrafted: state.itemsCrafted + 1);

  void addPlayTime(double seconds) =>
      state = state.copyWith(playSeconds: state.playSeconds + seconds);

  /// Soft reset for the Altar of Rebirth. Keeps gems and the lifetime clock.
  void resetForAscension({int bonusGold = 0}) {
    state = PlayerState(
      gold: 25 + bonusGold,
      gems: state.gems,
      playSeconds: state.playSeconds,
      deaths: state.deaths,
    );
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

/// Reads a renamed attribute, falling back to the pre-rework save keys.
int _readAttr(Map<String, dynamic> raw, Attribute attr) {
  final aliases = switch (attr) {
    Attribute.strength => const ['strength'],
    Attribute.agility => const ['agility'],
    Attribute.endurance => const ['endurance', 'vitality'],
    Attribute.intelligence => const ['intelligence', 'dexterity'],
  };
  for (final key in aliases) {
    final value = raw[key];
    if (value is num) return value.toInt();
  }
  return 5;
}
