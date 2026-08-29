import 'package:flutter/foundation.dart';

/// Permanent blessings bought with Ash Souls. Survive every ascension.
enum MetaPerk {
  emberHeritage,
  ashenSwiftness,
  fortunePilgrim,
  soulResonance;

  int get cost => switch (this) {
    MetaPerk.emberHeritage => 5,
    MetaPerk.ashenSwiftness => 8,
    MetaPerk.fortunePilgrim => 10,
    MetaPerk.soulResonance => 12,
  };

  String get nameKey => 'perk.$name';
  String get descKey => 'perk.${name}Desc';
}

/// Extra gold granted by Ember Heritage on a new pilgrimage.
const int emberHeritageGold = 80;

/// Common (tier-1) scraps granted by Ember Heritage.
const Map<String, int> emberHeritageMats = {
  'slime_jelly': 8,
  'linen_scrap': 6,
  'charred_pelt': 4,
  'ashen_bark': 3,
};

/// Default travel time between fights, before Ashen Swiftness.
const double baseTravelSeconds = 1.1;

/// Breakdown of a soft-reset payout so the altar can show its work.
@immutable
class PrestigeYield {
  const PrestigeYield({
    required this.fromLocation,
    required this.fromKills,
    required this.fromCrafts,
    required this.locationIndex,
    required this.kills,
    required this.crafts,
  });

  final int fromLocation;
  final int fromKills;
  final int fromCrafts;
  final int locationIndex;
  final int kills;
  final int crafts;

  int get total {
    final raw = fromLocation + fromKills + fromCrafts;
    if (raw > 0) return raw;
    if (kills > 0 || crafts > 0 || locationIndex > 0) return 1;
    return 0;
  }

  bool get canAscend => total > 0;
}

/// Souls from the farthest node, blood spilled, and items forged this life.
PrestigeYield calculatePrestigeYield({
  required int highestLocationIndex,
  required int totalKills,
  required int itemsCrafted,
}) {
  return PrestigeYield(
    fromLocation: highestLocationIndex * 4,
    fromKills: totalKills ~/ 25,
    fromCrafts: itemsCrafted ~/ 3,
    locationIndex: highestLocationIndex,
    kills: totalKills,
    crafts: itemsCrafted,
  );
}

/// Persistent meta-progression. Never wiped by [executeAscension].
@immutable
class PrestigeState {
  const PrestigeState({
    this.ashSouls = 0,
    this.owned = const {},
  });

  final int ashSouls;
  final Set<MetaPerk> owned;

  bool has(MetaPerk perk) => owned.contains(perk);

  double get travelSeconds =>
      baseTravelSeconds / (has(MetaPerk.ashenSwiftness) ? 1.10 : 1.0);

  double get masteryGainScale => has(MetaPerk.soulResonance) ? 1.25 : 1.0;

  PrestigeState copyWith({int? ashSouls, Set<MetaPerk>? owned}) =>
      PrestigeState(
        ashSouls: ashSouls ?? this.ashSouls,
        owned: owned ?? this.owned,
      );

  Map<String, dynamic> toJson() => {
    'ashSouls': ashSouls,
    'owned': [for (final perk in owned) perk.name],
  };

  static PrestigeState fromJson(Map<String, dynamic> json) {
    final raw = json['owned'];
    final owned = <MetaPerk>{};
    if (raw is List) {
      for (final value in raw) {
        if (value is! String) continue;
        for (final perk in MetaPerk.values) {
          if (perk.name == value) owned.add(perk);
        }
      }
    }
    return PrestigeState(
      ashSouls: (json['ashSouls'] as num?)?.toInt() ?? 0,
      owned: owned,
    );
  }
}
