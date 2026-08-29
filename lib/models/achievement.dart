import 'package:flutter/foundation.dart';

/// Lifetime counters that feed the chronicle. Survive every ascension.
enum AchievementStat { kills, gold, prestiges, bosses }

@immutable
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.stat,
    required this.threshold,
    required this.soulReward,
  });

  final String id;
  final AchievementStat stat;
  final int threshold;
  final int soulReward;

  String get titleKey => 'achieve.$id.title';
  String get descKey => 'achieve.$id.desc';

  bool isMet(AchievementState state) => state.valueOf(stat) >= threshold;
}

/// Milestone ledger plus one-time soul payouts still waiting to be collected.
@immutable
class AchievementState {
  const AchievementState({
    this.lifetimeKills = 0,
    this.lifetimeGold = 0,
    this.lifetimePrestiges = 0,
    this.lifetimeBosses = 0,
    this.unlocked = const {},
    this.pendingAshSouls = 0,
  });

  final int lifetimeKills;
  final int lifetimeGold;
  final int lifetimePrestiges;
  final int lifetimeBosses;
  final Set<String> unlocked;
  final int pendingAshSouls;

  int valueOf(AchievementStat stat) => switch (stat) {
    AchievementStat.kills => lifetimeKills,
    AchievementStat.gold => lifetimeGold,
    AchievementStat.prestiges => lifetimePrestiges,
    AchievementStat.bosses => lifetimeBosses,
  };

  bool isUnlocked(String id) => unlocked.contains(id);

  AchievementState copyWith({
    int? lifetimeKills,
    int? lifetimeGold,
    int? lifetimePrestiges,
    int? lifetimeBosses,
    Set<String>? unlocked,
    int? pendingAshSouls,
  }) => AchievementState(
    lifetimeKills: lifetimeKills ?? this.lifetimeKills,
    lifetimeGold: lifetimeGold ?? this.lifetimeGold,
    lifetimePrestiges: lifetimePrestiges ?? this.lifetimePrestiges,
    lifetimeBosses: lifetimeBosses ?? this.lifetimeBosses,
    unlocked: unlocked ?? this.unlocked,
    pendingAshSouls: pendingAshSouls ?? this.pendingAshSouls,
  );

  Map<String, dynamic> toJson() => {
    'lifetimeKills': lifetimeKills,
    'lifetimeGold': lifetimeGold,
    'lifetimePrestiges': lifetimePrestiges,
    'lifetimeBosses': lifetimeBosses,
    'unlocked': unlocked.toList(),
    'pendingAshSouls': pendingAshSouls,
  };

  static AchievementState fromJson(Map<String, dynamic> json) =>
      AchievementState(
        lifetimeKills: (json['lifetimeKills'] as num?)?.toInt() ?? 0,
        lifetimeGold: (json['lifetimeGold'] as num?)?.toInt() ?? 0,
        lifetimePrestiges: (json['lifetimePrestiges'] as num?)?.toInt() ?? 0,
        lifetimeBosses: (json['lifetimeBosses'] as num?)?.toInt() ?? 0,
        unlocked: {
          for (final v in (json['unlocked'] as List<dynamic>? ?? const []))
            if (v is String) v,
        },
        pendingAshSouls: (json['pendingAshSouls'] as num?)?.toInt() ?? 0,
      );
}
